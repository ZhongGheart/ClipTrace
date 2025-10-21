//
//  AppDelegate.swift
//  Clip
//
//  Created by Riley Testut on 6/10/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import UserNotifications

import ClipKit
import Roxas

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
    {
        // Override point for customization after application launch.
        print(RoxasVersionNumber)
        
        self.window?.tintColor = .clipPantone
        
        UserDefaults.shared.registerAppDefaults()
        
        func printError<T>(from result: Result<T, Error>, title: String)
        {
            guard let error = result.error else { return }
            print(title, error)
        }
        
        // 数据库初始化完成后再启动监控
        DatabaseManager.shared.prepare() { [weak self] result in
            printError(from: result, title: "Database Error:")
            
            // 初始化成功后才启动监控和刷新数据
            if case .success = result {
                ApplicationMonitor.shared.start()
                
                // 首次启动时主动刷新数据（确保数据加载）
                DatabaseManager.shared.refresh()
            } else {
                print("数据库初始化失败，无法启动核心功能")
            }
        }
        
        self.registerForNotifications()
        
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }
    
    func applicationDidEnterBackground(_ application: UIApplication)
    {
#if targetEnvironment(simulator)
        // Audio extension hack to access pasteboard doesn't work in simulator, so for testing just start background task.
        RSTBeginBackgroundTask("com.rileytestut.Clip.simulatorBackgroundTask")
#endif
        
        DatabaseManager.shared.purge()
    }
    
    func applicationWillEnterForeground(_ application: UIApplication)
    {
        DatabaseManager.shared.refresh()
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate
{
    private func registerForNotifications()
    {
        let category = UNNotificationCategory(identifier: UNNotificationCategory.clipboardReaderIdentifier, actions: [], intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
        
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (success, error) in
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        completionHandler(.alert)
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void)
    {
        guard response.notification.request.content.categoryIdentifier == UNNotificationCategory.clipboardReaderIdentifier else { return }
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        
        let location = ApplicationMonitor.shared.locationManager.location
        
        // Delay until next run loop so UIPasteboard no longer returns nil items due to being in background.
        DispatchQueue.main.async {
            DatabaseManager.shared.savePasteboard(location: location) { (result) in
                switch result
                {
                case .success: break
                case .failure(PasteboardError.duplicateItem): break
                    
                case .failure(let error):
                    DispatchQueue.main.async {
                        let alertController = UIAlertController(title: NSLocalizedString("Failed to Save Clipboard", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
                        alertController.addAction(.ok)
                        self.window?.rootViewController?.present(alertController, animated: true, completion: nil)
                    }
                }
                
                print("Save clipboard with result:", result)
                
                completionHandler()
            }
        }
    }
}
