//
//  GameView.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/04/30.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation

class GameView: UIViewController, UITextFieldDelegate {
    
    @IBOutlet var textField: UITextField!
    @IBOutlet var testLabel: UILabel!
    @IBOutlet var greatView: UIView!
    @IBOutlet var goodView: UIView!
    @IBOutlet var safeView: UIView!
    @IBOutlet var badView: UIView!
    @IBOutlet var missView: UIView!
    @IBOutlet var flickView: UIView!
    @IBOutlet var scoreLabel: UILabel!
    @IBOutlet var comboView: UIView!
    @IBOutlet var comboLabel: UIDecorationLabel!
    @IBOutlet var highScoreLabel: UILabel!
    @IBOutlet var judgeOffsetLabel: UILabel!
    
    @IBOutlet var borderView: UIView!
    @IBOutlet var borderMaxView: UIView!
    
    @IBOutlet var loadedAndCurrentTimeBarView: UIView!
    @IBOutlet var loadedTimeBarView: UIView!
    @IBOutlet var currentTimeBarView: UIView!
    
    //判定エフェクト用のView
    var greatViews:[UIView] = []
    var greatActionCount = 0
    var goodViews:[UIView] = []
    var goodActionCount = 0
    var safeViews:[UIView] = []
    var safeActionCount = 0
    var badViews:[UIView] = []
    var badActionCount = 0
    var missViews:[UIView] = []
    var missActionCount = 0
    var flickViews:[UIView] = []
    var flickActionCount = 0
    var comboFrameOriginY:CGFloat = 360.0

    //ゲーム  表示,判定 定数データ
    @IBOutlet var nodeLine: UIView!
    var nodeLineFlameOriginY:CGFloat = 345.0
    static let GameViewWidth = 375.0 //
    static let FlickPointX = 50.0
    let gameviewWidth = GameViewWidth
    let flickPointX = FlickPointX
    let nodeSize = CGSize(width: 40, height: 40)
    let greatLine:[Double] = [-0.080, 0.080]
    let goodLine:[Double] = [-0.200, 0.200]
    let safeLine:[Double] = [-0.400, 0.300]
    var judgeOffset = 0.0
    var xps:Double = 0.0 //ノートが一秒間に進む距離(あとで計算する)
    
    //動画
    var cachedMovies:CachedMovies = CachedMovies.sharedInstance
    var moviePlayerViewController:AVPlayerViewController!
    var timer:Timer!
    //効果音プレイヤー(シングルトン)
    var seAudio:SEAudio = SEAudio.sharedInstance
    
    //ゲームデータ
    var noteData: Notes!
    //保存データ
    let userData = UserData.sharedInstance
    var userScore = UserScore()
    
    var signSE:CGFloat = 1
    var firstAttack = false
    var borderOriginRect:CGRect?
    
    //遷移時に受け取り
    var selectMusic:musicData!
    var selectLevel:levelData!
    var returnToMeData:Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        //userData.lookedHelp = false
        if userData.lookedHelp == false {
            userData.lookedHelp = true
            DispatchQueue.main.async {
                //UI処理はメインスレッドの必要あり
                print("HowToを表示")
                self.performSegue(withIdentifier: "toHelpView", sender: self)
            }
        }else {
            self.viewDidLoad2()
        }
    }
    func viewDidLoad2() {
        //初期位置設定修正
        nodeLineFlameOriginY = nodeLine.frame.origin.y
        comboFrameOriginY = comboView.frame.origin.y
        
        textField.delegate = self
        //textField.returnKeyType = .done
        if selectLevel.level>10 {
            borderMaxView.isHidden = true
        }
        //se対策
        if UIScreen.main.bounds.size.height <= 568 {
            signSE = -1
            borderMaxView.frame.origin.y = nodeLineFlameOriginY + 41
            comboFrameOriginY = comboView.frame.origin.y - 50
            comboLabel.textColor = UIColor.white
            comboLabel.strokeSize = 3
            comboLabel.strokeColor = UIColor.darkGray
        }
        //ipad対策（対象じゃないけど）
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow(_:)), name: .UIKeyboardDidShow, object: nil)
    
        //計算しておく
        xps = (gameviewWidth-flickPointX)*Double(selectLevel.speed)/300 //ノートが一秒間に進む距離
        
        //Movie呼び込み _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
        var ans:[String]=[]
        var smNum = ""
        if (self.selectMusic.movieURL.pregMatche(pattern: "watch/(.+)$", matches: &ans)){
            smNum = ans[1]
        }
        MovieAccess.init().StreamingUrlNicoAccess(smNum: smNum){ nicodougaURL in
            print(nicodougaURL)
            //session.dataTas後のサブスレッド内でviewを処理させると表示関連が後回しになるので、メインスレッドでaddSubviewする。
            DispatchQueue.main.async {
                //UI処理はメインスレッドの必要あり
                self.moviePlayerViewController = self.cachedMovies.access(url: URL(string: nicodougaURL)!, smNum: smNum)
                //  add
                self.view.addSubview(self.moviePlayerViewController.view)
                self.view.sendSubview(toBack: self.moviePlayerViewController.view)
                //  動画再生
                self.moviePlayerViewController.player?.seek(to: CMTimeMakeWithSeconds(0.0, Int32(NSEC_PER_SEC)) )
                self.moviePlayerViewController.player?.play()
                
                let screenWidth:CGFloat = self.view.frame.size.width - self.view.safeAreaInsets.left - self.view.safeAreaInsets.right
                let movieHeight = self.judgeOffsetLabel.frame.origin.y + self.judgeOffsetLabel.frame.size.height - self.view.safeAreaInsets.top
                //let screenHeight:CGFloat = self.view.frame.size.height - self.view.safeAreaInsets.top - self.view.safeAreaInsets.bottom
                print("\(screenWidth)x\(movieHeight)")
                //  動画Viewの位置
                self.moviePlayerViewController.view.frame = CGRect(x: 0, y: self.view.safeAreaInsets.top, width: screenWidth, height: movieHeight)
                // 動画が終了した時に呼ばれるnotificationを登録
                NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil, queue: nil){ notification in
                    //再生終了したとき
                    print("終了")
                    DispatchQueue.main.async {
                        //UI処理はメインスレッドの必要あり
                        self.performSegue(withIdentifier: "toResultView", sender: self)
                    }
                }
                //ムービーロードbar
                self.loadedAndCurrentTimeBarView.frame = CGRect(x: 0, y: self.view.safeAreaInsets.top+movieHeight, width: screenWidth, height: self.loadedAndCurrentTimeBarView.frame.size.height)
                self.loadedAndCurrentTimeBarView.isHidden = false
            }
        }
        
        //ノートデータを解析、生成 _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
        noteData = Notes()
        noteData.noteAnalyze(noteString: selectLevel.noteData, speed: selectLevel.speed, level_: selectLevel.level)
        //ノートラベルも最初にすべて作ってしまう（移動だとか処理をさせるのは見えるやつだけにする）
        //「フリックしない文字」のLabel作成 -> 「フリックする文字」のLabel作成 の順にして、フリック文字が前面に出るようにする。
        for note in noteData.notes {
            if note.isFlickable == false {
                //Label生成
                let label = UILabel()
                label.text = note.word
                label.frame = CGRect(x: -200, y: 0, width: 40, height: 40)
                label.textAlignment = NSTextAlignment.center
                label.font = UIFont(name: "HiraKakuProN-W6", size: 30)//systemFont(ofSize: 40)
                label.isHidden = true
                self.nodeLine.addSubview(label)
                //  labelを保持
                note.label = label
                //  文字の見た目を変える（フリックしない文字）
                note.setUnFlickableFont()
            }
        }
        for note in noteData.notes {
            if note.isFlickable == true {
                //Label生成
                let label = UILabel()
                label.text = note.word
                label.frame = CGRect(x: -200, y: 0, width: 40, height: 40)
                label.textAlignment = NSTextAlignment.center
                label.font = UIFont(name: "HiraKakuProN-W6", size: 30)//systemFont(ofSize: 40)
                label.isHidden = true
                self.nodeLine.addSubview(label)
                //  labelを保持
                note.label = label
                //  文字の見た目を変える（フリックする文字）
                note.setFlickableFont()
            }
        }

        //保存データ取得 _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
        //  スコアデータの読み込み
        userScore = userData.Score
        if let us = userScore.scores[selectLevel.sqlID] {
            highScoreLabel.text = "High Score: "+String(us[0])+" "
        }
        //  ジャッジオフセットの取得
        if let jo = userData.JudgeOffset[selectLevel.sqlID] {
            judgeOffset = Double(jo)
        }
        judgeOffsetLabel.text = "offset: \(String(format:"%0.02f",judgeOffset)) "

        //効果音準備 _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
        seAudio.loadGameSE()
        
        //判定エフェクトView下準備。Great等を複製 _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
        // １つだけだと連続で判定されたとき複数表示されないので複製を作る(ImegeView化)
        for i in (0 ..< 5) {
            greatViews.append(self.greatView.GetImageView())
            self.nodeLine.addSubview(greatViews[i])
            goodViews.append(self.goodView.GetImageView())
            self.nodeLine.addSubview(goodViews[i])
            safeViews.append(self.safeView.GetImageView())
            self.nodeLine.addSubview(safeViews[i])
            badViews.append(self.badView.GetImageView())
            self.nodeLine.addSubview(badViews[i])
            missViews.append(self.missView.GetImageView())
            self.nodeLine.addSubview(missViews[i])
            flickViews.append(self.flickView.GetImageView())
            self.nodeLine.addSubview(flickViews[i])
        }

        //タイマー発動 _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
        timer = Timer.scheduledTimer(timeInterval: 0.001, target: self, selector: #selector(self.update), userInfo: nil, repeats: true)
        timer.fire()
        firstAttack=true
        
        //キーボードを開く _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
        textField.becomeFirstResponder()
    }
    override func viewDidLayoutSubviews() {
        if borderOriginRect != nil{
            return
        }
        borderOriginRect = borderMaxView.frame
    }
    override func viewWillAppear(_ animated: Bool) {
        self.SetBorderY()
    }
    func SetBorderY(){
        if let rect = borderOriginRect {
            if userData.BorderY > 0 {
                borderMaxView.frame = CGRect(x: rect.origin.x + rect.width/6 , y: userData.BorderY, width: rect.width * 2/3, height: rect.height)
            }else{
                borderMaxView.frame = rect
            }
        }
    }
    override func viewWillDisappear(_ animated: Bool) {
        if (timer != nil) {
            timer.invalidate()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        //print("ViewController/viewDidDisappear/別の画面に遷移した直後")
        if moviePlayerViewController != nil {
            moviePlayerViewController.player?.pause()
            moviePlayerViewController.removeFromParentViewController()
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //フリック判定
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        testLabel.text = string
        if string == "\n" {
            //強制終了(ランク算出に難あり)
            //performSegue(withIdentifier: "toResultView", sender: self)
        }
        //フリックアクション
        self.FlickAction()
        
        var flickTime = -1.0
        if moviePlayerViewController != nil {
            if moviePlayerViewController.player != nil {
                flickTime = CMTimeGetSeconds((moviePlayerViewController.player?.currentTime())!)+judgeOffset//キー打ち定量ズレ
            }
        }
        //着目ノートを決定 _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
        var flickedNote:Note? = nil
        var minDiffTime = 1.0 //フリックとノートのズレ時間
        for i in (noteData.lastFlickedNum ..< noteData.notes.count) {
            let note = noteData.notes[i]
            if note.isFlickable && note.flicked==false  {
                let diffTime = note.time-flickTime
                if safeLine[0]<=diffTime && diffTime<=safeLine[1]{
                    if fabs(minDiffTime) > fabs(diffTime) {
                        minDiffTime = diffTime
                        flickedNote = note
                        noteData.lastFlickedNum = i + 1
                    }
                }
            }
        }
        //着目noteがあったとき
        if flickedNote != nil {
            
            //まずフリックした文字とnoteの文字があっているか判定して次にタイミング判定
            let judge=(flickedNote?.judgeWord(flickWord: string))!
            if judge == Note.BAD{
                //Bad
                flickedNote?.flickedTime = flickTime
                flickedNote?.flicked = true
                flickedNote?.judge = Note.BAD
                noteData.score.addScore(judge: Note.BAD)
                //print("Bad")
                //ゲージ
                borderView.frame.size.width = borderMaxView.frame.size.width * CGFloat(noteData.score.borderScore/100)
                //フリック済みフォントに設定
                flickedNote?.setUnFlickableFont()
                //エフェクト
                self.BadAction()
                //se
                seAudio.badJinglePlay()
                
            }else if judge == Note.SAFE{
                //Safe
                flickedNote?.flickedTime = flickTime
                flickedNote?.flicked = true
                flickedNote?.judge = Note.SAFE
                noteData.score.addScore(judge: Note.SAFE)
                //print("Safe")
                //フリック済みフォントに設定
                flickedNote?.setUnFlickableFont()
                //エフェクト
                self.SafeAction()
                //se
                seAudio.safeJinglePlay()
                
            }else if greatLine[0]<=minDiffTime && minDiffTime<=greatLine[1] {
                //Great!!
                flickedNote?.flickedTime = flickTime
                flickedNote?.flicked = true
                flickedNote?.judge = Note.GREAT
                noteData.score.addScore(judge: Note.GREAT)
                //print("Great!!")
                //let ft = flickTime - judgeOffset
                //print("\(ft) / \(flickedNote?.time) : \(flickedNote?.word) ")
                //ゲージ
                borderView.frame.size.width = borderMaxView.frame.size.width * CGFloat(noteData.score.borderScore/100)
                //フリック済みフォントに設定
                flickedNote?.setUnFlickableFont()
                //エフェクト
                self.GreatAction()
                //se
                seAudio.okJinglePlay()
                
            }else if goodLine[0]<=minDiffTime && minDiffTime<=goodLine[1]{
                //Good!
                flickedNote?.flickedTime = flickTime
                flickedNote?.flicked = true
                flickedNote?.judge = Note.GOOD
                noteData.score.addScore(judge: Note.GOOD)
                //print("Good!")
                //ゲージ
                borderView.frame.size.width = borderMaxView.frame.size.width * CGFloat(noteData.score.borderScore/100)
                //フリック済みフォントに設定
                flickedNote?.setUnFlickableFont()
                //エフェクト
                self.GoodAction()
                //se
                seAudio.okJinglePlay()
                
            }else if safeLine[0]<=minDiffTime && minDiffTime<=safeLine[1]{
                //Safe
                flickedNote?.flickedTime = flickTime
                flickedNote?.flicked = true
                flickedNote?.judge = Note.SAFE
                noteData.score.addScore(judge: Note.SAFE)
                //print("Safe")
                //フリック済みフォントに設定
                flickedNote?.setUnFlickableFont()
                //エフェクト
                self.SafeAction()
                //se
                seAudio.safeJinglePlay()
                
            }else {
                //何かしらには入ったはずだが、一応BAD
                flickedNote?.flickedTime = flickTime
                flickedNote?.flicked = true
                flickedNote?.judge = Note.BAD
                noteData.score.addScore(judge: Note.BAD)
                //print("Bad")
                //ゲージ
                borderView.frame.size.width = borderMaxView.frame.size.width * CGFloat(noteData.score.borderScore/100)
                //フリック済みフォントに設定
                flickedNote?.setUnFlickableFont()
                //エフェクト
                self.BadAction()
                //se
                seAudio.badJinglePlay()
            }
            //print(String.init(format: "time(%f,%f) word(%@,%@) diff(%.3f)", (flickedNote?.time)!, flickTime,(flickedNote?.word)!,string, minDiffTime))
        }
        self.scoreLabel.text = "Score: "+String(noteData.score.totalScore)+" "
        //if (noteData.score.comboCounter % 10) == 0 && noteData.score.comboCounter > 0 {
            self.ComboAction()
        //}
        return false
    }
    
    //タイマー（ノート進行表示） _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    @objc func update(tm: Timer) {
        if firstAttack { //なんか前のが勝手に再利用される？ので苦肉の策
            for note in noteData.notes {
                note.label.frame.origin.x = -200
                note.label.isHidden = true
            }
        }
        if selectLevel.level<=10 && noteData.score.borderScore <= 0 {
            //強制終了(ランク算出に難あり)
            performSegue(withIdentifier: "toResultView", sender: self)
        }
        if moviePlayerViewController == nil {
            return
        }
        if moviePlayerViewController.player == nil {
            return
        }
        
        //ムービーロード状況
        let loadedTime = moviePlayerViewController.player?.currentItem?.loadedTimeRanges.asTimeRanges.first?.end
        let duration = moviePlayerViewController.player?.currentItem?.duration
        let currentTime = moviePlayerViewController.player?.currentTime()
        //print(loadedTime)
        //print(duration)
        //print(currentTime)
        if loadedTime != nil {
            //print("\(CMTimeGetSeconds(currentTime!))|\(CMTimeGetSeconds(loadedTime!))/\(CMTimeGetSeconds(duration!))")
            
            loadedTimeBarView.frame.size.width = loadedAndCurrentTimeBarView.frame.size.width * CGFloat(CMTimeGetSeconds(loadedTime!)/CMTimeGetSeconds(duration!))
            
            currentTimeBarView.frame.size.width = loadedAndCurrentTimeBarView.frame.size.width * CGFloat(CMTimeGetSeconds(currentTime!)/CMTimeGetSeconds(duration!))
        }
        
        if moviePlayerViewController.player?.isPlaying == false {
            return
        }
        
        let time = CMTimeGetSeconds((moviePlayerViewController.player?.currentTime())!)
        //xps = (gameviewWidth-flickPointX)*Double(selectLevel.speed)/300 //ノートが一秒間に進む距離（View作成時に計算済み）
        // speed=300が出現してから打つまでの時間が１秒。つまりspeed=100は出現してから打つまでの時間が３秒。
        let offsetX:Double = time * xps
        //ノートをゾロ動かす
        for note in noteData.notes {
            let x = note.posX - offsetX + flickPointX
            //もしオフセット後の表示位置が400(375+25)以内なら動かす
            if -100<x && x<400 {
                note.label.frame.origin.x = CGFloat(x)
                note.label.isHidden = false
                
                //過ぎ去りBad判定
                if note.isFlickable && note.flicked==false  {
                    let diffTime = note.time-(time+judgeOffset)
                    if diffTime < safeLine[0]{
                        //Miss
                        note.flickedTime = -1.0
                        note.flicked = true
                        note.judge = Note.MISS
                        noteData.score.addScore(judge: Note.MISS)
                        //print("Miss")
                        //ゲージ
                        borderView.frame.size.width = borderMaxView.frame.size.width * CGFloat(noteData.score.borderScore/100)
                        if selectLevel.level<=10 {
                            //フリック済みフォントに設定
                            note.setUnFlickableFont()
                            //エフェクト
                            self.MissAction()
                        }//Fullバージョンのときはエフェクトしない（MISSとしてカウント。但しリザルトも表示は0にする。）
                        
                        self.ComboAction()
                    }
                }
                //左に消えたらビューも消す
                if x <= -50 {
                    note.label.isHidden = true
                }
            }/*else {
                if note.label.isHidden == false {
                    note.label.isHidden = true
                }
            }*/
        }

        
    }
    
    //ゲームの描写 エフェクト処理 関数 _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    func GreatAction(){
        let view = greatViews[greatActionCount]
        view.frame.origin.y = greatView.frame.origin.y
        view.isHidden = false
        UIView.animate(withDuration: 0.3, animations: {
            view.frame.origin.y = self.greatView.frame.origin.y - 19.9
        }, completion: {finished in
            UIView.animate(withDuration: 0.2, animations: {
                view.frame.origin.y = self.greatView.frame.origin.y - 20.0
            }, completion: {finished in
                view.isHidden = true
            })
        })
        greatActionCount += 1
        greatActionCount = greatActionCount % 5
    }
    func GoodAction(){
        let view = goodViews[goodActionCount]
        view.frame.origin.y = goodView.frame.origin.y
        view.isHidden = false
        UIView.animate(withDuration: 0.3, animations: {
            view.frame.origin.y = self.goodView.frame.origin.y - 19.9
        }, completion: {finished in
            UIView.animate(withDuration: 0.2, animations: {
                view.frame.origin.y = self.goodView.frame.origin.y - 20.0
            }, completion: {finished in
                view.isHidden = true
            })
        })
        goodActionCount += 1
        goodActionCount = goodActionCount % 5
    }
    func SafeAction(){
        let view = safeViews[safeActionCount]
        view.frame.origin.y = safeView.frame.origin.y
        view.isHidden = false
        UIView.animate(withDuration: 0.3, animations: {
            view.frame.origin.y = self.safeView.frame.origin.y - 19.9
        }, completion: {finished in
            UIView.animate(withDuration: 0.2, animations: {
                view.frame.origin.y = self.safeView.frame.origin.y - 20.0
            }, completion: {finished in
                view.isHidden = true
            })
        })
        safeActionCount += 1
        safeActionCount = safeActionCount % 5
    }
    func BadAction(){
        let view = badViews[badActionCount]
        view.frame.origin.y = badView.frame.origin.y
        view.isHidden = false
        UIView.animate(withDuration: 0.3, animations: {
            view.frame.origin.y = self.badView.frame.origin.y - 19.9
        }, completion: {finished in
            UIView.animate(withDuration: 0.2, animations: {
                view.frame.origin.y = self.badView.frame.origin.y - 20.0

            }, completion: {finished in
                view.isHidden = true
            })
        })
        badActionCount += 1
        badActionCount = badActionCount % 5
    }
    func MissAction(){
        let view = missViews[missActionCount]
        view.frame.origin.y = missView.frame.origin.y
        view.isHidden = false
        UIView.animate(withDuration: 0.3, animations: {
            view.frame.origin.y = self.missView.frame.origin.y - 19.9
        }, completion: {finished in
            UIView.animate(withDuration: 0.2, animations: {
                view.frame.origin.y = self.missView.frame.origin.y - 20.0
            }, completion: {finished in
                view.isHidden = true
            })
        })
        missActionCount += 1
        missActionCount = missActionCount % 5
    }
    func FlickAction(){
        for view in flickViews {
            //全部非表示にしてアクションが重ならないようにする
            view.isHidden = true
        }
        let view = flickViews[flickActionCount]
        view.alpha = 0.0
        view.isHidden = false
        
        let transform = view.transform
        
        //小さくして
        view.transform = view.transform.scaledBy(x: 0.1, y: 0.1)
        
        UIView.animate(withDuration: 0.1, animations: {
            //一瞬大きくして
            view.alpha = 1.0
            view.transform = view.transform.scaledBy(x: 10.0, y: 10.0)
        }, completion: {finished in
            UIView.animate(withDuration: 0.2, animations: {
                //ほぼそのまま保持して
                view.transform = view.transform.scaledBy(x: 0.99, y: 0.99)
            }, completion: {finished in
                UIView.animate(withDuration: 0.1, animations: {
                    //透明にする
                    view.alpha = 0
                }, completion: {finished in
                    view.isHidden = true
                    view.transform = transform
                })
            })
            
        })
        flickActionCount += 1
        flickActionCount = flickActionCount % 5
    }
    func ComboAction(){
        let view = self.comboView!
        if noteData.score.comboCounter == 0{
            view.isHidden = true
            return
        }
        if noteData.score.comboCounter < 5{
            return
        }
        if noteData.score.comboCounter > 5{
            comboLabel.text = String(format: "%d combo", noteData.score.comboCounter)
            return
        }
        comboLabel.text = String(format: "%d combo", noteData.score.comboCounter)
        view.frame.origin.y = comboFrameOriginY
        view.isHidden = false
        UIView.animate(withDuration: 0.3, animations: {
            view.frame.origin.y = self.comboFrameOriginY + 19.9 * self.signSE
        }, completion: {finished in
            UIView.animate(withDuration: 1.0, animations: {
                view.frame.origin.y = self.comboFrameOriginY + 20.0 * self.signSE
            }, completion: {finished in
                //view.isHidden = true
            })
        })
    }
    //通知
    //ipad対策（対象じゃないけど）
    @objc private func keyboardDidShow(_ notification: Notification) {
        guard let userInfo = notification.userInfo as? [String: Any] else {
            return
        }
        guard let keyboardInfo = userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue else {
            return
        }
        let keyboardSize = keyboardInfo.cgRectValue.size
        if ( (UIApplication.shared.keyWindow?.bounds.height)! - keyboardSize.height ) < ( nodeLineFlameOriginY + nodeLine.bounds.size.height ){
            nodeLine.frame.origin.y = (UIApplication.shared.keyWindow?.bounds.height)! - keyboardSize.height - nodeLine.bounds.size.height
        }
    }
    
    //画面遷移処理_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    @IBAction func returnToMe(segue: UIStoryboardSegue){
        if segue.identifier == "fromGameMenu" {
            switch returnToMeData {
            case 0:
                // 再開
                textField.becomeFirstResponder() //キーボードを開く
                
                if moviePlayerViewController != nil {
                    if moviePlayerViewController.player != nil {
                        //再生
                        moviePlayerViewController.player?.play()
                    }
                }
                //  ジャッジオフセットの取得
                if let jo = userData.JudgeOffset[selectLevel.sqlID] {
                    judgeOffset = Double(jo)
                }
                judgeOffsetLabel.text = "offset: \(String(format:"%0.02f",judgeOffset))"
                //
                self.SetBorderY()
                break
            case 1:
                //リトライ
                textField.becomeFirstResponder() //キーボードを開く
                noteData.noteReset() //データをリセットする
                self.comboView.isHidden = true //表示関係もリセット
                scoreLabel.text = "Score: "+String(noteData.score.totalScore)+" "
                //  ジャッジオフセットの取得
                if let jo = userData.JudgeOffset[selectLevel.sqlID] {
                    judgeOffset = Double(jo)
                }
                judgeOffsetLabel.text = "offset: \(String(format:"%0.02f",judgeOffset))"
                //
                self.SetBorderY()
                
                //Labelを非表示かつ見えない位置に移動
                for note in noteData.notes { //なんか前のが勝手に再利用される？ので苦肉の策
                    note.label.frame.origin.x = -200
                    note.label.isHidden = true
                }
                
                if moviePlayerViewController != nil {
                    if moviePlayerViewController.player != nil {
                        //再生
                        moviePlayerViewController.player?.seek(to: CMTimeMakeWithSeconds(0.0, Int32(NSEC_PER_SEC)) )
                        moviePlayerViewController.player?.play()
                    }
                }
                
                break
            case 2:
                print("戻る")
                
                if moviePlayerViewController != nil {
                    if moviePlayerViewController.player != nil {
                        //ムービー状況
                        let duration = CMTimeGetSeconds((moviePlayerViewController.player?.currentItem?.duration)!)
                        let currentTime = CMTimeGetSeconds((moviePlayerViewController.player?.currentTime())!)
                        if currentTime > (duration / 2) {
                            //カウンタを回す
                            print("PlayCount")
                            //  プレイ回数データ
                            userData.PlayCount.addPlayCount(levelID: selectLevel.sqlID)
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
                    }
                }
                
                //曲選択に戻る
                self.performSegue(withIdentifier: "fromGameView", sender: self)
                
                break
            default:
                break
            }
            
        }else if segue.identifier == "fromResultView" {
            //曲選択に戻る
            self.performSegue(withIdentifier: "fromGameView", sender: self)

        }else if segue.identifier == "fromHowToView" {
            //プレイ開始
            self.viewDidLoad2()
            
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toGameMenu" {
            
            if moviePlayerViewController != nil {
                if moviePlayerViewController.player != nil {
                    //一時停止
                    moviePlayerViewController.player?.pause()
                }
            }
            //キーボードを閉じる _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
            textField.resignFirstResponder()

            //Labelを非表示かつ見えない位置に移動
            for note in noteData.notes { //なんか前のが勝手に再利用される？ので苦肉の策
                note.label.frame.origin.x = -200
                note.label.isHidden = true
            }
            
            let gameMenuController:GameMenu = segue.destination as! GameMenu
            gameMenuController.gameViewController = self
            
        }
        if segue.identifier == "toResultView" {
            
            if moviePlayerViewController != nil {
                if moviePlayerViewController.player != nil {
                    //一時停止
                    moviePlayerViewController.player?.pause()
                }
            }
            //キーボードを閉じる _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
            textField.resignFirstResponder()
            
            //Labelを非表示かつ見えない位置に移動
            for note in noteData.notes {
                note.label.frame.origin.x = -200
                note.label.isHidden = true
            }
            
            let destinationNavigationController = segue.destination as! UINavigationController
            let resultViewController:ResultView = destinationNavigationController.topViewController as! ResultView
            //let resultViewController:ResultView = segue.destination as! ResultView
            resultViewController.gameViewController = self
            
        }

    }
    
}

// Convert a collection of NSValues into an array of CMTimeRanges.
private extension Collection where Iterator.Element == NSValue {
    var asTimeRanges : [CMTimeRange] {
        return self.map({ value -> CMTimeRange in
            return value.timeRangeValue
        })
    }
}
