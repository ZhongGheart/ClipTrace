//
//  PasteboardItem.swift
//  Clip
//
//  Created by Riley Testut on 6/11/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import CoreData
import MobileCoreServices
import CoreLocation

private extension PasteboardItemRepresentation.RepresentationType
{
    var priority: Int {
        switch self
        {
        case .attributedText: return 0
        case .text: return 1
        case .url: return 2
        case .image: return 3
        }
    }
}

@objc(PasteboardItem)
public class PasteboardItem: NSManagedObject, Identifiable
{
    /* Properties */
    @NSManaged public private(set) var date: Date
    @NSManaged public var isMarkedForDeletion: Bool
    
    public var location: CLLocation? {
        get {
            guard let latitude, let longitude else { return nil }
            
            let coordinate = CLLocation(latitude: latitude.doubleValue, longitude: longitude.doubleValue)
            return coordinate
        }
        set {
            self.latitude = newValue?.coordinate.latitude as? NSNumber
            self.longitude = newValue?.coordinate.longitude as? NSNumber
        }
    }
    @NSManaged private var latitude: NSNumber?
    @NSManaged private var longitude: NSNumber?
    
    /* Relationships */
    @nonobjc public var representations: [PasteboardItemRepresentation] {
        return self._representations.array as! [PasteboardItemRepresentation]
    }
    @NSManaged @objc(representations) private var _representations: NSOrderedSet
    
    @NSManaged public var preferredRepresentation: PasteboardItemRepresentation?
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?)
    {
        super.init(entity: entity, insertInto: context)
    }
    
    public init?(representations: [PasteboardItemRepresentation], context: NSManagedObjectContext)
    {
        guard !representations.isEmpty else { return nil }
        
        super.init(entity: PasteboardItem.entity(), insertInto: context)
        
        self._representations = NSOrderedSet(array: representations)
        
        let prioritizedRepresentationTypes = PasteboardItemRepresentation.RepresentationType.allCases.sorted { $0.priority > $1.priority }
        for type in prioritizedRepresentationTypes
        {
            guard let representation = representations.first(where: { $0.type == type }) else { continue }
            
            self.preferredRepresentation = representation
            break
        }
    }
    
    override public func awakeFromInsert()
    {
        super.awakeFromInsert()
        
        self.date = Date()
    }
}

public extension PasteboardItem
{
    @nonobjc class func fetchRequest() -> NSFetchRequest<PasteboardItem>
    {
        return NSFetchRequest<PasteboardItem>(entityName: "PasteboardItem")
    }
    
    class func historyFetchRequest() -> NSFetchRequest<PasteboardItem>
    {
        let fetchRequest = PasteboardItem.fetchRequest() as NSFetchRequest<PasteboardItem>
        fetchRequest.predicate = NSPredicate(format: "%K == NO", #keyPath(PasteboardItem.isMarkedForDeletion))
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PasteboardItem.date, ascending: false)]
        fetchRequest.fetchLimit = UserDefaults.shared.historyLimit.rawValue
        return fetchRequest
    }
}

// SwiftUI
extension PasteboardItem
{
    class func make(item: NSItemProviderWriting, date: Date = Date(), context: NSManagedObjectContext) -> PasteboardItem
    {
        let itemProvider = NSItemProvider(object: item)
        let semaphore = DispatchSemaphore(value: 0)
        
        let childContext = DatabaseManager.shared.persistentContainer.newBackgroundContext()
        var objectID: NSManagedObjectID!
        
        PasteboardItemRepresentation.representations(for: itemProvider, in: childContext) { (representations) in
            let item = PasteboardItem(representations: representations, context: childContext)!
            item.date = date
            
            try! childContext.obtainPermanentIDs(for: [item])
            objectID = item.objectID
            
            try! childContext.save()
            semaphore.signal()
        }
        semaphore.wait()
        
        let pasteboardItem = context.object(with: objectID) as! PasteboardItem
        return pasteboardItem
    }
}

// ClipKit/Database/Model/PasteboardItem.swift
public extension PasteboardItem {
    func isDuplicate(of itemProvider: NSItemProvider) -> Bool {
        let currentRepresentations = self.representations.reduce(into: Set<String>()) {
            $0.insert($1.uti)
        }
        
        let itemTypes = Set(itemProvider.registeredTypeIdentifiers)
        return currentRepresentations.intersection(itemTypes).count > 0
    }
}

// 辅助方法：获取最新剪贴板项目
extension DatabaseManager {
    public func latestPasteboardItem() -> PasteboardItem? {
        let fetchRequest = PasteboardItem.fetchRequest() as NSFetchRequest<PasteboardItem>
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PasteboardItem.date, ascending: false)]
        fetchRequest.fetchLimit = 1
        
        do {
            return try persistentContainer.viewContext.fetch(fetchRequest).first
        } catch {
            print("获取最新剪贴板项目失败: \(error)")
            return nil
        }
    }
}

/// ClipKit/Database/Model/PasteboardItem.swift (完整扩展代码)
extension PasteboardItem {
    // 1. 新增：用于 Core Data 存储的内容类型原始值（必须@NSManaged，需在数据模型中添加该字段）
    @NSManaged public var contentTypeRawValue: String?
    
    // 2. 公开 ContentType 枚举（跨模块访问需 public）
    public enum ContentType: String {
        case text, link, image, phoneNumber, email, address, code, unknown
    }
    
    // 3. 公开 contentType 计算属性，关联 rawValue 存储
    public var contentType: ContentType {
        // 优先从存储的 rawValue 读取，避免重复计算
        if let rawValue = contentTypeRawValue, let type = ContentType(rawValue: rawValue) {
            return type
        }
        
        // 原识别逻辑（计算后同步到 rawValue）
        let type: ContentType
        if representations.contains(where: { $0.type == .image }) {
            type = .image
        } else if let text = textRepresentation {
            if text.lowercased().hasPrefix("http://") || text.lowercased().hasPrefix("https://") {
                type = .link
            } else if NSPredicate(format: "SELF MATCHES %@", "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}").evaluate(with: text) {
                type = .email
            } else if NSPredicate(format: "SELF MATCHES %@", "^[+]?[(]?[0-9]{1,4}[)]?[-\\s.]?[0-9]{1,4}[-\\s.]?[0-9]{1,9}$").evaluate(with: text) {
                type = .phoneNumber
            } else if NSPredicate(format: "SELF MATCHES[c] %@", ".*\\d+.*(street|st|road|rd|avenue|ave|lane|ln|drive|dr|court|ct|circle|cir|boulevard|blvd|city|town|county|state|zip|postal|country).*").evaluate(with: text) {
                type = .address
            } else if NSPredicate(format: "SELF MATCHES %@", ".*(function|class|import|def|print|return|var|let|const|if|else|for|while|{|}).*").evaluate(with: text) {
                type = .code
            } else {
                type = .text
            }
        } else {
            type = .unknown
        }
        
        // 同步到 rawValue（避免下次重复计算）
        self.contentTypeRawValue = type.rawValue
        return type
    }
    
    // 4. 公开文本提取属性（之前已加，确保 public）
    public var textRepresentation: String? {
        if let textRep = representations.first(where: { $0.type == .text }), let text = textRep.value as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let attrRep = representations.first(where: { $0.type == .attributedText }), let attrText = attrRep.value as? NSAttributedString {
            return attrText.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
    
    // 5. 公开标签关系与方法（之前已加，确保 public）
    @NSManaged public var tags: Set<ClipKit.Tag>
    public func addTag(_ tag: ClipKit.Tag) { tags.insert(tag); tag.items.insert(self) }
    public func removeTag(_ tag: ClipKit.Tag) { tags.remove(tag); tag.items.remove(self) }
}

// 6. 公开 ContentType 的本地化名称和颜色（跨模块访问需 public）
public extension PasteboardItem.ContentType {
    var localizedName: String {
        switch self {
        case .text: NSLocalizedString("Text", comment: "")
        case .link: NSLocalizedString("Link", comment: "")
        case .image: NSLocalizedString("Image", comment: "")
        case .phoneNumber: NSLocalizedString("Phone", comment: "")
        case .email: NSLocalizedString("Email", comment: "")
        case .address: NSLocalizedString("Address", comment: "")
        case .code: NSLocalizedString("Code", comment: "")
        case .unknown: NSLocalizedString("Unknown", comment: "")
        }
    }
    
    var color: UIColor {
        switch self {
        case .text: .systemBlue
        case .link: .systemGreen
        case .image: .systemPurple
        case .phoneNumber: .systemOrange
        case .email: .systemRed
        case .address: .systemTeal
        case .code: .systemIndigo
        case .unknown: .systemGray
        }
    }
}
