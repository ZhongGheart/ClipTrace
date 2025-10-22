// ClipKit/Database/Model/Tag.swift（最终正确代码）
import CoreData
import UIKit

// 1. 自定义 Objective-C 类名，彻底避免冲突
@objc(ClipKit_Tag)
// 2. 明确类属于 ClipKit 模块（文件在 ClipKit 目录下，无需额外声明）
public class Tag: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var color: String // 十六进制颜色，如 "#FF6B6B"
    // 3. 明确 items 关联的是 ClipKit 的 PasteboardItem
    @NSManaged public var items: Set<ClipKit.PasteboardItem>
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        color = "#FF6B6B" // 默认颜色
    }
}

public extension Tag {
    // 4. 明确 fetchRequest 的实体名（与 Core Data 实体名一致）
    @nonobjc class func fetchRequest() -> NSFetchRequest<Tag> {
        return NSFetchRequest<Tag>(entityName: "Tag")
    }
}
