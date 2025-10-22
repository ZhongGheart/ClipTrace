// PredicateSafetyChecker.swift
import Foundation
import CoreData

@objcMembers  // 关键：暴露所有成员给Objective-C
class PredicateSafetyChecker: NSObject {  // 必须继承NSObject
    /// 检查并返回安全的谓词（移除nil参数）
    static func safePredicate(from predicate: NSPredicate?) -> NSPredicate {
        guard let predicate = predicate else {
            return NSPredicate(value: true)
        }
        
        // 处理复合谓词
        if let compound = predicate as? NSCompoundPredicate {
            let safeSubpredicates = compound.subpredicates.compactMap { $0 as? NSPredicate }.map { safePredicate(from: $0) }
            return NSCompoundPredicate(type: compound.compoundPredicateType, subpredicates: safeSubpredicates)
        }
        
        // 处理基础比较谓词
        if let comparison = predicate as? NSComparisonPredicate {
            let leftValue = evaluate(expression: comparison.leftExpression)
            let rightValue = evaluate(expression: comparison.rightExpression)
            
            // 若左右值有nil，返回安全谓词
            if leftValue == nil || rightValue == nil {
                return NSPredicate(value: true)
            }
        }
        
        return predicate
    }
    
    /// 计算表达式的值（判断是否为nil）
    private static func evaluate(expression: NSExpression) -> Any? {
        do {
            return try expression.expressionValue(with: nil, context: nil)
        } catch {
            return nil
        }
    }
}
