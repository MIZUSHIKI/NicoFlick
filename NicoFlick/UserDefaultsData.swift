//
//  UserDefaultsData.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/09/23.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//

import Foundation
/*
 //変数が書き換わるとUserDefaultsに保存してアプリを落としても残るようにしている
 class UserData {
     var UserID
     var UserName
     var NicoMail
     var NicoPass
     var Score:UserScore
     var PlayCount:PlayCounter
     var 
 }
 class UserScore        //データベースにスコア等を送る際、ネット接続出来ない場合は後からまとめて送信処理する
 class PlayCounter      //プレイ回数を記録（データベースに送るため。送ったら都度、初期化)
 */

class UserData {
    static let sharedInstance = UserData()
    
    let userDefaults = UserDefaults.standard
    
    //ユニークユーザーID
    var UserID:String {
        get {
            //  ユニークユーザーIDを作り、以降忘れないように保存する
            if let uuid = userDefaults.string(forKey: "UniqueUserID") {
                print("already:"+uuid)
                return uuid
            }else {
                let uuid = NSUUID().uuidString
                print("new:"+uuid)
                userDefaults.set(uuid, forKey: "UniqueUserID")
                userDefaults.synchronize()
                return uuid
            }
        }
    }
    //ユニークユーザーID
    var UserIDxxx:String {
        get {
            //  ユニークユーザーIDを作り、以降忘れないように保存する
            if let uuid = userDefaults.string(forKey: "UniqueUserID") {
                let uuidxxx:String = uuid.prefix(24)+"************"
                print("already:"+uuidxxx)
                return uuidxxx
            }
            return ""
        }
    }
    var UserName:String {
        get {
            if let name = userDefaults.string(forKey: "UserName") {
                return name
            }
            return ""
        }
        set(name) {
            userDefaults.set(name, forKey: "UserName")
            userDefaults.synchronize()
        }
    }
    //
    var NicoMail:String {
        get {
            if let mail = userDefaults.string(forKey: "NiconicoMail") {
                return mail
            }
            return ""
        }
        set(mail) {
            userDefaults.set(mail, forKey: "NiconicoMail")
            userDefaults.synchronize()
        }
    }
    var NicoPass:String {
        get {
            if let pass = userDefaults.string(forKey: "NiconicoPass") {
                return pass
            }
            return ""
        }
        set(pass) {
            userDefaults.set(pass, forKey: "NiconicoPass")
            userDefaults.synchronize()
        }
    }
    
    //Score
    var Score:UserScore {
        get {
            let userScore = UserScore()
            if let us = userDefaults.object(forKey: "UserScore") as? NSData {
                print("スコア 読み込み")
                userScore.scores = NSKeyedUnarchiver.unarchiveObject(with: us as Data) as! [Int:[Int]]
            }
            return userScore
        }
        set(userScore) {
            let data = NSKeyedArchiver.archivedData(withRootObject: userScore.scores)
            userDefaults.set(data, forKey: "UserScore")
            userDefaults.synchronize()
            print("set")
        }
    }
    
    //PlayCounter
    var PlayCount:PlayCounter {
        get {
            let playCounter = PlayCounter()
            if let pc = userDefaults.object(forKey: "PlayCount") as? NSData {
                print("プレイ回数 読み込み")
                playCounter.counter = NSKeyedUnarchiver.unarchiveObject(with: pc as Data) as! [Int:Int]
            }
            return playCounter
        }
        set(playCounter){
            let data = NSKeyedArchiver.archivedData(withRootObject: playCounter.counter)
            userDefaults.set(data, forKey: "PlayCount")
            userDefaults.synchronize()
        }
    }
    
    //tagやソートの設定
    var SelectedMusicCondition:SelectConditions {
        get {
            var tags = "@初期楽曲"
            var sortItem = "曲の投稿が古い順"
            if let tags_ = userDefaults.string(forKey: "SelectConditionsTags") {
                tags = tags_
            }
            if let sortItem_ = userDefaults.string(forKey: "SelectConditionsSortItem") {
                sortItem = sortItem_
            }
            let selectCondition = SelectConditions(tags: tags, sortItem: sortItem)
            return selectCondition
        }
        set(selectCondition) {
            userDefaults.set(selectCondition.tags, forKey: "SelectConditionsTags")
            userDefaults.set(selectCondition.sortItem, forKey: "SelectConditionsSortItem")
            userDefaults.synchronize()
            print("保存したよ")
        }
    }
    
    var JudgeOffset:[Int:Float] {
        get{
            if let us = userDefaults.object(forKey: "JudgeOffset") as? NSData {
                print("JudgeOffset 読み込み")
                return NSKeyedUnarchiver.unarchiveObject(with: us as Data) as! [Int:Float]
            }
            let judgeOffset:[Int:Float] = [:]
            return judgeOffset
        }
        set(judgeOffset){
            let data = NSKeyedArchiver.archivedData(withRootObject: judgeOffset)
            userDefaults.set(data, forKey: "JudgeOffset")
            userDefaults.synchronize()
            print("set")
        }
    }
    
    var createdNoteData:String {
        get {
            if let name = userDefaults.string(forKey: "UserName") {
                return name
            }
            return ""
        }
        set(name) {
            userDefaults.set(name, forKey: "UserName")
            userDefaults.synchronize()
        }
    }
    
    //cachedMoviesNum
    var cachedMovieNum:Int {
        get {
            userDefaults.register(defaults: ["CachedMovieNum":3])
            let num = userDefaults.integer(forKey: "CachedMovieNum")
            return num
        }
        set(num) {
            userDefaults.set(num, forKey: "CachedMovieNum")
            userDefaults.synchronize()
        }
    }
    
}

class UserScore {
    var scores: [Int:[Int]] = [:] // [levelID:[score,rank,flg(投稿済みかどうか)]]
    private let SCORE = 0
    private let RANK = 1
    private let FLG = 2
    
    func setScore(levelID:Int, score:Int, rank:Int) -> Bool{
        var sup = false
        if let us = scores[levelID] {
            //あった
            if us[SCORE] < score {
                scores[levelID]?[SCORE] = score
                if rank < Score.RankFalse {
                    scores[levelID]?[FLG] = 0 //スコア投稿済みかのフラグ
                }else {
                    scores[levelID]?[FLG] = 1 //スコア投稿済みかのフラグ
                }
                //print("スコア更新")
                sup = true
            }
            if us[RANK] > rank {
                scores[levelID]?[RANK] = rank
                //print("ランク更新")
            }
        }else {
            //なかった
            scores[levelID] = [score, rank, 0]
            sup = true
        }
        //保存
        let userData = UserData.sharedInstance
        userData.Score = self
        return sup
    }
    //データベースに送るスコアセット文字列
    func getSendScoresStr() -> String {
        var scoreset = ""
        for (levelID,us) in scores {
            if us[FLG] == 0 {
                scoreset += "<\(levelID),\(us[SCORE])>"
            }
        }
        return scoreset
    }
    //スコア送信後、FLGを送信済みにする
    func setSendedFLG() {
        for (levelID,us) in scores {
            if us[FLG]==0 {
                scores[levelID]?[FLG]=1
            }
        }
        //保存
        let userData = UserData.sharedInstance
        userData.Score = self
    }
    func getScore(levelID:Int) -> Int{
        return (scores[levelID]?[SCORE])!
    }
    func getRank(levelID:Int) -> Int{
        return (scores[levelID]?[RANK])!
    }
}

class PlayCounter {
    var counter:[Int:Int] = [:]
    
    func addPlayCount(levelID:Int){
        //  既にそのlevelのプレイ回数データが有れば、カウント、無ければ作る
        if let pc = counter[levelID] {
            //あった
            counter[levelID] = pc + 1
        }else {
            //なかった
            counter[levelID] = 1
        }
        //保存
        let userData = UserData.sharedInstance
        userData.PlayCount = self
    }
    //データベースに送るプレイ回数セット文字列
    func getSendPlayCountStr() -> String {
        var playcountset = ""
        for (levelID,pc) in counter {
            playcountset += "<\(levelID),\(pc)>"
        }
        return playcountset
    }
    //スコア送信後、FLGを送信済みにする
    func setSended() {
        counter = [:] //初期化
        //保存
        let userData = UserData.sharedInstance
        userData.PlayCount = self
    }
}

class SelectConditions {
    
    init(tags:String, sortItem:String) {
        //init時はdidsetが効かない
        self.tags = tags
        self.sortItem = sortItem
        //以下tags{didset}と重複するけど・・・
        tag = [] //初期化
        if tags == "" {
            return
        }
        let array = tags.components(separatedBy: " ") //タグ文字列を空白で分割
        var type = "or" //１つ目のデフォルトはorで以降のデフォルトはand
        for var val in array {
            switch val {
            case "and":
                type = "and"
                continue
            case "or":
                type = "or"
                continue
            case "":
                continue
            default:
                if val[val.startIndex] == "-" {
                    val = String(val[val.index(after: val.startIndex)..<val.endIndex])
                    type = "-"
                }
            }
            tag.append(tagp(tag: val,type: type))
            type = "and"
        }
    }
    
    private(set) var tag:[tagp] = []
    var sortItem:String {
        didSet {
            //保存
            let userData = UserData.sharedInstance
            userData.SelectedMusicCondition = self
        }
    }
    
    static let SortItems = [
        "曲の投稿が新しい順",
        "曲の投稿が古い順",
        "ゲームの投稿が新しい曲順",
        "ゲームの投稿が古い曲順",
        "ゲームプレイ回数が多い曲順",
        "ゲームプレイ回数が少ない曲順",
        "最近ハイスコアが更新された曲順",
        "最近コメントされた曲順"
    ]
    
    //タグとタイプのセット
    struct tagp {
        var word:String = ""
        var type:String = ""
        init(tag: String, type:String){
            self.word = tag
            self.type = type
        }
    }
    
    //複数タグの平文。セット時にタグを分割して保持する -> tag:[tagp]
    var tags:String {
        didSet {
            print("didset")
            tag = [] //初期化
            if tags == "" {
                //保存
                let userData = UserData.sharedInstance
                userData.SelectedMusicCondition = self
                return
            }
            let array = tags.components(separatedBy: " ") //タグ文字列を空白で分割
            var type = "or" //１つ目のデフォルトはorで以降のデフォルトはand
            for var val in array {
                switch val {
                case "and":
                    type = "and"
                    continue
                case "or":
                    type = "or"
                    continue
                case "":
                    continue
                default:
                    if val[val.startIndex] == "-" {
                        val = String(val[val.index(after: val.startIndex)..<val.endIndex])
                        type = "-"
                    }
                }
                tag.append(tagp(tag: val,type: type))
                type = "and"
            }
            //保存
            let userData = UserData.sharedInstance
            userData.SelectedMusicCondition = self
        }
    }
    
}

