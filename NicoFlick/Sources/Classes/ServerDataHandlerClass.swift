//
//  ServerDataHandlerClass.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2018/12/03.
//  Copyright © 2018年 i.MIZUSHIKI. All rights reserved.
//

import Foundation

private enum ServerResponseError: LocalizedError {
    case invalidResponse
    case unacceptableStatusCode(Int)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "サーバーから正しいHTTPレスポンスを受信できませんでした。"
        case .unacceptableStatusCode(let statusCode):
            return "サーバーエラーが発生しました。（HTTP \(statusCode)）"
        case .noData:
            return "サーバーからデータを受信できませんでした。"
        }
    }
}

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
    private static let userNameDownloadLock = NSLock()
    private static var userNameDownloadCallbacks: [(Error?) -> Void] = []

    
    //音楽データ
    var musicDatas:MusicDataLists = MusicDataLists.sharedInstance
    //各ユーザーのネームデータ
    var userNameDatas:userNameDataLists = userNameDataLists.sharedInstance
    //
    var scoreDatas:ScoreDataLists = ScoreDataLists.sharedInstance
    var commentDatas:CommentDataLists = CommentDataLists.sharedInstance
    
    
    private func validateHTTPResponse(_ response: URLResponse?, data: Data?) -> Error? {
        guard let httpResponse = response as? HTTPURLResponse else {
            return ServerResponseError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            return ServerResponseError.unacceptableStatusCode(httpResponse.statusCode)
        }
        guard data != nil else {
            return ServerResponseError.noData
        }
        return nil
    }

    //サーバデータダウンロード 処理
    func DownloadMusicDataAndUserNameData(callback: @escaping (Error?) -> Void ) -> Void {
        // 通常ロードで保存される前に、編集中データの救出が必要かを保持する。
        let needsMyEditRecovery = UserData.sharedInstance.LevelsJson == ""
        
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
        userNameDatas.restoreIfNeeded()
        
        //データベース接続 1：まずmusicデータロード。
        ServerDataHandler().DownloadMusicData { (error) in
            if let error = error {
                // print(error)
                //callback(error)
                //return
            }
            //データベース接続 2：次にlevelデータロード。
            ServerDataHandler().DownloadLevelData { (error) in
                if let error = error {
                    // print(error)
                    //callback(error)
                    //return
                }
                // データベース接続2.1: 「ロードデータ削除」後であれば、自分の「編集中」データ救出
                self.downloadMyEditingLevelsIfNeeded(needsRecovery: needsMyEditRecovery) { _ in
                    // 救出に失敗した場合も後続ロードを続ける。再取得はロードデータ削除で行う。
                    //データベース接続 3：次にplayCount,likeCountデータロード。
                    ServerDataHandler().Download_level_PlayLikeCountData { (error) in
                        if let error = error {
                            // print(error)
                            //callback(error)
                            //return
                        }
                        //データベース接続 4：次にfavoriteCountデータロード。
                        ServerDataHandler().Download_music_FavoriteCountData { (error) in
                            if let error = error {
                                // print(error)
                                //callback(error)
                                //return
                            }
                            //データベース接続 5：もしUserNameを登録していてまだIDを取得していない場合（Ver.1.4未満ケア）
                            ServerDataHandler().getUserNameSqlID(userID: UserData.sharedInstance.UserID) {
                                //データベース接続 おまけ：プレイ回数をデータベースに送信する(送信済みでないもの)。リザルトまで行かずに溜まったものがあれば出す。
                                // playCount,like,dislike,musicFavorite の送信(成功したらカウントデータを初期化)
                                self.postUserCountData()
                                
                                // Selectorへ
                                // print("ServerData Download")
                                callback(nil)
                            }// 5.UserNameIDデータ取得
                        }// 4.favoriteCountデータ取得
                    }// 3.playCount,likeCountデータロード
                }// 2.1.編集中データ救出
            }// 2.levelデータロード
        }// 1.musicデータロード
    }
    
    func DownloadMusicData(callback: @escaping (Error?) -> Void ) -> Void {
        AppDelegate.ServerErrorMessage = ""
        AppDelegate.serverErrorTitle = "サーバエラー"
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL+"?req=musics&time="+String(self.musicDatas.getLastUpdateTimeMusic()))!
        // print("URL=\(url)")
        let req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let task = session.dataTask(with: req){(data,response,error) in
            if let error = error {
                // print("musicLoad-error") //エラー。例えばオフラインとか
                AppDelegate.ServerErrorMessage = "予期しないエラーが発生しました"
                callback(error)
                return
            }
            if let responseError = self.validateHTTPResponse(response, data: data) {
                callback(responseError)
                return
            }
            // print("downloaded")
            guard var data = data else { return }
            //ロードしたmusicデータを処理
            guard var htRet = String(data: data, encoding:.utf8) else { return }
            // ロードの先頭であるmusicXのみNicoFlickMessageを受信する可能性がある
            if htRet.hasPrefix("<!--NicoFlickMessage=") {
                AppDelegate.ServerErrorMessage = htRet.pregMatche_firstString(pattern: "^<!--NicoFlickMessage=(.*?)-->")
                AppDelegate.ServerErrorMessage = AppDelegate.ServerErrorMessage.pregReplace(pattern: "&NicoFlickSubMessage=.*?$", with:"" )  // おそらくSubMessageがニコRe仮のためのもので役割を終えたから強制削除してるものだと思われる
                htRet = htRet.pregReplace(pattern: "^<!--NicoFlickMessage=.*?-->", with:"" )
                // タイトル内の文字列を端末指定と誤認しないよう、先に取り除く。
                let titlePattern = "\\{title:([^}]*)\\}"
                let title = AppDelegate.ServerErrorMessage.pregMatche_firstString(pattern: titlePattern)
                if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    AppDelegate.serverErrorTitle = title
                }
                AppDelegate.ServerErrorMessage = AppDelegate.ServerErrorMessage.pregReplace(pattern: titlePattern, with: "")
                AppDelegate.ServerErrorMessage = AppDelegate.ServerErrorMessage.pregReplace(pattern: "\\[\\[Silent:.*?\\]\\]", with:"" )
                // 端末指定は本文の先頭・末尾だけを判定する。指定なしは両OS共通。
                var message = AppDelegate.ServerErrorMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                if message.hasPrefix("[Android]") || message.hasSuffix("[Android]") {
                    message = ""
                } else {
                    if message.hasPrefix("[iOS]") {
                        message = String(message.dropFirst("[iOS]".count))
                    }
                    if message.hasSuffix("[iOS]") {
                        message = String(message.dropLast("[iOS]".count))
                    }
                }
                AppDelegate.ServerErrorMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
                // print(AppDelegate.ServerErrorMessage)
                data = htRet.data(using: .utf8)!
            }
//            print("update music!")
            // print(htRet)
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
                // ロードデータ処理
                try self.LoadMusicData(data: data)
                callback(nil)
                
            } catch (let e) {
                // print(e)
                //Jsonではなかった。何か他の結果が帰ってきた
                callback(e)
            }
        }
        task.resume()
    }
    func DownloadMusicData_FirstData(serverURL:String, callback: @escaping (Error?) -> Void ) -> Void {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:serverURL+"musicJson")!
        // print("URL=\(url)")
        let req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let task = session.dataTask(with: req){(data,response,error) in
            if let error = error {
                // print("musicLoad-error") //エラー。例えばオフラインとか
                callback(error)
                return
            }
            if let responseError = self.validateHTTPResponse(response, data: data) {
                callback(responseError)
                return
            }
            // print("downloaded")
            guard let data = data else { return }
            //ロードしたmusicデータを処理
            //print(String(data: data!, encoding:.utf8)!)
            do {
                // ロードデータ処理
                try self.LoadMusicData(data: data)
                //もう一度通常取得を試みる
                self.DownloadMusicData(callback: callback)
                
            } catch (let e) {
                // print(e)
                //Jsonではなかった。何か他の結果が帰ってきた
                callback(e)
            }
        }
        task.resume()
    }
    private func LoadMusicData(data: Data) throws {
        let jsonArray = try decodeStringDictionaryArray(from: data)
        for dic in jsonArray {
            let favoriteCount = try optionalJSONInt(dic, key: "favorite")
            let favoriteCountTime = try optionalJSONInt(dic, key: "favoriteTime")
            self.musicDatas.setMusic(
                sqlID: try requiredJSONInt(dic, key: "id"),
                movieURL: try requiredJSONString(dic, key: "movieURL"),
                thumbnailURL: try requiredJSONString(dic, key: "thumbnailURL"),
                title: try requiredJSONString(dic, key: "title"),
                artist: try requiredJSONString(dic, key: "artist"),
                movieLength: try requiredJSONString(dic, key: "movieLength"),
                tags: try requiredJSONString(dic, key: "tags"),
                updateTime: try requiredJSONInt(dic, key: "updateTime"),
                createTime: try requiredJSONInt(dic, key: "createTime"),
                favoriteCount: favoriteCount,
                favoriteCountTime: favoriteCountTime
            )
        }
        //タグリストを更新
        self.musicDatas.createTaglist()
        //保存データも更新
        UserData.sharedInstance.MusicsJson = self.musicDatas.toMusicsJsonString()
    }
    
    func DownloadLevelData(callback: @escaping (Error?) -> Void ) -> Void {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL+"?req=levely-noTimetag&userID=\(UserData.sharedInstance.UserID.prefix(8))&time="+String(self.musicDatas.getLastUpdateTimeLevel()))!
        // print("URL=\(url)")
        let req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let task = session.dataTask(with: req){(data,response,error) in
            if let error = error {
                // print("levelLoad-error") //エラー
                callback(error)
                return
            }
            if let responseError = self.validateHTTPResponse(response, data: data) {
                callback(responseError)
                return
            }
            // print("downloaded")
            guard let data = data else { return }
            //ロードしたlevelデータを処理
            let htRet = String(decoding: data, as: UTF8.self)
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
                // ロードデータ処理
                try self.LoadLevelData(data: data)
                callback(nil)

            } catch (let e) {
                // print(e)
                //Jsonではなかった。何か他の結果が帰ってきた
                callback(e)
            }
        }
        task.resume()
    }
    private func downloadMyEditingLevelsIfNeeded(needsRecovery: Bool, callback: @escaping (Error?) -> Void) {
        guard needsRecovery else {
            callback(nil)
            return
        }

        // 更新日時による絞り込みをせず、自分の編集中データを取得する。
        guard let url = URL(string: AppDelegate.PHPURL + "?req=level-noTimetag-onlyMyEdit&userID=\(UserData.sharedInstance.UserID.prefix(8))") else {
            callback(URLError(.badURL))
            return
        }
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                callback(error)
                return
            }
            if let responseError = self.validateHTTPResponse(response, data: data) {
                callback(responseError)
                return
            }
            guard let data = data else {
                callback(ServerResponseError.noData)
                return
            }
            do {
                try self.LoadLevelData(data: data)
                callback(nil)
            } catch {
                callback(error)
            }
        }
        task.resume()
    }

    func DownloadLevelData_FirstData(serverURL:String, callback: @escaping (Error?) -> Void ) -> Void {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:serverURL+"levelJson")!
        // print("URL=\(url)")
        let req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let task = session.dataTask(with: req){(data,response,error) in
            if let error = error {
                // print("musicLoad-error") //エラー。例えばオフラインとか
                callback(error)
                return
            }
            if let responseError = self.validateHTTPResponse(response, data: data) {
                callback(responseError)
                return
            }
            // print("downloaded-fd")
            guard let data = data else { return }
            //ロードしたmusicデータを処理
            //print(String(data: data!, encoding:.utf8)!)
            do {
                // ロードデータ処理
                try self.LoadLevelData(data: data)
                //もう一度通常取得を試みる
                self.DownloadLevelData(callback: callback)

            } catch (let e) {
                // print(e)
                //Jsonではなかった。何か他の結果が帰ってきた
                callback(e)
            }
        }
        task.resume()
    }
    private func LoadLevelData(data: Data) throws {
        let jsonArray = try decodeStringDictionaryArray(from: data)
        for dic in jsonArray {
            let calcLv = try optionalJSONInt(dic, key: "calcLv")
            let playCountTime = try optionalJSONInt(dic, key: "playCountTime")
            let commentTime = try optionalJSONInt(dic, key: "commentTime")
            let scoreTime = try optionalJSONInt(dic, key: "scoreTime")
            let likeCount = try optionalJSONInt(dic, key: "poslike")
            let dislikeCount = try optionalJSONInt(dic, key: "dislike")
            let likeCountTime = try optionalJSONInt(dic, key: "likeTime")
            self.musicDatas.setLevel(
                sqlID: try requiredJSONInt(dic, key: "id"),
                movieURL: try requiredJSONString(dic, key: "movieURL"),
                level: try requiredJSONInt(dic, key: "level"),
                calcLv: calcLv,
                creator: try requiredJSONString(dic, key: "creator"),
                description: try requiredJSONString(dic, key: "description"),
                speed: try requiredJSONInt(dic, key: "speed"),
                noteData: dic["bitNote"] ?? "",
                updateTime: try requiredJSONInt(dic, key: "updateTime"),
                createTime: try requiredJSONInt(dic, key: "createTime"),
                playCount: try requiredJSONInt(dic, key: "playCount"),
                playCountTime: playCountTime,
                favoriteCount: 0,
                favoriteCountTime: 0,
                commentTime: commentTime,
                scoreTime: scoreTime,
                likeCount: likeCount,
                dislikeCount: dislikeCount,
                likeCountTime: likeCountTime
            )
            //noteDataは最初に全部取得すると通信量が大きいからゲーム開始時に取得することにする
        }
        //タグリストを更新
        self.musicDatas.createTaglist()
        //保存データも更新
        UserData.sharedInstance.LevelsJson = self.musicDatas.toLevelsJsonString()
    }
    
    func Download_music_FavoriteCountData(callback: @escaping (Error?) -> Void ) -> Void {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL+"?req=music-Fc&musicFavoriteTime="+String(self.musicDatas.getLastFavoriteCountTimeMusic()))!
        // print("URL=\(url)")
        let req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let task = session.dataTask(with: req){(data,response,error) in
            if let error = error {
                // print("FavoriteCountLoad-error") //エラー
                callback(error)
                return
            }
            if let responseError = self.validateHTTPResponse(response, data: data) {
                callback(responseError)
                return
            }
            // print("downloaded")
            guard let data = data else { return }
            //ロードしたlevelデータを処理
            let htRet = String(decoding: data, as: UTF8.self)
            //print(htRet)
            if htRet == "latest" {
                callback(nil)
                return
            }
            do {
                let jsonArray = try decodeStringDictionaryArray(from: data)
                for dic in jsonArray {
                    self.musicDatas.setMusic_Favoritecount( sqlID: try requiredJSONInt(dic, key: "id"),
                                              favoriteCount: dic["favorite"].flatMap(Int.init) ?? -1,
                                              favoriteCountTime: dic["favoriteTime"].flatMap(Int.init) ?? -1
                    )
                }
                //保存データも更新
                UserData.sharedInstance.LevelsJson = self.musicDatas.toLevelsJsonString()
                callback(nil)

            } catch (let e) {
                // print(e)
                //Jsonではなかった。何か他の結果が帰ってきた
                callback(e)
            }
        }
        task.resume()
    }
    func Download_level_PlayLikeCountData(callback: @escaping (Error?) -> Void ) -> Void {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL+"?req=level-PcLcCtSt&playcountTime="+String(self.musicDatas.getLastPlayCountTimeLevel())+"&likeTime="+String(self.musicDatas.getLastLikeCountTimeLevel())+"&commentTime="+String(self.musicDatas.getLastCommentTimeLevel())+"&scoreTime="+String(self.musicDatas.getLastScoreTimeLevel()))!
        // print("URL=\(url)")
        let req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let task = session.dataTask(with: req){(data,response,error) in
            if let error = error {
                // print("PlayLikeCountLoad-error") //エラー
                callback(error)
                return
            }
            if let responseError = self.validateHTTPResponse(response, data: data) {
                callback(responseError)
                return
            }
            // print("downloaded")
            guard let data = data else { return }
            //ロードしたlevelデータを処理
            let htRet = String(decoding: data, as: UTF8.self)
            //print(htRet)
            if htRet == "latest" {
                callback(nil)
                return
            }
            do {
                let jsonArray = try decodeStringDictionaryArray(from: data)
                for dic in jsonArray {
                    self.musicDatas.setLevel_PlaycountLike( sqlID: try requiredJSONInt(dic, key: "id"),
                                                                playCount: dic["playCount"].flatMap(Int.init) ?? -1,
                                                                playCountTime: dic["playCountTime"].flatMap(Int.init) ?? -1,
                                                                commentTime: dic["commentTime"].flatMap(Int.init) ?? -1,
                                                                scoreTime: dic["scoreTime"].flatMap(Int.init) ?? -1,
                                                                likeCount: dic["poslike"].flatMap(Int.init) ?? -1,
                                                                dislikeCount: dic["dislike"].flatMap(Int.init) ?? -1,
                                                                likeCountTime: dic["likeTime"].flatMap(Int.init) ?? -1
                    )
                }
                //保存データも更新
                UserData.sharedInstance.LevelsJson = self.musicDatas.toLevelsJsonString()
                callback(nil)

            } catch (let e) {
                // print(e)
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
        let req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let task = session.dataTask(with: req){(data,response,error) in
            if let error = error {
                // print("notesLoad-error")//エラー。例えばオフラインとか
                callback(error)
                return
            }
            if let responseError = self.validateHTTPResponse(response, data: data) {
                callback(responseError)
                return
            }
            guard let data = data else {
                let error = NSError(domain: "NicoFlick.DownloadTimetag",
                                    code: 1,
                                    userInfo: [NSLocalizedDescriptionKey: "譜面データが返されませんでした"])
                callback(error)
                return
            }
            
            do {
                guard let jsonDic = try JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, String>,
                      let notes = jsonDic["notes"] else {
                    let error = NSError(domain: "NicoFlick.DownloadTimetag",
                                        code: 2,
                                        userInfo: [NSLocalizedDescriptionKey: "有効な譜面データを取得できませんでした"])
                    callback(error)
                    return
                }
                //musicDatasに保存（次回からロードしなくなる）
                level.noteData = notes
                
                //保存データも更新
                UserData.sharedInstance.LevelsJson = self.musicDatas.toLevelsJsonString()
                // print("Notes Download")
                callback(nil)
                
            } catch (let e) {
                // print(e)
                //Jsonではなかった。何か他の結果が帰ってきた
                callback(e)
            }
            
        }
        task.resume()
    }
    func DownloadScoreData(levelID:Int, callback: @escaping (Error?) -> Void ) -> Void {
        //データベース接続
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = 30
        let session = URLSession(configuration: configuration)
        let url = URL(string:AppDelegate.PHPURL+"?req=scorez&levelID=\(levelID)&time=\(scoreDatas.getLastUpdateTime(levelID: levelID))")!
        let req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let task = session.dataTask(with: req){(data,response,error) in
            defer { session.finishTasksAndInvalidate() }
            if let error = error {
                // print("DownloadScoreData-error")//エラー。例えばオフラインとか
                callback(error)
                return
            }
            if let responseError = self.validateHTTPResponse(response, data: data) {
                callback(responseError)
                return
            }
            // print("downloaded")
            guard let data = data else { return }
            //print(String(data: data!, encoding:.utf8)!)
            do{
                let jsonArray = try decodeStringDictionaryArray(from: data)
                for dic in jsonArray {
                    self.scoreDatas.setScore(sqlID: try requiredJSONInt(dic, key: "id"),
                                             levelID: levelID,
                                             score: try requiredJSONInt(dic, key: "score"),
                                             userID: try requiredJSONString(dic, key: "userID"),
                                             updateTime: try requiredJSONInt(dic, key: "updateTime")
                    )
                }
                //保存データも更新
                UserData.sharedInstance.ScoresJson = self.scoreDatas.toScoresJsonString()
                callback(nil)
            }catch(let e){
                // print(e)
                callback(e)
            }
            return
        }
        task.resume()
    }
    func DownloadCommentData(levelID:Int, callback: @escaping (Error?) -> Void ) -> Void {
        //データベース接続
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = 30
        let session = URLSession(configuration: configuration)
        let url = URL(string:AppDelegate.PHPURL+"?req=commentz&levelID=\(levelID)&time=\(commentDatas.getLastUpdateTime(levelID: levelID))")!
        let req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let task = session.dataTask(with: req){(data,response,error) in
            defer { session.finishTasksAndInvalidate() }
            if let error = error {
                // print("DownloadCommentData-error")//エラー。例えばオフラインとか
                callback(error)
                return
            }
            if let responseError = self.validateHTTPResponse(response, data: data) {
                callback(responseError)
                return
            }
            // print("downloaded")
            guard let data = data else { return }
            //print(String(data: data!, encoding:.utf8)!)
            do{
                let jsonArray = try decodeStringDictionaryArray(from: data)
                for dic in jsonArray {
                    self.commentDatas.setComment(sqlID: try requiredJSONInt(dic, key: "id"),
                                                 levelID: levelID,
                                                 comment: try requiredJSONString(dic, key: "comment"),
                                                 userID: try requiredJSONString(dic, key: "userID"),
                                                 updateTime: try requiredJSONInt(dic, key: "updateTime")
                    )
                }
                //保存データも更新
                UserData.sharedInstance.CommentsJson = self.commentDatas.toCommentsJsonString()
                callback(nil)
            }catch(let e){
                // print(e)
                callback(e)
            }
        }
        task.resume()
    }
    func DownloadUserNameData(callback: @escaping (Error?) -> Void) {
        Self.userNameDownloadLock.lock()
        Self.userNameDownloadCallbacks.append(callback)
        let shouldStart = Self.userNameDownloadCallbacks.count == 1
        Self.userNameDownloadLock.unlock()
        guard shouldStart else { return }

        userNameDatas.restoreIfNeeded()
        downloadUserNames(generation: userNameDatas.generation) { error in
            Self.userNameDownloadLock.lock()
            let callbacks = Self.userNameDownloadCallbacks
            Self.userNameDownloadCallbacks.removeAll()
            Self.userNameDownloadLock.unlock()
            // Do not invoke client code while holding the coordination lock.
            callbacks.forEach { $0(error) }
        }
    }

    private func downloadUserNames(generation: Int, allowChunk: Bool = true, callback: @escaping (Error?) -> Void) {
        //データベース接続
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = 30
        let session = URLSession(configuration: configuration)
        var updateTime = userNameDatas.getLastUpdateTime()
        if userNameDatas.usernameJsonNumCount >= 0 {
            updateTime = 0
        }
        let url = URL(string:AppDelegate.PHPURL+"?req=usernamez&time=\(updateTime)")!
        let req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let task = session.dataTask(with: req){(data,response,error) in
            defer { session.finishTasksAndInvalidate() }
            if let error = error {
                // print("DownloadUserName-error")//エラー。例えばオフラインとか
                callback(error)
                return
            }
            if let responseError = self.validateHTTPResponse(response, data: data) {
                callback(responseError)
                return
            }
            // print("downloaded")
            guard let data = data else { return }
            let htRet = String(decoding: data, as: UTF8.self)
            //print(htRet)
            if htRet == "latest" {
                callback(nil)
                return
            }else if htRet.hasPrefix("[{\"server-url\":"){
                
                // Avoid an endless reconciliation loop if the server keeps returning a snapshot.
                guard allowChunk else {
                    callback(ServerResponseError.invalidResponse)
                    return
                }
                //(サブ)サーバにファイルを取りに行く
                do{
                    let jsonArray = try decodeStringDictionaryArray(from: data)
                    guard !jsonArray.isEmpty else { throw ServerResponseError.noData }
                    for dic in jsonArray {
                        let serverURL = try requiredJSONString(dic, key: "server-url")
                        let createTime = try requiredJSONInt(dic, key: "createTime")
                        // print(serverURL)
                        // print(createTime)
                        let previousTime = self.userNameDatas.usernameJsonCreateTime
                        let chunk = previousTime != 0 && previousTime != createTime
                            ? 0 : max(0, self.userNameDatas.usernameJsonNumCount)
                        self.downloadUserNameChunk(serverURL: serverURL, chunk: chunk,
                                                   createTime: createTime, generation: generation,
                                                   callback: callback)
                        break
                    }
                    
                }catch(let e){
                    // print(e)
                    callback(e)
                }
                return
            }
            do{
                try self.userNameDatas.applyDownloadedData(data, generation: generation)
                callback(nil)
            }catch(let e){
                // print(e)
                callback(e)
            }
        }
        task.resume()
    }
    private func downloadUserNameChunk(serverURL: String, chunk: Int, createTime: Int,
                                       generation: Int, callback: @escaping (Error?) -> Void) {
        //データベース接続
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = 30
        let session = URLSession(configuration: configuration)
        let url = URL(string:serverURL+"usernameJson\(chunk)")!
        // print(url)
        let req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let task = session.dataTask(with: req){(data,response,error) in
            defer { session.finishTasksAndInvalidate() }
            if let error = error {
                // print("DownloadUserName-error")//エラー。例えばオフラインとか
                callback(error)
                return
            }
            if let responseError = self.validateHTTPResponse(response, data: data) {
                callback(responseError)
                return
            }
            guard var data = data else { return }
            // print("downloaded")
            
            let nextMarker = Data("//next".utf8)
            let nextFlg = data.suffix(nextMarker.count) == nextMarker
            if nextFlg {
                // print("//next")
                data.removeLast(nextMarker.count)
            }else{
                // print("//finish")
            }
            
            //print(String(data: data!, encoding:.utf8)!)
            do{
                try self.userNameDatas.applyDownloadedData(data, generation: generation, chunk: chunk,
                                                          createTime: createTime, nextDataExists: nextFlg)
                if !nextFlg {
                    //分割Jsonの最後まで来た。もう一度通常取得を試みてFirstデータにない残りを取得。
                    self.downloadUserNames(generation: generation, allowChunk: false, callback: callback)
                }else{
                    callback(nil)
                }
                
            }catch(let e){
                // print(e)
                callback(e)
            }
        }
        task.resume()
    }
    func Chance_DownloadUserNameData_FirstData(callback: @escaping (Error?) -> Void ) -> Void {
        userNameDatas.restoreIfNeeded()
        if userNameDatas.usernameJsonNumCount == -1 {
            callback(nil)
            return
        }
        DownloadUserNameData(callback: callback)
    }
    
    
    func getMusicScoreData(musicID:Int, userID:String, callback: @escaping (Dictionary<String,String>?) -> Void ) -> Void {
        //データベース接続
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = 30
        let session = URLSession(configuration: configuration)
        let url = URL(string:AppDelegate.PHPURL+"?req=mscore&musicID=\(musicID)&userID=\(userID)")!
        let req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let task = session.dataTask(with: req){(data,response,error) in
            defer { session.finishTasksAndInvalidate() }
            if error != nil {
                // print("getScoreData-error")//エラー。例えばオフラインとか
                callback( nil )
                return
            }
            if self.validateHTTPResponse(response, data: data) != nil {
                callback(nil)
                return
            }
            guard let data = data else { return }
            do {
                guard let scoreData = try JSONSerialization.jsonObject(with: data) as? [String: String] else {
                    callback(nil)
                    return
                }
                callback(scoreData)
            }catch _ {
                callback(nil)
            }
        }
        task.resume()
    }
    
    func checkLevelPassword(id:Int, pass:String, userID:String, callback: @escaping (Bool) -> Void ) -> Void {
        //
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL+"?req=level-passCheckz&id=\(id)&userPASS=\(pass)&userID=\(userID)")!
        let req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let task = session.dataTask(with: req){(data,response,error) in
            if error != nil {
                // print("checkLevelPass-error") //エラー。例えばオフラインとか
                callback(false)
                return
            }
            if self.validateHTTPResponse(response, data: data) != nil {
                callback(false)
                return
            }
            guard let data = data else { return }
            // print(String(decoding: data, as: UTF8.self))
            callback(String(decoding: data, as: UTF8.self) == "true")
        }
        task.resume()
    }
    
    func postUserName(name:String, userID:String, callback: @escaping (Bool) -> Void ) -> Void {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let body = "req=userName-add&id="+userID+"&name="+name.urlEncoded
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: req){(data,response,error) in
            if error != nil {
                // print("postUserName-error")//エラー。例えばオフラインとか
                callback(false)
                return
            }
            if self.validateHTTPResponse(response, data: data) != nil {
                callback(false)
                return
            }
            guard let data = data else { return }
            let str:String = String(decoding: data, as: UTF8.self)
            // print(str)
            if str.hasPrefix("success userName-add UserNameSqlID="){ //Ver.1.4〜
                UserData.sharedInstance.UserNameID = Int(str.pregMatche_firstString(pattern: "UserNameSqlID=(\\d+)")) ?? 0
                callback(true)
                return
            }
            callback(false)
        }
        task.resume()
    }
    //Ver.1.4未満のケア
    func getUserNameSqlID(userID:String, callback: @escaping () -> Void ) -> Void {
        if UserData.sharedInstance.UserName == "" || UserData.sharedInstance.UserNameID != 0 { //名前登録してるけど、まだIDを取得していなときだけ実行する（Ver.1.4未満）
            // print("usernameid=\( UserData.sharedInstance.UserNameID )")
            callback()
            return
        }
        //データベース接続
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL+"?req=userNameID&id=\(userID)")!
        let req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let task = session.dataTask(with: req){(data,response,error) in
            if error != nil {
                // print("getUserNameID-error")//エラー。例えばオフラインとか
                callback()
                return
            }
            if self.validateHTTPResponse(response, data: data) != nil {
                callback()
                return
            }
            guard let data = data else { return }
            let str:String = String(decoding: data, as: UTF8.self)
            // print(str)
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
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let body = "req=scorem-add&userID=\(userID)&userNameID=\(UserData.sharedInstance.UserNameID)&scoreset=\(scoreset)&pass=\(Crypt.init().encriptx_urlsafe(plainText: "ニコFlick", pass: userID))"
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        // print(body)
        let task = session.dataTask(with: req){(data,response,error) in
            if (error != nil) {
                callback(false)
                return
            }
            if self.validateHTTPResponse(response, data: data) != nil {
                callback(false)
                return
            }
            guard let data = data else {
                callback(false)
                return
            }
            let str:String = String(decoding: data, as: UTF8.self)
            // print(str)
            if str.contains("success score-add"){ //php warningが追記されていたとき怖いので「==」じゃなくて「含む」にしとく
                // print("スコア送信成功")
                callback(true)
            }else {
                // print("スコア送信失敗")
                callback(false)
            }
        }
        task.resume()
    }
    func postPlayCountData(playcountset:String, callback: @escaping (Bool) -> Void ) -> Void {
        //  登録
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let body = "req=playcount-add&playcountset=\(playcountset)"
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: req){(data,response,error) in
            if (error != nil) {
                callback(false)
                return
            }
            if self.validateHTTPResponse(response, data: data) != nil {
                callback(false)
                return
            }
            guard let data = data else { return }
            let str:String = String(decoding: data, as: UTF8.self)
            // print(str)
            if str == "success playcount-add" {
                callback(true)
            }else{
                // print("playcount送信失敗")
                callback(false)
            }
        }
        task.resume()
    }
    func postMusicFavoriteCountData(musicfavoritecountset:String, callback: @escaping (Bool) -> Void ) -> Void {
        //  登録
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let body = "req=musicfavorite-add&musicfavoritecountset=\(musicfavoritecountset)"
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: req){(data,response,error) in
            if (error != nil) {
                callback(false)
                return
            }
            if self.validateHTTPResponse(response, data: data) != nil {
                callback(false)
                return
            }
            guard let data = data else { return }
            let str:String = String(decoding: data, as: UTF8.self)
            // print(str)
            if str == "success musicfavorite-add" {
                callback(true)
            }else{
                // print("musicfavorite送信失敗")
                callback(false)
            }
        }
        task.resume()
    }
    func postLikeCountData(likecountset:String, callback: @escaping (Bool) -> Void ) -> Void {
        //  登録
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let body = "req=likecount-add&likecountset=\(likecountset)"
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: req){(data,response,error) in
            if (error != nil) {
                callback(false)
                return
            }
            if self.validateHTTPResponse(response, data: data) != nil {
                callback(false)
                return
            }
            guard let data = data else { return }
            let str:String = String(decoding: data, as: UTF8.self)
            // print(str)
            if str == "success likecount-add" {
                callback(true)
            }else{
                // print("like送信失敗")
                callback(false)
            }
        }
        task.resume()
    }
    func postDislikeCountData(dislikecountset:String, callback: @escaping (Bool) -> Void ) -> Void {
        //  登録
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let body = "req=dislikecount-add&dislikecountset=\(dislikecountset)"
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: req){(data,response,error) in
            if (error != nil) {
                callback(false)
                return
            }
            if self.validateHTTPResponse(response, data: data) != nil {
                callback(false)
                return
            }
            guard let data = data else { return }
            let str:String = String(decoding: data, as: UTF8.self)
            // print(str)
            if str == "success dislikecount-add" {
                callback(true)
            }else{
                // print("dislike送信失敗")
                callback(false)
            }
        }
        task.resume()
    }
    func postComment(comment:String, levelID:Int, userID:String, callback: @escaping (Bool) -> Void ) -> Void {
        //  登録
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = 30
        let session = URLSession(configuration: configuration)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let urlEncodeComment:String = comment.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!
        let body = "req=comment-add&userID=\(userID)&levelID=\(levelID)&comment=\(urlEncodeComment)"
        //print(body)
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: req){(data,response,error) in
            defer { session.finishTasksAndInvalidate() }
            if error != nil || self.validateHTTPResponse(response, data: data) != nil {
                callback(false)
                return
            }
            guard let data = data else { return }
            let str:String = String(decoding: data, as: UTF8.self)
            // print(str)
            if str == "success comment-add" {
                callback(true)
            }else{
                // print("dislike送信失敗")
                callback(false)
            }
        }
        task.resume()
    }
    func postUserCountData(){
        let playcountset = UserData.sharedInstance.PlayCount.getSendPlayCountStr() //送信するデータ
        // print("playcountset="+playcountset)
        if playcountset != "" {
            // プレイ回数 送信
            ServerDataHandler().postPlayCountData(playcountset: playcountset) { (bool) in
                if bool {
                    //プレイ回数データを保存する(初期化データになる)
                    UserData.sharedInstance.PlayCount.setSended()
                }
            }
        }
        let likecountset = UserData.sharedInstance.LikeCount.getSendLikeCountStr() //送信するデータ
        // print("likecountset="+likecountset)
        if likecountset != "" {
            // お気に入り回数 送信
            ServerDataHandler().postLikeCountData(likecountset: likecountset) { (bool) in
                if bool {
                    //お気に入り回数データを保存する(初期化データになる)
                    UserData.sharedInstance.LikeCount.setSended()
                }
            }
        }
        let dislikecountset = UserData.sharedInstance.DislikeCount.getSendLikeCountStr() //送信するデータ
        // print("dislikecountset="+dislikecountset)
        if dislikecountset != "" {
            // お気に入り回数 送信
            ServerDataHandler().postDislikeCountData(dislikecountset: dislikecountset) { (bool) in
                if bool {
                    //お気に入り回数データを保存する(初期化データになる)
                    UserData.sharedInstance.DislikeCount.setSended()
                }
            }
        }
        let musicfavoritecountset = UserData.sharedInstance.MusicFavoriteCount.getSendMusicFavoriteCountStr() //送信するデータ
        // print("musicfavoritecountset="+musicfavoritecountset)
        if musicfavoritecountset != "" {
            // お気に入り回数 送信
            ServerDataHandler().postMusicFavoriteCountData(musicfavoritecountset: musicfavoritecountset) { (bool) in
                if bool {
                    //お気に入り回数データを保存する(初期化データになる)
                    UserData.sharedInstance.MusicFavoriteCount.setSended()
                }
            }
        }
    }
    
    func postMusicInsert(nicoURL:String, thumbnailURL:String, title:String, artist:String, timeLength:String, tags:String, userPASS:String, callback: @escaping (String, Error?) -> Void) -> Void {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let body = "req=music-insert&movieURL=\(nicoURL)&thumbnailURL=\(thumbnailURL)&title=\(title.urlEncoded)&artist=\(artist.urlEncoded)&movieLength=\(timeLength)&tags=\(tags.urlEncoded)&userPASS=\(userPASS)"
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: req){(data,response,error) in
            if let error = error {
                callback("",error)
                return
            }
            if let responseError = self.validateHTTPResponse(response, data: data) {
                callback("", responseError)
                return
            }
            guard let data = data else { return }
            let retStr:String = String(decoding: data, as: UTF8.self)
            //print(retStr)
            callback(retStr, nil)
        }
        task.resume()
    }
    func postMusicTagUpdate(id:Int, tags:String, userID:String, callback: @escaping (Bool) -> Void ) -> Void {
        //  登録
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let body = "req=musicTag-update&id=\(id)&tags=\(tags.urlEncoded)&userID=\(userID)&pass=\(Crypt.init().encriptx_urlsafe(plainText: "ニコFlick", pass: userID))"
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        //print(body)
        let task = session.dataTask(with: req){(data,response,error) in
            if (error != nil) {
                callback(false)
                return
            }
            if self.validateHTTPResponse(response, data: data) != nil {
                callback(false)
                return
            }
            guard let data = data else { return }
            let str:String = String(decoding: data, as: UTF8.self)
            // print(str)
            if str == "success musictag-update"{
                callback(true)
            }else {
                // print("musicタグ送信失敗")
                callback(false)
            }
        }
        task.resume()
    }
    func postMusicThumbnailUpdate(id:Int, thumbnailURL:String, userID:String, callback: @escaping (Bool) -> Void ) -> Void {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let pass = Crypt.init().encriptx_urlsafe(plainText: "ニコFlick", pass: userID)
        let body = "req=musicThumbnail-update&id=\(id)&thumbnailURL=\(thumbnailURL.urlEncoded)&userID=\(userID)&pass=\(pass)"
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: req){(data,response,error) in
            if error != nil {
                callback(false)
                return
            }
            if self.validateHTTPResponse(response, data: data) != nil {
                callback(false)
                return
            }
            guard let data = data else {
                callback(false)
                return
            }
            let str = String(decoding: data, as: UTF8.self)
            callback(str == "success musicthumbnail-update")
        }
        task.resume()
    }
    /// Use the ID returned by this insertion, never an inferred latest chart ID.
    static func insertedLevelID(from response: String) -> Int? {
        guard response.contains("<!--EchoHtmlMes_OK-->"),
              let regex = try? NSRegularExpression(pattern: "<!--InsertedLevelID=([0-9]+)-->") else {
            return nil
        }
        let matches = regex.matches(in: response, range: NSRange(response.startIndex..., in: response))
        guard matches.count == 1,
              let range = Range(matches[0].range(at: 1), in: response),
              let id = Int(response[range]), id > 0 else { return nil }
        return id
    }

    func postLevelInsert(nicoURL:String, level:Int, creator:String, description:String, speed:Int, notes:String, userPASS:String, userID:String, callback: @escaping (String,Error?) -> Void ) -> Void {
        // ゲームデータの投稿
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let body = "req=levelm-insert&movieURL=\(nicoURL)&level=\(level)&creator=\(creator.urlEncoded)&description=\(description.urlEncoded)&speed=\(speed)&notes=\(notes.urlEncoded)&userPASS=\(userPASS)&userID=\(userID)"
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: req){(data,response,error) in
            if let error = error {
                callback("",error)
                return
            }
            if let responseError = self.validateHTTPResponse(response, data: data) {
                callback("", responseError)
                return
            }
            guard let data = data else { return }
            let retStr:String = String(decoding: data, as: UTF8.self)
            //print(retStr)
            callback(retStr, nil)
        }
        task.resume()
    }
    func postLevelUpdate(sqlID:Int, nicoURL:String, level:Int, creator:String, description:String, speed:Int, notes:String, userPASS:String, callback: @escaping (String,Error?) -> Void ) -> Void {
        // ゲームデータの投稿
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let body = "req=level-update&id=\(sqlID)&movieURL=\(nicoURL)&level=\(level)&creator=\(creator.urlEncoded)&description=\(description.urlEncoded)&speed=\(speed)&notes=\(notes.urlEncoded)&userPASS=\(userPASS)"
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: req){(data,response,error) in
            if let error = error {
                callback("",error)
                return
            }
            if let responseError = self.validateHTTPResponse(response, data: data) {
                callback("", responseError)
                return
            }
            guard let data = data else { return }
            let retStr:String = String(decoding: data, as: UTF8.self)
            //print(retStr)
            callback(retStr, nil)
        }
        task.resume()
    }
    func postLevelDelete(sqlID:Int, userPASS:String, callback:@escaping (String,Error?) -> Void ) -> Void {
        // ゲームデータの投稿
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let body = "req=level-delete&id=\(sqlID)&userPASS=\(userPASS)"
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: req){(data,response,error) in
            if let error = error {
                callback("",error)
                return
            }
            if let responseError = self.validateHTTPResponse(response, data: data) {
                callback("", responseError)
                return
            }
            guard let data = data else { return }
            let retStr:String = String(decoding: data, as: UTF8.self)
            //print(retStr)
            callback(retStr, nil)
        }
        task.resume()
    }
    
    func postReport(musicID:Int, comment:String, userID:String, callback: @escaping (Bool) -> Void ) -> Void {
        //  登録
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let urlEncodeComment:String = comment.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!
        // print("urlEncodeComment")
        // print(urlEncodeComment)
        let body = "req=report&userID=\(userID)&musicID=\(musicID)&comment=\(urlEncodeComment)"
        //print(body)
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: req){(data,response,error) in
            if error != nil {
                // print("postReport-error")//エラー。例えばオフラインとか
                callback(false)
                return
            }
            if self.validateHTTPResponse(response, data: data) != nil {
                callback(false)
                return
            }
            guard let data = data else { return }
            let retStr:String = String(decoding: data, as: UTF8.self)
            // print(retStr)
            if retStr == "success report" {
                callback(true)
            }else {
                callback(false)
            }
        }
        task.resume()
    }
    func getReport(musicID:Int, callback: @escaping (Int,String) -> Void ) -> Void {
        //データベース接続
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL+"?req=getReport&musicID=\(musicID)&pass=nicoflick_lzmys")!
        let req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let task = session.dataTask(with: req){(data,response,error) in
            if error != nil {
                // print("getReport-error")//エラー。例えばオフラインとか
                return
            }
            if self.validateHTTPResponse(response, data: data) != nil {
                return
            }
            guard let data = data else { return }
            let str:String = String(decoding: data, as: UTF8.self)
            // print(str)
            if str.hasPrefix("success num="){
                let num = Int(str.pregMatche_firstString(pattern: "num=(\\d+)&")) ?? -1
                let comm = str.pregMatche_firstString(pattern: "comment=(.*)$")
                callback( num, comm )
            }
        }
        task.resume()
    }
    func postMusicDelete(musicID:Int,masterPass:String, callback: @escaping () -> Void ) -> Void {
        //データベース接続
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL+"?req=music-delete&musicID=\(musicID)&masterPASS=\(masterPass)")!
        let req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let task = session.dataTask(with: req){(data,response,error) in
            if error != nil {
                // print("postMusicDelete-error")//エラー。例えばオフラインとか
                return
            }
            if self.validateHTTPResponse(response, data: data) != nil {
                return
            }
            guard let data = data else { return }
            let str:String = String(decoding: data, as: UTF8.self)
            // print(str)
            if str.pregMatche(pattern: "message=Success"){
                callback()
            }
        }
        task.resume()
    }
    
    func postTagsToMusics(tags:String, musicsStr:String, callback: @escaping () -> Void ) -> Void {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        let body = "req=tagsToMusics&tags="+tags.urlEncoded+"&musics="+musicsStr.urlEncoded
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: req){(data,response,error) in
            if error != nil || self.validateHTTPResponse(response, data: data) != nil {
                callback()
                return
            }
            callback()
        }
        task.resume()
    }
    
}
