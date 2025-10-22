//
//  ClippingTableViewCell.swift
//  Clip
//
//  Created by Riley Testut on 6/13/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import ClipKit

@objc(ClippingTableViewCell)
class ClippingTableViewCell: UITableViewCell
{
    @IBOutlet var clippingView: UIView!
    
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var dateLabel: UILabel!
    @IBOutlet var contentLabel: UILabel!
    @IBOutlet var contentImageView: UIImageView!
    @IBOutlet var locationButton: UIButton!
    
    @IBOutlet var bottomConstraint: NSLayoutConstraint!
    
    // 新增：内容类型标签
    @IBOutlet var typeLabel: UILabel!
    // 新增：标签显示标签（或保留 tagsStackView，二选一）
    @IBOutlet var tagsLabel: UILabel!
    
    // 添加标签显示控件
    @IBOutlet var tagsContainer: UIView!
    @IBOutlet var tagsStackView: UIStackView!
    
    // 添加选择状态图标
    var selectionIndicator = UIImageView()
    
    override func awakeFromNib()
    {
        super.awakeFromNib()
        
        self.clippingView.layer.cornerRadius = 10
        self.clippingView.layer.masksToBounds = true
        
        self.contentImageView.layer.cornerRadius = 10
        self.contentImageView.layer.masksToBounds = true
        
        // 配置选择指示器
        selectionIndicator = UIImageView()
        selectionIndicator.translatesAutoresizingMaskIntoConstraints = false
        selectionIndicator.contentMode = .center
        selectionIndicator.layer.cornerRadius = 12
        selectionIndicator.layer.borderWidth = 2
        selectionIndicator.clipsToBounds = true
        clippingView.addSubview(selectionIndicator)
        
        
        // 添加约束（左上角显示）
        NSLayoutConstraint.activate([
            selectionIndicator.widthAnchor.constraint(equalToConstant: 24),
            selectionIndicator.heightAnchor.constraint(equalToConstant: 24),
            selectionIndicator.leadingAnchor.constraint(equalTo: clippingView.leadingAnchor, constant: 12),
            selectionIndicator.centerYAnchor.constraint(equalTo: clippingView.centerYAnchor),
        ])
        // 将zPosition设置移到约束激活外面
        selectionIndicator.layer.zPosition = 1
        // 默认隐藏
        selectionIndicator.isHidden = true
    }
    // 更新选择状态样式
    func updateSelectionState(isSelected: Bool) {
        if isSelected {
            // 选中状态：勾选图标
            selectionIndicator.backgroundColor = UIColor.clipPink
            selectionIndicator.layer.borderColor = UIColor.clipPink.cgColor
            selectionIndicator.image = UIImage(systemName: "checkmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .bold))
            selectionIndicator.tintColor = .white
        } else {
            // 未选中状态：空心圆
            selectionIndicator.backgroundColor = .clear
            selectionIndicator.layer.borderColor = UIColor.systemGray3.cgColor
            selectionIndicator.image = nil
        }
    }
    
    // 更新标签显示
    func updateTags(_ tags: Set<Tag>) {
        
//        let tagNames = tags.map { $0.name }.joined(separator: ", ")
//        tagsLabel.text = tagNames.isEmpty ? nil : tagNames // 无标签时隐藏
        
        // 清除现有标签
        tagsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // 添加新标签
        for tag in tags {
            let tagView = UIView()
            tagView.backgroundColor = .clipLightPink
            tagView.layer.cornerRadius = 12
            
            let label = UILabel()
            label.text = tag.name
            label.font = UIFont.systemFont(ofSize: 12)
            label.textColor = .white
            label.translatesAutoresizingMaskIntoConstraints = false
            
            tagView.addSubview(label)
            tagsStackView.addArrangedSubview(tagView)
            
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: tagView.leadingAnchor, constant: 8),
                label.trailingAnchor.constraint(equalTo: tagView.trailingAnchor, constant: -8),
                label.topAnchor.constraint(equalTo: tagView.topAnchor, constant: 4),
                label.bottomAnchor.constraint(equalTo: tagView.bottomAnchor, constant: -4),
                tagView.heightAnchor.constraint(equalToConstant: 24)
            ])
        }
    }
}
