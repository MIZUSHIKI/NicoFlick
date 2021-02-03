//
//  ServerDataHandlerClass.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2018/12/03.
//  Copyright © 2018年 i.MIZUSHIKI. All rights reserved.
//

import Foundation
/*
・サーバーデータ
MusicDataClass.swift
    class MusicDataLists {
        var musics : [musicData]
        var levels : [levelData]
    }
PostedDataClass.swift
    class userNameDataLists {
        var userNames: [String:userNameData]
    }
    class ScoreDataLists {
        var scores:[scoreData]
    }
    class CommentDataLists {
        var comments:[commentData]
    }
*/
class ServerDataHandler {
    
    //音楽データ
    var musicDatas:MusicDataLists = MusicDataLists.sharedInstance
    //各ユーザーのネームデータ
    var userNameDatas:userNameDataLists = userNameDataLists.sharedInstance
    //
    var scoreDatas:ScoreDataLists = ScoreDataLists.sharedInstance
    var commentDatas:CommentDataLists = CommentDataLists.sharedInstance
    
    
    //サーバデータダウンロード 処理
    func DownloadMusicDataAndUserNameData(callback: @escaping (Error?) -> Void ) -> Void {
        
        //最初に保存データを持ってくる

        if musicDatas.musics.count == 0 {
            musicDatas.loadMusicsJsonString(jsonStr: UserData.sharedInstance.MusicsJson)
        }
        if musicDatas.levels.count == 0 {
            musicDatas.loadLevelsJsonString(jsonStr: UserData.sharedInstance.LevelsJson)
        }
        if scoreDatas.scores.count == 0 {
            scoreDatas.loadScoresJsonString(jsonStr: UserData.sharedInstance.ScoresJson)
        }
        if commentDatas.comments.count == 0 {
            commentDatas.loadCommentsJsonString(jsonStr: UserData.sharedInstance.CommentsJson)
        }
        if userNameDatas.userNames.count == 0 {
            userNameDatas.loadUserNamesJsonString(jsonStr: UserData.sharedInstance.UserNamesJson)
            userNameDatas.usernameJsonNumCount = UserData.sharedInstance.UserNamesServerJsonNumCount
            userNameDatas.usernameJsonCreateTime = UserData.sharedInstance.UserNamesServerJsonCreateTime
        }
        
        //データベース接続 1：まずmusicデータロード。
        ServerDataHandler().DownloadMusicData { (error) in
            if let error = error {
                print(error)
                //callback(error)
                //return
            }
            //データベース接続 2：次にlevelデータロード。
            ServerDataHandler().DownloadLevelData { (error) in
                if let error = error {
                    print(error)
                    //callback(error)
                    //return
                }
                //データベース接続 3：次にplayCount,favoriteデータロード。
                ServerDataHandler().DownloadPlayFavoriteCountData { (error) in
                    if let error = error {
                        print(error)
                        //callback(error)
                        //return
                    }
                    //データベース接続 4：もしUserNameを登録していてまだIDを取得していない場合（Ver.1.4未満ケア）
                    ServerDataHandler().getUserNameSqlID(userID: UserData.sharedInstance.UserID) {
                        
                        
                        //データベース接続 おまけ：プレイ回数をデータベースに送信する(送信済みでないもの)。リザルトまで行かずに溜まったものがあれば出す。
                        // 3.でのロード後に送信してるけど気にしない
                        let pfcountset = PFCounter.init().getSendPlayFavoriteCountStr()
                        print("pfcountset="+pfcountset)
                        if pfcountset != "" {
                            // プレイ、お気に入り回数 送信
                            ServerDataHandler().postPlayFavoriteCountData(pfcountset: pfcountset) { (bool) in
                                if bool {
                                    //プレイ、お気に入り回数データを保存する(初期化データになる)
                                    UserData.sharedInstance.PlayCount.setSended()
                                    UserData.sharedInstance.FavoriteCount.setSended()
                                }
                            }
                        }else{
                            let playcountset = UserData.sharedInstance.PlayCount.getSendPlayCountStr() //送信するデータ
                            print("playcountset="+playcountset)
                            if playcountset != "" {
                                // プレイ回数 送信
                                ServerDataHandler().postPlayCountData(playcountset: playcountset) { (bool) in
                                    if bool {
                                        //プレイ回数データを保存する(初期化データになる)
                                        UserData.sharedInstance.PlayCount.setSended()
                                    }
                                }
                            }
                            let favoritecountset = UserData.sharedInstance.FavoriteCount.getSendFavoriteCountStr() //送信するデータ
                            print("favoritecountset="+favoritecountset)
                            if favoritecountset != "" {
                                // お気に入り回数 送信
                                ServerDataHandler().postFavoriteCountData(favoritecountset: favoritecountset) { (bool) in
                                    if bool {
                                        //お気に入り回数データを保存する(初期化データになる)
                                        UserData.sharedInstance.FavoriteCount.setSended()
                                    }
                                }
                            }
                        }
                        // Selectorへ
                        print("ServerData Download")
                        callback(nil)
                   
                    
                    }// 4.UserNameIDデータ取得
                }// 3.playCount,favoriteデータロード
            }// 2.levelデータロード
        }// 1.musicデータロード
    }
    
    func DownloadMusicData(callback: @escaping (Error?) -> Void ) -> Void {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL+"?req=musicz&time="+String(self.musicDatas.getLastUpdateTimeMusic()))!
        print("URL=\(url)")
        let task = session.dataTask(with: url){(data,responce,error) in
            if let error = error {
                print("musicLoad-error") //エラー。例えばオフラインとか
                callback(error)
                return
            }
            print("downloaded")
            //ロードしたmusicデータを処理
            let htRet = String(data: data!, encoding:.utf8)!
            //print(htRet)
            if htRet == "latest" {
                callback(nil)
                return
            }else if htRet.hasPrefix("server-url:"){
                let st = htRet.index(htRet.startIndex, offsetBy: "server-url:".count)
                let ed = htRet.endIndex
                let mj = htRet[st ..< ed]
                self.DownloadMusicData_FirstData( serverURL: String(mj), callback: callback )
                return
            }
            do {
                let jsonArray = (try JSONSerialization.jsonObject(with: data!, options: [])) as! Array<Dictionary<String,String>>
                for dic in jsonArray {
                    self.musicDatas.setMusic( sqlID: Int(dic["id"]!)!,
                                              movieURL: dic["movieURL"]!,
                                              thumbnailURL: dic["thumbnailURL"]!,
                                              title: dic["title"]!,
                                              artist: dic["artist"]!,
                                              movieLength: dic["movieLength"]!,
                                              tags: dic["tags"]!,
                                              updateTime: Int(dic["updateTime"]!)!,
                                              createTime: Int(dic["createTime"]!)!
                    )
                }
                self.musicDatas.createTaglist() //タグリストを更新
                //保存データも更新
                UserData.sharedInstance.MusicsJson = self.musicDatas.toMusicsJsonString()
                callback(nil)
                
            } catch (let e) {
                print(e)
                //Jsonではなかった。何か他の結果が帰ってきた
                callback(e)
            }
        }
        task.resume()
    }
    func DownloadMusicData_FirstData(serverURL:String, callback: @escaping (Error?) -> Void ) -> Void {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:serverURL+"musicJson")!
        print("URL=\(url)")
        let task = session.dataTask(with: url){(data,responce,error) in
            if let error = error {
                print("musicLoad-error") //エラー。例えばオフラインとか
                callback(error)
                return
            }
            print("downloaded")
            //ロードしたmusicデータを処理
            //print(String(data: data!, encoding:.utf8)!)
            do {
                let jsonArray = (try JSONSerialization.jsonObject(with: data!, options: [])) as! Array<Dictionary<String,String>>
                for dic in jsonArray {
                    self.musicDatas.setMusic( sqlID: Int(dic["id"]!)!,
                                              movieURL: dic["movieURL"]!,
                                              thumbnailURL: dic["thumbnailURL"]!,
                                              title: dic["title"]!,
                                              artist: dic["artist"]!,
                                              movieLength: dic["movieLength"]!,
                                              tags: dic["tags"]!,
                                              updateTime: Int(dic["updateTime"]!)!,
                                              createTime: Int(dic["createTime"]!)!
                    )
                }
                self.musicDatas.createTaglist() //タグリストを更新
                //保存データも更新
                UserData.sharedInstance.MusicsJson = self.musicDatas.toMusicsJsonString()
                //もう一度通常取得を試みる
                self.DownloadMusicData(callback: callback)
                
            } catch (let e) {
                print(e)
                //Jsonではなかった。何か他の結果が帰ってきた
                callback(e)
            }
        }
        task.resume()
    }
    
    func DownloadLevelData(callback: @escaping (Error?) -> Void ) -> Void {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL+"?req=levelm-noTimetag&userID=\(UserData.sharedInstance.UserID.prefix(8))&time="+String(self.musicDatas.getLastUpdateTimeLevel()))!
        print("URL=\(url)")
        let task = session.dataTask(with: url){(data,responce,error) in
            if let error = error {
                print("levelLoad-error") //エラー
                callback(error)
                return
            }
            print("downloaded")
            //ロードしたlevelデータを処理
            let htRet = String(data: data!, encoding:.utf8)!
            //print(htRet)
            if htRet == "latest" {
                callback(nil)
                return
            }else if htRet.hasPrefix("server-url:"){
                let st = htRet.index(htRet.startIndex, offsetBy: "server-url:".count)
                let ed = htRet.endIndex
                let mj = htRet[st ..< ed]
                self.DownloadLevelData_FirstData( serverURL: String(mj), callback: callback )
                return
            }
            do {
                let jsonArray = (try JSONSerialization.jsonObject(with: data!, options: [])) as! Array<Dictionary<String,String>>
                for dic in jsonArray {
                    var playCountTime = 0
                    var favoriteCount = 0
                    var favoriteCountTime = 0
                    var commentTime = 0
                    var scoreTime = 0
                    if dic["playCountTime"] != nil {
                        playCountTime = Int(dic["playCountTime"]!)!
                    }
                    if dic["favorite"] != nil {
                        favoriteCount = Int(dic["favorite"]!)!
                    }
                    if dic["favoriteTime"] != nil {
                        favoriteCountTime = Int(dic["favoriteTime"]!)!
                    }
                    if dic["commentTime"] != nil {
                        commentTime = Int(dic["commentTime"]!)!
                    }
                    if dic["scoreTime"] != nil {
                        scoreTime = Int(dic["scoreTime"]!)!
                    }
                    self.musicDatas.setLevel( sqlID: Int(dic["id"]!)!,
                                              movieURL: dic["movieURL"]!,
                                              level: Int(dic["level"]!)!,
                                              creator: dic["creator"]!,
                                              description: dic["description"]!,
                                              speed: Int(dic["speed"]!)!,
                                              noteData: "",
                                              updateTime: Int(dic["updateTime"]!)!,
                                              createTime: Int(dic["createTime"]!)!,
                                              playCount: Int(dic["playCount"]!)!,
                                              playCountTime: playCountTime,
                                              favoriteCount: favoriteCount,
                                              favoriteCountTime: favoriteCountTime,
                                              commentTime: commentTime,
                                              scoreTime: scoreTime
                    )
                    //noteDataは最初に全部取得すると通信量が大きいからゲーム開始時に取得することにする
                }
                //保存データも更新
                UserData.sharedInstance.LevelsJson = self.musicDatas.toLevelsJsonString()
                callback(nil)

            } catch (let e) {
                print(e)
                //Jsonではなかった。何か他の結果が帰ってきた
                callback(e)
            }
        }
        task.resume()
    }
    func DownloadLevelData_FirstData(serverURL:String, callback: @escaping (Error?) -> Void ) -> Void {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:serverURL+"levelJson")!
        print("URL=\(url)")
        let task = session.dataTask(with: url){(data,responce,error) in
            if let error = error {
                print("musicLoad-error") //エラー。例えばオフラインとか
                callback(error)
                return
            }
            print("downloaded-fd")
            //ロードしたmusicデータを処理
            //print(String(data: data!, encoding:.utf8)!)
            do {
                let jsonArray = (try JSONSerialization.jsonObject(with: data!, options: [])) as! Array<Dictionary<String,String>>
                for dic in jsonArray {
                    var playCountTime = 0
                    var favoriteCount = 0
                    var favoriteCountTime = 0
                    var commentTime = 0
                    var scoreTime = 0
                    if dic["playCountTime"] != nil {
                        playCountTime = Int(dic["playCountTime"]!)!
                    }
                    if dic["favorite"] != nil {
                        favoriteCount = Int(dic["favorite"]!)!
                    }
                    if dic["favoriteTime"] != nil {
                        favoriteCountTime = Int(dic["favoriteTime"]!)!
                    }
                    if dic["commentTime"] != nil {
                        commentTime = Int(dic["commentTime"]!)!
                    }
                    if dic["scoreTime"] != nil {
                        scoreTime = Int(dic["scoreTime"]!)!
                    }
                    self.musicDatas.setLevel( sqlID: Int(dic["id"]!)!,
                                              movieURL: dic["movieURL"]!,
                                              level: Int(dic["level"]!)!,
                                              creator: dic["creator"]!,
                                              description: dic["description"]!,
                                              speed: Int(dic["speed"]!)!,
                                              noteData: "",
                                              updateTime: Int(dic["updateTime"]!)!,
                                              createTime: Int(dic["createTime"]!)!,
                                              playCount: Int(dic["playCount"]!)!,
                                              playCountTime: playCountTime,
                                              favoriteCount: favoriteCount,
                                              favoriteCountTime: favoriteCountTime,
                                              commentTime: commentTime,
                                              scoreTime: scoreTime
                    )
                    //noteDataは最初に全部取得すると通信量が大きいからゲーム開始時に取得することにする
                }
                //保存データも更新
                UserData.sharedInstance.LevelsJson = self.musicDatas.toLevelsJsonString()
                //もう一度通常取得を試みる
                self.DownloadLevelData(callback: callback)

            } catch (let e) {
                print(e)
                //Jsonではなかった。何か他の結果が帰ってきた
                callback(e)
            }
        }
        task.resume()
    }
    
    func DownloadPlayFavoriteCountData(callback: @escaping (Error?) -> Void ) -> Void {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL+"?req=PcFcCtSt&playcountTime="+String(self.musicDatas.getLastPlayCountTimeLevel())+"&favoriteTime="+String(self.musicDatas.getLastFavoriteCountTimeLevel())+"&commentTime="+String(self.musicDatas.getLastCommentTimeLevel())+"&scoreTime="+String(self.musicDatas.getLastScoreTimeLevel()))!
        print("URL=\(url)")
        let task = session.dataTask(with: url){(data,responce,error) in
            if let error = error {
                print("PlayFavoriteCountLoad-error") //エラー
                callback(error)
                return
            }
            print("downloaded")
            //ロードしたlevelデータを処理
            let htRet = String(data: data!, encoding:.utf8)!
            //print(htRet)
            if htRet == "latest" {
                callback(nil)
                return
            }
            do {
                let jsonArray = (try JSONSerialization.jsonObject(with: data!, options: [])) as! Array<Dictionary<String,String>>
                for dic in jsonArray {
                    self.musicDatas.setLevel_PlaycountFavorite( sqlID: Int(dic["id"]!)!,
                                              playCount: Int(dic["playCount"] ?? "-1")!,
                                              playCountTime: Int(dic["playCountTime"] ?? "-1")!,
                                              favoriteCount: Int(dic["favorite"] ?? "-1")!,
                                              favoriteCountTime: Int(dic["favoriteTime"] ?? "-1")!,
                                              commentTime: Int(dic["commentTime"] ?? "-1")!,
                                              scoreTime: Int(dic["scoreTime"] ?? "-1")!
                    )
                }
                //保存データも更新
                UserData.sharedInstance.LevelsJson = self.musicDatas.toLevelsJsonString()
                callback(nil)

            } catch (let e) {
                print(e)
                //Jsonではなかった。何か他の結果が帰ってきた
                callback(e)
            }
        }
        task.resume()
    }
    func DownloadTimetag(level:levelData, callback: @escaping (Error?) -> Void ) -> Void {
        //データベース接続、noteDataロード。
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL( string:AppDelegate.PHPURL+"?req=timetag&id=\(level.sqlID!)")!
        let task = session.dataTask(with: url){(data,responce,error) in
            if let error = error {
                print("notesLoad-error")//エラー。例えばオフラインとか
                callback(error)
                return
            }
            let jsonDic = (try! JSONSerialization.jsonObject(with: data!, options: [])) as! Dictionary<String,String>
            //musicDatasに保存（次回からロードしなくなる）
            level.noteData = jsonDic["notes"]
            
            print("Notes Download")
            callback(nil)
            
        }
        task.resume()
    }
    func DownloadScoreData(levelID:Int, callback: @escaping (Error?) -> Void ) -> Void {
        //データベース接続
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL+"?req=scorez&levelID=\(levelID)&time=\(scoreDatas.getLastUpdateTime(levelID: levelID))")!
        let task = session.dataTask(with: url){(data,responce,error) in
            if let error = error {
                print("DownloadScoreData-error")//エラー。例えばオフラインとか
                callback(error)
                return
            }
            print("downloaded")
            //print(String(data: data!, encoding:.utf8)!)
            do{
                let jsonArray = (try JSONSerialization.jsonObject(with: data!, options: [])) as! Array<Dictionary<String,String>>
                for dic in jsonArray {
                    self.scoreDatas.setScore(sqlID: Int(dic["id"]!)!,
                                             levelID: levelID,
                                             score: Int(dic["score"]!)!,
                                             userID: dic["userID"]!,
                                             updateTime: Int(dic["updateTime"]!)!
                    )
                }
                //保存データも更新
                UserData.sharedInstance.ScoresJson = self.scoreDatas.toScoresJsonString()
                callback(nil)
            }catch(let e){
                print(e)
                callback(e)
            }
            return
        }
        task.resume()
    }
    func DownloadCommentData(levelID:Int, callback: @escaping (Error?) -> Void ) -> Void {
        //データベース接続
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL+"?req=commentz&levelID=\(levelID)&time=\(commentDatas.getLastUpdateTime(levelID: levelID))")!
        let task = session.dataTask(with: url){(data,responce,error) in
            if let error = error {
                print("DownloadCommentData-error")//エラー。例えばオフラインとか
                callback(error)
                return
            }
            print("downloaded")
            //print(String(data: data!, encoding:.utf8)!)
            do{
                let jsonArray = (try JSONSerialization.jsonObject(with: data!, options: [])) as! Array<Dictionary<String,String>>
                for dic in jsonArray {
                    self.commentDatas.setComment(sqlID: Int(dic["id"]!)!,
                                                 levelID: levelID,
                                                 comment: dic["comment"]!,
                                                 userID: dic["userID"]!,
                                                 updateTime: Int(dic["updateTime"]!)!
                    )
                }
                //保存データも更新
                UserData.sharedInstance.CommentsJson = self.commentDatas.toCommentsJsonString()
                callback(nil)
            }catch(let e){
                print(e)
                callback(e)
            }
        }
        task.resume()
    }
    func DownloadUserNameData(callback: @escaping (Error?) -> Void ) -> Void {
        //データベース接続
        let session = URLSession(configuration: URLSessionConfiguration.default)
        var updateTime = userNameDatas.getLastUpdateTime()
        if userNameDatas.usernameJsonNumCount >= 0 {
            updateTime = 0
        }
        let url = URL(string:AppDelegate.PHPURL+"?req=usernamez&time=\(updateTime)")!
        let task = session.dataTask(with: url){(data,responce,error) in
            if let error = error {
                print("DownloadUserName-error")//エラー。例えばオフラインとか
                callback(error)
                return
            }
            print("downloaded")
            let htRet = String(data: data!, encoding:.utf8)!
            //print(htRet)
            if htRet == "latest" {
                callback(nil)
                return
            }else if htRet.hasPrefix("[{\"server-url\":"){
                
                //(サブ)サーバにファイルを取りに行く
                do{
                    let jsonArray = (try JSONSerialization.jsonObject(with: data!, options: [])) as! Array<Dictionary<String,String>>
                    for dic in jsonArray {
                        let serverURL = dic["server-url"]!
                        let createTime = Int(dic["createTime"]!)!
                        print(serverURL)
                        print(createTime)
                        if self.userNameDatas.usernameJsonCreateTime == 0 {
                            self.userNameDatas.usernameJsonCreateTime = createTime
                        }else if self.userNameDatas.usernameJsonCreateTime != createTime {
                            self.userNameDatas.reset()
                            self.userNameDatas.usernameJsonCreateTime = createTime
                        }
                        
                        self.DownloadUserNameData_FirstData( serverURL: serverURL, callback: callback )
                        break
                    }
                    
                }catch(let e){
                    print(e)
                    callback(e)
                }
                return
            }
            do{
                let jsonArray = (try JSONSerialization.jsonObject(with: data!, options: [])) as! Array<Dictionary<String,String>>
                for dic in jsonArray {
                    self.userNameDatas.setUserName(sqlID: Int(dic["id"]!)!,
                                                   userID: dic["userID"]!,
                                                   userName: dic["name"]!,
                                                   updateTime: Int(dic["updateTime"]!)!
                    )
                }
                //保存データも更新
                UserData.sharedInstance.UserNamesJson = self.userNameDatas.toUserNamesJsonString()
                UserData.sharedInstance.UserNamesServerJsonNumCount = self.userNameDatas.usernameJsonNumCount
                UserData.sharedInstance.UserNamesServerJsonCreateTime = self.userNameDatas.usernameJsonCreateTime
                callback(nil)
            }catch(let e){
                print(e)
                callback(e)
            }
        }
        task.resume()
    }
    func DownloadUserNameData_FirstData(serverURL:String, callback: @escaping (Error?) -> Void ) -> Void {
        //データベース接続
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:serverURL+"usernameJson\(userNameDatas.usernameJsonNumCount)")!
        print(url)
        let task = session.dataTask(with: url){(data,responce,error) in
            if let error = error {
                print("DownloadUserName-error")//エラー。例えばオフラインとか
                callback(error)
                return
            }
            guard var data = data else { return }
            print("downloaded")
            
            let start = data.index(after: data.count - 7)
            let end = data.endIndex
            var nextFlg = false
            if String(data: data.subdata(in: start ..< end), encoding:.utf8)! == "//next" {
                print("//next")
                nextFlg = true
                data = data.subdata(in: data.startIndex ..< start) //nextを外す
            }else{
                print("//finish")
            }
            
            //print(String(data: data!, encoding:.utf8)!)
            do{
                let jsonArray = (try JSONSerialization.jsonObject(with: data, options: [])) as! Array<Dictionary<String,String>>
                for dic in jsonArray {
                    self.userNameDatas.setUserName(sqlID: Int(dic["id"]!)!,
                                                   userID: dic["userID"]!,
                                                   userName: dic["name"]!,
                                                   updateTime: Int(dic["updateTime"]!)!
                    )
                }
                if nextFlg {
                    self.userNameDatas.usernameJsonNumCount += 1
                }else{
                    self.userNameDatas.usernameJsonNumCount = -1
                }
                //保存データも更新
                UserData.sharedInstance.UserNamesJson = self.userNameDatas.toUserNamesJsonString()
                UserData.sharedInstance.UserNamesServerJsonNumCount = self.userNameDatas.usernameJsonNumCount
                UserData.sharedInstance.UserNamesServerJsonCreateTime = self.userNameDatas.usernameJsonCreateTime
                if !nextFlg {
                    //分割Jsonの最後まで来た。もう一度通常取得を試みてFirstデータにない残りを取得。
                    self.DownloadUserNameData(callback: callback)
                }else{
                    callback(nil)
                }
                
            }catch(let e){
                print(e)
                callback(e)
            }
        }
        task.resume()
    }
    func Chance_DownloadUserNameData_FirstData(callback: @escaping (Error?) -> Void ) -> Void {
        if userNameDatas.usernameJsonNumCount == -1 {
            callback(nil)
            return
        }
        DownloadUserNameData(callback: callback)
    }
    
    
    func getScoreData(levelID:Int, callback: @escaping (Array<Dictionary<String,String>>?) -> Void ) -> Void {
        //データベース接続
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL+"?req=score&levelID=\(levelID)")!
        let task = session.dataTask(with: url){(data,responce,error) in
            if error != nil {
                print("getScoreData-error")//エラー。例えばオフラインとか
                callback(nil)
                return
            }
            let scoreData = (try! JSONSerialization.jsonObject(with: data!, options: [])) as! Array<Dictionary<String,String>>
            callback(scoreData)
        }
        task.resume()
    }
    func getCommentData(levelID:Int, callback: @escaping (Array<Dictionary<String,String>>?) -> Void ) -> Void {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL+"?req=comment&levelID=\(levelID)")!
        let task = session.dataTask(with: url){(data,responce,error) in
            if error != nil {
                print("getCommentData-error")//エラー。例えばオフラインとか
                callback(nil)
                return
            }
            let commentData = (try! JSONSerialization.jsonObject(with: data!, options: [])) as! Array<Dictionary<String,String>>
            callback(commentData)
        }
        task.resume()
    }
    
    func checkLevelPassword(id:Int, pass:String, callback: @escaping (Bool) -> Void ) -> Void {
        //
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL+"?req=level-passCheck&id=\(id)&userPASS=\(pass)")!
        let task = session.dataTask(with: url){(data,responce,error) in
            if error != nil {
                print("checkLevelPass-error") //エラー。例えばオフラインとか
                callback(false)
                return
            }
            callback(String(data: data!, encoding:.utf8)! == "true")
        }
        task.resume()
    }
    
    func postUserName(name:String, userID:String, callback: @escaping () -> Void ) -> Void {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url)
        let body = "req=userName-add&id="+userID+"&name="+name.urlEncoded
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: req){(data,responce,error) in
            let str:String = String(data: data!, encoding: String.Encoding.utf8)!
            print(str)
            if str.hasPrefix("success userName-add UserNameSqlID="){ //Ver.1.4〜
                UserData.sharedInstance.UserNameID = Int(str.pregMatche_firstString(pattern: "UserNameSqlID=(\\d+)")) ?? 0
            }
            callback()
        }
        task.resume()
    }
    //Ver.1.4未満のケア
    func getUserNameSqlID(userID:String, callback: @escaping () -> Void ) -> Void {
        if UserData.sharedInstance.UserName == "" || UserData.sharedInstance.UserNameID != 0 { //名前登録してるけど、まだIDを取得していなときだけ実行する（Ver.1.4未満）
            print("usernameid=\( UserData.sharedInstance.UserNameID )")
            callback()
            return
        }
        //データベース接続
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL+"?req=userNameID&id=\(userID)")!
        let task = session.dataTask(with: url){(data,responce,error) in
            if error != nil {
                print("getUserNameID-error")//エラー。例えばオフラインとか
                callback()
                return
            }
            let str:String = String(data: data!, encoding: String.Encoding.utf8)!
            print(str)
            if str.hasPrefix("success UserNameSqlID="){ //Ver.1.4〜
                UserData.sharedInstance.UserNameID = Int(str.pregMatche_firstString(pattern: "UserNameSqlID=(\\d+)")) ?? 0
            }
            callback()
        }
        task.resume()
    }
    
    func postScoreData(scoreset:String, userID:String, callback: @escaping (Bool) -> Void ) -> Void {
        //  登録
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url)
        let body = "req=scorez-add&userID=\(userID)&userNameID=\(UserData.sharedInstance.UserNameID)&scoreset=\(scoreset)&pass=\(Crypt.init().encriptx_urlsafe(plainText: "ニコFlick", pass: userID))"
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        print(body)
        let task = session.dataTask(with: req){(data,responce,error) in
            if (error != nil) {
                callback(false)
                return
            }
            let str:String = String(data: data!, encoding: String.Encoding.utf8)!
            print(str)
            if str == "success score-add"{
                callback(true)
            }else {
                print("スコア送信失敗")
                callback(false)
            }
        }
        task.resume()
    }
    func postPlayCountData(playcountset:String, callback: @escaping (Bool) -> Void ) -> Void {
        //  登録
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url)
        let body = "req=playcount-add&playcountset=\(playcountset)"
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: req){(data,responce,error) in
            if (error != nil) {
                callback(false)
                return
            }
            let str:String = String(data: data!, encoding: String.Encoding.utf8)!
            print(str)
            if str == "success playcount-add" {
                callback(true)
            }else{
                print("playcount送信失敗")
                callback(false)
            }
        }
        task.resume()
    }
    func postFavoriteCountData(favoritecountset:String, callback: @escaping (Bool) -> Void ) -> Void {
        //  登録
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url)
        let body = "req=favorite-add&favoritecountset=\(favoritecountset)"
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: req){(data,responce,error) in
            if (error != nil) {
                callback(false)
                return
            }
            let str:String = String(data: data!, encoding: String.Encoding.utf8)!
            print(str)
            if str == "success favorite-add" {
                callback(true)
            }else{
                print("favorite送信失敗")
                callback(false)
            }
        }
        task.resume()
    }
    func postPlayFavoriteCountData(pfcountset:String, callback: @escaping (Bool) -> Void ) -> Void {
        //  登録
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url)
        let body = "req=PlaycountFavorite-add&PFcountset=\(pfcountset)"
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: req){(data,responce,error) in
            if (error != nil) {
                callback(false)
                return
            }
            let str:String = String(data: data!, encoding: String.Encoding.utf8)!
            print(str)
            if str == "success PFcount-add" {
                callback(true)
            }else{
                print("PFcount送信失敗")
                callback(false)
            }
        }
        task.resume()
    }
    func postComment(comment:String, levelID:Int, userID:String, callback: @escaping () -> Void ) -> Void {
        //  登録
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url)
        let urlEncodeComment:String = comment.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!
        let body = "req=comment-add&userID=\(userID)&levelID=\(levelID)&comment=\(urlEncodeComment)"
        //print(body)
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: req){(data,responce,error) in
            callback()
        }
        task.resume()
    }
    
    func postMusicInsert(nicoURL:String, thumbnailURL:String, title:String, artist:String, timeLength:String, tags:String, userPASS:String, callback: @escaping (String, Error?) -> Void) -> Void {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url)
        let body = "req=music-insert&movieURL=\(nicoURL)&thumbnailURL=\(thumbnailURL)&title=\(title.urlEncoded)&artist=\(artist.urlEncoded)&movieLength=\(timeLength)&tags=\(tags.urlEncoded)&userPASS=\(userPASS)"
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: req){(data,responce,error) in
            if let error = error {
                callback("",error)
                return
            }
            let retStr:String = String(data: data!, encoding: String.Encoding.utf8)!
            //print(retStr)
            callback(retStr, nil)
        }
        task.resume()
    }
    func postMusicTagUpdate(id:Int, tags:String, userID:String, callback: @escaping (Bool) -> Void ) -> Void {
        //  登録
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url)
        let body = "req=musicTag-update&id=\(id)&tags=\(tags.urlEncoded)&userID=\(userID)&pass=\(Crypt.init().encriptx_urlsafe(plainText: "ニコFlick", pass: userID))"
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        //print(body)
        let task = session.dataTask(with: req){(data,responce,error) in
            if (error != nil) {
                callback(false)
                return
            }
            let str:String = String(data: data!, encoding: String.Encoding.utf8)!
            print(str)
            if str == "success musictag-update"{
                callback(true)
            }else {
                print("musicタグ送信失敗")
                callback(false)
            }
        }
        task.resume()
    }
    func postLevelInsert(nicoURL:String, level:Int, creator:String, description:String, speed:Int, notes:String, userPASS:String, callback: @escaping (String,Error?) -> Void ) -> Void {
        // ゲームデータの投稿
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url)
        let body = "req=level-insert&movieURL=\(nicoURL)&level=\(level)&creator=\(creator.urlEncoded)&description=\(description.urlEncoded)&speed=\(speed)&notes=\(notes.urlEncoded)&userPASS=\(userPASS)"
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: req){(data,responce,error) in
            if let error = error {
                callback("",error)
                return
            }
            let retStr:String = String(data: data!, encoding: String.Encoding.utf8)!
            //print(retStr)
            callback(retStr, nil)
        }
        task.resume()
    }
    func postLevelUpdate(sqlID:Int, nicoURL:String, level:Int, creator:String, description:String, speed:Int, notes:String, userPASS:String, callback: @escaping (String,Error?) -> Void ) -> Void {
        // ゲームデータの投稿
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url)
        let body = "req=level-update&id=\(sqlID)&movieURL=\(nicoURL)&level=\(level)&creator=\(creator.urlEncoded)&description=\(description.urlEncoded)&speed=\(speed)&notes=\(notes.urlEncoded)&userPASS=\(userPASS)"
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: req){(data,responce,error) in
            if let error = error {
                callback("",error)
                return
            }
            let retStr:String = String(data: data!, encoding: String.Encoding.utf8)!
            //print(retStr)
            callback(retStr, nil)
        }
        task.resume()
    }
    func postLevelDelete(sqlID:Int, userPASS:String, callback:@escaping (String,Error?) -> Void ) -> Void {
        // ゲームデータの投稿
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url)
        let body = "req=level-delete&id=\(sqlID)&userPASS=\(userPASS)"
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: req){(data,responce,error) in
            if let error = error {
                callback("",error)
                return
            }
            let retStr:String = String(data: data!, encoding: String.Encoding.utf8)!
            //print(retStr)
            callback(retStr, nil)
        }
        task.resume()
    }
    
    func postReport(musicID:Int, comment:String, userID:String, callback: @escaping (Bool) -> Void ) -> Void {
        //  登録
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url)
        let urlEncodeComment:String = comment.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!
        print("urlEncodeComment")
        print(urlEncodeComment)
        let body = "req=report&userID=\(userID)&musicID=\(musicID)&comment=\(urlEncodeComment)"
        //print(body)
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: req){(data,responce,error) in
            let retStr:String = String(data: data!, encoding: String.Encoding.utf8)!
            print(retStr)
            if retStr == "success report" {
                callback(true)
            }else {
                callback(false)
            }
        }
        task.resume()
    }
    func postTagsToMusics(tags:String, musicsStr:String, callback: @escaping () -> Void ) -> Void {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url)
        let body = "req=tagsToMusics&tags="+tags.urlEncoded+"&musics="+musicsStr.urlEncoded
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: req){(data,responce,error) in
            callback()
        }
        task.resume()
    }
    
}

