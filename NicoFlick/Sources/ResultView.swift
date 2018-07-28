//
//  ResultView.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/06/13.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//

import UIKit

class ResultView: UIViewController {
    
    @IBOutlet var thumbnailView: UIView!
    @IBOutlet var musicTitle: UILabel!
    @IBOutlet var musicArtist: UILabel!
    @IBOutlet var musicLength: UILabel!
    @IBOutlet var musicLevel: UILabel!
    @IBOutlet var musicLevelCreator: UILabel!
    @IBOutlet var totalNotes: UILabel!
    @IBOutlet var combo: UILabel!
    @IBOutlet var great: UILabel!
    @IBOutlet var good: UILabel!
    @IBOutlet var safe: UILabel!
    @IBOutlet var bad: UILabel!
    @IBOutlet var miss: UILabel!
    @IBOutlet var stageScore: UILabel!
    @IBOutlet var comboBonus: UILabel!
    @IBOutlet var totalScore: UILabel!
    @IBOutlet var rank: UILabel!
    @IBOutlet var HiScoreUpdate: UILabel!
    
    
    //遷移時に受け取り
    var gameViewController:GameView!
    //commentViewのため保持
    var commentPostable = true

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let selectMusic = gameViewController.selectMusic!
        let selectLevel = gameViewController.selectLevel!
        let noteData = gameViewController.noteData!
        
        let itemView = AsyncImageView(frame: CGRect(x: 0, y: 0,
                                                    width: self.thumbnailView.frame.size.width,
                                                    height: self.thumbnailView.frame.size.height))
        itemView.loadImage(urlString: selectMusic.thumbnailURL)
        itemView.contentMode = .center

        self.thumbnailView.addSubview(itemView)
        self.musicTitle.text = selectMusic.title
        self.musicArtist.text = selectMusic.artist
        self.musicLength.text = selectMusic.movieLength
        self.musicLevel.text = selectLevel.getLevelAsString()
        self.musicLevelCreator.text = selectLevel.creator
        
        self.totalNotes.text = String(noteData.getTotalNoteNum())
        self.combo.text = String(noteData.score.comboMax)
        self.great.text = String(noteData.getJudgeNum(judge: Note.GREAT))
        self.good.text = String(noteData.getJudgeNum(judge: Note.GOOD))
        self.safe.text = String(noteData.getJudgeNum(judge: Note.SAFE))
        self.bad.text = String(noteData.getJudgeNum(judge: Note.BAD))
        self.miss.text = String(noteData.getJudgeNum(judge: Note.MISS))
        if selectLevel.level>10 { self.miss.text = "0" }

        self.stageScore.text = String(noteData.score.stageScore)
        self.comboBonus.text = String(noteData.score.comboScore)
        self.totalScore.text = String(noteData.score.totalScore)
        
        self.rank.text = noteData.getJudgeRankStr()
        
        //【編集中】データの場合、スコア等は保存・送信しないで終わる
        if selectLevel.description.pregMatche(pattern: "【編集中:?\\w*】") {
            self.HiScoreUpdate.text = "編集中データのため保存・送信は行われません。"
            self.HiScoreUpdate.isHidden = false
            return
        }
        //
        //ユーザースコアの保存->送信、プレイ回数のカウント->送信
        //
        //保存データ
        let userData = UserData.sharedInstance
        //  ユーザースコア
        let updatedScore = userData.Score.setScore(levelID: selectLevel.sqlID,
                                               score: noteData.score.totalScore,
                                               rank: noteData.getJudgeRank() )
        if updatedScore {
            self.HiScoreUpdate.isHidden = false
        }
        
        //  プレイ回数データ
        userData.PlayCount.addPlayCount(levelID: selectLevel.sqlID)
        
        //スコアをデータベースに送信する(送信済みでないもの)
        let scoreset = userData.Score.getSendScoresStr() //送信するデータ
        if scoreset != "" {
            //  ユーザーID
            let uuid = userData.UserID
            //  登録
            let session = URLSession(configuration: URLSessionConfiguration.default)
            let url = URL(string:AppDelegate.PHPURL)!
            var req = URLRequest(url: url)
            let body = "req=score-add&userID=\(uuid)&scoreset=\(scoreset)&pass=\(Crypt.init().encriptx_urlsafe(plainText: "ニコFlick", pass: userData.UserID))"
            req.httpMethod = "POST"
            req.httpBody = body.data(using: String.Encoding.utf8)
            print(body)
            let task = session.dataTask(with: req){(data,responce,error) in
                if (error != nil) {
                    return
                }
                let str:String = String(data: data!, encoding: String.Encoding.utf8)!
                print(str)
                DispatchQueue.main.async {
                    //メインスレッド
                    //スコアデータを保存する(FLGを降ろして)
                    userData.Score.setSendedFLG()
                }
            }
            task.resume()
        }
        //プレイ回数をデータベースに送信する(送信済みでないもの)
        let playcountset = userData.PlayCount.getSendPlayCountStr() //送信するデータ
        if playcountset != "" {
            //  登録
            let session = URLSession(configuration: URLSessionConfiguration.default)
            let url = URL(string:AppDelegate.PHPURL)!
            var req = URLRequest(url: url)
            let body = "req=playcount-add&playcountset=\(playcountset)"
            req.httpMethod = "POST"
            req.httpBody = body.data(using: String.Encoding.utf8)
            let task = session.dataTask(with: req){(data,responce,error) in
                if (error != nil) {
                    return
                }
                let str:String = String(data: data!, encoding: String.Encoding.utf8)!
                print(str)
                DispatchQueue.main.async {
                    //メインスレッド
                    //プレイ回数データを保存する(初期化データになる)
                    userData.PlayCount.setSended()
                }
            }
            task.resume()
        }

    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    //画面遷移処理_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    @IBAction func returnToMe(segue: UIStoryboardSegue){
        print("return")
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("seg")
        if segue.identifier == "toRankingTabBar" {
            print("toRanking")
            //現在選択中のデータをRankingTabBarに渡す
            let destinationTabBarController = segue.destination as! UITabBarController
            let rankingViewController:RankingView = destinationTabBarController.viewControllers?.first as! RankingView
            //let gameViewController:GameView = segue.destination as! GameView
            rankingViewController.selectMusic = gameViewController.selectMusic!
            rankingViewController.selectLevel = gameViewController.selectLevel!
            let commentViewController:CommentView = destinationTabBarController.viewControllers?[1] as! CommentView
            //let gameViewController:GameView = segue.destination as! GameView
            commentViewController.selectMusic = gameViewController.selectMusic!
            commentViewController.selectLevel = gameViewController.selectLevel!
            commentViewController.commentPostable = commentPostable
            commentViewController.resultViewController = self

        }
    }


}
