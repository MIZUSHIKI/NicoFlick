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
        var avPlayerViewController:AVPlayerViewController
    }
    
    static let sharedInstance = CachedMovies()
    //保存データ
    let userData = UserData.sharedInstance
    
    var cachedMovies:[CachedMovie] = []
    
    func access(url:URL) -> AVPlayerViewController {
        //読み込み済みの物があればそれを返す
        for i in 0 ..< cachedMovies.count {
            if cachedMovies[i].url == url {
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
                    cachedMovies.remove(at: i) //ロード中なのはlastとは限らない
                    //print("cachedMovies.remove")
                    break //そして１つだけ
                }
            }
        }
        if cachedMovies.count > 0{
        }
        //URLから動画をロード
        let avPlayerItem = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: avPlayerItem)
        let avPlayerViewController = AVPlayerViewController()
        avPlayerViewController.player = avPlayer
        //  コントローラ非表示（？）
        avPlayerViewController.showsPlaybackControls = false
        //  viewのタッチアクションを下に透過（スルー）させるようにして、ムービーViewには何も干渉出来ないようにする
        avPlayerViewController.view.isUserInteractionEnabled = false
        
        let cashedMovie = CachedMovie(url: url, avPlayerViewController: avPlayerViewController)
        cachedMovies.append(cashedMovie)
        
        while cachedMovies.count > userData.cachedMovieNum {
            cachedMovies.removeFirst()
        }
        
        return avPlayerViewController
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
