// LocationGroup.swift（完整修正后）
import MapKit
import SwiftUI
import ClipKit
import CoreLocation

@available(iOS 17, *)
struct LocationGroup: Identifiable, MapSelectable, Equatable, Hashable {
    typealias ID = UUID
    
    let id: UUID // 改为显式声明（方便自定义初始化器赋值）
    let coordinate: CLLocationCoordinate2D
    var items: [PasteboardItem]
    
    // 计算属性（不变）
    var count: Int { items.count }
    var timeRangeDescription: String {
        guard let first = items.first, let last = items.last else { return "" }
        return "\(first.date.formatted()) - \(last.date.formatted())"
    }
    
    // MARK: - 1. 业务用自定义初始化器（核心修复：供创建分组时调用）
    init(coordinate: CLLocationCoordinate2D, items: [PasteboardItem]) {
        self.id = UUID() // 生成唯一ID
        self.coordinate = coordinate // 传入位置坐标
        self.items = items // 传入该位置的剪贴项数组
    }
    
    // MARK: - 2. MapSelectable 协议必需初始化器（不变）
    init(_ feature: MapFeature?) {
        self.id = UUID() // 生成默认ID
        self.coordinate = feature?.coordinate ?? CLLocationCoordinate2D() // 默认坐标
        self.items = [] // 默认空数组
    }
    
    // MARK: - 3. MapSelectable 协议必需：feature 返回 nil（不变）
    var feature: MapFeature? { nil }
    
    // MARK: - Equatable（不变）
    static func == (lhs: LocationGroup, rhs: LocationGroup) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Hashable（不变）
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
