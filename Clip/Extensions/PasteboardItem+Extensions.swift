//
//  PasteboardItem+Extensions.swift
//  Clip
//
//  Created by 杨进 on 2025/10/21.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

// PasteboardItem+Extensions.swift
import ClipKit
import UIKit

extension PasteboardItem {
    // 提取文本类型的内容（文本、URL等）
    var textRepresentation: String? {
        // 假设 representations 中包含文本类型的表示（如 .text 或 .url）
        // 根据实际项目中 PasteboardRepresentation 的类型定义调整
        if let textRep = representations.first(where: { $0.type == .text }),
           let text = textRep.value as? String {
            return text
        } else if let urlRep = representations.first(where: { $0.type == .url }),
                  let url = urlRep.value as? URL {
            return url.absoluteString // URL 也作为文本展示
        }
        return nil
    }
    
    // 提取图片类型的内容（补充代码中用到的 image 属性）
    var image: UIImage? {
        if let imageRep = representations.first(where: { $0.type == .image }),
           let image = imageRep.value as? UIImage {
            return image
        }
        return nil
    }
}
