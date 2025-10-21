//
//  CollageEditorViewController.swift
//  Clip
//
//  Created by 杨进 on 2025/10/20.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

// CollageEditorViewController.swift
import UIKit
import ClipKit

class CollageEditorViewController: UIViewController {
    private let items: [PasteboardItem]
    private let collageView = UIImageView()
    private var currentCollageImage: UIImage?
    
    // 添加回调闭包，用于通知是否需要保留选中状态
    var onDismiss: ((Bool) -> Void)?  // true: 保留选中, false: 清除选中
    
    
    // 样式选项
    private let backgroundOptions = [UIColor.white, UIColor.systemGray5, UIColor.systemPink.withAlphaComponent(0.1)]
    private let borderWidths = [0, 2, 4]
    private var selectedBackground: UIColor = .white
    private var selectedBorderWidth: Int = 2
    
    init(items: [PasteboardItem]) {
        self.items = items
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    // 在CollageEditorViewController中添加更多布局选项
    private let layoutOptions = ["Vertical", "Grid", "Masonry"]
    private var selectedLayout: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "拼贴编辑"
        
        // 导航栏按钮
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareCollage))
        
        // 拼贴预览
        collageView.contentMode = .scaleAspectFit
        view.addSubview(collageView)
        collageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            collageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            collageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            collageView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.6)
        ])
        
        // 生成初始拼贴
        generateCollage()
        
        // 添加样式选择器（简化版：使用分段控件）
        let backgroundControl = UISegmentedControl(items: ["白色", "灰色", "粉色"])
        backgroundControl.selectedSegmentIndex = 0
        backgroundControl.addTarget(self, action: #selector(backgroundChanged(_:)), for: .valueChanged)
        
        let borderControl = UISegmentedControl(items: ["无边框", "细边框", "粗边框"])
        borderControl.selectedSegmentIndex = 1
        borderControl.addTarget(self, action: #selector(borderChanged(_:)), for: .valueChanged)
        
        let stackView = UIStackView(arrangedSubviews: [backgroundControl, borderControl])
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 16
        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    private func generateCollage() {
        // 生成拼贴图片（核心逻辑）
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 800))
        currentCollageImage = renderer.image { context in
            // 绘制背景
            selectedBackground.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 600, height: 800))
            
            // 绘制边框
            if selectedBorderWidth > 0 {
                UIColor.systemGray3.setStroke()
                let borderPath = UIBezierPath(rect: CGRect(x: CGFloat(selectedBorderWidth)/2,
                                                           y: CGFloat(selectedBorderWidth)/2,
                                                           width: 600 - CGFloat(selectedBorderWidth),
                                                           height: 800 - CGFloat(selectedBorderWidth)))
                borderPath.lineWidth = CGFloat(selectedBorderWidth)
                borderPath.stroke()
            }
            
            // 排版内容（垂直布局）
            var yOffset: CGFloat = 20
            let contentWidth: CGFloat = 560
            
            for item in items {
                let contentRect = CGRect(x: 20, y: yOffset, width: contentWidth, height: 0)
                
                // 根据内容类型绘制
                if let image = item.representations.first(where: { $0.type == .image })?.value as? UIImage {
                    // 绘制图片
                    let scaledHeight = (contentWidth / image.size.width) * image.size.height
                    let imageRect = CGRect(x: 20, y: yOffset, width: contentWidth, height: scaledHeight)
                    image.draw(in: imageRect)
                    yOffset += scaledHeight + 16
                } else if let text = item.representations.first(where: { $0.type == .text })?.value as? String {
                    // 绘制文本
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 16),
                        .foregroundColor: UIColor.black
                    ]
                    let textSize = text.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                                                     options: .usesLineFragmentOrigin,
                                                     attributes: attributes,
                                                     context: nil).size
                    text.draw(in: CGRect(x: 20, y: yOffset, width: contentWidth, height: textSize.height),
                              withAttributes: attributes)
                    yOffset += textSize.height + 16
                } else if let url = item.representations.first(where: { $0.type == .url })?.value as? URL {
                    // 绘制链接
                    let urlText = url.absoluteString
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 16),
                        .foregroundColor: UIColor.systemBlue
                    ]
                    urlText.draw(in: CGRect(x: 20, y: yOffset, width: contentWidth, height: 20),
                                 withAttributes: attributes)
                    yOffset += 36
                }
                
                // 超过高度限制时停止绘制
                if yOffset > 780 { break }
            }
        }
        
        collageView.image = currentCollageImage
    }
    
    @objc private func backgroundChanged(_ sender: UISegmentedControl) {
        selectedBackground = backgroundOptions[sender.selectedSegmentIndex]
        generateCollage()
    }
    
    @objc private func borderChanged(_ sender: UISegmentedControl) {
        selectedBorderWidth = borderWidths[sender.selectedSegmentIndex]
        generateCollage()
    }
    
    @objc private func cancel() {
        dismiss(animated: true) {
            // 取消时通知保留选中状态
            self.onDismiss?(true)
        }
    }
    
    @objc private func shareCollage() {
        guard let image = currentCollageImage else { return }
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        
        // 分享完成后通知清除选中状态
        activityVC.completionWithItemsHandler = { [weak self] _, _, _, _ in
            self?.dismiss(animated: true) {
                self?.onDismiss?(false)
            }
        }
        
        present(activityVC, animated: true)
    }
    
}
