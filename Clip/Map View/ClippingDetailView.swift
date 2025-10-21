//
//  ClippingDetailView.swift
//  Clip
//
//  Created by 杨进 on 2025/10/21.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

import SwiftUI
import ClipKit

// 4. 创建剪贴项详情视图（增强版）
@available(iOS 16.4, *)
struct ClippingDetailView: View {
    let pasteboardItem: PasteboardItem
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let text = pasteboardItem.textRepresentation {
                    Text(text)
                        .font(.body)
                        .padding()
                } else if let image = pasteboardItem.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("复制时间")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(pasteboardItem.date.formatted())
                        .font(.subheadline)
                }
                .padding()
                
                if let location = pasteboardItem.location {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("位置信息")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("纬度: \(location.coordinate.latitude)\n经度: \(location.coordinate.longitude)")
                            .font(.subheadline)
                    }
                    .padding()
                }
            }
            .padding()
        }
        .navigationTitle("剪贴详情")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("拷贝") {
                    copyItem()
                }
            }
            
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") {
                    dismiss()
                }
            }
        }
    }
    
    private func copyItem() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, .ignoreNextPasteboardChange, nil, nil, true)
        
        UIPasteboard.general.copy(pasteboardItem)
        dismiss()
    }
}
