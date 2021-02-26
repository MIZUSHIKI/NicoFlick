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
    var playCountTime:Int!
    var favoriteCount:Int!
    var favoriteCountTime:Int!
    var commentTime:Int!
    var scoreTime:Int!
    
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
    var isEditing: Bool {
        return description.pregMatche(pattern: "【編集中:?\\w*】")
    }
    var isMyEditing: Bool {
        if isEditing{
            return ( description.pregMatche_firstString(pattern: "【編集中:?(\\w*)】") == MusicDataLists.sharedInstance.userID.prefix(8) )
        }
        return false
    }
}


class MusicDataLists{
    
    static let sharedInstance = MusicDataLists()
    
    var musics:[musicData] = []
    var levels: [String:[levelData]] = [:]
    var taglist: [String:Int] = [:] //musicのタグまとめ。[tag:count]
    var musicsSqlIDtoIndex:[Int:Int] = [:] //最初から musics:[Int:musics] にしとけば良かった
    var musicsMovieURLtoIndex:[String:Int] = [:] //最初から もう少し考えとけば良かった
    var levelsSqlIDtoMovieURL:[Int:String] = [:] //最初から もう少し考えとけば良かった
    var flg_levelsFistrLoad = false //なんか処理に時間がかかる場所がある・・・。最初のloadのときは必要ない処理なのでflgで回避する。
    
    var userID: String = ""
    
    //表示する楽曲を tagで抽出、ソートする
    //var selectCondition = SelectConditions() user
    
    func reset(){
        musics = []
        levels = [:]
        taglist = [:]
        musicsSqlIDtoIndex = [:]
        musicsMovieURLtoIndex = [:]
        flg_levelsFistrLoad = false
    }

    func setMusic(sqlID:Int, movieURL:String, thumbnailURL:String, title:String, artist:String, movieLength:String, tags:String, updateTime:Int, createTime:Int){
        if movieURL == "delete" {
            //削除
            if let index = musicsSqlIDtoIndex[sqlID] {
                musics.remove(at: index)
                musicsSqlIDtoIndex[sqlID] = nil
                for (key,value) in musicsSqlIDtoIndex {
                    if value > index {
                        musicsSqlIDtoIndex[key]! -= 1
                    }
                }
                musicsMovieURLtoIndex[movieURL] = nil
                for (key,value) in musicsMovieURLtoIndex {
                    if value > index {
                        musicsMovieURLtoIndex[key]! -= 1
                    }
                }
            }
            return
        }
        if let index = musicsSqlIDtoIndex[sqlID] {
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
        musicsSqlIDtoIndex[sqlID] = musics.count
        musicsMovieURLtoIndex[movieURL] = musics.count
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
    }
    
    func setLevel(sqlID:Int, movieURL:String, level:Int, creator:String, description:String, speed:Int, noteData:String, updateTime:Int, createTime:Int, playCount:Int, playCountTime:Int, favoriteCount:Int, favoriteCountTime:Int, commentTime:Int, scoreTime:Int){
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
            if levelsSqlIDtoMovieURL[sqlID] != nil {
                levelsSqlIDtoMovieURL[sqlID] = nil
            }
            return
        }
        if let index = musicsMovieURLtoIndex[movieURL] {
            musics[index].levelIDs.insert(sqlID)
        }
        // なんか処理に時間がかかるようなのでフラグで回避（初回Load時には不要：上書き処理）
        if !flg_levelsFistrLoad {
            if let levelm = levels[movieURL] {
                levelsSqlIDtoMovieURL[sqlID] = movieURL
                let f = levelm.filter { (leveldata) -> Bool in
                    return leveldata.sqlID == sqlID
                }
                if f.count > 0 { // 実は１個しかない(ハズだ)からfirstで処理
                    f.first!.level = level
                    f.first!.creator = creator
                    f.first!.description = description
                    f.first!.speed = speed
                    f.first!.noteData = noteData
                    f.first!.sqlUpdateTime = updateTime
                    f.first!.sqlCreateTime = createTime
                    f.first!.playCount = playCount
                    f.first!.playCountTime = playCountTime
                    f.first!.favoriteCount = favoriteCount
                    f.first!.favoriteCountTime = favoriteCountTime
                    f.first!.commentTime = commentTime
                    f.first!.scoreTime = scoreTime
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
        leveldata.playCountTime = playCountTime
        leveldata.favoriteCount = favoriteCount
        leveldata.favoriteCountTime = favoriteCountTime
        leveldata.commentTime = commentTime
        leveldata.scoreTime = scoreTime
        levels[movieURL] = levels[movieURL] ?? []// nilの場合配列を初期化する
        levels[movieURL]?.append(leveldata)
        
        levelsSqlIDtoMovieURL[sqlID] = movieURL
        //print(movieURL)
        //print(String(format: "levelsCount=%d", (levels[movieURL]?.count)!))
    }
    func setLevel_PlaycountFavorite(sqlID:Int, playCount:Int, playCountTime:Int, favoriteCount:Int, favoriteCountTime:Int, commentTime:Int, scoreTime:Int){
        guard let movieURL = levelsSqlIDtoMovieURL[sqlID] else {
            return
        }
        if let levelm = levels[movieURL] {
            let f = levelm.filter { (leveldata) -> Bool in
                return leveldata.sqlID == sqlID
            }
            if f.count > 0 { // 実は１個しかない(ハズだ)からfirstで処理
                if playCount != -1 {
                    f.first!.playCount = playCount
                    f.first!.playCountTime = playCountTime
                }
                if favoriteCount != -1 {
                    f.first!.favoriteCount = favoriteCount
                    f.first!.favoriteCountTime = favoriteCountTime
                }
                if commentTime != -1 {
                    f.first!.commentTime = commentTime
                }
                if scoreTime != -1 {
                    f.first!.scoreTime = scoreTime
                }
                return
            }
        }
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
    func getLastPlayCountTimeLevel() -> Int {
        var time = 0
        for leveldates in levels {
            for level in leveldates.value {
                if time < level.playCountTime {
                    time = level.playCountTime
                }
            }
        }
        return time
    }
    func getLastFavoriteCountTimeLevel() -> Int {
        var time = 0
        for leveldates in levels {
            for level in leveldates.value {
                if time < level.favoriteCountTime {
                    time = level.favoriteCountTime
                }
            }
        }
        return time
    }
    func getLastCommentTimeLevel() -> Int {
        var time = 0
        for leveldates in levels {
            for level in leveldates.value {
                if time < level.commentTime {
                    time = level.commentTime
                }
            }
        }
        return time
    }
    func getLastScoreTimeLevel() -> Int {
        var time = 0
        for leveldates in levels {
            for level in leveldates.value {
                if time < level.scoreTime {
                    time = level.scoreTime
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
    
    func getLevelIDtoMusicID(levelID:Int) -> Int {
        if let movieURL = levelsSqlIDtoMovieURL[levelID] {
            if let music = musics.first(where: { $0.movieURL == movieURL }) {
                return music.sqlID
            }
        }
        return 0
    }
    
    //selectConditionsによって抽出、ソートされるmusicを取得
    func getSelectMusics( callback:@escaping ([musicData]) -> () ){
        //let selectCondition = UserData.sharedInstance.SelectedMusicCondition //userData読み出し
        let outputMusics = _getSelectMusics(selectCondition: UserData.sharedInstance.SelectedMusicCondition)
        
        self.getSortedMusics(musics: outputMusics, callback: callback)
        return
    }
    func _getSelectMusics(selectCondition:SelectConditions, isMe:Bool = true) -> [musicData] {
        var tagps:[SelectConditions.tagp] = []
        for tagp in selectCondition.tag {
            if tagp.word.hasPrefix("@g:") {//tagp.word.suffix(tagp.word.count-3)
                let ids = tagp.word.suffix(tagp.word.count-3).components(separatedBy: "-").compactMap{ Int($0) }
                //tagps += ids.map{ SelectConditions.tagp.init(tag: "@g:\($0)", type: tagp.type) }
                //print(ids.map{ SelectConditions.tagp.init(tag: "@g:\($0)", type: tagp.type) })
                // @mへの変換
                for id in ids {
                    if let movieURL = levelsSqlIDtoMovieURL[id],
                       let music = musics.first(where: { $0.movieURL == movieURL }),
                       let musicID = music.sqlID {
                        let t = SelectConditions.tagp.init(tag: "@m:\(musicID)", type: tagp.type)
                        tagps.append(t)
                    }
                }
                continue
            }else if tagp.word.hasPrefix("@m:") {
                let ids = tagp.word.suffix(tagp.word.count-3).components(separatedBy: "-").compactMap{ Int($0) }
                tagps += ids.map{ SelectConditions.tagp.init(tag: "@m:\($0)", type: tagp.type) }
                continue
            }else if tagp.word == "@初期楽曲" {
                //
            }else if tagp.word.hasPrefix("@") {
                let w = tagp.word.suffix(tagp.word.count-1)
                if let music = musics.first(where: { $0.movieURL.hasSuffix(w) }),
                   let musicID = music.sqlID {
                    let t = SelectConditions.tagp.init(tag: "@m:\(musicID)", type: tagp.type)
                    tagps.append(t)
                    print(t)
                }
                continue
            }
            tagps.append(tagp)
        }
        
        print("selectCondition.tag.count = \(tagps.count)")
        print(tagps)
        var extractMusics:[musicData] = []
        if tagps.count == 0 {
            extractMusics = musics
        }else {
            var remainMusics:[musicData] = musics
            
            for tagp in tagps {
                //print("\(tagp.type) \(tagp.word)")
                switch tagp.type {
                case "or":
                    let rmCount = remainMusics.count
                    if rmCount == 0 {
                        continue
                    }
                    for bindex in 1...rmCount {
                        let index = rmCount - bindex
                        //print("\(remainMusics[index].sqlID! ) //")
                        //print(tagp.word)
                        if tagp.word == "@初期楽曲" {
                            if remainMusics[index].sqlID! > 14 {
                                continue
                            }
                        }else if tagp.word.hasPrefix("@m:") {
                            if let id = Int(tagp.word.suffix(tagp.word.count-3)){
                                if remainMusics[index].sqlID != id {
                                    continue
                                }
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
                        }else if tagp.word.hasPrefix("@m:") {
                            if let id = Int(tagp.word.suffix(tagp.word.count-3)){
                                if extractMusics[index].sqlID == id {
                                    continue
                                }
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
                    }else if tagp.word.hasPrefix("@m:") {
                        if let id = Int(tagp.word.suffix(tagp.word.count-3)){
                            extractMusics = extractMusics.filter({ $0.sqlID != id })
                            remainMusics = remainMusics.filter({ $0.sqlID != id })
                        }
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
            if getSelectMusicLevels_noSort(selectMovieURL: music.movieURL, isMe: isMe).count == 0 {
                continue
            }
            outputMusics.append(music)
        }
        return outputMusics
    }
    
    
    func getSortedMusics(musics:[musicData], callback:@escaping ([musicData]) -> ()) {
        let selectCondition = UserData.sharedInstance.SelectedMusicCondition //userData読み出し
        
        var sortedMusics:[musicData] = []
        switch selectCondition.sortItem {
        case "曲の投稿が新しい順":
            sortedMusics = musics.sorted{ $0.sqlCreateTime > $1.sqlCreateTime }
            break
        case "曲の投稿が古い順":
            sortedMusics = musics.sorted{ $0.sqlCreateTime < $1.sqlCreateTime }
            break
        case "ゲームの投稿が新しい曲順":
            var levelp:[String:Int] = [:] //[URL:sqlInt]
            for (key,lvInURL) in levels {
                //print("\(key), \(lvInURL)")
                for level in lvInURL {
                    if level.isEditing && !level.isMyEditing {
                        continue
                    }
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
                //print("\(key), \(lvInURL)")
                for level in lvInURL {
                    if level.isEditing && !level.isMyEditing {
                        continue
                    }
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
            var levelp:[String:Int] = [:] //[URL:allPlayCount]
            for (key,lvInURL) in levels {
                levelp[key] = lvInURL.reduce(0){ max($0 , $1.scoreTime) }
            }
            sortedMusics = musics.filter({ levelp.keys.contains($0.movieURL)})
            sortedMusics.sort(by: {levelp[$0.movieURL]! > levelp[$1.movieURL]!})
            break
        case "最近コメントされた曲順":
            var levelp:[String:Int] = [:] //[URL:allPlayCount]
            for (key,lvInURL) in levels {
                levelp[key] = lvInURL.reduce(0){ max($0 , $1.commentTime) }
            }
            sortedMusics = musics.filter({ levelp.keys.contains($0.movieURL)})
            sortedMusics.sort(by: {levelp[$0.movieURL]! > levelp[$1.movieURL]!})
            break
        case "お気に入り数が多い曲順":
            var levelp:[String:Int] = [:] //[URL:allPlayCount]
            for (key,lvInURL) in levels {
                levelp[key] = lvInURL.reduce(0){ $0 + $1.favoriteCount}
            }
            sortedMusics = musics.filter({ levelp.keys.contains($0.movieURL)})
            sortedMusics.sort(by: {levelp[$0.movieURL]! > levelp[$1.movieURL]!})
            break
        case "お気に入り数が少ない曲順":
            var levelp:[String:Int] = [:] //[URL:allPlayCount]
            for (key,lvInURL) in levels {
                levelp[key] = lvInURL.reduce(0){ $0 + $1.favoriteCount}
            }
            sortedMusics = musics.filter({ levelp.keys.contains($0.movieURL)})
            sortedMusics.sort(by: {levelp[$0.movieURL]! <= levelp[$1.movieURL]!})
            break
        case "タグで選んだ順":
            sortedMusics = musics
            break
        default:
            sortedMusics = musics
            break
        }
        //《編集中》 levels[$0.movieURL] のすべてのdescriptionを調べて【非表示】が含まれるものを排除したとき、lelvelの数が0ならmusicもフィルタリングで除外される
        //sortedMusics = sortedMusics.filter({ levels[$0.movieURL]!.count>0 })
        
        //お気に入りを先頭に集める
        if UserData.sharedInstance.musicSortCondition == 1 {
            var levelp:[String:Bool] = [:] //[URL:allPlayCount]
            for (key,lvInURL) in levels {
                levelp[key] = false
                for level in lvInURL {
                    if UserData.sharedInstance.MyFavoriteAll.contains(level.sqlID){
                        levelp[key] = true
                        break
                    }
                }
            }
            sortedMusics = sortedMusics.filter({ (levelp[$0.movieURL] ?? false) }) + sortedMusics.filter({ !(levelp[$0.movieURL] ?? false) })
        }
        
        callback(sortedMusics)
    }
    //とりあえずレベル取り出しを作ったけど、level順ソートだけしか無いか確認してから入れ替える
    // レベルソート条件
    func getSelectMusicLevels(selectMovieURL:String) -> [levelData]{
        if UserData.sharedInstance.LevelSortCondition == 0 {
            return getSelectMusicLevels_noSort(selectMovieURL:selectMovieURL).sorted{ $0.level < $1.level }
        }else {
            var a:[levelData] = []
            var b:[levelData] = []
            for level in getSelectMusicLevels_noSort(selectMovieURL:selectMovieURL) {
                if UserData.sharedInstance.MyFavoriteAll.contains(level.sqlID) {
                    a.append(level)
                }else {
                    b.append(level)
                }
            }
            a.sort{ $0.level < $1.level }
            b.sort{ $0.level < $1.level }
            return a + b
        }
    }
    func getSelectMusicLevels_noSort(selectMovieURL:String, isMe:Bool = true) -> [levelData]{
        var selectLevels:[levelData] = []
        guard let levels = levels[selectMovieURL] else {
            return selectLevels
        }
        for level in levels {
            if level.isEditing && !(level.isMyEditing && isMe){
                continue
            }
            selectLevels.append(level)
        }
        return selectLevels
    }
    
    // music Json化。UserData保存用
    func toMusicsJsonString() -> String {
        var jArray:[[String:String]] = []
        for musicdata in musics {
            var jObject:[String:String] = [:]
            jObject["id"] = String(musicdata.sqlID)
            jObject["movieURL"] = musicdata.movieURL
            jObject["thumbnailURL"] = musicdata.thumbnailURL
            jObject["title"] = musicdata.title
            jObject["artist"] = musicdata.artist
            jObject["movieLength"] = musicdata.movieLength
            jObject["tags"] = musicdata.tags
            jObject["updateTime"] = String(musicdata.sqlUpdateTime)
            jObject["createTime"] = String(musicdata.sqlCreateTime)
            
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
    func loadMusicsJsonString(jsonStr:String){
        if( jsonStr=="" ){ return }
        let jsonData: Data =  jsonStr.data(using: String.Encoding.utf8)!
        do {
            let jsonArray = (try JSONSerialization.jsonObject(with: jsonData, options: [])) as! Array<Dictionary<String,String>>
            for dic in jsonArray {
                self.setMusic(
                    sqlID: Int(dic["id"]!)!,
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
            self.createTaglist() //タグリストを更新
        } catch {
            print(error)
        }
    }
    
    // levels Json化。UserData保存用
    func toLevelsJsonString() -> String {
        
        var jArray:[[String:String]] = []
        for (movieURL,leveldatas) in levels {
            for leveldata in leveldatas {
                var jObject:[String:String] = [:]
                jObject["id"] = String(leveldata.sqlID)
                jObject["movieURL"] = movieURL
                jObject["level"] = String(leveldata.level)
                jObject["creator"] = leveldata.creator
                jObject["description"] = leveldata.description
                jObject["speed"] = String(leveldata.speed)
                jObject["notes"] = leveldata.noteData
                jObject["updateTime"] = String(leveldata.sqlUpdateTime)
                jObject["createTime"] = String(leveldata.sqlCreateTime)
                jObject["playCount"] = String(leveldata.playCount)
                jObject["playCountTime"] = String(leveldata.playCountTime)
                jObject["favorite"] = String(leveldata.favoriteCount)
                jObject["favoriteTime"] = String(leveldata.favoriteCountTime)
                jObject["commentTime"] = String(leveldata.commentTime)
                jObject["scoreTime"] = String(leveldata.scoreTime)
                
                jArray.append(jObject)
            }
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
    func loadLevelsJsonString(jsonStr:String){
        if( jsonStr=="" ){ return }
        flg_levelsFistrLoad = true
        let jsonData: Data =  jsonStr.data(using: String.Encoding.utf8)!
        do {
            let jsonArray = (try JSONSerialization.jsonObject(with: jsonData, options: [])) as! Array<Dictionary<String,String>>
            for dic in jsonArray {
                //下位互換
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
                self.setLevel(
                    sqlID: Int(dic["id"]!)!,
                    movieURL: dic["movieURL"]!,
                    level: Int(dic["level"]!)!,
                    creator: dic["creator"]!,
                    description: dic["description"]!,
                    speed: Int(dic["speed"]!)!,
                    noteData: dic["notes"]!,
                    updateTime: Int(dic["updateTime"]!)!,
                    createTime: Int(dic["createTime"]!)!,
                    playCount: Int(dic["playCount"]!)!,
                    playCountTime: playCountTime,
                    favoriteCount: favoriteCount,
                    favoriteCountTime: favoriteCountTime,
                    commentTime: commentTime,
                    scoreTime: scoreTime
                )
            }
            self.createTaglist() //タグリストを更新
        } catch {
            print(error)
        }
        flg_levelsFistrLoad = false
    }
}



