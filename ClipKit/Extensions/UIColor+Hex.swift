//
//  UIColor+Hex.swift
//  Clip
//
//  Created by 杨进 on 2025/10/22.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

import UIKit

extension UIColor {
    // 支持 hex 字符串（如 "#FFFFFF"、"FFFFFF"、"#FFF"、"FFF"）
    convenience init?(hex: String) {
        // 处理字符串格式
        let hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        
        // 检查长度是否合法
        guard hexString.count == 3 || hexString.count == 6 else {
            return nil
        }
        
        // 转换为RGB值
        var rgbValue: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgbValue)
        
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        
        if hexString.count == 3 {
            // 3位格式（如 "FFF"）
            red = CGFloat((rgbValue & 0xF00) >> 8) / 15.0
            green = CGFloat((rgbValue & 0x0F0) >> 4) / 15.0
            blue = CGFloat(rgbValue & 0x00F) / 15.0
        } else {
            // 6位格式（如 "FFFFFF"）
            red = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
            green = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
            blue = CGFloat(rgbValue & 0x0000FF) / 255.0
        }
        
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}
