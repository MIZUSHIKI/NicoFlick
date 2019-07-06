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
        
        //データベース接続 1：まずmusicデータロード。
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL+"?req=music&time="+String(self.musicDatas.getLastUpdateTimeMusic()))!
        let task = session.dataTask(with: url){(data,responce,error) in
            if let error = error {
                print("musicLoad-error") //エラー。例えばオフラインとか
                callback(error)
                return
            }
            //ロードしたmusicデータを処理
            if String(data: data!, encoding:.utf8)! != "latest" {
                let jsonArray = (try! JSONSerialization.jsonObject(with: data!, options: [])) as! Array<Dictionary<String,String>>
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
            }
            
            //データベース接続 2：次にlevelデータロード。
            let session = URLSession(configuration: URLSessionConfiguration.default)
            let url = URL(string:AppDelegate.PHPURL+"?req=level-noTimetag&time="+String(self.musicDatas.getLastUpdateTimeLevel()))!
            let task = session.dataTask(with: url){(data,responce,error) in
                if let error = error {
                    print("levelLoad-error") //エラー
                    callback(error)
                    return
                }
                //ロードしたlevelデータを処理
                if String(data: data!, encoding:.utf8)! != "latest" {
                    let jsonArray = (try! JSONSerialization.jsonObject(with: data!, options: [])) as! Array<Dictionary<String,String>>
                    for dic in jsonArray {
                        self.musicDatas.setLevel( sqlID: Int(dic["id"]!)!,
                                                  movieURL: dic["movieURL"]!,
                                                  level: Int(dic["level"]!)!,
                                                  creator: dic["creator"]!,
                                                  description: dic["description"]!,
                                                  speed: Int(dic["speed"]!)!,
                                                  noteData: "",
                                                  updateTime: Int(dic["updateTime"]!)!,
                                                  createTime: Int(dic["createTime"]!)!,
                                                  playCount: Int(dic["playCount"]!)!
                        )
                        //noteDataは最初に全部取得すると通信量が大きいからゲーム開始時に取得することにする
                    }
                }
                
                //データベース接続 3：次にスコアデータロード
                ServerDataHandler().DownloadScoreData { (error) in
                    if let error = error {
                        print(error)
                        callback(error)
                        return
                    }
                    
                    //データベース接続 5：次にコメントデータロード
                    ServerDataHandler().DownloadCommentData { (error) in
                        if let error = error {
                            print(error)
                            callback(error)
                            return
                        }
                        
                        //データベース接続 4：最後にusernameデータロード。
                        let session = URLSession(configuration: URLSessionConfiguration.default)
                        let url = URL(string:AppDelegate.PHPURL+"?req=username&time="+String(self.userNameDatas.getLastUpdateTime()))!
                        //print(url)
                        let task = session.dataTask(with: url){(data,responce,error) in
                            //print(data)
                            if let error = error {
                                print("usernameLoad-error") //エラー
                                callback(error)
                                return
                            }
                            //ロードしたusernameデータを処理
                            if String(data: data!, encoding:.utf8)! != "latest" {
                                let jsonArray = (try! JSONSerialization.jsonObject(with: data!, options: [])) as! Array<Dictionary<String,String>>
                                for dic in jsonArray {
                                    self.userNameDatas.setUserName(sqlID: Int(dic["id"]!)!,
                                                                   userID: dic["userID"]!,
                                                                   userName: dic["name"]!,
                                                                   updateTime: Int(dic["updateTime"]!)!
                                    )
                                }
                            }
                            
                            print("ServerData Download")
                            callback(nil)
                            
                        }//5.usernameデータロード
                        task.resume()
                    }
                }// 3.スコアデータロード
            }// 2.levelデータロード
            task.resume()
        }// 1.musicデータロード
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
    func DownloadScoreData(callback: @escaping (Error?) -> Void ) -> Void {
        //データベース接続
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL+"?req=score&levelID=ALL&time=\(scoreDatas.getLastUpdateTime())")!
        let task = session.dataTask(with: url){(data,responce,error) in
            if let error = error {
                print("DownloadScoreData-error")//エラー。例えばオフラインとか
                callback(error)
                return
            }
            //print(String(data: data!, encoding:.utf8)!)
            if String(data: data!, encoding:.utf8)! == "latest" {
                callback(nil)
                return
            }
            let jsonArray = (try! JSONSerialization.jsonObject(with: data!, options: [])) as! Array<Dictionary<String,String>>
            for dic in jsonArray {
                self.scoreDatas.setScore(sqlID: Int(dic["id"]!)!,
                                         levelID: Int(dic["levelID"]!)!,
                                         score: Int(dic["score"]!)!,
                                         userID: dic["userID"]!,
                                         updateTime: Int(dic["updateTime"]!)!
                )
            }
            callback(nil)
        }
        task.resume()
    }
    func DownloadCommentData(callback: @escaping (Error?) -> Void ) -> Void {
        //データベース接続
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL+"?req=comment&levelID=ALL&time=\(commentDatas.getLastUpdateTime())")!
        let task = session.dataTask(with: url){(data,responce,error) in
            if let error = error {
                print("DownloadCommentData-error")//エラー。例えばオフラインとか
                callback(error)
                return
            }
            //print(String(data: data!, encoding:.utf8)!)
            if String(data: data!, encoding:.utf8)! == "latest" {
                callback(nil)
                return
            }
            let jsonArray = (try! JSONSerialization.jsonObject(with: data!, options: [])) as! Array<Dictionary<String,String>>
            for dic in jsonArray {
                self.commentDatas.setComment(sqlID: Int(dic["id"]!)!,
                                             levelID: Int(dic["levelID"]!)!,
                                             comment: "",
                                             userID: dic["userID"]!,
                                             updateTime: Int(dic["updateTime"]!)!
                )
            }
            callback(nil)
        }
        task.resume()
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
        let body = "req=userName-add&id="+userID+"&name="+name
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: req){(data,responce,error) in
            callback()
        }
        task.resume()
    }
    
    func postScoreData(scoreset:String, userID:String, callback: @escaping (Bool) -> Void ) -> Void {
        //  登録
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url)
        let body = "req=score-add&userID=\(userID)&scoreset=\(scoreset)&pass=\(Crypt.init().encriptx_urlsafe(plainText: "ニコFlick", pass: userID))"
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
        let body = "req=music-insert&movieURL=\(nicoURL)&thumbnailURL=\(thumbnailURL)&title=\(title)&artist=\(artist)&movieLength=\(timeLength)&tags=\(tags)&userPASS=\(userPASS)"
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
    func postLevelInsert(nicoURL:String, level:Int, creator:String, description:String, speed:Int, notes:String, userPASS:String, callback: @escaping (String,Error?) -> Void ) -> Void {
        // ゲームデータの投稿
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url)
        let body = "req=level-insert&movieURL=\(nicoURL)&level=\(level)&creator=\(creator)&description=\(description)&speed=\(speed)&notes=\(notes)&userPASS=\(userPASS)"
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
        let body = "req=level-update&id=\(sqlID)&movieURL=\(nicoURL)&level=\(level)&creator=\(creator)&description=\(description)&speed=\(speed)&notes=\(notes)&userPASS=\(userPASS)"
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
}

