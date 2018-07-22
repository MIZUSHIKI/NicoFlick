//
//  MusicDataClass.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/06/10.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//

import Foundation

/*
 楽曲とゲームデータを保持
 class musicData
 class levelData
 class MusicDataLists {
     var musics : [musicData]
     var levels : [levelData]
     var taglist : ['tag':'count']
     var selectCondition : SelectConditions
 }
 class SelectConditions {
     var tag:[tagp]      //tagp = [tag, type]
     var sortItem:String //
     var tags:String     //複数タグの平文。
 
 class scoreData
 class PostedDatalists
 */

class musicData {
    var sqlID:Int!
    var movieURL:String!
    var thumbnailURL:String!
    var title:String!
    var artist:String!
    var movieLength:String!
    var tags:String!
    var tag:[String] = []
    var sqlUpdateTime:Int!
    var sqlCreateTime:Int!
    
    var levelIDs:Set<Int> = [] //levelから逆引きできるように保存（ソート用）

}

class levelData {
    var sqlID:Int!
    var level:Int!
    var creator:String!
    var description:String!
    var speed:Int!
    var noteData:String!
    var sqlUpdateTime:Int!
    var sqlCreateTime:Int!
    var playCount:Int!
    
    func getLevelAsString() -> String {
        var star = ""
        if level>10 {
            return "FULL"
        }
        for i in 0..<10 {
            if i<level {
                star += "★"
            }else       {
                star += "☆"
            }
        }
        return star
    }
}


class MusicDataLists{
    
    static let sharedInstance = MusicDataLists()
    
    var musics:[musicData] = []
    var levels: [String:[levelData]] = [:]
    var taglist: [String:Int] = [:] //musicのタグまとめ。[tag:count]
    
    //表示する楽曲を tagで抽出、ソートする
    //var selectCondition = SelectConditions() user

    func setMusic(sqlID:Int, movieURL:String, thumbnailURL:String, title:String, artist:String, movieLength:String, tags:String, updateTime:Int, createTime:Int){
        if movieURL == "delete" {
            //削除
            for index in 0 ..< musics.count {
                if musics[index].sqlID == sqlID {
                    musics.remove(at: index)
                }
            }
            return
        }
        for index in 0 ..< musics.count {
            if musics[index].sqlID == sqlID {
                musics[index].movieURL = movieURL
                musics[index].thumbnailURL = thumbnailURL
                musics[index].title = title
                musics[index].artist = artist
                musics[index].movieLength = movieLength
                musics[index].tags = tags
                musics[index].tag = tags.components(separatedBy: " ")
                musics[index].sqlUpdateTime = updateTime
                musics[index].sqlCreateTime = createTime
                return
            }
        }
        let musicdata = musicData()
        musicdata.sqlID = sqlID
        musicdata.movieURL = movieURL
        musicdata.thumbnailURL = thumbnailURL
        musicdata.title = title
        musicdata.artist = artist
        musicdata.movieLength = movieLength
        musicdata.tags = tags
        musicdata.tag = tags.components(separatedBy: " ")
        musicdata.sqlUpdateTime = updateTime
        musicdata.sqlCreateTime = createTime
        //print(String(format: "musicsCount=%d", musics.count))
        musics.append(musicdata)
        //print(musicdata.tag)
    }
    
    func setLevel(sqlID:Int, movieURL:String, level:Int, creator:String, description:String, speed:Int, noteData:String, updateTime:Int, createTime:Int, playCount:Int){
        if level == -1 {
            //削除
            //musicsの逆引き用のlevelIDsから指定IDを削除する
            if let mf = musics.filter({ $0.movieURL == movieURL}).first {
                mf.levelIDs.remove(sqlID) //
            }
            //levelsの
            if levels[movieURL] != nil {
                levels[movieURL] = levels[movieURL]?.filter{$0.sqlID != sqlID}
                /*
                for index in 0 ..< (levels[movieURL]?.count)! {
                    if levels[movieURL]?[index].sqlID == sqlID {
                        levels[movieURL]?.remove(at: index)
                    }
                }
                */
            }
            return
        }
        for music in musics {
            print(music.movieURL)
            print(movieURL)
            if music.movieURL == movieURL {
                print("in")
                music.levelIDs.insert(sqlID)
                break
            }
        }
        for music in musics {
            print(music.levelIDs)
        }

        if levels[movieURL] != nil {
            for index in 0 ..< (levels[movieURL]?.count)! {
                if levels[movieURL]?[index].sqlID == sqlID {
                    levels[movieURL]?[index].level = level
                    levels[movieURL]?[index].creator = creator
                    levels[movieURL]?[index].description = description
                    levels[movieURL]?[index].speed = speed
                    levels[movieURL]?[index].noteData = noteData
                    levels[movieURL]?[index].sqlUpdateTime = updateTime
                    levels[movieURL]?[index].sqlCreateTime = createTime
                    levels[movieURL]?[index].playCount = playCount
                    return
                }
            }
        }
        let leveldata = levelData()
        leveldata.sqlID = sqlID
        leveldata.level = level
        leveldata.creator = creator
        leveldata.description = description
        leveldata.speed = speed
        leveldata.noteData = noteData
        leveldata.sqlUpdateTime = updateTime
        leveldata.sqlCreateTime = createTime
        leveldata.playCount = playCount
        levels[movieURL] = levels[movieURL] ?? []// nilの場合配列を初期化する
        levels[movieURL]?.append(leveldata)
        //print(movieURL)
        //print(String(format: "levelsCount=%d", (levels[movieURL]?.count)!))
    }
    
    func getLastUpdateTimeMusic() -> Int {
        var time = 0
        for music in musics {
            if time < music.sqlUpdateTime {
                time = music.sqlUpdateTime
            }
        }
        return time
    }
    func getLastUpdateTimeLevel() -> Int {
        var time = 0
        for leveldates in levels {
            for level in leveldates.value {
                if time < level.sqlUpdateTime {
                    time = level.sqlUpdateTime
                }
                
            }
        }
        return time
    }

    func createTaglist(){
        taglist = [:] //初期化
        for music in musics {
            for tag in music.tag {
                if tag == "" { continue }
                if let num = taglist[tag] {
                    taglist[tag] = num+1
                 }else {
                    taglist[tag] = 1
                 }
            }
        }
    }
    
    //selectConditionsによって抽出、ソートされるmusicを取得
    func getSelectMusics( callback:@escaping ([musicData]) -> () ){
        let selectCondition = UserData.sharedInstance.SelectedMusicCondition //userData読み出し
        
        print("selectCondition.tag.count = \(selectCondition.tag.count)")
        var extractMusics:[musicData] = []
        if selectCondition.tag.count == 0 {
            extractMusics = musics
        }else {
            var remainMusics:[musicData] = musics
            
            for tagp in selectCondition.tag {
                print("\(tagp.type) \(tagp.word)")
                switch tagp.type {
                case "or":
                    let rmCount = remainMusics.count
                    if rmCount == 0 {
                        continue
                    }
                    for bindex in 1...rmCount {
                        let index = rmCount - bindex
                        print("\(remainMusics[index].sqlID! ) //")
                        print(tagp.word)
                        if tagp.word == "@初期楽曲" {
                            if remainMusics[index].sqlID! > 14 {
                                continue
                            }
                        }else if !remainMusics[index].tag.contains(tagp.word) {
                            continue
                        }
                        extractMusics.append(remainMusics[index])
                        remainMusics.remove(at: index)
                    }
                    break
                case "and":
                    let emCount = extractMusics.count
                    if emCount == 0 {
                        continue
                    }
                    for bindex in 1...emCount {
                        let index = emCount - bindex
                        if tagp.word == "@初期楽曲" {
                            if extractMusics[index].sqlID! <= 14 {
                                continue
                            }
                        }else if extractMusics[index].tag.contains(tagp.word) {
                            continue
                        }
                        remainMusics.append(extractMusics[index])
                        extractMusics.remove(at: index)
                    }
                    break
                case "-":
                    if tagp.word == "@初期楽曲" {
                        extractMusics = extractMusics.filter({$0.sqlID! > 14})
                        remainMusics = remainMusics.filter({$0.sqlID! > 14})
                    }else{
                        extractMusics = extractMusics.filter({!$0.tag.contains(tagp.word)})
                        remainMusics = remainMusics.filter({!$0.tag.contains(tagp.word)})
                    }
                    break
                default: break
                }
            }
        }
        var outputMusics:[musicData] = []
        for music in extractMusics {
            if getSelectMusicLevels_noSort(selectMovieURL: music.movieURL).count == 0 {
                continue
            }
            outputMusics.append(music)
        }
        self.getSortedMusics(musics: outputMusics, callback: callback)
        return
    }
    
    
    func getSortedMusics(musics:[musicData], callback:@escaping ([musicData]) -> ()) {
        let selectCondition = UserData.sharedInstance.SelectedMusicCondition //userData読み出し
        
        var sortedMusics:[musicData] = []
        switch selectCondition.sortItem {
        case "曲の投稿が新しい順":
            sortedMusics = musics.sorted{ $0.sqlID > $1.sqlID }
            break
        case "曲の投稿が古い順":
            sortedMusics = musics.sorted{ $0.sqlID < $1.sqlID }
            break
        case "ゲームの投稿が新しい曲順":
            var levelp:[String:Int] = [:] //[URL:sqlInt]
            for (key,lvInURL) in levels {
                print("\(key), \(lvInURL)")
                for level in lvInURL {
                    if let sqlID = levelp[key] {
                        if sqlID < level.sqlID {
                            levelp[key] = level.sqlID
                        }
                    }else {
                        levelp[key] = level.sqlID
                    }
                }
            }
            sortedMusics = musics.filter({ levelp.keys.contains($0.movieURL)})
            sortedMusics.sort(by: {levelp[$0.movieURL]! > levelp[$1.movieURL]!})
            break
        case "ゲームの投稿が古い曲順":
            var levelp:[String:Int] = [:] //[URL:sqlInt]
            for (key,lvInURL) in levels {
                print("\(key), \(lvInURL)")
                for level in lvInURL {
                    if let sqlID = levelp[key] {
                        if sqlID > level.sqlID {
                            levelp[key] = level.sqlID
                        }
                    }else {
                        levelp[key] = level.sqlID
                    }
                }
            }
            sortedMusics = musics.filter({ levelp.keys.contains($0.movieURL)})
            sortedMusics.sort(by: {levelp[$0.movieURL]! < levelp[$1.movieURL]!})
            break
        case "ゲームプレイ回数が多い曲順":
            var levelp:[String:Int] = [:] //[URL:allPlayCount]
            for (key,lvInURL) in levels {
                levelp[key] = lvInURL.reduce(0){ $0 + $1.playCount}
            }
            sortedMusics = musics.filter({ levelp.keys.contains($0.movieURL)})
            sortedMusics.sort(by: {levelp[$0.movieURL]! > levelp[$1.movieURL]!})
            break
        case "ゲームプレイ回数が少ない曲順":
            var levelp:[String:Int] = [:] //[URL:allPlayCount]
            for (key,lvInURL) in levels {
                levelp[key] = lvInURL.reduce(0, { $0 + $1.playCount})
            }
            sortedMusics = musics.filter({ levelp.keys.contains($0.movieURL)})
            sortedMusics.sort(by: {levelp[$0.movieURL]! <= levelp[$1.movieURL]!})
            break
        case "最近ハイスコアが更新された曲順":
            //スコアデータ更新取得
            let postedDatas:PostedDataLists = PostedDataLists.sharedInstance
            //データベース接続、まずscoreデータロード。
            let session = URLSession(configuration: URLSessionConfiguration.default)
            let url = URL(string:AppDelegate.PHPURL+"?req=score&levelID=ALL&time="+String(postedDatas.getLastUpdateTimeScore()))!
            let task = session.dataTask(with: url){(data,responce,error) in
                if (error != nil) {
                    print("error") //エラー。
                    return
                }
                //print(String(data: data!, encoding:.utf8)!)
                //ロードしたmusicデータを処理
                if String(data: data!, encoding:.utf8)! != "latest" {
                    let jsonArray = (try! JSONSerialization.jsonObject(with: data!, options: [])) as! Array<Dictionary<String,String>>
                    for dic in jsonArray {
                        postedDatas.setScore(sqlID: Int(dic["id"]!)!,
                                             levelID: Int(dic["levelID"]!)!,
                                             score: Int(dic["score"]!)!,
                                             userID: "",
                                             updateTime: Int(dic["updateTime"]!)!
                        )
                    }
                }
                
                //すべてのスコアを処理。レベルIDをkeyにして一番スコアの高いものを保持する。
                var highScores : [Int : scoreData] = [:]
                for score in postedDatas.scores {
                    if let highScore = highScores[score.levelID] {
                        if highScore.score < score.score {
                            highScores[score.levelID] = score
                        }
                    }else {
                        highScores[score.levelID] = score
                    }
                }
                print(highScores)
                //これでレベルがタイム順で並んだ
                let sortedHighScores = highScores.sorted{ $0.value.sqlUpdateTime > $1.value.sqlUpdateTime }                
                //print(sortedHighScores)
                
                //レベルから曲を逆引き(曲が複数選ばれないようにしなくてはならない)
                for (levelID, _) in sortedHighScores {
                    var music:musicData? = nil
                    for m in musics {
                        if m.levelIDs.contains(levelID){
                            music = m
                            break
                        }
                    }
                    if music == nil {
                        continue
                    }
                    var appendable = true
                    for m in sortedMusics {
                        if m.sqlID == music?.sqlID {
                            //既にこの曲は追加済み
                            appendable = false
                            break
                        }
                    }
                    if appendable {
                        sortedMusics.append(music!)
                    }
                }
                callback(sortedMusics)
            }
            task.resume()
            break
        case "最近コメントされた曲順":
            //コメントデータ更新
            let postedDatas:PostedDataLists = PostedDataLists.sharedInstance
            //データベース接続、まずcommentデータロード。
            let session = URLSession(configuration: URLSessionConfiguration.default)
            let url = URL(string:AppDelegate.PHPURL+"?req=comment&levelID=ALL&time="+String(postedDatas.getLastUpdateTimeComment()))!
            let task = session.dataTask(with: url){(data,responce,error) in
                if (error != nil) {
                    print("error") //エラー。
                    return
                }
                //print(String(data: data!, encoding:.utf8)!)
                //ロードしたmusicデータを処理
                if String(data: data!, encoding:.utf8)! != "latest" {
                    let jsonArray = (try! JSONSerialization.jsonObject(with: data!, options: [])) as! Array<Dictionary<String,String>>
                    for dic in jsonArray {
                        postedDatas.setComment(sqlID: Int(dic["id"]!)!,
                                               levelID: Int(dic["levelID"]!)!,
                                               comment: "",
                                               userID: "",
                                               updateTime: Int(dic["updateTime"]!)!
                        )
                    }
                }
                
                //すべてのスコアを処理。レベルIDをkeyにして一番スコアの高いものを保持する。
                var highScores : [Int : scoreData] = [:]
                for score in postedDatas.scores {
                    if let highScore = highScores[score.levelID] {
                        if highScore.score < score.score {
                            highScores[score.levelID] = score
                        }
                    }else {
                        highScores[score.levelID] = score
                    }
                }
                
                //これでレベルがタイム順で並んだ
                let sortedComments = postedDatas.comments.sorted{ $0.sqlUpdateTime > $1.sqlUpdateTime }
                //print(sortedHighScores)
                
                //レベルから曲を逆引き(曲が複数選ばれないようにしなくてはならない)
                for comment in sortedComments {
                    let levelID = comment.levelID
                    var music:musicData? = nil
                    for m in musics {
                        if m.levelIDs.contains(levelID!){
                            music = m
                            break
                        }
                    }
                    if music == nil {
                        continue
                    }
                    var appendable = true
                    for m in sortedMusics {
                        if m.sqlID == music?.sqlID {
                            //既にこの曲は追加済み
                            appendable = false
                            break
                        }
                    }
                    if appendable {
                        sortedMusics.append(music!)
                    }
                }
                callback(sortedMusics)
            }
            task.resume()
            break
        default:
            sortedMusics = musics
            break
        }
        //《編集中》 levels[$0.movieURL] のすべてのdescriptionを調べて【非表示】が含まれるものを排除したとき、lelvelの数が0ならmusicもフィルタリングで除外される
        //sortedMusics = sortedMusics.filter({ levels[$0.movieURL]!.count>0 })
        callback(sortedMusics)
    }
    //とりあえずレベル取り出しを作ったけど、level順ソートだけしか無いか確認してから入れ替える
    func getSelectMusicLevels(selectMovieURL:String) -> [levelData]{
        return getSelectMusicLevels_noSort(selectMovieURL:selectMovieURL).sorted{ $0.level < $1.level }
    }
    func getSelectMusicLevels_noSort(selectMovieURL:String) -> [levelData]{
        var selectLevels:[levelData] = []
        for level in levels[selectMovieURL]! {
            if level.description.pregMatche(pattern: "【編集中:?\\w*】"){
                let id = level.description.pregMatche_firstString(pattern: "【編集中:?(\\w*)】")
                if id != UserData.sharedInstance.UserID.prefix(8){
                    continue
                }
            }
            selectLevels.append(level)
        }
        return selectLevels
    }
}



