//
//  TagEditorViewController.swift
//  Clip
//
//  Created by 杨进 on 2025/10/21.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

// Clip/Tags/TagEditorViewController.swift
import UIKit
import CoreData
import ClipKit

class TagEditorViewController: UITableViewController {
    var pasteboardItem: PasteboardItem!
    var allTags: [Tag] = []
    private var context: NSManagedObjectContext {
        return DatabaseManager.shared.persistentContainer.viewContext
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Manage Tags", comment: "")
        loadTags()
        
        // 添加新建标签按钮
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addNewTag)
        )
    }
    
    private func loadTags() {
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            allTags = try context.fetch(fetchRequest)
        } catch {
            print("Error fetching tags: \(error)")
        }
    }
    
    @objc private func addNewTag() {
        let alert = UIAlertController(
            title: NSLocalizedString("New Tag", comment: ""),
            message: NSLocalizedString("Enter tag name", comment: ""),
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = NSLocalizedString("Tag name", comment: "")
        }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Add", comment: ""), style: .default) { [weak self] _ in
            guard let self = self, let name = alert.textFields?.first?.text, !name.isEmpty else { return }
            
            let tag = Tag(context: self.context)
            tag.name = name
            tag.color = self.randomTagColor()
            
            do {
                try self.context.save()
                self.allTags.append(tag)
                self.tableView.reloadData()
            } catch {
                print("Error saving new tag: \(error)")
            }
        })
        
        present(alert, animated: true)
    }
    
    private func randomTagColor() -> String {
        let colors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#FFA07A", "#98D8C8", "#F7DC6F", "#BB8FCE", "#5DADE2"]
        return colors.randomElement()!
    }
    
    // 表格数据源和代理方法
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allTags.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TagCell", for: indexPath)
        let tag = allTags[indexPath.row]
        
        cell.textLabel?.text = tag.name
        cell.accessoryType = pasteboardItem.tags.contains(tag) ? .checkmark : .none
        
        // 设置标签颜色
            cell.imageView?.backgroundColor = UIColor.clipPink
            cell.imageView?.layer.cornerRadius = 10
            cell.imageView?.frame = CGRect(x: 0, y: 0, width: 20, height: 20)

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let tag = allTags[indexPath.row]
        
        if pasteboardItem.tags.contains(tag) {
            pasteboardItem.removeTag(tag)
        } else {
            pasteboardItem.addTag(tag)
        }
        
        do {
            try context.save()
            tableView.reloadRows(at: [indexPath], with: .automatic)
        } catch {
            print("Error updating tags: \(error)")
        }
    }
}
