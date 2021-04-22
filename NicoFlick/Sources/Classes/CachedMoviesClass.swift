//
//  CachedMoviesClass.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2018/06/07.
//  Copyright © 2018年 i.MIZUSHIKI. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation

class CachedMovies {
    
    struct CachedMovie {
        var url:URL
        var smNum:String
        var avPlayerViewController:AVPlayerViewController
    }
    
    static let sharedInstance = CachedMovies()
    //保存データ
    let userData = UserData.sharedInstance
    
    var cachedMovies:[CachedMovie] = []
    
    func access(url:URL,smNum:String) -> AVPlayerViewController {
        //読み込み済みの物があればそれを返す
        for i in 0 ..< cachedMovies.count {
            if cachedMovies[i].smNum == smNum {
                cachedMovies.append(cachedMovies[i])
                cachedMovies.remove(at: i)
                while cachedMovies.count > userData.cachedMovieNum {
                    cachedMovies.removeFirst()
                }
                return (cachedMovies.last?.avPlayerViewController)!
            }
        }
        //ムービーロード状況確認。2重読み込みを防ぐため、ロード中の物があれば削除する
        for bi in 0 ..< cachedMovies.count {
            let i = cachedMovies.count - bi - 1
            let loadedTime = cachedMovies[i].avPlayerViewController.player?.currentItem?.loadedTimeRanges.asTimeRanges.first?.end
            let duration = cachedMovies[i].avPlayerViewController.player?.currentItem?.duration
            //print(loadedTime)
            //print(duration)
            if loadedTime != nil {
                let per = CGFloat(CMTimeGetSeconds(loadedTime!)/CMTimeGetSeconds(duration!))
                print(per)
                if per < 0.99 {
                    cachedMovies[i].avPlayerViewController.player = nil
                    cachedMovies.remove(at: i) //ロード中なのはlastとは限らない
                    //print("cachedMovies.remove")
                    break //そして１つだけ
                }
            }
        }
        //URLから動画をロード
        let cookiesArray = HTTPCookieStorage.shared.cookies! //Stored Cookies of your request
        let values = HTTPCookie.requestHeaderFields(with: cookiesArray)// Returns a dictionary of header fields corresponding to a provided array of cookies.ex.["Cookie":"your cookies values"]
        let cookieArrayOptions = ["AVURLAssetHTTPHeaderFieldsKey": values]
        let assets = AVURLAsset(url: url as URL, options: cookieArrayOptions)
        let avPlayerItem = AVPlayerItem(asset: assets)
        
        //var options:[String:Any] = [:]
        //if let cookies = HTTPCookieStorage.shared.cookies{
        //    options[AVURLAssetHTTPCookiesKey] = cookies
        //    print("cookies=")
        //    print(cookies)
        //}
        //let assets:AVURLAsset = .init(url: url, options: options)
        //let avPlayerItem:AVPlayerItem = .init(asset: assets)
        
        //let avPlayerItem = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: avPlayerItem)
        let avPlayerViewController = AVPlayerViewController()
        avPlayerViewController.player = avPlayer
        //  コントローラ非表示（？）
        avPlayerViewController.showsPlaybackControls = false
        //  viewのタッチアクションを下に透過（スルー）させるようにして、ムービーViewには何も干渉出来ないようにする
        avPlayerViewController.view.isUserInteractionEnabled = false
        
        let cashedMovie = CachedMovie(url: url, smNum: smNum, avPlayerViewController: avPlayerViewController)
        cachedMovies.append(cashedMovie)
        
        while cachedMovies.count > userData.cachedMovieNum {
            cachedMovies.first?.avPlayerViewController.player = nil
            cachedMovies.removeFirst()
        }
        
        return avPlayerViewController
    }
    func remove(smNum:String){
        for i in 0 ..< cachedMovies.count {
            if cachedMovies[i].smNum == smNum {
                cachedMovies[i].avPlayerViewController.player = nil
                cachedMovies.remove(at: i)
                return
            }
        }
    }
}
class CachedThumbMovies {
    
    class CachedMovie {
        let url:URL
        let smNum:String
        let avPlayerViewController:AVPlayerViewController
        var check:Int
        var time:Date
        init(url:URL, smNum:String, avPlayerViewController:AVPlayerViewController, check:Int) {
            self.url = url
            self.smNum = smNum
            self.avPlayerViewController = avPlayerViewController
            self.check = check
            self.time = Date()
        }
    }
    
    static let sharedInstance = CachedThumbMovies()
    //保存データ
    let userData = UserData.sharedInstance
    
    var cachedMovies:[CachedMovie] = []
    
    func access(url:URL,smNum:String) -> AVPlayerViewController {
        
        // プレイ指示して、5秒間再生されてない状態が続くとHeartBeat切れとみなしcheck=2になっている(Selectorで)。なのでキャッシュを削除
        // もしくは、もう120秒たったら強制的に読み込みし直しにしてしまう、か。
        let num = cachedMovies.count
        for i in 0 ..< num {
            let index = num - 1 - i
            if !withinExpiration(cachedMovie: cachedMovies[index] ){
                print("cached削除 - \(cachedMovies[index].smNum)")
                cachedMovies[index].avPlayerViewController.player = nil
                cachedMovies.remove(at: index)
            }
        }
        //読み込み済みの物があればそれを返す
        for i in 0 ..< cachedMovies.count {
            if cachedMovies[i].smNum == smNum {
                cachedMovies.append(cachedMovies[i])
                cachedMovies.remove(at: i)
                while cachedMovies.count > 20 {
                    cachedMovies.first?.avPlayerViewController.player = nil
                    cachedMovies.removeFirst()
                }
                cachedMovies.last?.check = 0
                return (cachedMovies.last?.avPlayerViewController)!
            }
        }
        
        //URLから動画をロード
        let cookiesArray = HTTPCookieStorage.shared.cookies! //Stored Cookies of your request
        let values = HTTPCookie.requestHeaderFields(with: cookiesArray)// Returns a dictionary of header fields corresponding to a provided array of cookies.ex.["Cookie":"your cookies values"]
        let cookieArrayOptions = ["AVURLAssetHTTPHeaderFieldsKey": values]
        let assets = AVURLAsset(url: url as URL, options: cookieArrayOptions)
        let avPlayerItem = AVPlayerItem(asset: assets)
        
        //var options:[String:Any] = [:]
        //if let cookies = HTTPCookieStorage.shared.cookies{
        //    options[AVURLAssetHTTPCookiesKey] = cookies
        //    print("cookies=")
        //    print(cookies)
        //}
        //let assets:AVURLAsset = .init(url: url, options: options)
        //let avPlayerItem:AVPlayerItem = .init(asset: assets)
        
        //let avPlayerItem = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: avPlayerItem)
        let avPlayerViewController = AVPlayerViewController()
        avPlayerViewController.player = avPlayer
        //  コントローラ非表示（？）
        avPlayerViewController.showsPlaybackControls = false
        //  viewのタッチアクションを下に透過（スルー）させるようにして、ムービーViewには何も干渉出来ないようにする
        avPlayerViewController.view.isUserInteractionEnabled = false
        
        let cachedMovie = CachedMovie(url: url, smNum: smNum, avPlayerViewController: avPlayerViewController, check: 0)
        cachedMovies.append(cachedMovie)
        
        while cachedMovies.count > 20 {
            cachedMovies.first?.avPlayerViewController.player = nil
            cachedMovies.removeFirst()
        }
        
        return avPlayerViewController
    }
    func withinExpiration(cachedMovie:CachedMovie) -> Bool{
        return cachedMovie.check != 2 && cachedMovie.time.timeIntervalSinceNow > -120
    }
    func containsWithinExpiration(smNum:String) -> Bool {
        return cachedMovies.contains(where: {$0.smNum == smNum && withinExpiration(cachedMovie: $0)})
    }
    
}
// Convert a collection of NSValues into an array of CMTimeRanges.
private extension Collection where Iterator.Element == NSValue {
    var asTimeRanges : [CMTimeRange] {
        return self.map({ value -> CMTimeRange in
            return value.timeRangeValue
        })
    }
}
