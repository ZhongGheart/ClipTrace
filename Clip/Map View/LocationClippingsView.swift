import SwiftUI
import ClipKit
import UIKit

@available(iOS 17.0, *)
struct LocationClippingsView: View {
    let group: LocationGroup
    
    @Environment(\.dismiss) private var dismiss
    
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
