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
            var st = str.pregMatche_firstString(pattern: "<div id=\"js-initial-watch-data\" data-api-data=\"(.*?)\" hidden></div>")
            st.htmlDecode()
            if let nicoDMC = NicoDmc(smNum: smNum, js_initial_watch_data: st, isThumbMovie: false) {
                nicoDMC.eco = false
                let session = URLSession(configuration: URLSessionConfiguration.default)
                let url = URL(string:"https://api.dmc.nico/api/sessions?_format=json")!
                var req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
                let body = nicoDMC.sessionFormatJson
                req.httpMethod = "POST"
                req.httpBody = body.data(using: String.Encoding.utf8)
                let task3 = session.dataTask(with: req){(data,responce,error) in
                    if error != nil {
                        print("NicoDmc-error")//エラー。例えばオフラインとか
                        //nicoDMC.content_uriは nicoDMC.Set_session_metadata(ResponseMetadata: ) で代入される。
                        //callbackも返さないので、動画読み込み処理は途中で止まることになる。
                        return
                    }
                    guard let data = data else { return }
                    let str:String = String(data: data, encoding: String.Encoding.utf8)!
                    print(str)
                    nicoDMC.Set_session_metadata(ResponseMetadata: str)
                    //短く再生するだけの場合はハートビートしない（40秒以内）
                    //if !self.ecoThumb {
                        nicoDMC.Start_HeartBeat()
                    //}
                    callback(nicoDMC.content_uri)
                }
                task3.resume()
            }
            
        }
        task2.resume()
    }
    
    func StreamingUrlNicoAccessForThumbMovie(smNum: String, callback: @escaping (String,NicoDmc?) -> Void ) -> Void {
        
        //先にキャッシュ内にあるか確認。あればもうニコニコの動画ページにすらアクセスしないことにする
        if CachedThumbMovies.sharedInstance.containsWithinExpiration(smNum: smNum){
            callback("cached",nil)
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
            var st = str.pregMatche_firstString(pattern: "<div id=\"js-initial-watch-data\" data-api-data=\"(.*?)\" hidden></div>")
            st.htmlDecode()
            if let nicoDMC = NicoDmc(smNum: smNum, js_initial_watch_data: st, isThumbMovie: true) {
                //nicoDMC.eco = true
                let session = URLSession(configuration: URLSessionConfiguration.default)
                let url = URL(string:"https://api.dmc.nico/api/sessions?_format=json")!
                var req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
                let body = nicoDMC.sessionFormatJson
                req.httpMethod = "POST"
                req.httpBody = body.data(using: String.Encoding.utf8)
                let task3 = session.dataTask(with: req){(data,responce,error) in
                    if error != nil {
                        print("NicoDmc-error")//エラー。例えばオフラインとか
                        //nicoDMC.content_uriは nicoDMC.Set_session_metadata(ResponseMetadata: ) で代入される。
                        //callbackも返さないので、動画読み込み処理は途中で止まることになる。
                        return
                    }
                    guard let data = data else { return }
                    let str:String = String(data: data, encoding: String.Encoding.utf8)!
                    print(str)
                    nicoDMC.Set_session_metadata(ResponseMetadata: str)
                    //短く再生するだけの場合はハートビートしない（40秒以内）⇦ただしThumbMovieもSelector内全編再生指定時には後からハートビートすることにした。その為callbackでnicoDMCを返す必要が出てきた。
                    //if !self.ecoThumb {
                    //    nicoDMC.Start_HeartBeat()
                    //}
                    callback(nicoDMC.content_uri, nicoDMC)
                }
                task3.resume()
            }
        }
        task2.resume()
    }
}

class NicoDmc {
    let smNum : String
    let recipeId : String
    let playerID : String
    let videos : String
    let audios : String
    let signature : String
    let contentId : String
    let heartbeatLifetime : String
    let contentKeyTimeout : String
    let priority : String
    let transferPresets : String
    let service_id : String
    let player_id : String
    let service_user_id : String
    let auth_type : String
    let token : String
    private(set) var session_metadata = ""
    private(set) var session_id = ""
    private(set) var content_uri = ""
    
    let isThumbMovie : Bool
    var eco = false
    private var timer:Timer?
    
    init?(smNum:String, js_initial_watch_data:String, isThumbMovie:Bool) {
        self.smNum = smNum
        self.isThumbMovie = isThumbMovie
        print("DMC")
        //print(js_initial_watch_data)
        // Jsonのマッピング辛すぎるので文字列検索
        var ans:[String]=[]
        if !js_initial_watch_data.pregMatche(pattern: "\"session\":\\{\"recipeId\":\"(.*?)\",\"playerId\":\"(.*?)\",\"videos\":\\[(.*?)\\],\"audios\":\\[(.*?)\\],", matches: &ans){
            return nil
        }
        recipeId = ans[1]
        print("recipe_id= \(recipeId)")
        playerID = ans[2]
        print("playerID= \(playerID)")
        videos = ans[3]
        print("videos= \(videos)")
        audios = ans[4]
        print("audios= \(audios)")
        ans = []
        if !js_initial_watch_data.pregMatche(pattern: "\"signature\":\"(.*?)\",\"contentId\":\"(.*?)\",\"heartbeatLifetime\":(.*?),\"contentKeyTimeout\":(.*?),\"priority\":(.*?),\"transferPresets\":\\[(.*?)\\],", matches: &ans){
            return nil
        }
        signature = ans[1]
        print("signature= \(signature)")
        contentId = ans[2]
        print("contentId= \(contentId)")
        heartbeatLifetime = ans[3]
        print("heartbeatLifetime= \(heartbeatLifetime)")
        contentKeyTimeout = ans[4]
        print("contentKeyTimeout= \(contentKeyTimeout)")
        priority = ans[5]
        print("priority= \(priority)")
        transferPresets = ans[6].pregReplace(pattern: "^\"|\"$", with: "")
        print("transferPresets= \(transferPresets)")
        ans = []
        if !js_initial_watch_data.pregMatche(pattern: "\\\\\"service_id\\\\\":\\\\\"(.*?)\\\\\",\\\\\"player_id\\\\\":\\\\\"(.*?)\\\\\",\\\\\"recipe_id\\\\\":\\\\\".*?\\\\\",\\\\\"service_user_id\\\\\":\\\\\"(.*?)\\\\\",\\\\\"protocols\\\\\":\\[\\{\\\\\"name\\\\\":\\\\\"http\\\\\",\\\\\"auth_type\\\\\":\\\\\"(.*?)\\\\\"\\}", matches: &ans){
            return nil
        }
        service_id = ans[1]
        print("service_id= \(service_id)")
        player_id = ans[2]
        print("player_id= \(player_id)")
        service_user_id = ans[3]
        print("service_user_id= \(service_user_id)")
        auth_type = ans[4]
        print("auth_type= \(auth_type)")
        ans = []
        if !js_initial_watch_data.pregMatche(pattern: "\"token\":\"(.*?\\\\\"transfer_presets\\\\\":.*?\\})\",", matches: &ans){
            return nil
        }
        token = ans[1]
        print("token= \(token)")
    }
    var sessionFormatJson : String {
        get{
            var video_src = videos
            print("video_src(raw)=\(video_src)")
            let audio_src = audios
            let reachability = AMReachability()
            if isThumbMovie && eco == false {
                if (reachability?.isReachable)! {
                    print("インターネット接続あり")
                    if (reachability?.isReachableViaWiFi)!{
                        print("Wifi接続有り")
                    }else {
                        print("Wifi接続なし")
                        eco = true
                    }
                } else {
                    print("インターネット接続なし")
                }
            }
            if eco {
                //強制eco（曲セレクト画面でWifiじゃないときの30秒プレビュー）
                video_src = video_src.pregReplace(pattern: "^.*,", with: "")
                print("video_src=\(video_src)")
                //hls
                return #"{"session":{"recipe_id":"\#(recipeId)","content_id":"\#(contentId)","content_type":"movie","content_src_id_sets":[{"content_src_ids":[{"src_id_to_mux":{"video_src_ids":[\#(video_src)],"audio_src_ids":[\#(audio_src)]}}]}],"timing_constraint":"unlimited","keep_method":{"heartbeat":{"lifetime":\#(heartbeatLifetime)}},"protocol":{"name":"http","parameters":{"http_parameters":{"parameters":{"hls_parameters":{"use_well_known_port":"yes","use_ssl":"yes","transfer_preset":"\#(transferPresets)","segment_duration":6000}}}}},"content_uri":"","session_operation_auth":{"session_operation_auth_by_signature":{"token":"\#(token)","signature":"\#(signature)"}},"content_auth":{"auth_type":"\#(auth_type)","content_key_timeout":\#(contentKeyTimeout),"service_id":"\#(service_id)","service_user_id":"\#(service_user_id)"},"client_info":{"player_id":"\#(playerID)"},"priority":\#(priority)}}"#
            }else{
                if (reachability?.isReachable)! {
                    print("インターネット接続あり")
                    if (reachability?.isReachableViaWiFi)!{
                        print("Wifi接続有り")
                    }else {
                        print("Wifi接続なし(eco扱い)")
                        video_src = video_src.pregReplace(pattern: "^.*,", with: "")
                        print("video_src=\(video_src)")
                        //audio_src = audio_src.pregReplace(pattern: "^.*,", with: "")
                    }
                } else {
                    print("インターネット接続なし")
                }
                //mp4
                return #"{"session":{"recipe_id":"\#(recipeId)","content_id":"\#(contentId)","content_type":"movie","content_src_id_sets":[{"content_src_ids":[{"src_id_to_mux":{"video_src_ids":[\#(video_src)],"audio_src_ids":[\#(audio_src)]}}]}],"timing_constraint":"unlimited","keep_method":{"heartbeat":{"lifetime":\#(heartbeatLifetime)}},"protocol":{"name":"http","parameters":{"http_parameters":{"parameters":{"http_output_download_parameters":{"use_well_known_port":"yes","use_ssl":"yes","transfer_preset":"\#(transferPresets)"}}}}},"content_uri":"","session_operation_auth":{"session_operation_auth_by_signature":{"token":"\#(token)","signature":"\#(signature)"}},"content_auth":{"auth_type":"\#(auth_type)","content_key_timeout":\#(contentKeyTimeout),"service_id":"\#(service_id)","service_user_id":"\#(service_user_id)"},"client_info":{"player_id":"\#(playerID)"},"priority":\#(priority)}}"#
            }
        }
    }
    func Set_session_metadata(ResponseMetadata:String) {
        session_metadata = ResponseMetadata.pregMatche_firstString(pattern: "\"data\":(.*)\\}$")
        session_id = session_metadata.pregMatche_firstString(pattern: "\"id\":\"(.*?)\",")
        content_uri = session_metadata.pregMatche_firstString(pattern: "\"content_uri\":\"(.*?)\",").pregReplace(pattern: "\\\\", with: "")
        session_metadata = session_metadata.pregReplace(pattern: "\"content_uri\":\"(.*?)\",", with: "\"content_uri\":\"\(content_uri)\",")
    }
    func Start_HeartBeat() {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:"https://api.dmc.nico/api/sessions/\(self.session_id)?_format=json&_method=PUT")!
        var req = URLRequest(url: url)
        let body = ""
        req.httpMethod = "OPTIONS"
        req.httpBody = body.data(using: String.Encoding.utf8)
        print("start heartbeat! \(smNum)")
        let task = session.dataTask(with: req){(data,responce,error) in
            if error != nil {
                print("Start_HeartBeat-error")//エラー。例えばオフラインとか
                //ハートビート失敗。Timerも起動させないのでEnd_HeartBeat()も必要なし
                return
            }
            self.Post_HeartBeat()
            DispatchQueue.main.async {
                self.timer = Timer.scheduledTimer(withTimeInterval: 40.0, repeats: true, block: { (Timer) in
                    self.Post_HeartBeat()
                    var checkSurvival = false
                    if !self.isThumbMovie {
                        checkSurvival = CachedMovies.sharedInstance.cachedMovies.contains(where: {$0.smNum == self.smNum})
                    }else {
                        checkSurvival = CachedThumbMovies.sharedInstance.cachedMovies.contains(where: {$0.smNum == self.smNum})
                    }
                    if checkSurvival == false {
                        print("別のをダウンロードに行ってキャッシュから消されてたら終わり")
                        self.End_HeartBeat()
                    }else {
                        if let index = CachedMovies.sharedInstance.cachedMovies.lastIndex(where: {$0.smNum == self.smNum}){
                            let cacheMovie = CachedMovies.sharedInstance.cachedMovies[index]
                            let loadedTime = cacheMovie.avPlayerViewController.player?.currentItem?.loadedTimeRanges.asTimeRanges.first?.end
                            let duration = cacheMovie.avPlayerViewController.player?.currentItem?.duration
                            //print(loadedTime)
                            //print(duration)
                            if loadedTime != nil {
                                let per = CGFloat(CMTimeGetSeconds(loadedTime!)/CMTimeGetSeconds(duration!))
                                print(per)
                                if per > 0.99 {
                                    print("ロード終わり")
                                    self.End_HeartBeat()
                                }
                            }
                        }
                    }
                })
            }
        }
        task.resume()
    }
    func Post_HeartBeat() {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:"https://api.dmc.nico/api/sessions/\(self.session_id)?_format=json&_method=PUT")!
        var req = URLRequest(url: url)
        let body = self.session_metadata
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: req){(data,responce,error) in
            if error != nil {
                print("Post_HeartBeat-error")//エラー。例えばオフラインとか
                //ハートビートを一回失敗したぐらいでは止めなくて良いか？
                //self.End_HeartBeat() //本当は止めないにしてもカウントして連続エラー何回目かで止めるようにした方が良いかも
                return
            }
            guard let data = data else { return }
            let str:String = String(data: data, encoding: String.Encoding.utf8)!
            print("HeatBeat戻り！！")
            print(str)
            self.Set_session_metadata(ResponseMetadata: str)
        }
        task.resume()
    }
    func End_HeartBeat() {
        timer?.invalidate()
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
