//
//  MovieAccessClass.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/04/30.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation

class MovieAccess{
    
    let session = URLSession(configuration: .default)
    var firstAttack = true
    
    init(){
        //不要になった
    }
    
    //(ログアウト確認→)ニコページアクセス→再生 処理
    func StreamingUrlNicoAccess(smNum: String, callback: @escaping (String) -> Void ) -> Void {
        
        //先にキャッシュ内にあるか確認。あればもうニコニコの動画ページにすらアクセスしないことにする
        if CachedMovies.sharedInstance.cachedMovies.contains(where: { $0.smNum == smNum }){
            callback("cached")
            return
        }
        let strURL = String.init(format: "https://www.nicovideo.jp/watch/%@",smNum);
        let url = URL(string: strURL)
        let task2 = self.session.dataTask(with: url!){  (data, responce, error) in
            if error != nil {
                print("StreamingUrlNicoAccess-error")//エラー。例えばオフラインとか
                return
            }
            guard let data = data else { return }
            //動画ページにアクセス。動画URLを取得
            let str:String = String(data: data, encoding: String.Encoding.utf8)!
            //ニコニコにログインしてたらログアウトする
            if self.firstAttack && !str.contains("user.login_status = 'not_login';"){
                //ニコニコから強制ログアウト（しないとURLSessionとAVURLAssetとでうまく噛み合わない？）
                let url = URL(string:"https://account.nicovideo.jp/logout?site=spniconico&sec=header_spweb&cmnhd_ref=device%3Dsp%26site%3Dspniconico%26pos%3Duserpanel%26page%3Dtop")!
                let task = self.session.dataTask(with: url){(data,responce,error) in
                    print("ログアウト")
                    //もう一度アクセス
                    self.StreamingUrlNicoAccess(smNum: smNum, callback: callback)
                }
                task.resume()
                return
            }
            self.firstAttack = false
            let watchTrackId = str.pregMatche_firstString(pattern: "&quot;watchTrackId&quot;:&quot;([a-zA-Z0-9_]+?)&quot;")
            print(String.init(format: "watchTrackId=%@",watchTrackId))
            let accessRightKey = str.pregMatche_firstString(pattern: "&quot;accessRightKey&quot;:&quot;([a-zA-Z0-9_\\.-]+?)&quot;")
            print(String.init(format: "accessRightKey=%@",accessRightKey))
            var videos:[String] = str.pregMatche_strings(pattern:  "&quot;id&quot;:&quot;(video-[a-zA-Z0-9]+-\\d+p(?:-low(?:est)?)?)&quot;,&quot;isAvailable&quot;:true")
            //dump(videos)
            var audios:[String] = str.pregMatche_strings(pattern:  "&quot;id&quot;:&quot;(audio-[a-zA-Z0-9]+-\\d+kbps)&quot;,&quot;isAvailable&quot;:true")
            //dump(audios)
            if watchTrackId != "" && accessRightKey != "" && !videos.isEmpty && !audios.isEmpty {
                var video = ""
                var audio = audios[1]
                let reachability = AMReachability()
                if (reachability?.isReachable)! {
                    print("インターネット接続あり")
                    if (reachability?.isReachableViaWiFi)!{
                        print("Wifi接続有り")
                        video = videos[1]
                    }else {
                        print("Wifi接続なし")
                        video = videos[videos.count - 1]
                    }
                } else {
                    print("インターネット接続なし")
                    video = videos[videos.count - 1]
                }
                
                let url = URL(string:"https://nvapi.nicovideo.jp/v1/watch/"+smNum+"/access-rights/hls?actionTrackId="+watchTrackId)!
                print("https://nvapi.nicovideo.jp/v1/watch/"+smNum+"/access-rights/hls?actionTrackId="+watchTrackId)
                var req = URLRequest(url: url, timeoutInterval: 21.0)
                req.httpMethod = "POST"
                req.setValue(accessRightKey, forHTTPHeaderField: "X-Access-Right-Key")
                req.setValue("6", forHTTPHeaderField: "X-Frontend-Id")
                req.setValue("0", forHTTPHeaderField: "X-Frontend-Version")
                req.setValue("https://www.nicovideo.jp", forHTTPHeaderField: "X-Request-With")
                let body = String.init(format: "{\"outputs\": [[\"%@\",\"%@\"]]}", video, audio)
                print(body)
                req.httpBody = body.data(using: String.Encoding.utf8)
                print("CMAF:post")
                let task3 = self.session.dataTask(with: req){(data,responce,error) in
                    if error != nil {
                        print("NicoAccess-error")//エラー。例えばオフラインとか
                        //callbackも返さないので、動画読み込み処理は途中で止まることになる。
                        return
                    }
                    guard
                        let data = data,
                        let url = responce?.url,
                        let httpResponse = responce as? HTTPURLResponse,
                        let fields = httpResponse.allHeaderFields as? [String: String]
                    else { return }
                    
                    let str:String = String(data: data, encoding: String.Encoding.utf8)!
                    print("CMAF:post:result")
                    //print(str)
                    let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
                    HTTPCookieStorage.shared.setCookies(cookies, for: url, mainDocumentURL: nil)
                    for cookie in cookies {
                        var cookieProperties = [HTTPCookiePropertyKey: Any]()
                        cookieProperties[.name] = cookie.name
                        cookieProperties[.value] = cookie.value
                        cookieProperties[.domain] = cookie.domain
                        cookieProperties[.path] = cookie.path
                        cookieProperties[.version] = cookie.version
                        cookieProperties[.expires] = Date().addingTimeInterval(31536000)

                        let newCookie = HTTPCookie(properties: cookieProperties)
                        HTTPCookieStorage.shared.setCookie(newCookie!)

                        //print("name: \(cookie.name) value: \(cookie.value)")
                    }
                    let contentUrl = str.pregMatche_firstString(pattern: "\"contentUrl\":\"(.+?)\"")
                    print(contentUrl)
                    callback(contentUrl)
                }
                task3.resume()
            }
        }
        task2.resume()
    }
    
    // 最終的にStreamingUrlNicoAccessとほぼ変わらなくなったけどまだ根本から分かれてる
    func StreamingUrlNicoAccessForThumbMovie(smNum: String, callback: @escaping (String) -> Void ) -> Void {
        
        //先にキャッシュ内にあるか確認。あればもうニコニコの動画ページにすらアクセスしないことにする
        if CachedThumbMovies.sharedInstance.containsWithinExpiration(smNum: smNum){
            callback("cached")
            return
        }
        let strURL = String.init(format: "https://www.nicovideo.jp/watch/%@",smNum);
        let url = URL(string: strURL)
        let task2 = self.session.dataTask(with: url!){  (data, responce, error) in
            if error != nil {
                print("StreamingUrlNicoAccess-error")//エラー。例えばオフラインとか
                return
            }
            guard let data = data else { return }
            //動画ページにアクセス。動画URLを取得
            let str:String = String(data: data, encoding: String.Encoding.utf8)!
            //ニコニコにログインしてたらログアウトする
            if self.firstAttack && !str.contains("user.login_status = 'not_login';"){
                //ニコニコから強制ログアウト（しないとURLSessionとAVURLAssetとでうまく噛み合わない？）
                let url = URL(string:"https://account.nicovideo.jp/logout?site=spniconico&sec=header_spweb&cmnhd_ref=device%3Dsp%26site%3Dspniconico%26pos%3Duserpanel%26page%3Dtop")!
                let task = self.session.dataTask(with: url){(data,responce,error) in
                    print("ログアウト")
                    //もう一度アクセス
                    self.StreamingUrlNicoAccessForThumbMovie(smNum: smNum, callback: callback)
                }
                task.resume()
                return
            }
            self.firstAttack = false
            let watchTrackId = str.pregMatche_firstString(pattern: "&quot;watchTrackId&quot;:&quot;([a-zA-Z0-9_]+?)&quot;")
            print(String.init(format: "watchTrackId=%@",watchTrackId))
            let accessRightKey = str.pregMatche_firstString(pattern: "&quot;accessRightKey&quot;:&quot;([a-zA-Z0-9_\\.-]+?)&quot;")
            print(String.init(format: "accessRightKey=%@",accessRightKey))
            var videos:[String] = str.pregMatche_strings(pattern:  "&quot;id&quot;:&quot;(video-[a-zA-Z0-9]+-\\d+p(?:-low(?:est)?)?)&quot;,&quot;isAvailable&quot;:true")
            //dump(videos)
            var audios:[String] = str.pregMatche_strings(pattern:  "&quot;id&quot;:&quot;(audio-[a-zA-Z0-9]+-\\d+kbps)&quot;,&quot;isAvailable&quot;:true")
            //dump(audios)
            if watchTrackId != "" && accessRightKey != "" && !videos.isEmpty && !audios.isEmpty {
                let video = videos[videos.count - 1]  // thumb用は軽量で(360p)
                let audio = audios[1]
                
                let url = URL(string:"https://nvapi.nicovideo.jp/v1/watch/"+smNum+"/access-rights/hls?actionTrackId="+watchTrackId)!
                print("https://nvapi.nicovideo.jp/v1/watch/"+smNum+"/access-rights/hls?actionTrackId="+watchTrackId)
                var req = URLRequest(url: url, timeoutInterval: 21.0)
                req.httpMethod = "POST"
                req.setValue(accessRightKey, forHTTPHeaderField: "X-Access-Right-Key")
                req.setValue("6", forHTTPHeaderField: "X-Frontend-Id")
                req.setValue("0", forHTTPHeaderField: "X-Frontend-Version")
                req.setValue("https://www.nicovideo.jp", forHTTPHeaderField: "X-Request-With")
                let body = String.init(format: "{\"outputs\": [[\"%@\",\"%@\"]]}", video, audio)
                print(body)
                req.httpBody = body.data(using: String.Encoding.utf8)
                print("CMAF:post")
                let task3 = self.session.dataTask(with: req){(data,responce,error) in
                    if error != nil {
                        print("NicoAccess-error")//エラー。例えばオフラインとか
                        //callbackも返さないので、動画読み込み処理は途中で止まることになる。
                        return
                    }
                    guard
                        let data = data,
                        let url = responce?.url,
                        let httpResponse = responce as? HTTPURLResponse,
                        let fields = httpResponse.allHeaderFields as? [String: String]
                    else { return }
                    
                    let str:String = String(data: data, encoding: String.Encoding.utf8)!
                    print("CMAF:post:result")
                    //print(str)
                    let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
                    HTTPCookieStorage.shared.setCookies(cookies, for: url, mainDocumentURL: nil)
                    for cookie in cookies {
                        var cookieProperties = [HTTPCookiePropertyKey: Any]()
                        cookieProperties[.name] = cookie.name
                        cookieProperties[.value] = cookie.value
                        cookieProperties[.domain] = cookie.domain
                        cookieProperties[.path] = cookie.path
                        cookieProperties[.version] = cookie.version
                        cookieProperties[.expires] = Date().addingTimeInterval(31536000)
                        
                        let newCookie = HTTPCookie(properties: cookieProperties)
                        HTTPCookieStorage.shared.setCookie(newCookie!)
                        
                        //print("name: \(cookie.name) value: \(cookie.value)")
                    }
                    let contentUrl = str.pregMatche_firstString(pattern: "\"contentUrl\":\"(.+?)\"")
                    print(contentUrl)
                    callback(contentUrl)
                }
                task3.resume()
            }
        }
        task2.resume()
    }
}
