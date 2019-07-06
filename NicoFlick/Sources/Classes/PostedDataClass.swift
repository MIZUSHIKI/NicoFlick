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
}

class ScoreDataLists {
    static let sharedInstance = ScoreDataLists()
    var scores:[scoreData] = []
    
    func setScore(sqlID:Int, levelID:Int, score:Int, userID:String, updateTime:Int) {
        for index in 0 ..< scores.count {
            if scores[index].sqlID == sqlID {
                scores[index].levelID = levelID
                scores[index].score = score
                scores[index].userID = userID
                scores[index].sqlUpdateTime = updateTime
                return
            }
        }
        let scoredata = scoreData()
        scoredata.sqlID = sqlID
        scoredata.levelID = levelID
        scoredata.score = score
        scoredata.userID = userID
        scoredata.sqlUpdateTime = updateTime
        scores.append(scoredata)
    }
    func getLastUpdateTime() -> Int {
        var time = 0
        for score in scores {
            if time < score.sqlUpdateTime {
                time = score.sqlUpdateTime
            }
        }
        return time
    }
}
class CommentDataLists {
    static let sharedInstance = CommentDataLists()
    var comments:[commentData] = []
    
    func setComment(sqlID:Int, levelID:Int, comment:String, userID:String, updateTime:Int) {
        for index in 0 ..< comments.count {
            if comments[index].sqlID == sqlID {
                comments[index].levelID = levelID
                comments[index].comment = comment
                comments[index].userID = userID
                comments[index].sqlUpdateTime = updateTime
                return
            }
        }
        let commentdata = commentData()
        commentdata.sqlID = sqlID
        commentdata.levelID = levelID
        commentdata.comment = comment
        commentdata.userID = userID
        commentdata.sqlUpdateTime = updateTime
        comments.append(commentdata)
    }
    func getLastUpdateTime() -> Int {
        var time = 0
        for comment in comments {
            if time < comment.sqlUpdateTime {
                time = comment.sqlUpdateTime
            }
        }
        return time
    }
}
