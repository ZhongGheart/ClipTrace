//
//  TagFilterViewController.swift
//  Clip
//
//  Created by 杨进 on 2025/10/21.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

// Clip/Tags/TagFilterViewController.swift
import UIKit
import CoreData
import ClipKit

class TagFilterViewController: UITableViewController {
    // 筛选结果回调（返回选中的标签）
    var selectedTags: [Tag] = []
    var onApplyFilter: (([Tag]) -> Void)?
    
    private var allTags: [Tag] = []
    private var context: NSManagedObjectContext {
        DatabaseManager.shared.persistentContainer.viewContext
    }
    
    // 新增：内容类型筛选（可选）
    var selectedContentType: ClipKit.PasteboardItem.ContentType?
    private let contentTypes: [ClipKit.PasteboardItem.ContentType] = [.text, .link, .image, .phoneNumber, .email, .address, .code]
    
    // 新增：分区标识（标签筛选 + 内容类型筛选）
    private enum Section: Int, CaseIterable {
        case tags // 标签筛选分区
        case contentType // 内容类型筛选分区
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // 注册默认单元格（或自定义 XIB 单元格）
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "TagFilterCell")
        
        title = NSLocalizedString("Filter by Tags", comment: "")
        loadTags()
        
        // 添加“应用筛选”按钮
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("Apply", comment: ""),
            style: .done,
            target: self,
            action: #selector(applyFilter)
        )
        
        // 新增：注册内容类型筛选单元格
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ContentTypeCell")
        
    }
    
    // 加载所有标签
    private func loadTags() {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        do {
            allTags = try context.fetch(request)
        } catch {
            print("Failed to load tags: \(error)")
        }
    }
    
    // 新增：分区数量（2个分区：标签 + 内容类型）
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    // 新增：分区标题
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else { return nil }
        switch section {
        case .tags: return NSLocalizedString("Tags", comment: "标签")
        case .contentType: return NSLocalizedString("Content Type", comment: "内容类型")
        }
    }
    
    
    // 应用筛选（回调选中的标签）
    @objc private func applyFilter() {
        onApplyFilter?(selectedTags)
        dismiss(animated: true)
    }
    
    // MARK: - 表格数据源
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        switch section {
        case .tags: return allTags.count
        case .contentType: return contentTypes.count
        }
    }
    // 修正：单元格配置（按分区显示标签或内容类型）
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else { return UITableViewCell() }
        
        switch section {
        case .tags:
            // 原有：标签单元格（不变）
            let cell = tableView.dequeueReusableCell(withIdentifier: "TagCell", for: indexPath)
            let tag = allTags[indexPath.row]
            cell.textLabel?.text = tag.name
            cell.accessoryType = selectedTags.contains(tag) ? .checkmark : .none
            if let color = UIColor.init(hex: tag.color) {
                cell.imageView?.backgroundColor = color
                cell.imageView?.layer.cornerRadius = 10
                cell.imageView?.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
            }
            return cell
            
        case .contentType:
            // 新增：内容类型单元格
            let cell = tableView.dequeueReusableCell(withIdentifier: "ContentTypeCell", for: indexPath)
            let type = contentTypes[indexPath.row]
            cell.textLabel?.text = type.localizedName
            cell.accessoryType = (selectedContentType == type) ? .checkmark : .none
            cell.textLabel?.textColor = type.color // 显示对应类型的颜色
            return cell
        }
    }
    
    // 修正：单元格点击事件（按分区处理标签或内容类型）
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = Section(rawValue: indexPath.section) else { return }
        
        switch section {
        case .tags:
            // 原有：标签选择逻辑（不变）
            let tag = allTags[indexPath.row]
            if let index = selectedTags.firstIndex(of: tag) {
                selectedTags.remove(at: index)
            } else {
                selectedTags.append(tag)
            }
            
        case .contentType:
            // 新增：内容类型选择逻辑（单选）
            let type = contentTypes[indexPath.row]
            selectedContentType = (selectedContentType == type) ? nil : type
        }
        
        // 刷新当前分区
        tableView.reloadSections([indexPath.section], with: .automatic)
    }
    
}
