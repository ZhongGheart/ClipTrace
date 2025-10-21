//
//  CollageContentExtractor.swift
//  Clip
//
//  Created by 杨进 on 2025/10/20.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

// CollageContentExtractor.swift
import UIKit
import ClipKit

enum CollageContent {
    case text(String)
    case image(UIImage)
    case url(URL)
}

class CollageContentExtractor {
    static func extract(from item: PasteboardItem) -> [CollageContent] {
        var contents = [CollageContent]()
        
        // 提取图片
        if let image = item.representations.first(where: { $0.type == .image })?.value as? UIImage {
            contents.append(.image(image))
        }
        
        // 提取文本
        if let text = item.representations.first(where: { $0.type == .text })?.value as? String, !text.isEmpty {
            contents.append(.text(text))
        }
        
        // 提取链接
        if let url = item.representations.first(where: { $0.type == .url })?.value as? URL {
            contents.append(.url(url))
        }
        
        return contents
    }
}
