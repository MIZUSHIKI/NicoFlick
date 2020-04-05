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
    var userNames: [String:userNameData] = [:]
    
    //初期データ取得管理用フラグ
    var usernameJsonNumCount = 0
    var usernameJsonCreateTime = 0

    func reset(){
        userNames = [:]
        usernameJsonNumCount = 0
        usernameJsonCreateTime = 0
    }
    func setUserName(sqlID:Int, userID:String, userName:String, updateTime:Int){
        if userNames[userID] != nil {
            userNames[userID]?.name = userName
            userNames[userID]?.sqlUpdateTime = updateTime
            return
        }
        let usernamedata = userNameData()
        usernamedata.sqlID = sqlID
        usernamedata.name = userName
        usernamedata.sqlUpdateTime = updateTime
        
        userNames[userID] = usernamedata
        //print(userID)
        //print(String(format: "userNamesCount=%d", userNames.count))
    }
    
    func getUserName(userID:String) -> String {
        if let usernamedata = userNames[userID] {
            return usernamedata.name
        }else {
            return "NO_NAME"
        }
    }
    
    func getLastUpdateTime() -> Int {
        var time = 0
        for (_,userName) in userNames {
            if time < userName.sqlUpdateTime {
                time = userName.sqlUpdateTime
            }
        }
        return time
    }
    
    // username Json化。UserData保存用
    func toUserNamesJsonString() -> String {
        var jArray:[[String:String]] = []
        for (userID,usernamedata) in userNames {
            var jObject:[String:String] = [:]
            jObject["id"] = String(usernamedata.sqlID)
            jObject["userID"] = userID
            jObject["name"] = usernamedata.name
            jObject["updateTime"] = String(usernamedata.sqlUpdateTime)
            
            jArray.append(jObject)
        }
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jArray, options: [])
            let jsonStr = String(bytes: jsonData, encoding: .utf8)!
            //print(jsonStr)
            return jsonStr
        } catch (let e) {
            print(e)
            return ""
        }
    }
    //保存データから読み込み
    func loadUserNamesJsonString(jsonStr:String){
        if( jsonStr=="" ){ return }
        let jsonData: Data =  jsonStr.data(using: String.Encoding.utf8)!
        do{
            //ロードしたusernameデータを処理
            let jsonArray = (try JSONSerialization.jsonObject(with: jsonData, options: [])) as! Array<Dictionary<String,String>>
            for dic in jsonArray {
                self.setUserName(
                    sqlID: Int(dic["id"]!)!,
                    userID: dic["userID"]!,
                    userName: dic["name"]!,
                    updateTime: Int(dic["updateTime"]!)!
                )
            }
        }catch (let e) {
            print(e)
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
            print(e)
            return ""
        }
    }
    //保存データから読み込み
    func loadScoresJsonString(jsonStr:String){
        if( jsonStr=="" ){ return }
        let jsonData: Data =  jsonStr.data(using: String.Encoding.utf8)!
        do{
            //ロードしたusernameデータを処理
            let jsonArray = (try JSONSerialization.jsonObject(with: jsonData, options: [])) as! Array<Dictionary<String,String>>
            for dic in jsonArray {
                self.setScore(sqlID: Int(dic["id"]!)!,
                              levelID: Int(dic["levelID"]!)!,
                              score: Int(dic["score"]!)!,
                              userID: dic["userID"]!,
                              updateTime: Int(dic["updateTime"]!)!)
            }
        }catch (let e) {
            print(e)
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
            print(e)
            return ""
        }
    }
    //保存データから読み込み
    func loadCommentsJsonString(jsonStr:String){
        if( jsonStr=="" ){ return }
        let jsonData: Data =  jsonStr.data(using: String.Encoding.utf8)!
        do{
            //ロードしたusernameデータを処理
            let jsonArray = (try JSONSerialization.jsonObject(with: jsonData, options: [])) as! Array<Dictionary<String,String>>
            for dic in jsonArray {
                self.setComment(
                    sqlID: Int(dic["id"]!)!,
                    levelID: Int(dic["levelID"]!)!,
                    comment: dic["comment"]!,
                    userID: dic["userID"]!,
                    updateTime: Int(dic["updateTime"]!)!)
            }
        }catch (let e) {
            print(e)
        }
    }
}
