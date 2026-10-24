//
//  NoteDataClass.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/05/06.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//

import UIKit
import Foundation

/*
 ゲームのNote情報とプレイ・スコア情報を保持
 class Notes {
     var notes:[Note]
     var score:Score
 }
 class Note
 class Score
 */

class Notes{
    
    var gameviewWidth:Double = GameView.GameViewWidth
    var flickPointX:Double = GameView.FlickPointX
    var notes:[Note] = []
    var score = Score()
    var level = 100
    var flickableNoteNum = 0
    var lastFlickedNum = 0 //最後にフリックした文字より前の文字をフリックされないようにする
    
    func noteAnalyze(noteString:String, speed:Int, level_:Int ){
        var noteString = noteString
        level = level_
        if level == 100 {
            
            noteString = noteString.pregReplace(pattern: "(\\[\\d\\d\\:\\d\\d)\\:(\\d\\d\\])", with: "$1.$2")
        }
        //どうなっているかわからないので改行データを統一し、文字列化する。
        noteString = noteString.pregReplace(pattern: "\r\n", with: "\r")
        noteString = noteString.pregReplace(pattern: "\n", with: "\r")
        noteString = noteString.pregReplace(pattern: "\r", with: "改")
        //@タグは全消去(NicoFlick=2(atTagExpMode.PreNicoFlickDB)のとき Offsetだけ反映)
        var offset = 0
        // print(noteString)
        if noteString.pregMatche(pattern: "@NicoFlick\\s*=\\s*2(改|$)") {
            let offset_str = noteString.pregMatche_firstString(pattern: "@Offset\\s*=\\s*(.*?)(改|$)")
            if offset_str != "" {
                offset = Int(offset_str)!
            }
        }
        // print("offset= \(offset)")
        noteString = noteString.pregReplace(pattern: "@.*?(改|$)", with: "")
        //先頭にタイムタグが付いてなかったら付いてるところまで削る
        noteString = noteString.pregReplace(pattern: "^.*?(\\[\\d\\d\\:\\d\\d[\\:|\\.]\\d\\d\\])", with: "$1")
        //処理簡易化のためにラストにダミータイムタグを置く
        noteString = noteString+"[99:99:99]"

        
        //簡易化のためタイムタグが付いていない文字にもタイムタグを補完する（変数移し替えしながら）
        var noteString_ = ""
        var ans:[String] = []
        while noteString.pregMatche(pattern: "^(\\[\\d\\d\\:\\d\\d[\\:|\\.]\\d\\d\\])(.*?)(\\[\\d\\d\\:\\d\\d[\\:|\\.]\\d\\d\\])", matches: &ans){
            //print(String.init(format: "ans[]=%@", ans))
            //取得した分を削除する
            noteString = noteString.pregReplace(pattern: "^(\\[\\d\\d\\:\\d\\d[\\:|\\.]\\d\\d\\])(.*?)(\\[\\d\\d\\:\\d\\d[\\:|\\.]\\d\\d\\])", with: "$3")
            //もしタグ間で取得した文字が２文字以上なら補完
            if ans[2].count>1 {
                var ans2:[String] = []
                if ans[1].pregMatche(pattern: "\\[(\\d\\d)\\:(\\d\\d)[\\:|\\.](\\d\\d)\\]", matches: &ans2){}
                let timeA = Double(ans2[1])!*60 + Double(ans2[2])! + Double(ans2[3])!/100
                ans2 = []
                if ans[3].pregMatche(pattern: "\\[(\\d\\d)\\:(\\d\\d)[\\:|\\.](\\d\\d)\\]", matches: &ans2){}
                let timeB = Double(ans2[1])!*60 + Double(ans2[2])! + Double(ans2[3])!/100

                var txtAns = ""
                for (index,char) in ans[2].enumerated() {
                    if index>0 {
                        let timeC = timeA+(timeB-timeA)/Double(ans[2].count)*Double(index)
                        txtAns += String.init(format: "[%02d:%02d:%02d]", Int(timeC/60), Int(timeC)%60, Int((timeC-Double(Int(timeC)))*100) )
                    }
                    txtAns += String(char)
                }
                //間のタイムタグを補完したテキストで上書き
                ans[2] = txtAns
                //ただし、最後だけは複数文字補完したら困るから１文字だけにして他は消す
                if ans[3] == "[99:99:99]" {
                    ans[2] = String(ans[2][ans[2].startIndex])
                }
            }
            noteString_ += ans[1]+ans[2]
            if ans[2]=="" { noteString_ += " " }
            //pregMatch変数を初期化
            ans = []
        }
        //print("noteString_")
        //print(noteString_)
        
        //完全に [00:00:00]あ ペアにすることが出来た。
        //次は 一文字ごとの詳細データに展開する
        ans = []
        if noteString_.pregMatche(pattern: "(\\[\\d\\d\\:\\d\\d[\\:|\\.]\\d\\d\\])(.)", matches: &ans){
            //print("ans")
            //print(ans)
            //print(ans.count)
            for i in 0..<ans.count/3 {
                let timetag = ans[i*3+1]
                let oneWord = ans[i*3+2]

                //もしoneWordに問題なければ格納していく
                if oneWord != "改" && (oneWord.isHiragana || oneWord.isKatakana) {
                    let note = Note(word: oneWord) //文字
                    //時間
                    var ans2:[String] = []
                    if timetag.pregMatche(pattern: "\\[(\\d\\d)\\:(\\d\\d)[\\:|\\.](\\d\\d)\\]", matches: &ans2){}
                    note.time = Double(ans2[1])!*60 + Double(ans2[2])! + Double(ans2[3])!/100 + Double(offset)/1000
                    //フリックNoteかどうか([00:00.00]かどうか)
                    note.isFlickable = timetag.contains(".")
                    if oneWord == "ー" {
                        note.isFlickable = false
                    }
                    //表示位置を計算しておく
                    //300/bpm //見えてからフリックポイントに行くまでの秒数
                    let xps:Double = (gameviewWidth-flickPointX)*Double(speed)/300 //一秒で進む距離
                    
                    note.posX = xps * note.time
                    
                    //ゲーム表示/管理用
                    //note.flickedTime = -1.0
                    
                    //フリックNoteの数
                    if note.isFlickable { flickableNoteNum+=1 }

                    //note保持
                    notes += [note]
                }

            }
        }
        //print("notes")
        //print(notes)
        score.flickableNoteNum = flickableNoteNum //スコアにも渡しておく
    }
    func noteReset(){
        for note in notes {
            note.flicked = false
            note.flickedTime = -1.0
            note.judge = Note.NORMAL
            note.comboCount = 0
            if note.isFlickable {
                note.setFlickableFont()
            }else {
                note.setUnFlickableFont()
            }
            note.label.frame.origin.x = -200
            note.label.isHidden = true
        }
        score = Score.init()
        score.flickableNoteNum = flickableNoteNum //スコアにも渡しておく
        lastFlickedNum = 0
    }
    func getTotalNoteNum() -> Int{
        /*
        var count=0
        for note in notes {
            if note.isFlickable {
                count+=1
            }
        }
        // print(String(format: "cnt=%d, flickableNoteNum=%d", count,flickableNoteNum))
         */
        return flickableNoteNum
    }
    func getJudgeNum(judge:Int) -> Int{
        var count=0
        for note in notes {
            if note.judge == judge {
                count+=1
            }
        }
        return count
        
    }
    func getJudgeRank() -> Int{
        if score.stageRank <= Score.RankFalse {
            //既に計算してあったらそれを返す
            return score.stageRank
        }
        if level<=10 && score.borderScore <= 0{
            score.stageRank = Score.RankFalse
            return score.stageRank
        }
        let maxJudgeNoteNum = Double(flickableNoteNum)//0.0
        var greatJudgeNoteNum = 0.0
        var goodJudgeNoteNum = 0.0
        for note in notes {
            if note.judge == Note.NORMAL {
                continue
            }
            //maxJudgeNoteNum += 1
            if note.judge == Note.GREAT{
                greatJudgeNoteNum += 1
            }else if note.judge == Note.GOOD {
                goodJudgeNoteNum += 1
            }
        }
        if maxJudgeNoteNum == greatJudgeNoteNum {
            score.stageRank = Score.RankPERFECT
            return score.stageRank
        }
        let rate = (greatJudgeNoteNum+goodJudgeNoteNum)/maxJudgeNoteNum*100
        if rate>=100 {
            score.stageRank = Score.RankS
        }else if rate>95 {
            score.stageRank = Score.RankA
        }else if rate>80 {
            score.stageRank = Score.RankB
        }else if rate>65 {
            score.stageRank = Score.RankC
        }else if rate>50 {
            score.stageRank = Score.RankD
        }else {
            score.stageRank = Score.RankE
        }
        return score.stageRank

    }
    
    func getJudgeRankStr() -> String{
        return Score.RankStr[getJudgeRank()]
    }
    
    //master
    func masterAllNotFlickable() {
        for note in notes {
            note.isFlickable = false
        }
    }
}

class Note{
    static let NORMAL:Int = 0
    static let GREAT:Int = 1
    static let GOOD:Int = 2
    static let SAFE:Int = 3
    static let BAD:Int = 4
    static let MISS:Int = 5
    
    var word:String!
    var time:Double!
    var isFlickable:Bool!
    var posX:Double!
    
    var flicked:Bool! = false
    var flickedTime:Double! = -1.0
    var judge:Int! = Note.NORMAL
    var comboCount:Int! = 0
    
    var label:UILabel!

    private let flickableAttributedText: NSAttributedString
    private let unFlickableAttributedText: NSAttributedString
    
    init(word:String){
        self.word = word
        flickableAttributedText = NSAttributedString(
            string: word,
            attributes: [
                NSAttributedStringKey.foregroundColor: UIColor.black,
                NSAttributedStringKey.strokeColor: UIColor.white,
                NSAttributedStringKey.strokeWidth: -2.0
            ]
        )
        unFlickableAttributedText = NSAttributedString(
            string: word,
            attributes: [
                NSAttributedStringKey.foregroundColor: UIColor.white,
                NSAttributedStringKey.strokeColor: UIColor.darkGray,
                NSAttributedStringKey.strokeWidth: -2.0
            ]
        )
    }
    
    func setFlickableFont(){
        label.attributedText = flickableAttributedText
        label.alpha = 1.0
    }
    func setUnFlickableFont(){
        label.attributedText = unFlickableAttributedText
        label.alpha = 0.5
    }
    
    func judgeWord(flickWord:String) -> Int{
        var flickWord = flickWord
        var noteWord = word!
        //1段回目
        noteWord = judgeWorder(noteWord: noteWord, level: 1)
        if noteWord == flickWord {
            //print(String(format: "OK-note:flick = %@:%@", noteWord,flickWord))
            return Note.NORMAL
        }
        
        //2段回目
        noteWord = judgeWorder(noteWord: noteWord, level: 2)
        flickWord = judgeWorder(noteWord: flickWord, level: 2)
        if noteWord == flickWord {
            //print(String(format: "SAFE-note:flick = %@:%@", noteWord,flickWord))
            return Note.SAFE
        }

        //print(String(format: "BAD-note:flick = %@:%@", noteWord,flickWord))
        return Note.BAD
    }
    
    func judgeWorder(noteWord: String, level: Int = 1) -> String {
        // レベル1
        if level == 1 {
            let noteTransWord = noteWord.applyingTransform(.hiraganaToKatakana, reverse: true)!
            switch noteTransWord {
            case "ぁ": return "あ"
            case "ぃ": return "い"
            case "ぅ": return "う"
            case "ぇ": return "え"
            case "ぉ": return "お"
            case "が": return "か"
            case "ぎ": return "き"
            case "ぐ": return "く"
            case "げ": return "け"
            case "ご": return "こ"
            case "ざ": return "さ"
            case "じ": return "し"
            case "ず": return "す"
            case "ぜ": return "せ"
            case "ぞ": return "そ"
            case "だ": return "た"
            case "ぢ": return "ち"
            case "づ": return "つ"
            case "で": return "て"
            case "ど": return "と"
            case "ば": return "は"
            case "び": return "ひ"
            case "ぶ": return "ふ"
            case "べ": return "へ"
            case "ぼ": return "ほ"
            case "ぱ": return "は"
            case "ぴ": return "ひ"
            case "ぷ": return "ふ"
            case "ぺ": return "へ"
            case "ぽ": return "ほ"
            case "ゔ": return "う"
            default: break
            }
            return noteTransWord
        }
        // レベル2: 2段階目はレベル1実行済み想定なのでtransform必要無し
        switch noteWord {
        case "い": return "あ"
        case "う": return "あ"
        case "え": return "あ"
        case "お": return "あ"
        case "き": return "か"
        case "く": return "か"
        case "け": return "か"
        case "こ": return "か"
        case "し": return "さ"
        case "す": return "さ"
        case "せ": return "さ"
        case "そ": return "さ"
        case "ち": return "た"
        case "つ": return "た"
        case "て": return "た"
        case "と": return "た"
        case "に": return "な"
        case "ぬ": return "な"
        case "ね": return "な"
        case "の": return "な"
        case "ひ": return "は"
        case "ふ": return "は"
        case "へ": return "は"
        case "ほ": return "は"
        case "み": return "ま"
        case "む": return "ま"
        case "め": return "ま"
        case "も": return "ま"
        case "ゆ": return "や"
        case "よ": return "や"
        case "り": return "ら"
        case "る": return "ら"
        case "れ": return "ら"
        case "ろ": return "ら"
        case "ん": return "わ"
        default: break
        }
        return noteWord
    }
}

class Score {
    
    static let GREAT = 300
    static let GOOD = 150
    static let SAFE = 50
    static let BAD = 30
    static let MISS = 0
    
    static let RankPERFECT = 0
    static let RankS = 1
    static let RankA = 2
    static let RankB = 3
    static let RankC = 4
    static let RankD = 5
    static let RankE = 6
    static let RankFalse = 7

    static let RankStr = ["PERFECT","S","A","B","C","D","E","False"]
    
    var stageRank = 100
    
    var stageScore = 0
    var comboScore = 0
    var totalScore = 0
    
    var comboCounter = 0
    var comboMax = 0
    
    var flickableNoteNum = 0
    var borderScore = 50.0
    
    func addScore(judge:Int) {
        switch judge {
        case Note.GREAT:
            stageScore += Score.GREAT
            comboCounter += 1
            borderScore += 100.0/(2.0*Double(flickableNoteNum))
            break
        case Note.GOOD:
            stageScore += Score.GOOD
            comboCounter += 1
            borderScore += 100.0/(2.0*Double(flickableNoteNum))
            break
        case Note.SAFE:
            stageScore += Score.SAFE
            comboCounter = 0
            break
        case Note.BAD:
            stageScore += Score.BAD
            comboCounter = 0
            borderScore -= 100.0/(0.8*Double(flickableNoteNum))*2
            if borderScore < 0 { borderScore = 0 }
            break
        case Note.MISS:
            stageScore += Score.MISS
            comboCounter = 0
            borderScore -= 100.0/(0.4*Double(flickableNoteNum))*2
            if borderScore < 0 { borderScore = 0 }
            break
        default:
            break
        }
        if 95 <= comboCounter {
            comboScore += 500
        }else if 85 <= comboCounter {
            comboScore += 450
        }else if 75 <= comboCounter {
            comboScore += 400
        }else if 65 <= comboCounter {
            comboScore += 350
        }else if 55 <= comboCounter {
            comboScore += 300
        }else if 45 <= comboCounter {
            comboScore += 250
        }else if 35 <= comboCounter {
            comboScore += 200
        }else if 25 <= comboCounter {
            comboScore += 150
        }else if 15 <= comboCounter {
            comboScore += 100
        }else if 5 <= comboCounter {
            comboScore += 50
        }
        if comboCounter >= 100{
            stageScore += 200
        }
        totalScore = stageScore + comboScore
        if comboMax < comboCounter {
            comboMax = comboCounter
        }
        //print("borderScore=\(borderScore)")
    }
    // 練習モード用で戻って再フリックしたとき用に前回取得した点数を引く
    func subScore(maeJudge:Int, maeComboCount:Int) {
        switch maeJudge {
        case Note.GREAT:
            stageScore -= Score.GREAT
            break
        case Note.GOOD:
            stageScore -= Score.GOOD
            break
        case Note.SAFE:
            stageScore -= Score.SAFE
            break
        case Note.BAD:
            stageScore -= Score.BAD
            break
        case Note.MISS:
            stageScore -= Score.MISS
            break
        default:
            break
        }
        if 95 <= maeComboCount {
            comboScore -= 500
        }else if 85 <= maeComboCount {
            comboScore -= 450
        }else if 75 <= maeComboCount {
            comboScore -= 400
        }else if 65 <= maeComboCount {
            comboScore -= 350
        }else if 55 <= maeComboCount {
            comboScore -= 300
        }else if 45 <= maeComboCount {
            comboScore -= 250
        }else if 35 <= maeComboCount {
            comboScore -= 200
        }else if 25 <= maeComboCount {
            comboScore -= 150
        }else if 15 <= maeComboCount {
            comboScore -= 100
        }else if 5 <= maeComboCount {
            comboScore -= 50
        }
        if maeComboCount >= 100{
            stageScore -= 200
        }
        totalScore = stageScore + comboScore
    }
}
