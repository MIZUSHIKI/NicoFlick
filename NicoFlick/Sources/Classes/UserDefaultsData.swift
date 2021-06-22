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
     var FavoriteCount:FavoriteCounter
     var 
 }
 class UserScore        //データベースにスコア等を送る際、ネット接続出来ない場合は後からまとめて送信処理する
 class PlayCounter      //プレイ回数を記録（データベースに送るため。送ったら都度、初期化)
 */

class UserData {
    static let sharedInstance = UserData()
    
    let userDefaults = UserDefaults.standard
    
    //MyVersion
    //  バージョンアップ時に必要な処理があれば実行するため
    var MyVersion:Int {
        get {
            userDefaults.register(defaults: ["MyVersion":0])
            let num = userDefaults.integer(forKey: "MyVersion")
            return num
        }
        set(num) {
            userDefaults.set(num, forKey: "MyVersion")
            userDefaults.synchronize()
        }
    }
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
            return "NO_NAME"
        }
        set(name) {
            userDefaults.set(name, forKey: "UserName")
            userDefaults.synchronize()
        }
    }
    var UserNameID:Int {
        get {
            userDefaults.register(defaults: ["UserNameID":0])
            let num = userDefaults.integer(forKey: "UserNameID")
            return num
        }
        set(num) {
            userDefaults.set(num, forKey: "UserNameID")
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
                //print("スコア 読み込み")
                userScore.scores = NSKeyedUnarchiver.unarchiveObject(with: us as Data) as! [Int:[Int]]
            }
            return userScore
        }
        set(userScore) {
            let data = NSKeyedArchiver.archivedData(withRootObject: userScore.scores)
            userDefaults.set(data, forKey: "UserScore")
            userDefaults.synchronize()
            //print("Score set")
        }
    }
    //MyFavorite
    var MyFavorite:Set<Int> {
        get {
            if let ids = userDefaults.string(forKey: "MyFavorite") {
                //print(ids)
                if ids == "" {
                    return Set()
                }
                return Set( ids.components(separatedBy: ",").map { Int($0)! } )
            }
            return Set()
        }
        set(value) {
            print("myfavorite set")
            userDefaults.set(value.map{String($0)}.joined(separator: ","), forKey: "MyFavorite")
            userDefaults.synchronize()
        }
    }
    //MyFavorite
    var MyFavorite2:Set<Int> {
        get {
            if let ids = userDefaults.string(forKey: "MyFavorite2") {
                //print(ids)
                if ids == "" {
                    return Set()
                }
                return Set( ids.components(separatedBy: ",").map { Int($0)! } )
            }
            return Set()
        }
        set(value) {
            print("myfavorite set")
            userDefaults.set(value.map{String($0)}.joined(separator: ","), forKey: "MyFavorite2")
            userDefaults.synchronize()
        }
    }
    var MyFavoriteAll:Set<Int> {
        return self.MyFavorite.union(self.MyFavorite2)
    }
    
    //PlayCounter
    var PlayCount:PlayCounter {
        get {
            let playCounter = PlayCounter()
            if let pc = userDefaults.object(forKey: "PlayCount") as? NSData {
                //print("プレイ回数 読み込み")
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
    //FavoriteCounter
    var FavoriteCount:FavoriteCounter {
        get {
            let favoriteCounter = FavoriteCounter()
            if let pc = userDefaults.object(forKey: "FavoriteCount") as? NSData {
                //print("プレイ回数 読み込み")
                favoriteCounter.counter = NSKeyedUnarchiver.unarchiveObject(with: pc as Data) as! [Int:Int]
            }
            return favoriteCounter
        }
        set(favoriteCounter){
            let data = NSKeyedArchiver.archivedData(withRootObject: favoriteCounter.counter)
            userDefaults.set(data, forKey: "FavoriteCount")
            userDefaults.synchronize()
        }
    }
    
    //tagやソートの設定
    var _SelectedMusicCondition:SelectConditions?
    var SelectedMusicCondition:SelectConditions {
        get {
            if _SelectedMusicCondition == nil {
                var tags = "@初期楽曲"
                var sortItem = "曲の投稿が古い順"
                if let tags_ = userDefaults.string(forKey: "SelectConditionsTags") {
                    tags = tags_
                }
                if let sortItem_ = userDefaults.string(forKey: "SelectConditionsSortItem") {
                    sortItem = sortItem_
                }
                _SelectedMusicCondition = SelectConditions(tags: tags, sortItem: sortItem)
            }
            return _SelectedMusicCondition!
        }
        set {
            _SelectedMusicCondition = newValue
            userDefaults.set(newValue.tags, forKey: "SelectConditionsTags")
            userDefaults.set(newValue.sortItem, forKey: "SelectConditionsSortItem")
            userDefaults.synchronize()
            //print("保存したよ")
        }
    }
    //
    var LevelSortCondition:Int {
        get {
            userDefaults.register(defaults: ["LevelSortCondition":0])
            let num = userDefaults.integer(forKey: "LevelSortCondition")
            return num
        }
        set(num) {
            userDefaults.set(num, forKey: "LevelSortCondition")
            userDefaults.synchronize()
        }
    }
    var musicSortCondition:Int {
        get {
            userDefaults.register(defaults: ["musicSortCondition":0])
            let num = userDefaults.integer(forKey: "musicSortCondition")
            return num
        }
        set(num) {
            userDefaults.set(num, forKey: "musicSortCondition")
            userDefaults.synchronize()
        }
    }
    
    var JudgeOffset:[Int:Float] {
        get{
            if let us = userDefaults.object(forKey: "JudgeOffset") as? NSData {
                //print("JudgeOffset 読み込み")
                return NSKeyedUnarchiver.unarchiveObject(with: us as Data) as! [Int:Float]
            }
            let judgeOffset:[Int:Float] = [:]
            return judgeOffset
        }
        set(judgeOffset){
            let data = NSKeyedArchiver.archivedData(withRootObject: judgeOffset)
            userDefaults.set(data, forKey: "JudgeOffset")
            userDefaults.synchronize()
            //print("JudgeOffset set")
        }
    }
    var BorderY:CGFloat {
        get {
            userDefaults.register(defaults: ["BorderY":Float(0)])
            let x = userDefaults.float(forKey: "BorderY")
            return CGFloat(x)
        }
        set(x) {
            userDefaults.set(Float(x), forKey: "BorderY")
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
    
    //
    var thumbMoviePlay:Bool {
        get {
            userDefaults.register(defaults: ["thumbMoviePlay":false])
            return userDefaults.bool(forKey: "thumbMoviePlay")
        }
        set(bo) {
            userDefaults.set(bo, forKey: "thumbMoviePlay")
            userDefaults.synchronize()
        }
    }
    
    //プレイ方法、本体キーボード設定のヘルプを見たかどうか
    var lookedHelp:Bool {
        get {
            userDefaults.register(defaults: ["LookedHelp":false])
            let lh = userDefaults.bool(forKey: "LookedHelp")
            return lh
        }
        set(lh) {
            userDefaults.set(lh, forKey: "LookedHelp")
            userDefaults.synchronize()
        }
    }
    //５曲プレイ後に曲数拡張の仕方を見たかどうか
    var lookedExtend:Bool {
        get {
            userDefaults.register(defaults: ["LookedExtend":false])
            let le = userDefaults.bool(forKey: "LookedExtend")
            return le
        }
        set(lh) {
            userDefaults.set(lh, forKey: "LookedExtend")
            userDefaults.synchronize()
        }
    }
    //Editorの使い方を見たかどうか
    var lookedHowToEditor:Bool {
        get {
            userDefaults.register(defaults: ["LookedHowToEditor":false])
            let le = userDefaults.bool(forKey: "LookedHowToEditor")
            return le
        }
        set(lh) {
            userDefaults.set(lh, forKey: "LookedHowToEditor")
            userDefaults.synchronize()
        }
    }
    //Notesの使い方を見たかどうか
    var lookedHowToNotes:Bool {
        get {
            userDefaults.register(defaults: ["LookedHowToNotes":false])
            let le = userDefaults.bool(forKey: "LookedHowToNotes")
            return le
        }
        set(lh) {
            userDefaults.set(lh, forKey: "LookedHowToNotes")
            userDefaults.synchronize()
        }
    }
    //ver.1.5でのお気に入り仕様変更についてを見たかどうか
    var lookedChangeFavoSpec_v1500:Bool {
        get {
            userDefaults.register(defaults: ["lookedChangeFavoSpec_v1500":true])
            let le = userDefaults.bool(forKey: "lookedChangeFavoSpec_v1500")
            return le
        }
        set(lh) {
            userDefaults.set(lh, forKey: "lookedChangeFavoSpec_v1500")
            userDefaults.synchronize()
        }
    }
    var lookedDesignCoop_v1900:Bool {
        get {
            userDefaults.register(defaults: ["lookedDesignCoop_v1900":false])
            let le = userDefaults.bool(forKey: "lookedDesignCoop_v1900")
            return le
        }
        set(lh) {
            userDefaults.set(lh, forKey: "lookedDesignCoop_v1900")
            userDefaults.synchronize()
        }
    }
    
    var MySpoonSet:[Int:String] {
        get {
            if let us = userDefaults.object(forKey: "MySpoonSet") as? NSData {
                //print("JudgeOffset 読み込み")
                return NSKeyedUnarchiver.unarchiveObject(with: us as Data) as! [Int:String]
            }
            let mySpoonSet:[Int:String] = [:]
            return mySpoonSet
        }
        set(mySpoonSet) {
            let data = NSKeyedArchiver.archivedData(withRootObject: mySpoonSet)
            userDefaults.set(data, forKey: "MySpoonSet")
            userDefaults.synchronize()
        }
    }

    //
    var MusicsJson:String {
        get {
            if let str = userDefaults.string(forKey: "MusicsJson") {
                return str
            }
            return ""
        }
        set(value) {
            userDefaults.set(value, forKey: "MusicsJson")
            userDefaults.synchronize()
        }
    }
    var LevelsJson:String {
        get {
            if let str = userDefaults.string(forKey: "LevelsJson") {
                return str
            }
            return ""
        }
        set(value) {
            userDefaults.set(value, forKey: "LevelsJson")
            userDefaults.synchronize()
        }
    }
    
    var UserNamesJson:String {
        get {
            if let str = userDefaults.string(forKey: "UserNamesJson") {
                return str
            }
            return ""
        }
        set(value) {
            userDefaults.set(value, forKey: "UserNamesJson")
            userDefaults.synchronize()
        }
    }
    var UserNamesServerJsonNumCount:Int {
        get {
            userDefaults.register(defaults: ["UserNamesServerJsonNumCount":0])
            let num = userDefaults.integer(forKey: "UserNamesServerJsonNumCount")
            return num
        }
        set(num) {
            userDefaults.set(num, forKey: "UserNamesServerJsonNumCount")
            userDefaults.synchronize()
        }
    }
    var UserNamesServerJsonCreateTime:Int {
        get {
            userDefaults.register(defaults: ["UserNamesServerJsonCreateTime":0])
            let num = userDefaults.integer(forKey: "UserNamesServerJsonCreateTime")
            return num
        }
        set(num) {
            userDefaults.set(num, forKey: "UserNamesServerJsonCreateTime")
            userDefaults.synchronize()
        }
    }
    
    var ScoresJson:String {
        get {
            if let str = userDefaults.string(forKey: "ScoresJson") {
                return str
            }
            return ""
        }
        set(value) {
            userDefaults.set(value, forKey: "ScoresJson")
            userDefaults.synchronize()
        }
    }
    var CommentsJson:String {
        get {
            if let str = userDefaults.string(forKey: "CommentsJson") {
                return str
            }
            return ""
        }
        set(value) {
            userDefaults.set(value, forKey: "CommentsJson")
            userDefaults.synchronize()
        }
    }
    
    var ReportedMusicID:[String] {
        get {
            if let ids = userDefaults.string(forKey: "ReportedMusicID") {
                return ids.components(separatedBy: ",")
            }
            return []
        }
        set(value) {
            print("report set")
            userDefaults.set(value.joined(separator: ","), forKey: "ReportedMusicID")
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
                //FalseはHighScoreを保存するけどデータベースには送信しない
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
            //FalseはHighScoreを保存するけどデータベースには送信しない
            if rank < Score.RankFalse {
                scores[levelID] = [score, rank, 0]
            }else {
                scores[levelID] = [score, rank, 1]
            }
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
                let musicID = MusicDataLists.sharedInstance.getLevelIDtoMusicID(levelID: levelID)
                scoreset += "<\(levelID),\(musicID),\(us[SCORE])>"
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

class FavoriteCounter {
    var counter:[Int:Int] = [:]
    
    func addFavoriteCount(levelID:Int){
        if let fc = counter[levelID] {
            //あった
            if fc == -1 {
                //けど引こうとしていた
                counter[levelID] = nil
            }else {
                return
            }
        }else {
            //なかった
            counter[levelID] = 1
        }
        
        //保存
        let userData = UserData.sharedInstance
        userData.FavoriteCount = self
    }
    func subFavoriteCount(levelID:Int){
        if let fc = counter[levelID] {
            //あった
            if fc == 1 {
                //足そうとしていた
                counter[levelID] = nil
            }else {
                return
            }
        }else {
            //なかった
            counter[levelID] = -1
        }
        //保存
        let userData = UserData.sharedInstance
        userData.FavoriteCount = self
    }
    //データベースに送るプレイ回数セット文字列
    func getSendFavoriteCountStr() -> String {
        var favoritecountset = ""
        for (levelID,pc) in counter {
            favoritecountset += "<\(levelID),\(pc)>"
        }
        return favoritecountset
    }
    //スコア送信後、FLGを送信済みにする
    func setSended() {
        counter = [:] //初期化
        //保存
        let userData = UserData.sharedInstance
        userData.FavoriteCount = self
    }
}

class PFCounter {
    let userData = UserData.sharedInstance
    let playCounter:[Int:Int]
    let favoriteCounter:[Int:Int]
    init() {
        playCounter = userData.PlayCount.counter
        favoriteCounter = userData.FavoriteCount.counter
    }
    func getSendPlayFavoriteCountStr() -> String {
        
        let sets = Set( Array(playCounter.keys) + Array(favoriteCounter.keys) )
        
        if sets.count == (playCounter.count + favoriteCounter.count){
            //pfで重複してないなら片方だけで送るようにする
            return ""
        }
        
        var pfcountset = ""
        for levelID in sets {
            let pc = playCounter[levelID] ?? 0
            let fc = favoriteCounter[levelID] ?? 0
            pfcountset += "<\(levelID),\(pc),\(fc)>"
        }
        return pfcountset
    }
}

class SelectConditions {
    
    init(tags:String="", sortItem:String="") {
        //init時はdidsetが効かない
        self.tags = tags
        self.sortItem = sortItem
        sortStars = getSortStars(containingStars: sortItem)
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
            sortStars = getSortStars(containingStars: self.sortItem)
            //保存
            let userData = UserData.sharedInstance
            userData.SelectedMusicCondition = self
        }
    }
    var sortStars:[Bool] = [true,true,true,true,true,true,true,true,true,true,true]
    func getSortStarsString(containingStars:String? = nil) -> String {
        if let str = containingStars {
            return str.pregMatche_firstString(pattern: " [★☆]{10}[■□]$")
        }
        return sortItem.pregMatche_firstString(pattern: " [★☆]{10}[■□]$")
    }
    func getSortStars(containingStars:String? = nil) -> [Bool] {
        var containingStars = containingStars
        if containingStars == nil {
            containingStars = sortItem
        }
        let hosi = getSortStarsString(containingStars: containingStars)
        if hosi == "" {
            return [true,true,true,true,true,true,true,true,true,true,true]
        }
        sortStars[0] = hosi.pregMatche(pattern: "★[★☆][★☆][★☆][★☆][★☆][★☆][★☆][★☆][★☆][■□]$")
        sortStars[1] = hosi.pregMatche(pattern: "[★☆]★[★☆][★☆][★☆][★☆][★☆][★☆][★☆][★☆][■□]$")
        sortStars[2] = hosi.pregMatche(pattern: "[★☆][★☆]★[★☆][★☆][★☆][★☆][★☆][★☆][★☆][■□]$")
        sortStars[3] = hosi.pregMatche(pattern: "[★☆][★☆][★☆]★[★☆][★☆][★☆][★☆][★☆][★☆][■□]$")
        sortStars[4] = hosi.pregMatche(pattern: "[★☆][★☆][★☆][★☆]★[★☆][★☆][★☆][★☆][★☆][■□]$")
        sortStars[5] = hosi.pregMatche(pattern: "[★☆][★☆][★☆][★☆][★☆]★[★☆][★☆][★☆][★☆][■□]$")
        sortStars[6] = hosi.pregMatche(pattern: "[★☆][★☆][★☆][★☆][★☆][★☆]★[★☆][★☆][★☆][■□]$")
        sortStars[7] = hosi.pregMatche(pattern: "[★☆][★☆][★☆][★☆][★☆][★☆][★☆]★[★☆][★☆][■□]$")
        sortStars[8] = hosi.pregMatche(pattern: "[★☆][★☆][★☆][★☆][★☆][★☆][★☆][★☆]★[★☆][■□]$")
        sortStars[9] = hosi.pregMatche(pattern: "[★☆][★☆][★☆][★☆][★☆][★☆][★☆][★☆][★☆]★[■□]$")
        sortStars[10] = hosi.pregMatche(pattern: "[★☆][★☆][★☆][★☆][★☆][★☆][★☆][★☆][★☆][★☆]■$")
        return sortStars
    }
    
    static let SortItems = [
        "曲の投稿が新しい順",
        "曲の投稿が古い順",
        "ゲームの投稿が新しい曲順",
        "ゲームの投稿が古い曲順",
        "ゲームプレイ回数が多い曲順",
        "ゲームプレイ回数が少ない曲順",
        "お気に入り数が多い曲順",
        "お気に入り数が少ない曲順",
        "動画IDが大きい順",
        "動画IDが小さい順",
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

