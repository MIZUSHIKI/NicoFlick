//
//  AppDelegate.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/04/29.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//

import UIKit
import TwitterKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    static let PHPURL = "http://timetag.main.jp/nicoflick/nicoflick.php"
    //static let PHPURL = "http://192.168.11.7/nicoflick_20201103/nicoflick.php" //windows xampp
    //static let PHPURL = "http://127.0.0.1:8888/nicoflick.php" //mac mamp PC
    //static let PHPURL = "http://MacBook.local:8000/nicoflick.php" //mac mamp スマホ
    
    static let NICOFLICK_PATH = "https://main-timetag.ssl-lolipop.jp/nicoflick/"
    //static let NICOFLICK_PATH = "http://192.168.11.7/nicoflick_20201103/"
    
    static let NicoApiURL_GetThumbInfo = "http://ext.nicovideo.jp/api/getthumbinfo/"
    static let Version = 1907
    static var ServerErrorMessage = ""
    static var DidEnterBackgroundTime:Date?

    static let MIZUSHIKI_IDxxx = "358ED61B-F5F1-4A70-BF39-************"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        TWTRTwitter.sharedInstance().start(withConsumerKey:"XrswCPUMoXr3EZUk22mJmCWKx",consumerSecret:"hrTsCmcBBEVdOLphMHTK0fgsKr2CJ6Hk5jEIeRCpB6bLHC8U1S")
        return true
    }
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if TWTRTwitter.sharedInstance().application(app, open: url, options: options) {
            return true
        }
        print(app)
        print(url)
        print(options)
        // Your other open URL handlers follow […]
        return false
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        AppDelegate.DidEnterBackgroundTime = Date()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        if let backDate = AppDelegate.DidEnterBackgroundTime {
            if backDate.timeIntervalSinceNow < -60.0 {
                //アプリ閉じて60秒以上立ってたら動画のキャッシュを削除する
                print("Cached(Thumb)Movies削除")
                CachedMovies.sharedInstance.cachedMovies = [] //HeartBeat切れるとアクセス出来なくなる
                CachedThumbMovies.sharedInstance.cachedMovies = [] //HeartBeatすらしてない(ver.1.9.1〜してる可能性あり)
            }
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

