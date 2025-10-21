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
        self.tabBarItem.title = NSLocalizedString("Map", comment: "标签栏中“地图”功能的名称")
    }
}

// 2. 修改地图视图，实现按位置分组显示
@MainActor @available(iOS 17, *)
struct ClippingsMapView: View {
    @FetchRequest(fetchRequest: PasteboardItem.historyFetchRequest())
    private var pasteboardItems: FetchedResults<PasteboardItem>
    
    // 按位置分组的剪贴项
    private var locationGroups: [LocationGroup] {
        groupItemsByLocation()
    }
    
    @State private var selectedGroup: LocationGroup?
    
    var body: some View {
        Map(selection: $selectedGroup) {
            ForEach(locationGroups) { group in
                Marker(
                    "\(group.count) 条记录",
                    systemImage: "paperclip.circle.fill",
                    coordinate: group.coordinate
                )
                .tint(Color(UIColor.clipPink))
            }
        }
        .sheet(item: $selectedGroup) { group in
            LocationClippingsView(group: group)
        }
        .navigationTitle(NSLocalizedString("Location History", comment: "地图视图标题"))
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
                return distance < 100 // 100米以内视为同一位置
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
