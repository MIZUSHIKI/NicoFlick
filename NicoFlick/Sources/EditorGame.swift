//
//  EditorGame.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2019/01/20.
//  Copyright © 2019年 i.MIZUSHIKI. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation

class EditorGame: UIViewController, UITextFieldDelegate {
    
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
    @IBOutlet var comboLabel: UILabel!
    @IBOutlet var highScoreLabel: UILabel!
    @IBOutlet var judgeOffsetLabel: UILabel!
    
    @IBOutlet var borderView: UIView!
    @IBOutlet var borderMaxView: UIView!
    
    @IBOutlet var loadedAndCurrentTimeBarView: UIView!
    @IBOutlet var loadedTimeBarView: UIView!
    @IBOutlet var currentTimeBarView: UIView!
    
    @IBOutlet weak var rateSlider: VerticalSlider!
    @IBOutlet weak var rateSliderView: UIView!
    
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
    var moviePlayerViewController:AVPlayerViewController!
    var timer:Timer!
    //効果音プレイヤー(シングルトン)
    var seAudio:SEAudio = SEAudio.sharedInstance
    
    //ゲームデータ
    var noteData: Notes!
    
    //遷移時に受け取り
    var selectLevel:levelData!
    var editorViewController:EditorView!
    
    
    @IBOutlet var speedLabel: UILabel!
    @IBOutlet var offsetLabel: UILabel!
    
    @IBOutlet var speedSlider: UISlider!
    @IBOutlet var offsetSlider: UISlider!
    
    @IBOutlet var ExitButton: UIButton!
    
    @IBOutlet var detailedJudgeLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        speedSlider.value = Float(selectLevel.speed)
        if let os = editorViewController.mySpoon.atTag["Offset"] {
            judgeOffset = Double(os)! / 1000
            offsetSlider.value  = Float(os)!
        }
        
        speedLabel.text = "Speed: \(Int(speedSlider.value))"
        offsetLabel.text = "Offset: \(Int(offsetSlider.value))ms"
        
        if let rate = editorViewController.moviePlayerViewController?.player?.rate {
            rateSlider.value = rate
        }
        
        xps = (gameviewWidth-flickPointX)*Double(speedSlider.value)/300 //一秒で進む距離
       
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
            borderMaxView.frame.origin.y = nodeLineFlameOriginY + 42
            rateSliderView.center.x = editorViewController.movieRateSliderView.center.x
        }
        //ipad対策（対象じゃないけど）
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow(_:)), name: .UIKeyboardDidShow, object: nil)
        
        //計算しておく
        xps = (gameviewWidth-flickPointX)*Double(selectLevel.speed)/300 //ノートが一秒間に進む距離
        
        
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
        
        //効果音準備 _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
        //seAudio.loadGameSE() //instance時に準備する
        
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
        timer = Timer.scheduledTimer(timeInterval: TimeInterval(UserData.sharedInstance.DrawingUpdateInterval), target: self, selector: #selector(self.update), userInfo: nil, repeats: true)
        timer.fire()
        
        //キーボードを開く _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
        textField.becomeFirstResponder()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if (timer != nil) {
            timer.invalidate()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        //print("ViewController/viewDidDisappear/別の画面に遷移した直後")
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
        if let controller = editorViewController.moviePlayerViewController {
            if let currentTime = controller.player?.currentTime() {
                flickTime = CMTimeGetSeconds(currentTime) - judgeOffset
                if flickTime < 0 { flickTime = 0.0 }
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
            var string = string
            //まずフリックした文字とnoteの文字があっているか判定して次にタイミング判定
            var judge=(flickedNote?.judgeWord(flickWord: string))!
            if string == "\n" || string == "☻" || string == "？" || string == "！" || string == "。" || string == "、" {
                string = "＊"
                judge = Note.NORMAL
            }
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
            detailedJudgeLabel.text = String(format: "%.3fs, \(string), \(flickedNote!.word!), \(["NORMAL","GREAT","GOOD","SAFE","BAD","MISS"][(flickedNote?.judge)!])", minDiffTime) + "\n" + detailedJudgeLabel.text!.prefix(1024)
        }
        self.scoreLabel.text = "Score: "+String(noteData.score.totalScore)
        //if (noteData.score.comboCounter % 10) == 0 && noteData.score.comboCounter > 0 {
        self.ComboAction()
        //}
        return false
    }
    
    //タイマー（ノート進行表示） _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    @objc func update(tm: Timer) {
        
        guard let controller = editorViewController.moviePlayerViewController else {
            return
        }
        guard let currentTime = controller.player?.currentTime() else {
            return
        }
        var time = CMTimeGetSeconds(currentTime) - judgeOffset//ズレ
        if time < 0 { time = 0.0 }
        //xps = (gameviewWidth-flickPointX)*Double(selectLevel.speed)/300 //ノートが一秒間に進む距離（View作成時に計算済み）
        // speed=300が出現してから打つまでの時間が１秒。つまりspeed=100は出現してから打つまでの時間が３秒。
        
        let offsetX:Double = time * xps
        //ノートをゾロ動かす
        for note in noteData.notes {
            let x = xps * note.time - offsetX + flickPointX
            //もしオフセット後の表示位置が400(375+25)以内なら動かす
            if -200<x && x<400 {
                if -100<x {
                    note.label.frame.origin.x = CGFloat(x)
                    note.label.isHidden = false
                }
                
                //過ぎ去りBad判定
                if note.isFlickable && note.flicked==false  {
                    let diffTime = note.time-(time)
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
                //if x <= -50 {
                //    note.label.isHidden = true
                //}
            }else {
             if note.label.isHidden == false {
                note.label.isHidden = true
             }
            }
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
            view.frame.origin.y = self.comboFrameOriginY + 19.9
        }, completion: {finished in
            UIView.animate(withDuration: 1.0, animations: {
                view.frame.origin.y = self.comboFrameOriginY + 20.0
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
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        //キーボードを閉じる _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
        textField.resignFirstResponder()
        
    }
    
    @IBAction func SpeedSlider(_ sender: UISlider) {
        sender.value = round(sender.value)
        speedLabel.text = "Speed: \(Int(sender.value))"
        selectLevel.speed = Int(sender.value)
        editorViewController.mySpoon.atTag["Speed"] = "\(Int(sender.value))"
        
        xps = (gameviewWidth-flickPointX)*Double(speedSlider.value)/300 //一秒で進む距離
    }
    
    @IBAction func OffsetSlider(_ sender: UISlider) {
        sender.value = round( Float(Int(sender.value / 10) * 10) )
        offsetLabel.text = "Offset: \(Int(sender.value))ms"
        judgeOffset = Double(sender.value) / 1000
        editorViewController.mySpoon.atTag["Offset"] = "\(Int(sender.value ))"
    }
    
    @IBAction func RateSlider(_ sender: UISlider) {
        let rate = Float(Int(round(sender.value * 10))) / 10
        sender.value = rate
        editorViewController.setMovieRate(rate: rate)
    }
    @IBAction func RewindButton(_ sender: UIButton) {
        editorViewController.playerRewind()
        UndoAllFlickedNote()
    }
    
    @IBAction func ForwardButton(_ sender: UIButton) {
        editorViewController.playerForward()
        UndoAllFlickedNote()
    }
    
    private func UndoAllFlickedNote() {
        noteData.lastFlickedNum = 0
        for note in noteData.notes {
            if note.isFlickable && note.flicked {
                note.flickedTime = -1.0
                note.flicked = false
                note.judge = Note.NORMAL
                note.setFlickableFont()
            }
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

