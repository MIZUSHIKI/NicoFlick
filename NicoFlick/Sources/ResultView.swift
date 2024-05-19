//
//  ResultView.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/06/13.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//

import UIKit
import ReplayKit

class ResultView: UIViewController, RPPreviewViewControllerDelegate {
    
    @IBOutlet var thumbnailView: UIView!
    @IBOutlet var musicTitle: UILabel!
    @IBOutlet var musicArtist: UILabel!
    @IBOutlet var musicLength: UILabel!
    @IBOutlet var musicLevel: UILabel!
    @IBOutlet var musicLevelCreator: UILabel!
    @IBOutlet var totalNotes: ChainLabel!
    @IBOutlet var combo: ChainLabel!
    @IBOutlet var great: ChainLabel!
    @IBOutlet var good: ChainLabel!
    @IBOutlet var safe: ChainLabel!
    @IBOutlet var bad: ChainLabel!
    @IBOutlet var miss: ChainLabel!
    @IBOutlet var stageScore: ChainLabel!
    @IBOutlet var comboBonus: ChainLabel!
    @IBOutlet var totalScore: ChainLabel!
    @IBOutlet var rank: UILabel!
    @IBOutlet weak var rankPerfect: UILabel!
    @IBOutlet var HiScoreUpdate: UILabel!
    @IBOutlet weak var okButton: UIButton!
    @IBOutlet weak var rankingCommentButton: UIButton!
    @IBOutlet weak var rankingCommentLabel: UILabel!
    @IBOutlet weak var tweetButton: UIButton!
    @IBOutlet weak var savePlayMovieButton: UIButton!
    
    
    @IBOutlet weak var usumaku: UIView!
    
    var updatedScore = false
    //効果音プレイヤー(シングルトン)
    var seSystemAudio:SESystemAudio = SESystemAudio.sharedInstance
    
    var playPreviewViewController:RPPreviewViewController?
    
    //遷移時に受け取り
    var gameViewController:GameView!
    //commentViewのため保持
    var commentPostable = true
    //Indicator（ネット処理中 画面中央でくるくるさせる）
    private var activityIndicator:UIActivityIndicatorView!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let selectMusic = gameViewController.selectMusic!
        let selectLevel = gameViewController.selectLevel!
        let noteData = gameViewController.noteData!
        
        //Indicatorを作成
        activityIndicator = Indicator(center: self.view.center).view
        self.view.addSubview(activityIndicator)
        
        let itemView = AsyncImageView(frame: CGRect(x: 0, y: 0,
                                                    width: self.thumbnailView.frame.size.width,
                                                    height: self.thumbnailView.frame.size.height))
        itemView.loadImage(urlString: selectMusic.thumbnailURL, contentMode: .scaleAspectFill)
        itemView.contentMode = .center

        self.thumbnailView.addSubview(itemView)
        self.musicTitle.text = selectMusic.title
        self.musicArtist.text = selectMusic.artist
        self.musicLength.text = selectMusic.movieLength
        self.musicLevel.text = selectLevel.getLevelAsString()
        if musicLevel.text == "FULL" {
            musicLevel.text = "FULL MODE"
            musicLevel.font = UIFont(name: "NicoKaku", size: 17)
        }
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
        
        if UserData.sharedInstance.SavePlayMovie {
            savePlayMovieButton.alpha = 1.0
            if gameViewController.failedSavePlayMovie {
                self.savePlayMovieButton.alpha = 0.3
                self.savePlayMovieButton.isEnabled = false
            }
        }
        
        //
        let view = SlashShadeView.init(frame: self.view.frame, color: UIColor.init(red: 199/255, green: 227/255, blue: 255/255, alpha: 1.0), lineWidth: 1, space: 2)
        self.view.addSubview(view)
        self.view.sendSubview(toBack: view)
        
        //サムネイル
        let backThumbView = AsyncImageView(frame: CGRect(x: 0, y: 0,
                                                    width: self.view.frame.size.width,
                                                    height: self.view.frame.size.height))
        backThumbView.loadImage(urlString: selectMusic.thumbnailURL, contentMode: .scaleAspectFill)
        backThumbView.alpha = 0.5
        self.view.addSubview(backThumbView)
        self.view.sendSubview(toBack: backThumbView)
        
        //thumbMovie予約読み込み
        if let selector = self.gameViewController.selectorController {
            selector.ThumbMoviePlay(forceType: .loadOnly)
        }
        //チェインLabelスタート
        totalNotes.StartNumberRoll(duration: 0.8, option: .callStartFinish) { (chainState) in
            if chainState == .start { self.seSystemAudio.drumRollSeLoop(); return }
            if chainState == .finish { self.seSystemAudio.drumRollSeStop() }
            self.combo.StartNumberRoll(duration: 0.4, option: .callStartFinish) { (chainState) in
                if chainState == .start { self.seSystemAudio.drumRollSeLoop(); return }
                if chainState == .finish { self.seSystemAudio.drumRollSeStop() }
                self.great.StartNumberRoll(duration: 0.4, option: .callStartFinish) { (chainState) in
                    if chainState == .start { self.seSystemAudio.drumRollSeLoop(); return }
                    if chainState == .finish { self.seSystemAudio.drumRollSeStop() }
                    self.good.StartNumberRoll(duration: 0.4, option: .callStartFinish) { (chainState) in
                        if chainState == .start { self.seSystemAudio.drumRollSeLoop(); return }
                        if chainState == .finish { self.seSystemAudio.drumRollSeStop() }
                        self.safe.StartNumberRoll(duration: 0.4, option: .callStartFinish) { (chainState) in
                            if chainState == .start { self.seSystemAudio.drumRollSeLoop(); return }
                            if chainState == .finish { self.seSystemAudio.drumRollSeStop() }
                            self.bad.StartNumberRoll(duration: 0.4, option: .callStartFinish) { (chainState) in
                                if chainState == .start { self.seSystemAudio.drumRollSeLoop(); return }
                                if chainState == .finish { self.seSystemAudio.drumRollSeStop() }
                                self.miss.StartNumberRoll(duration: 0.4, option: .callStartFinish) { (chainState) in
                                    if chainState == .start { self.seSystemAudio.drumRollSeLoop(); return }
                                    if chainState == .finish { self.seSystemAudio.drumRollSeStop() }
                                    self.stageScore.StartNumberRoll(duration: 0.4, option: .callStartFinish) { (chainState) in
                                        if chainState == .start { self.seSystemAudio.drumRollSeLoop(); return }
                                        if chainState == .finish { self.seSystemAudio.drumRollSeStop() }
                                        self.comboBonus.StartNumberRoll(duration: 0.4, option: .callStartFinish) { (chainState) in
                                            if chainState == .start { self.seSystemAudio.drumRollSeLoop(); return }
                                            if chainState == .finish { self.seSystemAudio.drumRollSeStop() }
                                            self.totalScore.StartNumberRoll(duration: 0.4, option: .callStartFinish) { (chainState) in
                                                if chainState == .start { self.seSystemAudio.drumRollSeLoop(); return }
                                                if chainState == .finish { self.seSystemAudio.drumRollSeStop() }
                                                Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false, block: { timer in
                                                    //ランク、ボタン類 表示
                                                    self.seSystemAudio.rankSePlay()
                                                    if noteData.getJudgeRankStr() == Score.RankStr[0] {
                                                        self.rankPerfect.isHidden = false
                                                    }else {
                                                        self.rank.isHidden = false
                                                    }
                                                    if !selectLevel.isEditing && self.updatedScore {
                                                        self.HiScoreUpdate.isHidden = false
                                                    }
                                                    self.okButton.isHidden = false
                                                    self.rankingCommentButton.isHidden = false
                                                    self.rankingCommentLabel.isHidden = false
                                                    self.tweetButton.isHidden = false
                                                    
                                                    self.savePlayMovieButton.isHidden = false
                                                    
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                                        self.endRecording() //録画してたら終了させる
                                                    }
                                                    
                                                    if let selector = self.gameViewController.selectorController {
                                                        selector.ThumbMoviePlay(forceType: .play)
                                                    }
                                                })
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        //【編集中】データの場合、スコア等は保存・送信しないで終わる
        if selectLevel.isEditing /*|| true*/ {
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
        updatedScore = userData.Score.setScore(levelID: selectLevel.sqlID,
                                               score: noteData.score.totalScore,
                                               rank: noteData.getJudgeRank() )
        userData.JustPlayedScore.setScore(levelID: selectLevel.sqlID,
                                          score: noteData.score.totalScore,
                                          rank: noteData.getJudgeRank() )
        //  プレイ回数データ
        userData.PlayCount.addPlayCount(levelID: selectLevel.sqlID)
        
        //スコアをデータベースに送信する(送信済みでないもの)
        var scoreset = userData.Score.getSendScoresStr() //送信するデータ
        scoreset = userData.JustPlayedScore.appendSendScoresStr(scoreset: scoreset)
        if scoreset != "" {
            //Score 送信
            ServerDataHandler().postScoreData(scoreset: scoreset, userID: userData.UserID) { (bool) in
                if bool {
                    //スコアデータを保存する(FLGを降ろして)
                    userData.Score.setSendedFLG()
                    userData.JustPlayedScore.clearSendedData()
                }
            }
        }
        //プレイ回数をデータベースに送信する(送信済みでないもの)
        let pfcountset = PFCounter.init().getSendPlayFavoriteCountStr()
        if pfcountset != "" {
            // プレイ回数 送信
            ServerDataHandler().postPlayFavoriteCountData(pfcountset: pfcountset) { (bool) in
                if bool {
                    //プレイ回数データを保存する(初期化データになる)
                    UserData.sharedInstance.PlayCount.setSended()
                    UserData.sharedInstance.FavoriteCount.setSended()
                }
            }
        }else{
            let playcountset = UserData.sharedInstance.PlayCount.getSendPlayCountStr() //送信するデータ
            if playcountset != "" {
                // プレイ回数 送信
                ServerDataHandler().postPlayCountData(playcountset: playcountset) { (bool) in
                    if bool {
                        //プレイ回数データを保存する(初期化データになる)
                        UserData.sharedInstance.PlayCount.setSended()
                    }
                }
            }
            let favoritecountset = UserData.sharedInstance.FavoriteCount.getSendFavoriteCountStr() //送信するデータ
            if favoritecountset != "" {
                // プレイ回数 送信
                ServerDataHandler().postFavoriteCountData(favoritecountset: favoritecountset) { (bool) in
                    if bool {
                        //プレイ回数データを保存する(初期化データになる)
                        UserData.sharedInstance.FavoriteCount.setSended()
                    }
                }
            }
        }
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func TapView(_ sender: UITapGestureRecognizer) {
        print("tap")
        totalNotes.chainFinish()
        combo.chainFinish()
        great.chainFinish()
        good.chainFinish()
        safe.chainFinish()
        bad.chainFinish()
        miss.chainFinish()
        stageScore.chainFinish()
        comboBonus.chainFinish()
        totalScore.chainFinish()
    }
    
    
    @IBAction func TweetButton(_ sender: UIButton) {
        print("tw")
        endRecording() //録画してたらtweetボタンでも終了させる
        
        //if !UIApplication.shared.canOpenURL(URL(string: "twitter://")!){ return }
        let tweetButton_isHidden = tweetButton.isHidden
        let savePlayMovieButton_isHidden = savePlayMovieButton.isHidden
        tweetButton.isHidden = true
        savePlayMovieButton.isHidden = true
        let image = self.view.GetImage()
        tweetButton.isHidden = tweetButton_isHidden
        savePlayMovieButton.isHidden = savePlayMovieButton_isHidden
        guard
            let data = UIImagePNGRepresentation(image) ,
            let url = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("result.png")
        else {return}
        do{
            try data.write(to: url, options: .atomic)
        }catch{
            print("error")
            return
        }
        let vc = UIActivityViewController(activityItems: [url, "\n#NicoFlick "], applicationActivities: nil)
        present(vc, animated: true, completion: nil)
        return
    }
    @IBAction func SavePlayMovieButton(_ sender: UIButton) {
        if UserData.sharedInstance.SavePlayMovie {
            endRecordingAndPresent()
        }else {
            let alert = UIAlertController(title:"プレイムービーを保存するには", message: "SETTINGSから「プレイムービー保存」のスイッチを入れておく必要があります。", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    //画面遷移処理_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    @IBAction func returnToMe(segue: UIStoryboardSegue){
        print("return")
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("seg")
        //print(segue.identifier)
        if segue.identifier == "toRankingTabBar" {
            print("toRanking")
            endRecording()
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
            commentViewController.rankingViewController = rankingViewController
            seSystemAudio.openSePlay()

        }
        if segue.identifier == "fromResultView" {
            //チェインFinishせずにOK押したときを考慮
            print("chainbreak back")
            totalNotes.chainBreak()
            combo.chainBreak()
            great.chainBreak()
            good.chainBreak()
            safe.chainBreak()
            bad.chainBreak()
            miss.chainBreak()
            stageScore.chainBreak()
            comboBonus.chainBreak()
            totalScore.chainBreak()
            seSystemAudio.drumRollSeStop()
            
            endRecording()
            playPreviewViewController = nil
            
            seSystemAudio.cansel2SePlay()
        }
    }
    //遷移の許可
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        print("should")
        print(identifier)
        return true
    }
    //\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
    
    func endRecording() {
        // 録画中じゃないと終了しない
        guard RPScreenRecorder.shared().isRecording else { return }
        // 録画終了
        RPScreenRecorder.shared().stopRecording(handler: { (previewViewController, error) in
            guard let previewViewController = previewViewController else { return }
            previewViewController.previewControllerDelegate = self //delegateを実装しないとdismissされない
            previewViewController.modalPresentationStyle = .fullScreen
            self.playPreviewViewController = previewViewController
            // プレビューの表示
            //self.present(previewViewController, animated: true, completion: nil)
        })
    }
    func endRecordingAndPresent() {
        //tweetButtonで既に録画終了しているとき
        if let playPreviewViewController = playPreviewViewController {
            // プレビューの表示
            self.present(playPreviewViewController, animated: true, completion: nil)
            return
        }
        // 録画中じゃないと終了しない
        guard RPScreenRecorder.shared().isRecording else { return }
        // 録画終了
        RPScreenRecorder.shared().stopRecording(handler: { (previewViewController, error) in
            guard let previewViewController = previewViewController else { return }
            previewViewController.previewControllerDelegate = self //delegateを実装しないとdismissされない
            previewViewController.modalPresentationStyle = .fullScreen
            self.playPreviewViewController = previewViewController
            // プレビューの表示
            self.present(previewViewController, animated: true, completion: nil)
        })
    }
    func canselRecording() {
        guard RPScreenRecorder.shared().isRecording else { return }
        RPScreenRecorder.shared().stopRecording(handler: nil)
    }
    func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        DispatchQueue.main.async {
            previewController.dismiss(animated: true, completion: nil)
            self.playPreviewViewController = nil
            let alert = UIAlertController(title:"「保存」した場合、動画はカメラロールに保存されています", message: nil, preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction( UIAlertAction(title: "OK", style: .default, handler: nil) )
            self.present(alert, animated: true, completion: nil)
            self.savePlayMovieButton.alpha = 0.3
            self.savePlayMovieButton.isEnabled = false
            //thumbMoviePlay
            if let selector = self.gameViewController.selectorController {
                if let isPlay = selector.moviePlayerViewController?.player?.isPlaying {
                    if isPlay == false {
                        selector.ThumbMoviePlay(forceType: .play)
                    }
                }
            }
        }
    }
}
