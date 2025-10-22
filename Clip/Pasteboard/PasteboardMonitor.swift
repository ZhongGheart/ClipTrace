//
//  PasteboardMonitor.swift
//  Clip
//
//  Created by Riley Testut on 6/11/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import AVFoundation
import UserNotifications
import CoreLocation

import ClipKit
import Roxas

private let PasteboardMonitorDidChangePasteboard: @convention(c) (CFNotificationCenter?, UnsafeMutableRawPointer?, CFNotificationName?, UnsafeRawPointer?, CFDictionary?) -> Void =
{ (center, observer, name, object, userInfo) in
    ApplicationMonitor.shared.pasteboardMonitor.didChangePasteboard()
}

private let PasteboardMonitorIgnoreNextPasteboardChange: @convention(c) (CFNotificationCenter?, UnsafeMutableRawPointer?, CFNotificationName?, UnsafeRawPointer?, CFDictionary?) -> Void =
{ (center, observer, name, object, userInfo) in
    ApplicationMonitor.shared.pasteboardMonitor.ignoreNextPasteboardChange = true
}

class PasteboardMonitor
{
    private(set) var isStarted = false
    fileprivate var ignoreNextPasteboardChange = false
    
    private let feedbackGenerator = UINotificationFeedbackGenerator()
}

extension PasteboardMonitor
{
    func start(completionHandler: @escaping (Result<Void, Error>) -> Void)
    {
        guard !self.isStarted else { return }
        self.isStarted = true
                
        self.registerForNotifications()
        completionHandler(.success(()))
    }
}

private extension PasteboardMonitor
{
    func registerForNotifications()
    {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(center, nil, PasteboardMonitorDidChangePasteboard, CFNotificationName.didChangePasteboard.rawValue, nil, .deliverImmediately)
        CFNotificationCenterAddObserver(center, nil, PasteboardMonitorIgnoreNextPasteboardChange, CFNotificationName.ignoreNextPasteboardChange.rawValue, nil, .deliverImmediately)
        
        #if !targetEnvironment(simulator)
        let beginListeningSelector = ["Notifications", "Change", "Pasteboard", "To", "Listening", "begin"].reversed().joined()
        
        let className = ["Connection", "Server", "PB"].reversed().joined()
        
        let PBServerConnection = NSClassFromString(className) as AnyObject
        _ = PBServerConnection.perform(NSSelectorFromString(beginListeningSelector))
        #endif
        
        let changedNotification = ["changed", "pasteboard", "apple", "com"].reversed().joined(separator: ".")
        NotificationCenter.default.addObserver(self, selector: #selector(PasteboardMonitor.pasteboardDidUpdate), name: Notification.Name(changedNotification), object: nil)
    }
    
    @objc func pasteboardDidUpdate()
    {
        guard !self.ignoreNextPasteboardChange else {
            self.ignoreNextPasteboardChange = false
            return
        }
        
        DispatchQueue.main.async {
            if UIApplication.shared.applicationState != .background
            {
                // Don't present notifications for items copied from within Clip.
                guard !UIPasteboard.general.contains(pasteboardTypes: [UTI.clipping]) else { return }
            }
            
            UNUserNotificationCenter.current().getNotificationSettings { (settings) in
                if settings.soundSetting == .enabled
                {
                    UIDevice.current.vibrate()
                }
            }            
            
            let content = UNMutableNotificationContent()
            content.categoryIdentifier = UNNotificationCategory.clipboardReaderIdentifier
            content.title = NSLocalizedString("Clipboard Changed", comment: "")
            content.body = NSLocalizedString("Swipe down to save to Clip.", comment: "")
            
            if let location = ApplicationMonitor.shared.locationManager.location
            {
                content.userInfo = [
                    UNNotification.latitudeUserInfoKey: location.coordinate.latitude,
                    UNNotification.longitudeUserInfoKey: location.coordinate.longitude
                ]
            }
            
            let request = UNNotificationRequest(identifier: "ClipboardChanged", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { (error) in
                if let error = error {
                    print(error)
                }
            }
        }
    }
}

private extension PasteboardMonitor
{
    func didChangePasteboard()
    {
        DatabaseManager.shared.refresh()
        
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["ClipboardChanged"])
    }
}

// Clip/Pasteboard/PasteboardMonitor.swift
private extension PasteboardMonitor {
    
    // 检查重复内容
    private func checkForDuplicateContent() -> Bool {
        guard let itemProvider = UIPasteboard.general.itemProviders.first else { return false }
        
        let context = DatabaseManager.shared.persistentContainer.viewContext
        let fetchRequest = PasteboardItem.fetchRequest() as NSFetchRequest<PasteboardItem>
        fetchRequest.predicate = NSPredicate(format: "%K == NO", #keyPath(PasteboardItem.isMarkedForDeletion))
        
        do {
            let existingItems = try context.fetch(fetchRequest)
            for item in existingItems {
                if item.isDuplicate(of: itemProvider) {
                    return true
                }
            }
        } catch {
            print("检查重复内容失败: \(error)")
        }
        return false
    }
    
    // 配置通知内容
    private func configureNotificationContent(_ content: UNMutableNotificationContent, isDuplicate: Bool) {
        if let text = UIPasteboard.general.string {
            // 文本内容预览（限制长度）
            let previewText = text.count > 100 ? String(text.prefix(100)) + "..." : text
            content.body = isDuplicate
                ? NSLocalizedString("已保存过，是否覆盖？", comment: "")
                : previewText
        } else if UIPasteboard.general.hasImages {
            // 图片内容提示
            content.body = isDuplicate
                ? NSLocalizedString("图片已保存过，是否覆盖？", comment: "")
                : NSLocalizedString("检测到图片，点击保存", comment: "")
        } else {
            // 其他类型内容
            content.body = isDuplicate
                ? NSLocalizedString("内容已保存过，是否覆盖？", comment: "")
                : NSLocalizedString("检测到新内容，点击保存", comment: "")
        }
    }
    
    // 创建通知附件（如图片缩略图）
    private func createNotificationAttachment() -> UNNotificationAttachment? {
        guard UIPasteboard.general.hasImages, let image = UIPasteboard.general.image else {
            return nil
        }
        
        // 处理图片缩略图
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString + ".png"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        guard let data = image.pngData() else { return nil }
        
        do {
            try data.write(to: fileURL)
            return try UNNotificationAttachment(identifier: "image", url: fileURL)
        } catch {
            print("创建图片附件失败: \(error)")
            return nil
        }
    }
}
