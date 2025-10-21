//
//  ClippingTableViewCell.swift
//  Clip
//
//  Created by Riley Testut on 6/13/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit

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
}
