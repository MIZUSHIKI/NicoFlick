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
    
    @IBOutlet weak var practiceAutoPlaySwitch: UISwitch!
    
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
    private weak var previousFlickView: UIView?
    let effectViewsNum = 10
    private var nextEffectZPosition: CGFloat = 1
    var comboFrameOriginY:CGFloat = 360.0
    
    //ゲーム  表示,判定 定数データ
    @IBOutlet var nodeLine: UIView!
    @IBOutlet private weak var dotCircleView: UIView!
    var nodeLineFlameOriginY:CGFloat = 345.0
    static let GameViewWidth = 375.0 //
    static let FlickPointX = 50.0
    private var gameviewWidth = GameViewWidth
    private var flickPointX = FlickPointX
    private var lastDisplayedNoteTime: Double?
    // EditorGame専用の調整値。GameViewとは独立して変更できる。
    private let visualFlickCenterRatio: CGFloat = 70.0 / 375.0
    let nodeSize = CGSize(width: 40, height: 40)
    let greatLine:[Double] = [-0.080, 0.080]
    let goodLine:[Double] = [-0.200, 0.200]
    let safeLine:[Double] = [-0.400, 0.300]
    var judgeOffset = 0.0
    var xps:Double = 0.0 //ノートが一秒間に進む距離(あとで計算する)
    
    var waitingForFlickAfterMovieTimeSeek = false
    var timetagRateFactor = 0.07
    
    //動画
    var moviePlayerViewController:AVPlayerViewController!
    private var displayLink: CADisplayLink?
    private var autoPlayTimeObserver: Any?
    private weak var autoPlayObserverPlayer: AVPlayer?
    private var nextAutoPlayIndex = 0
    private var nextMissCheckIndex = 0
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
        practiceAutoPlaySwitch.isOn = editorViewController.practiceAutoPlay
        practiceAutoPlaySwitch.addTarget(
            self,
            action: #selector(practiceAutoPlayValueChanged(_:)),
            for: .valueChanged
        )
        
        updateNoteLaneLayout()
       
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
        
        // 移動速度はupdateNoteLaneLayoutで現在の幅と速度スライダーから計算する。
        
        
        //ノートデータを解析、生成 _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
        noteData = Notes()
        noteData.noteAnalyze(noteString: selectLevel.noteData, speed: selectLevel.speed, level_: editorViewController.notesSwitch.isOn ? selectLevel.level : 100)
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
        for i in (0 ..< effectViewsNum) {
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
        
        updateNoteLaneLayout()

        // 画面を開いた時点より前のノートは、MISSにせず通過済みとして扱う
        synchronizeTimelineToCurrentPlaybackTime()

        //画面の更新をディスプレイのリフレッシュに同期させる
        startDisplayLink()
        configureAutoPlayObserver()
        
        //キーボードを開く _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
        textField.becomeFirstResponder()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateNoteLaneLayout()
    }

    // GameViewとは別に、編集画面の幅と操作感に合わせて配置する。
    private func updateNoteLaneLayout() {
        guard let nodeLine, let speedSlider, nodeLine.bounds.width > 0 else { return }

        let width = Double(nodeLine.bounds.width)
        let previousWidth = gameviewWidth
        let previousSpeed = xps
        gameviewWidth = width
        flickPointX = width * Self.FlickPointX / Self.GameViewWidth
        xps = (width - flickPointX) * Double(speedSlider.value) / 300

        let centerX = nodeLine.bounds.width * visualFlickCenterRatio
        let originals: [UIView?] = [
            dotCircleView, greatView, goodView, safeView, badView, missView, flickView, comboView
        ]
        let effects = greatViews + goodViews + safeViews + badViews + missViews + flickViews
        for effect in originals.compactMap({ $0 }) + effects {
            guard let parent = effect.superview else { continue }
            let x = parent.convert(CGPoint(x: centerX, y: 0), from: nodeLine).x
            // 拡縮アニメーション中も大きさと縦位置は維持する。
            if effect.center.x != x {
                effect.center.x = x
            }
        }

        if previousWidth != width || previousSpeed != xps {
            if let time = lastDisplayedNoteTime {
                updateNotePositions(at: time)
            }
        }
    }

    private func updateNotePositions(at time: Double) {
        guard let noteData else { return }
        lastDisplayedNoteTime = time
        for note in noteData.notes {
            let x = (note.time - time) * xps + flickPointX
            let shouldBeVisible = -100 < x && x < gameviewWidth + 25
            if shouldBeVisible {
                note.label.frame.origin.x = CGFloat(x)
            }
            if note.label.isHidden == shouldBeVisible {
                note.label.isHidden = !shouldBeVisible
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopDisplayLink()
        removeAutoPlayObserver()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        restoreEditorMovieLayout()
    }

    private func restoreEditorMovieLayout() {
        guard let playerView = editorViewController.moviePlayerViewController?.view else {
            return
        }

        editorViewController.movieView.addSubview(playerView)
        editorViewController.movieView.sendSubview(toBack: playerView)
        playerView.frame.origin = .zero
        playerView.frame.size = editorViewController.movieView.frame.size
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
        
        var flickTime = -1.0
        if let controller = editorViewController.moviePlayerViewController {
            if let currentTime = controller.player?.currentTime() {
                flickTime = CMTimeGetSeconds(currentTime) - judgeOffset
                if let rate = controller.player?.rate {
                    flickTime -= timetagRateFactor * (1.0 - Double(rate))
                }
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
                if diffTime > 1.0 { break }
            }
        }
        //着目noteがあったとき
        if let flickedNote {
            JudgeFlick(flickedNote: flickedNote, flickWord: string, flickTime: flickTime, diffTime: minDiffTime)
        }
        //フリックアクション
        self.FlickAction()
        // 時間シークした後フラグが立ちフリックするまで保持 (過ぎ去りMISSが誤爆しないように)
        if waitingForFlickAfterMovieTimeSeek {
            waitingForFlickAfterMovieTimeSeek = false

            for note in noteData.notes {
                if !note.isFlickable { continue }
                if note.flicked { continue }
                // 再生開始位置より前のものは打てないNoteにする(シークバー離した時も設定しているが、その後のフリックまでの間の分)
                if note.time <= flickTime {
                    note.flicked = true
                    note.setUnFlickableFont()
                }else {
                    break
                }
            }
        }
        return false
    }

    func JudgeFlick(flickedNote: Note, flickWord: String, flickTime: Double, diffTime: Double, updatesBorderView: Bool = true) {
        let wildcardWords = ["\n", "☻", "？", "！", "。", "、"]
        let displayedWord = wildcardWords.contains(flickWord) ? "＊" : flickWord
        let wordJudge = wildcardWords.contains(flickWord) ? Note.NORMAL : flickedNote.judgeWord(flickWord: flickWord)

        let judge: Int
        
        if flickTime == -1.0 {  // −1.0指定時は強制MISS
            judge = Note.MISS
        } else if wordJudge == Note.BAD {
            judge = Note.BAD
        } else if wordJudge == Note.SAFE {
            judge = Note.SAFE
        } else if greatLine[0] <= diffTime && diffTime <= greatLine[1] {
            judge = Note.GREAT
        } else if goodLine[0] <= diffTime && diffTime <= goodLine[1] {
            judge = Note.GOOD
        } else if safeLine[0] <= diffTime && diffTime <= safeLine[1] {
            judge = Note.SAFE
        } else {
            judge = Note.BAD
        }

        flickedNote.flickedTime = flickTime
        flickedNote.flicked = true
        flickedNote.judge = judge
        noteData.score.addScore(judge: judge)
        flickedNote.comboCount = noteData.score.comboCounter

        if updatesBorderView && judge != Note.SAFE {
            borderView.frame.size.width = borderMaxView.frame.size.width * CGFloat(noteData.score.borderScore / 100)
        }

        switch judge {
        case Note.GREAT:
            flickedNote.setUnFlickableFont()
            GreatAction()
            seAudio.okJinglePlay()
        case Note.GOOD:
            flickedNote.setUnFlickableFont()
            GoodAction()
            seAudio.okJinglePlay()
        case Note.SAFE:
            flickedNote.setUnFlickableFont()
            SafeAction()
            seAudio.safeJinglePlay()
        case Note.BAD:
            flickedNote.setUnFlickableFont()
            BadAction()
            seAudio.badJinglePlay()
        case Note.MISS:
            //Fullバージョンのときはエフェクトしない（MISSとしてカウント。但しリザルトも表示は0にする。）
            if selectLevel.level <= 10 {
                flickedNote.setUnFlickableFont()
                MissAction()
            }
        default: break
        }

        ComboAction()
        if judge != Note.MISS {
            let judgeNames = ["NORMAL", "GREAT", "GOOD", "SAFE", "BAD", "MISS"]
            detailedJudgeLabel.text = String(
                format: "%.3fs, \(displayedWord), \(flickedNote.word!), \(judgeNames[judge])",
                diffTime
            ) + "\n" + detailedJudgeLabel.text!.prefix(1024)
        }
    }
    
    private func synchronizeTimelineToCurrentPlaybackTime() {
        guard let player = editorViewController.moviePlayerViewController?.player else {
            return
        }

        let currentTime = max(0, CMTimeGetSeconds(player.currentTime()) - judgeOffset)
        for note in noteData.notes where note.isFlickable && note.time <= currentTime {
            note.flickedTime = -1.0
            note.flicked = true
            note.setUnFlickableFont()
        }

        resetTimelineCursors()
        noteData.lastFlickedNum = nextMissCheckIndex
    }

    private func startDisplayLink() {
        guard displayLink == nil else { return }

        let displayLink = CADisplayLink(target: self, selector: #selector(updateFrame(_:)))
        if #available(iOS 15.0, *) {
            displayLink.preferredFrameRateRange = CAFrameRateRange(
                minimum: 60,
                maximum: 60,
                preferred: 60
            )
        } else {
            displayLink.preferredFramesPerSecond = 60
        }
        displayLink.add(to: .main, forMode: RunLoopMode.commonModes)
        self.displayLink = displayLink
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    //画面更新と、表示フレーム単位で十分なMISS確定を行う
    @objc private func updateFrame(_ displayLink: CADisplayLink) {
        
        guard let controller = editorViewController.moviePlayerViewController else {
            return
        }
        guard let currentTime = controller.player?.currentTime() else {
            return
        }
        var time = CMTimeGetSeconds(currentTime) - judgeOffset//ズレ
        if time < 0 { time = 0.0 }
        processMissedNotes(at: time)
        updateNotePositions(at: time)
    }

    private func processMissedNotes(at currentTime: Double) {
        guard !waitingForFlickAfterMovieTimeSeek else { return }

        while nextMissCheckIndex < noteData.notes.count {
            let note = noteData.notes[nextMissCheckIndex]

            guard note.isFlickable else {
                nextMissCheckIndex += 1
                continue
            }
            guard !note.flicked else {
                nextMissCheckIndex += 1
                continue
            }

            let diffTime = note.time - currentTime
            guard diffTime < safeLine[0] else { break }

            JudgeFlick(
                flickedNote: note,
                flickWord: note.word,
                flickTime: -1.0,
                diffTime: diffTime
            )
            nextMissCheckIndex += 1
            
            // lastFlickedNum にも反映 (lastFlickedというかnextFlickだけど)
            if noteData.lastFlickedNum < nextMissCheckIndex {
                noteData.lastFlickedNum = nextMissCheckIndex
            }
        }
    }

    private func configureAutoPlayObserver(from requestedStartTime: Double? = nil) {
        removeAutoPlayObserver()

        guard
            practiceAutoPlaySwitch.isOn,
            let player = editorViewController.moviePlayerViewController?.player
        else {
            return
        }

        let playerTime = CMTimeGetSeconds(player.currentTime())
        let currentTime = requestedStartTime ?? max(0, playerTime - judgeOffset)
        resetTimelineCursors()
        processAutoPlayNotes(at: currentTime)

        guard nextAutoPlayIndex < noteData.notes.count else { return }
        let times = noteData.notes[nextAutoPlayIndex...].compactMap { note -> NSValue? in
            guard note.isFlickable, !note.flicked, note.time > currentTime else { return nil }
            let boundaryTime = max(0, note.time + judgeOffset)
            return NSValue(time: CMTime(seconds: boundaryTime, preferredTimescale: 600))
        }
        guard !times.isEmpty else { return }

        autoPlayObserverPlayer = player
        autoPlayTimeObserver = player.addBoundaryTimeObserver(forTimes: times, queue: .main) { [weak self, weak player] in
            guard let self, let player else { return }
            let time = max(0, CMTimeGetSeconds(player.currentTime()) - self.judgeOffset)
            self.processAutoPlayNotes(at: time)
        }
    }

    private func removeAutoPlayObserver() {
        if let autoPlayTimeObserver, let autoPlayObserverPlayer {
            autoPlayObserverPlayer.removeTimeObserver(autoPlayTimeObserver)
        }
        autoPlayTimeObserver = nil
        autoPlayObserverPlayer = nil
    }

    private func processAutoPlayNotes(at currentTime: Double) {
        guard practiceAutoPlaySwitch.isOn else { return }

        let boundaryTolerance = 0.02
        var processedNote = false

        while nextAutoPlayIndex < noteData.notes.count {
            let note = noteData.notes[nextAutoPlayIndex]

            guard note.isFlickable else {
                nextAutoPlayIndex += 1
                continue
            }
            guard !note.flicked else {
                nextAutoPlayIndex += 1
                continue
            }
            guard note.time <= currentTime + boundaryTolerance else { break }

            waitingForFlickAfterMovieTimeSeek = false
            JudgeFlick(
                flickedNote: note,
                flickWord: note.judgeWorder(noteWord: note.word, level: 1),
                flickTime: note.time,
                diffTime: 0,
                updatesBorderView: false
            )
            processedNote = true
            nextAutoPlayIndex += 1
        }

        if processedNote {
            borderView.frame.size.width = borderMaxView.frame.size.width * CGFloat(noteData.score.borderScore / 100)
        }
    }

    private func resetTimelineCursors() {
        let firstPendingIndex = noteData.notes.firstIndex {
            $0.isFlickable && !$0.flicked
        } ?? noteData.notes.count
        nextAutoPlayIndex = firstPendingIndex
        nextMissCheckIndex = firstPendingIndex
    }

    @objc private func practiceAutoPlayValueChanged(_ sender: UISwitch) {
        editorViewController.practiceAutoPlay = sender.isOn
        if sender.isOn {
            configureAutoPlayObserver()
        } else {
            removeAutoPlayObserver()
        }
    }
    
    //ゲームの描写 エフェクト処理 関数 _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    private func prepareEffectView(_ view: UIView) {
        view.layer.zPosition = nextEffectZPosition
        nextEffectZPosition += 1
    }

    func GreatAction(){
        let view = greatViews[greatActionCount]
        prepareEffectView(view)
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
        greatActionCount = greatActionCount % effectViewsNum
    }
    func GoodAction(){
        let view = goodViews[goodActionCount]
        prepareEffectView(view)
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
        goodActionCount = goodActionCount % effectViewsNum
    }
    func SafeAction(){
        let view = safeViews[safeActionCount]
        prepareEffectView(view)
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
        safeActionCount = safeActionCount % effectViewsNum
    }
    func BadAction(){
        let view = badViews[badActionCount]
        prepareEffectView(view)
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
        badActionCount = badActionCount % effectViewsNum
    }
    func MissAction(){
        let view = missViews[missActionCount]
        prepareEffectView(view)
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
        missActionCount = missActionCount % effectViewsNum
    }
    func FlickAction(){
        //直前のViewだけを非表示にしてアクションが重ならないようにする
        previousFlickView?.isHidden = true

        let view = flickViews[flickActionCount]
        previousFlickView = view
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
        flickActionCount = flickActionCount % effectViewsNum
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
        DispatchQueue.main.async { [weak self] in
            self?.restoreEditorMovieLayout()
        }
    }
    
    //画面遷移処理_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    @IBAction func returnToMe(segue: UIStoryboardSegue){
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        //キーボードを閉じる _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
        textField.resignFirstResponder()
        
        editorViewController.practiceAutoPlay = practiceAutoPlaySwitch.isOn
    }
    
    @IBAction func SpeedSlider(_ sender: UISlider) {
        sender.value = round(sender.value)
        speedLabel.text = "Speed: \(Int(sender.value))"
        selectLevel.speed = Int(sender.value)
        editorViewController.mySpoon.atTag["Speed"] = "\(Int(sender.value))"
        
        updateNoteLaneLayout()
    }
    
    @IBAction func OffsetSlider(_ sender: UISlider) {
        sender.value = round( Float(Int(sender.value / 10) * 10) )
        offsetLabel.text = "Offset: \(Int(sender.value))ms"
        judgeOffset = Double(sender.value) / 1000
        editorViewController.mySpoon.atTag["Offset"] = "\(Int(sender.value ))"
        configureAutoPlayObserver()
    }
    
    @IBAction func RateSlider(_ sender: UISlider) {
        let rate = Float(Int(round(sender.value * 10))) / 10
        sender.value = rate
        editorViewController.setMovieRate(rate: rate)
    }
    @IBAction func RewindButton(_ sender: UIButton) {
        UndoAllFlickedNote( time: editorViewController.playerRewind() )
    }
    
    @IBAction func ForwardButton(_ sender: UIButton) {
        UndoAllFlickedNote( time: editorViewController.playerForward() )
    }
    
    private func UndoAllFlickedNote(time:Double) {
        waitingForFlickAfterMovieTimeSeek = true
        let time = time - judgeOffset
        for note in noteData.notes {
            if !note.isFlickable { continue }
            if note.flicked {
                note.flickedTime = -1.0
                note.flicked = false
                //note.judge = Note.NORMAL
                note.setFlickableFont()
            }
            // 再生開始位置より前のものは打てないNoteにする
            if note.time <= time {
                note.flicked = true
                note.setUnFlickableFont()
            }
        }
        noteData.lastFlickedNum = 0
        for (i, note) in noteData.notes.enumerated() {
            if note.time > time {
                noteData.lastFlickedNum = i
                break
            }
        }
        resetTimelineCursors()
        configureAutoPlayObserver(from: max(0, time))
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
