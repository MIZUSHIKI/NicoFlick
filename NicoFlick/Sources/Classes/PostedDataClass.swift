//
//  PostedDataClass.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/10/18.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//

import Foundation

//データベースに登録されている以下項目を保持しておく
// ・ユーザーネーム
// ・スコア
// ・コメント


class userNameData {
    var sqlID:Int!
    var name:String!
    var sqlUpdateTime:Int!
}
class scoreData {
    var sqlID:Int!
    var levelID:Int!
    var score:Int!
    var userID:String!
    var sqlUpdateTime:Int!
}
class commentData {
    var sqlID:Int!
    var levelID:Int!
    var comment:String!
    var userID:String!
    var sqlUpdateTime:Int!
}


class userNameDataLists {
    static let sharedInstance = userNameDataLists()

    private struct Record: Codable {
        let sqlID: Int
        let name: String
        let updateTime: Int
    }

    private struct Snapshot: Codable {
        var names: [String: Record] = [:]
        var nextChunk = 0
        var createTime = 0
    }

    // All reads, batch commits and cache resets use the same lock. Records are values,
    // so no mutable objects escape to UI readers.
    private let lock = NSLock()
    private var snapshot = Snapshot()
    private var restored = false
    private var revision = 0
    private let storageKey = "UserNamesSnapshot"

    var usernameJsonNumCount: Int { synchronized { snapshot.nextChunk } }
    var usernameJsonCreateTime: Int { synchronized { snapshot.createTime } }
    var generation: Int { synchronized { revision } }

    private func synchronized<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    func restoreIfNeeded() {
        synchronized {
            guard !restored else { return }
            restored = true
            if let saved = LargeValueStore.read(storageKey),
               let decoded = try? JSONDecoder().decode(Snapshot.self, from: Data(saved.utf8)) {
                snapshot = decoded
                return
            }
            // Migrate the existing cache on the next successful commit.
            let userData = UserData.sharedInstance
            if let records = try? decodeRecords(Data(userData.UserNamesJson.utf8)) {
                snapshot.names = records
                snapshot.nextChunk = userData.UserNamesServerJsonNumCount
                snapshot.createTime = userData.UserNamesServerJsonCreateTime
            }
        }
    }

    func reset() {
        synchronized {
            revision += 1 // Reject any response that started before this reset.
            snapshot = Snapshot()
            restored = true
            if let data = try? JSONEncoder().encode(snapshot) {
                LargeValueStore.write(String(decoding: data, as: UTF8.self), key: storageKey)
            }
        }
    }

    func getUserName(userID: String) -> String {
        synchronized {
            guard let name = snapshot.names[userID]?.name, !name.isEmpty else { return "NO_NAME" }
            return name
        }
    }

    func getLastUpdateTime() -> Int {
        synchronized { snapshot.names.values.map { $0.updateTime }.max() ?? 0 }
    }

    private func decodeRecords(_ data: Data) throws -> [String: Record] {
        var records: [String: Record] = [:]
        for item in try decodeStringDictionaryArray(from: data) {
            let userID = try requiredJSONString(item, key: "userID")
            records[userID] = Record(sqlID: try requiredJSONInt(item, key: "id"),
                                     name: try requiredJSONString(item, key: "name"),
                                     updateTime: try requiredJSONInt(item, key: "updateTime"))
        }
        return records
    }

    func applyDownloadedData(_ data: Data, generation: Int,
                             chunk: Int? = nil, createTime: Int? = nil,
                             nextDataExists: Bool? = nil) throws {
        // Validate the entire response before changing the last-update watermark.
        let records = try decodeRecords(data)
        try synchronized {
            guard generation == revision else { throw URLError(.cancelled) }
            var updated = snapshot
            if let createTime {
                if updated.createTime != 0 && updated.createTime != createTime {
                    updated = Snapshot()
                }
                updated.createTime = createTime
            }
            for (id, record) in records { updated.names[id] = record }
            if let chunk, let nextDataExists {
                updated.nextChunk = nextDataExists ? chunk + 1 : -1
            }
            // Names and the resume position are one atomically replaced file.
            // A failed save leaves both the in-memory and persisted watermark unchanged.
            let encoded = try JSONEncoder().encode(updated)
            guard LargeValueStore.write(String(decoding: encoded, as: UTF8.self), key: storageKey) else {
                throw CocoaError(.fileWriteUnknown)
            }
            snapshot = updated
        }
    }
}

class ScoreDataLists {
    static let sharedInstance = ScoreDataLists()
    var scores:[scoreData] = []
    var SqlIDtoIndex:[Int:Int] = [:] //最初から scores:[Int:scoreData] にしとけば良かった
    
    func reset(){
        scores = []
        SqlIDtoIndex = [:]
    }
    func setScore(sqlID:Int, levelID:Int, score:Int, userID:String, updateTime:Int) {
        if let index = SqlIDtoIndex[sqlID] {
            scores[index].levelID = levelID
            scores[index].score = score
            scores[index].userID = userID
            scores[index].sqlUpdateTime = updateTime
            return
        }
        SqlIDtoIndex[sqlID] = scores.count
        let scoredata = scoreData()
        scoredata.sqlID = sqlID
        scoredata.levelID = levelID
        scoredata.score = score
        scoredata.userID = userID
        scoredata.sqlUpdateTime = updateTime
        scores.append(scoredata)
    }
    func getLastUpdateTime(levelID:Int?) -> Int {
        var time = 0
        for score in scores {
            if let levelID = levelID {
                if score.levelID != levelID { continue }
            }
            if time < score.sqlUpdateTime {
                time = score.sqlUpdateTime
            }
        }
        return time
    }
    func getSortedScores(levelID:Int) -> [scoreData] {
        return scores.filter({ (a) -> Bool in
            return a.levelID == levelID
        }).sorted { (a, b) -> Bool in
            a.score > b.score
        }
    }
    
    // score Json化。UserData保存用
    func toScoresJsonString() -> String {
        var jArray:[[String:String]] = []
        for scoredata in scores {
            var jObject:[String:String] = [:]
            jObject["id"] = String(scoredata.sqlID)
            jObject["levelID"] = String(scoredata.levelID)
            jObject["score"] = String(scoredata.score)
            jObject["userID"] = scoredata.userID
            jObject["updateTime"] = String(scoredata.sqlUpdateTime)
            
            jArray.append(jObject)
        }
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jArray, options: [])
            let jsonStr = String(bytes: jsonData, encoding: .utf8)!
            return jsonStr
        } catch (let e) {
            // print(e)
            return ""
        }
    }
    //保存データから読み込み
    func loadScoresJsonString(jsonStr:String){
        if( jsonStr=="" ){ return }
        let jsonData: Data =  jsonStr.data(using: String.Encoding.utf8)!
        do{
            //ロードしたusernameデータを処理
            let jsonArray = try decodeStringDictionaryArray(from: jsonData)
            for dic in jsonArray {
                self.setScore(sqlID: try requiredJSONInt(dic, key: "id"),
                              levelID: try requiredJSONInt(dic, key: "levelID"),
                              score: try requiredJSONInt(dic, key: "score"),
                              userID: try requiredJSONString(dic, key: "userID"),
                              updateTime: try requiredJSONInt(dic, key: "updateTime"))
            }
        }catch (let e) {
            // print(e)
        }
    }
}
class CommentDataLists {
    static let sharedInstance = CommentDataLists()
    var comments:[commentData] = []
    var SqlIDtoIndex:[Int:Int] = [:] //最初から comments:[Int:commentData] にしとけば良かった
    
    func reset(){
        comments = []
        SqlIDtoIndex = [:]
    }
    func setComment(sqlID:Int, levelID:Int, comment:String, userID:String, updateTime:Int) {
        if let index = SqlIDtoIndex[sqlID] {
            comments[index].levelID = levelID
            comments[index].comment = comment
            comments[index].userID = userID
            comments[index].sqlUpdateTime = updateTime
            return
        }
        SqlIDtoIndex[sqlID] = comments.count
        let commentdata = commentData()
        commentdata.sqlID = sqlID
        commentdata.levelID = levelID
        commentdata.comment = comment
        commentdata.userID = userID
        commentdata.sqlUpdateTime = updateTime
        comments.append(commentdata)
    }
    func getLastUpdateTime(levelID:Int?) -> Int {
        var time = 0
        for comment in comments {
            if let levelID = levelID {
                if comment.levelID != levelID { continue }
            }
            if time < comment.sqlUpdateTime {
                time = comment.sqlUpdateTime
            }
        }
        return time
    }
    func getSortedComments(levelID:Int) -> [commentData] {
        return comments.filter({ (a) -> Bool in
            return a.levelID == levelID
        }).sorted { (a, b) -> Bool in
            a.sqlID > b.sqlID
        }
    }
    
    // comment Json化。UserData保存用
    func toCommentsJsonString() -> String {
        var jArray:[[String:String]] = []
        for commentdata in comments {
            var jObject:[String:String] = [:]
            jObject["id"] = String(commentdata.sqlID)
            jObject["levelID"] = String(commentdata.levelID)
            jObject["comment"] = String(commentdata.comment)
            jObject["userID"] = commentdata.userID
            jObject["updateTime"] = String(commentdata.sqlUpdateTime)
            
            jArray.append(jObject)
        }
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jArray, options: [])
            let jsonStr = String(bytes: jsonData, encoding: .utf8)!
            return jsonStr
        } catch (let e) {
            // print(e)
            return ""
        }
    }
    //保存データから読み込み
    func loadCommentsJsonString(jsonStr:String){
        if( jsonStr=="" ){ return }
        let jsonData: Data =  jsonStr.data(using: String.Encoding.utf8)!
        do{
            //ロードしたusernameデータを処理
            let jsonArray = try decodeStringDictionaryArray(from: jsonData)
            for dic in jsonArray {
                self.setComment(
                    sqlID: try requiredJSONInt(dic, key: "id"),
                    levelID: try requiredJSONInt(dic, key: "levelID"),
                    comment: try requiredJSONString(dic, key: "comment"),
                    userID: try requiredJSONString(dic, key: "userID"),
                    updateTime: try requiredJSONInt(dic, key: "updateTime"))
            }
        }catch (let e) {
            // print(e)
        }
    }
}
