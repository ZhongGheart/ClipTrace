//
//  HistoryMapView.swift
//  Clip
//
//  Created by Riley Testut on 3/20/24.
//  Copyright © 2024 Riley Testut. All rights reserved.
//

import MapKit
import UIKit
import SwiftUI

import ClipKit

@available(iOS 17, *)
class ClippingsMapViewController: UIHostingController<AnyView>
{
    @MainActor
    required dynamic init?(coder aDecoder: NSCoder) {
        let view = AnyView(erasing: ClippingsMapView().environment(\.managedObjectContext, DatabaseManager.shared.persistentContainer.viewContext))
        super.init(coder: aDecoder, rootView: view)
        
        self.tabBarItem.image = UIImage(systemName: "map")
    }
}

@MainActor @available(iOS 17, *)
struct ClippingsMapView: View
{
    @FetchRequest(fetchRequest: PasteboardItem.historyFetchRequest())
    private var pasteboardItems: FetchedResults<PasteboardItem>
    
    // 按位置分组的剪贴项
    private var locationGroups: [LocationGroup] {
        groupItemsByLocation()
    }
    
    
    // 选中的单个item
    @State private var selectedItem: PasteboardItem?
    // 选中item所属的组（新增）
    @State private var selectedGroup: LocationGroup?
    
    var body: some View {
        Map(selection: $selectedItem) {
            // Must use \.self as keypath for selection to work
            ForEach(pasteboardItems, id: \.self) { pasteboardItem in
                if let location = pasteboardItem.location
                {
                    Marker(pasteboardItem.date.formatted(), systemImage: "paperclip", coordinate: location.coordinate)
                }
            }
        }
        // 监听选中item的变化，查找其所属的组
        .onChange(of: selectedItem) { item in
            guard let item = item else {
                selectedGroup = nil
                return
            }
            // 遍历分组，找到包含当前item的组（通过objectID精准匹配）
            selectedGroup = locationGroups.first { group in
                group.items.contains { $0.objectID == item.objectID }
            }
        }
        // 根据找到的组展示弹窗
        .sheet(item: $selectedGroup) { group in
            LocationClippingsView(group: group)
        }
    }
    
    
    // 按位置分组，考虑一定的坐标误差范围
    private func groupItemsByLocation(tolerance: CLLocationDegrees = 0.001) -> [LocationGroup] {
        let validItems = pasteboardItems.compactMap { $0.location != nil ? $0 : nil }
        var groups: [LocationGroup] = []
        
        for item in validItems {
            guard let location = item.location else { continue }
            
            // 查找相似位置的分组
            if let existingIndex = groups.firstIndex(where: { group in
                let distance = CLLocation(latitude: group.coordinate.latitude, longitude: group.coordinate.longitude)
                    .distance(from: location)
                return distance < 10 // 1米以内视为同一位置
            }) {
                // 添加到现有分组
                var updatedGroup = groups[existingIndex]
                updatedGroup.items.append(item)
                groups[existingIndex] = updatedGroup
            } else {
                // 创建新分组
                groups.append(LocationGroup(
                    coordinate: location.coordinate,
                    items: [item]
                ))
            }
        }
        
        // 按每组记录数量排序，多的在前
        return groups.sorted { $0.count > $1.count }
    }
}
