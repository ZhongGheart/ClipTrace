import SwiftUI
import ClipKit
import UIKit
import CoreLocation

@available(iOS 17.0, *)
struct LocationClippingsView: View {
    // 核心数据：可能是一个分组，也可能是单个item（内部转为分组处理）
    private let group: LocationGroup
    
    @Environment(\.dismiss) private var dismiss
    
    // 支持两种初始化方式：接收分组 或 单个item
    init(group: LocationGroup) {
        self.group = group
    }
    
    init(pasteboardItem: PasteboardItem) {
        // 将单个item包装为一个分组（复用现有逻辑）
        let coordinate = pasteboardItem.location?.coordinate ?? CLLocationCoordinate2D()
        self.group = LocationGroup(coordinate: coordinate, items: [pasteboardItem])
    }
    
    private var sortedItems: [PasteboardItem] {
        group.items.sorted { $0.date > $1.date }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section(group.timeRangeDescription) {
                    ForEach(sortedItems, id: \.objectID) { item in
                        NavigationLink {
                            ClippingDetailView(pasteboardItem: item)
                        } label: {
                            ClippingCell(pasteboardItem: item)
                        }
                    }
                }
            }
            .navigationTitle("\(group.count) 条记录")
            .navigationBarItems(
                leading: Button("关闭") { dismiss() },
                trailing: Menu("全部操作") {
                    Button("全部复制") { copyAllItems() }
                    Button("全部分享") { shareAllItems() }
                }
            )
        }
        .presentationBackground(Material.regular)
        .presentationDetents([.medium, .large])
        .tint(.init(uiColor: .clipPink))
    }
    
    private func copyAllItems() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, .ignoreNextPasteboardChange, nil, nil, true)
        
        let allText = group.items.compactMap { $0.textRepresentation }.joined(separator: "\n\n")
        UIPasteboard.general.string = allText
        
        dismiss()
    }
    
    private func shareAllItems() {
        let allText = group.items.compactMap { $0.textRepresentation }.joined(separator: "\n\n")
        let activityVC = UIActivityViewController(activityItems: [allText], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            if let presentedVC = rootVC.presentedViewController {
                presentedVC.dismiss(animated: true) {
                    rootVC.present(activityVC, animated: true)
                }
            } else {
                rootVC.present(activityVC, animated: true)
            }
        }
    }
}
