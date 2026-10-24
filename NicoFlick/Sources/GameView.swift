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
import ReplayKit

class GameView: UIViewController, UITextFieldDelegate {
    private static var hasWarmedUpKeyboardInput = false

    private var isWaitingForKeyboardWarmUp = false
    private var pendingInitialGameStart: (() -> Void)?
    private var keyboardWarmUpOverlay: UIView?
    private var keyboardWarmUpLabel: UILabel?
    private var keyboardWarmUpLabelCenterYConstraint: NSLayoutConstraint?
    
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
    @IBOutlet var comboLabel: OutlinedLabel!
    @IBOutlet var highScoreLabel: UILabel!
    @IBOutlet var judgeOffsetLabel: UILabel!
    
    @IBOutlet var borderView: UIView!
    @IBOutlet var borderMaxView: UIView!
    
    @IBOutlet var loadedAndCurrentTimeBarView: UIView!
    @IBOutlet var loadedTimeBarView: UIView!
    @IBOutlet var currentTimeBarView: UIView!
    
    @IBOutlet weak var keyboardImageView: UIImageView!
    @IBOutlet weak var keyboardKeyView: UIView!
    
    @IBOutlet weak var practiceSeekbar: UISlider!
    @IBOutlet weak var practiceRatebar: UISlider!
    @IBOutlet weak var practiceRateLabel: OutlinedLabel!
    @IBOutlet weak var practiceAutoPlaySwitch: UISwitch!
    @IBOutlet weak var practiceAutoPlayLabel: OutlinedLabel!
    
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
    var effectViewsNum = 10
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
    // iPhone 12 miniの標準幅375ptで、時刻一致位置70pt。
    private let visualFlickCenterRatio: CGFloat = 70.0 / 375.0
    let nodeSize = CGSize(width: 40, height: 40)
    let greatLine:[Double] = [-0.080, 0.080]
    let goodLine:[Double] = [-0.200, 0.200]
    let safeLine:[Double] = [-0.400, 0.300]
    var judgeOffset = 0.0
    var xps:Double = 0.0 //ノートが一秒間に進む距離(あとで計算する)
    var practiceMode = false
    var practice_movieTimeSliding = false
    var practice_waitingForFlickAfterMovieTimeSlide = false
    var timetagRateFactor = 0.07
    
    var keyboardRect:CGRect? = nil
    let savingPlayMovie = UserData.sharedInstance.SavePlayMovie
    var failedSavePlayMovie = false
    var Window_UIRemoteKeyboard:UIView?
    
    var hasPassedFirstNote = false
    private var hasRecordedPlayHistory = false

    func recordPlayHistoryIfNeeded() {
        guard hasPassedFirstNote,
              !hasRecordedPlayHistory,
              !selectLevel.isEditing else { return }
        hasRecordedPlayHistory = true
        userData.recordLevelPlay(levelID: selectLevel.sqlID)
    }

    //動画
    var cachedMovies:CachedMovies = CachedMovies.sharedInstance
    var moviePlayerViewController:AVPlayerViewController!
    var fitsMovieToKeyboardHeight = false
    private var presentationSizeObservation: NSKeyValueObservation?
    private var displayLink: CADisplayLink?
    private var autoPlayTimeObserver: Any?
    private weak var autoPlayObserverPlayer: AVPlayer?
    private var isGameMenuPresented = false
    private var gameMenuPresentedMediaTime: CFTimeInterval?
    private var nextAutoPlayIndex = 0
    private var nextMissCheckIndex = 0
    var t03 = 3.0
    var time3secMediaTime:CFTimeInterval?
    private var isWaitingForMovieLoad = false
    //効果音プレイヤー(シングルトン)
    var seAudio:SEAudio = SEAudio.sharedInstance
    var seSystemAudio:SESystemAudio = SESystemAudio.sharedInstance
    
    //ゲームデータ
    var noteData: Notes!
    //保存データ
    let userData = UserData.sharedInstance
    var userScore = UserScore()
    
    var signSE:CGFloat = 1
    var firstAttack = false
    var borderOriginRect:CGRect?
    
    //遷移時に受け取り
    var selectorController:Selector?
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
                // print("HowToを表示")
                self.performSegue(withIdentifier: "toHelpView", sender: self)
            }
        }else {
            self.viewDidLoad2()
        }
    }
    func viewDidLoad2() {
        // 設定値取得
        fitsMovieToKeyboardHeight = userData.fitsMovieToKeyboardHeight
        keyboardRect = userData.maeKeyboardRect
        judgeOffsetLabel.isHidden = !userData.showOffsetLabel
        
        //初期位置設定修正
        nodeLineFlameOriginY = nodeLine.frame.origin.y
        comboFrameOriginY = comboView.frame.origin.y
        
        textField.delegate = self
        isWaitingForKeyboardWarmUp = !Self.hasWarmedUpKeyboardInput
        if isWaitingForKeyboardWarmUp {
            showKeyboardWarmUpOverlay()
        }
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
            comboLabel.outlineWidth = 3
            comboLabel.outlineColor = UIColor.darkGray
        }
        //ipad対策（対象じゃないけど）
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow(_:)), name: .UIKeyboardDidShow, object: nil)
        
        // iOS16以降のキーボード画面取得用
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeVisible(_:)), name: .UIWindowDidBecomeVisible, object: nil)
        
        //計算しておく
        updateNoteLaneLayout()
        let timetag = selectLevel.noteData.pregMatche_firstString(pattern: "(\\[\\d\\d\\:\\d\\d[\\:|\\.]\\d\\d\\])")
        if timetag != "" {
            t03 = 3.0 - timetag.timetagToSeconds()
            if t03 < 0.0 {
                t03 = 0.0
            }
        }
        
        //Movie呼び込み _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
        var ans:[String]=[]
        var smNum = ""
        if (self.selectMusic.movieURL.pregMatche(pattern: "watch/(.+)$", matches: &ans)){
            smNum = ans[1]
        }
        MovieAccess.init().StreamingUrlNicoAccess(smNum: smNum){ nicodougaURL in
            // print(nicodougaURL)
            //session.dataTas後のサブスレッド内でviewを処理させると表示関連が後回しになるので、メインスレッドでaddSubviewする。
            DispatchQueue.main.async {
                //UI処理はメインスレッドの必要あり
                guard let videoURL = URL(string: nicodougaURL) else { return }
                self.moviePlayerViewController = self.cachedMovies.access(url: videoURL, smNum: smNum)
                self.moviePlayerViewController?.view.tag = 5050
                //  add
                self.view.addSubview(self.moviePlayerViewController.view)
                self.view.sendSubview(toBack: self.moviePlayerViewController.view)
                
                self.observeMoviePresentationSize()
                // 動画が終了した時に呼ばれるnotificationを登録
                NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil, queue: nil){ notification in
                    //再生終了したとき
                    // print("終了")
                    DispatchQueue.main.async {
                        //UI処理はメインスレッドの必要あり
                        self.performSegue(withIdentifier: "toResultView", sender: self)
                    }
                }
                self.loadedAndCurrentTimeBarView.isHidden = false
                
                self.requestInitialGameStart()


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
        if let score = userScore.scores[selectLevel.sqlID]?.first, score > 0 {
            highScoreLabel.text = "High Score: \(score) "
            highScoreLabel.isHidden = false
        } else {
            highScoreLabel.isHidden = true
        }
        SetJudgeOffset()

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

        // 動画の0秒シークが完了してから画面更新と判定を開始する
        firstAttack=true
        
        //キーボードを開く _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
        textField.becomeFirstResponder()
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if borderOriginRect == nil {
            borderOriginRect = borderMaxView.frame
        }
        updateMovieLayout()
        updateKeyboardWarmUpLabelPosition()
        updateNoteLaneLayout()
    }
    // ノーツの移動計算と独立した、操作感に合わせた比率で目印とエフェクトを配置する。
    private func updateNoteLaneLayout() {
        guard let nodeLine, let selectLevel, nodeLine.bounds.width > 0 else { return }

        let width = Double(nodeLine.bounds.width)
        let widthChanged = gameviewWidth != width
        gameviewWidth = width
        flickPointX = width * Self.FlickPointX / Self.GameViewWidth
        xps = (width - flickPointX) * Double(selectLevel.speed) / 300

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

        if widthChanged, let time = lastDisplayedNoteTime {
            updateNotePositions(at: time)
        }
    }

    private func updateNotePositions(at time: Double) {
        guard let noteData else { return }
        lastDisplayedNoteTime = time
        for note in noteData.notes {
            // 保存済みposXは基準幅で計算されているため、現在の幅と時刻から直接求める。
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.SetBorderY()
        observeMoviePresentationSize()
    }
    func SetJudgeOffset(){
        //  ジャッジオフセットの取得
        if let jo = userData.JudgeOffset[selectLevel.sqlID] {
            judgeOffset = Double(jo)
        }
        judgeOffsetLabel.text = "offset: \(String(format:"%0.02f",judgeOffset)) "
    }
    func SetBorderY(){
        if let rect = borderOriginRect {
            if userData.BorderY > 0 {
                borderMaxView.frame = CGRect(x: rect.origin.x + rect.width/4 , y: userData.BorderY, width: rect.width * 1/2, height: rect.height)
            }else{
                borderMaxView.frame = rect
            }
        }
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopDisplayLink()
        removeAutoPlayObserver()
        presentationSizeObservation?.invalidate()
        presentationSizeObservation = nil
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
        if isWaitingForKeyboardWarmUp {
            if !string.isEmpty && string != "\n" {
                finishKeyboardWarmUp()
            }
            return false
        }

        testLabel.text = string
        //print("string="+string)
        if string == "\n" {
            //強制終了(ランク算出に難あり)
            //開発者用
            //if userData.UserIDxxx == AppDelegate.MIZUSHIKI_IDxxx {
            //    performSegue(withIdentifier: "toResultView", sender: self)
            //}
        }
        
        var flickTime = -1.0
        if moviePlayerViewController != nil {
            if moviePlayerViewController.player != nil {
                flickTime = CMTimeGetSeconds((moviePlayerViewController.player?.currentTime())!)+judgeOffset//キー打ち定量ズレ
                if practiceMode {
                    if let rate = moviePlayerViewController?.player?.rate {
                        flickTime -= timetagRateFactor * (1.0 - Double(rate))
                    }
                }
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
        // 着目noteがあったとき
        if let flickedNote {
            JudgeFlick(flickedNote: flickedNote, flickWord: string, flickTime: flickTime, diffTime: minDiffTime)
        }
        //フリックアクション
        self.FlickAction()
        //スコア更新
        self.scoreLabel.text = "Score: "+String(noteData.score.totalScore)+" "
        
        // 練習モードでシークバー離した後フラグが立ちフリックするまで保持 (過ぎ去りMISSが誤爆しないように)
        if practice_waitingForFlickAfterMovieTimeSlide {
            practice_waitingForFlickAfterMovieTimeSlide = false

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
    
    func JudgeFlick(flickedNote: Note, flickWord:String, flickTime:Double, diffTime: Double, updatesBorderView: Bool = true){
        hasPassedFirstNote = true
        let wordJudge = flickedNote.judgeWord(flickWord: flickWord)
        // 文字判定を優先し、文字が合っていればタイミングで判定
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

        if practiceMode {
            // 戻って再フリックしたとき用に前回取得した点数を引く
            noteData.score.subScore(maeJudge: flickedNote.judge, maeComboCount: flickedNote.comboCount)
        }
        flickedNote.flickedTime = flickTime
        flickedNote.flicked = true
        flickedNote.judge = judge
        noteData.score.addScore(judge: judge)
        flickedNote.comboCount = noteData.score.comboCounter
        if updatesBorderView && judge != Note.SAFE {  // SAFEの場合はボーダーがかわらない
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
        self.ComboAction()
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
        if firstAttack { //なんか前のが勝手に再利用される？ので苦肉の策
            lastDisplayedNoteTime = nil
            for note in noteData.notes {
                note.label.frame.origin.x = -200
                note.label.isHidden = true
            }
            firstAttack = false
        }
        if selectLevel.level<=10 && noteData.score.borderScore <= 0 {
            if !practiceMode {
                //強制終了(ランク算出に難あり)
                performSegue(withIdentifier: "toResultView", sender: self)
            }
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

        if isWaitingForMovieLoad {
            guard let loadedTime, CMTimeGetSeconds(loadedTime) > 0 else {
                return
            }

            isWaitingForMovieLoad = false
            moviePlayerViewController.player?.pause()
            moviePlayerViewController.player?.seek(
                to: CMTime(seconds: 0, preferredTimescale: Int32(NSEC_PER_SEC)),
                toleranceBefore: kCMTimeZero,
                toleranceAfter: kCMTimeZero
            )

            if t03 <= 0 {
                time3secMediaTime = nil
                beginMoviePlayback()
            } else {
                time3secMediaTime = CACurrentMediaTime()
            }
        }
        
        if time3secMediaTime == nil && moviePlayerViewController.player?.isPlaying == false {
            return
        }
        
        var time = CMTimeGetSeconds((moviePlayerViewController.player?.currentTime())!)
        //print("time=\(time)")
        if time3secMediaTime != nil {
            let time3sec = -t03 + time3secMediaTime!.distance(to: CACurrentMediaTime())
            //print("time3sec=\(time3sec)")
            //print("userData.Time3secExitZureTime=\(userData.Time3secExitZureTime)")
            if time3sec < userData.Time3secExitZureTime {
                time = time3sec
            }else {
                if !isGameMenuPresented {
                    beginMoviePlayback()
                }
                if time == 0.0 {
                    time = time3sec
                }else {
                    userData.Time3secExitZureTime = userData.Time3secExitZureTime + ( time - time3sec ) / 2
                    time3secMediaTime = nil
                }
            }
        }
        
        // practiceMode
        if practiceMode {
            if !practice_movieTimeSliding {
                practiceSeekbar.value = Float(CGFloat(CMTimeGetSeconds(currentTime!)/CMTimeGetSeconds(duration!)))
            }else {
                time = CMTimeGetSeconds(duration!) * Double(practiceSeekbar.value)
            }
        }

        processMissedNotes(at: time)
        updateNotePositions(at: time)
        //プレイムービー録画中、キーボードイメージを取得してViewに描画し続ける
        if savingPlayMovie {
            self.setKeyboardImage()
        }
    }

    private func processMissedNotes(at currentTime: Double) {
        guard !practice_movieTimeSliding, !practice_waitingForFlickAfterMovieTimeSlide else {
            return
        }

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

            let diffTime = note.time - (currentTime + judgeOffset)
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

            if practiceMode {
                scoreLabel.text = "Score: " + String(noteData.score.totalScore) + " "
            }
        }
    }

    private func configureAutoPlayObserver(from requestedStartTime: Double? = nil) {
        removeAutoPlayObserver()

        guard
            practiceMode,
            practiceAutoPlaySwitch.isOn,
            !practice_movieTimeSliding,
            let player = moviePlayerViewController?.player
        else {
            return
        }

        let currentTime = requestedStartTime ?? CMTimeGetSeconds(player.currentTime())
        resetTimelineCursors(at: currentTime)
        processAutoPlayNotes(at: currentTime)

        guard nextAutoPlayIndex < noteData.notes.count else { return }
        let times = noteData.notes[nextAutoPlayIndex...].compactMap { note -> NSValue? in
            guard note.isFlickable, !note.flicked, note.time > currentTime else { return nil }
            return NSValue(time: CMTime(seconds: note.time, preferredTimescale: 600))
        }
        guard !times.isEmpty else { return }

        autoPlayObserverPlayer = player
        autoPlayTimeObserver = player.addBoundaryTimeObserver(forTimes: times, queue: .main) { [weak self, weak player] in
            guard let self, let player else { return }
            self.processAutoPlayNotes(at: CMTimeGetSeconds(player.currentTime()))
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
        guard practiceMode, practiceAutoPlaySwitch.isOn else { return }

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

            practice_waitingForFlickAfterMovieTimeSlide = false
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
            scoreLabel.text = "Score: " + String(noteData.score.totalScore) + " "
        }
    }

    private func resetTimelineCursors(at _: Double) {
        let firstPendingIndex = noteData.notes.firstIndex {
            $0.isFlickable && !$0.flicked
        } ?? noteData.notes.count
        nextAutoPlayIndex = firstPendingIndex
        nextMissCheckIndex = firstPendingIndex
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
        //キーボードサイズを取得してキーボードイメージ描画用のViewに反映
        keyboardRect = keyboardInfo.cgRectValue
        if let rect = keyboardRect {
            userData.maeKeyboardRect = rect
        }
        keyboardImageView.frame = keyboardInfo.cgRectValue
        keyboardKeyView.frame = keyboardInfo.cgRectValue
        updateKeyboardWarmUpLabelPosition()
        updateMovieLayout()
        if let label = keyboardWarmUpLabel, label.isHidden {
            // 正しい位置のレイアウトを完了してから文字を表示する。
            UIView.performWithoutAnimation {
                view.layoutIfNeeded()
                label.isHidden = false
            }
        }
    }

    private func updateMovieLayout() {
        guard let movieView = moviePlayerViewController?.view else {
            return
        }

        let topY = view.safeAreaInsets.top
        let safeWidth = view.bounds.width - view.safeAreaInsets.left - view.safeAreaInsets.right
        let barHeight = loadedAndCurrentTimeBarView.bounds.height

        if fitsMovieToKeyboardHeight,
           let keyboardRect {
            let movieTopY: CGFloat = 0
            let keyboardFrame = view.convert(keyboardRect, from: nil)
            let movieHeight = max(0, keyboardFrame.minY - movieTopY)
            let presentationSize = moviePlayerViewController.player?.currentItem?.presentationSize ?? .zero

            if presentationSize.width > 0, presentationSize.height > 0 {
                let movieWidth = movieHeight * presentationSize.width / presentationSize.height
                let movieX = (view.bounds.width - movieWidth) / 2
                movieView.frame = CGRect(x: movieX, y: movieTopY, width: movieWidth, height: movieHeight)
                movieView.isHidden = false
            } else {
                // presentationSizeが確定するまで誤った縦横比で表示しない
                movieView.isHidden = true
            }

            loadedAndCurrentTimeBarView.frame = CGRect(
                x: view.safeAreaInsets.left,
                y: keyboardFrame.minY - barHeight,
                width: safeWidth,
                height: barHeight
            )
        } else {
            movieView.isHidden = false
            let movieHeight = judgeOffsetLabel.frame.maxY - topY
            movieView.frame = CGRect(
                x: view.safeAreaInsets.left,
                y: topY,
                width: safeWidth,
                height: movieHeight
            )
            loadedAndCurrentTimeBarView.frame = CGRect(
                x: view.safeAreaInsets.left,
                y: topY + movieHeight,
                width: safeWidth,
                height: barHeight
            )
        }
    }

    private func observeMoviePresentationSize() {
        presentationSizeObservation?.invalidate()
        presentationSizeObservation = nil

        guard let item = moviePlayerViewController?.player?.currentItem else {
            return
        }

        updateMovieLayout()
        presentationSizeObservation = item.observe(\.presentationSize, options: [.new]) { [weak self] item, _ in
            guard item.presentationSize.width > 0, item.presentationSize.height > 0 else {
                return
            }

            DispatchQueue.main.async {
                guard let self,
                      item === self.moviePlayerViewController?.player?.currentItem else {
                    return
                }
                self.updateMovieLayout()
            }
        }
    }

    @objc private func windowDidBecomeVisible(_ info: Notification) {
        let type = String(describing: info.object)
        if type.range(of: "UIRemoteKeyboardWindow") != nil {
            // print("That's UIRemoteKeyboardWindow")
            Window_UIRemoteKeyboard = info.object as? UIView
        }
    }

    private func showKeyboardWarmUpOverlay() {
        let overlay = UIView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.65)

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        // 保存済みのキーボード位置では表示せず、今回の表示完了を待つ。
        label.isHidden = true
        label.text = "キーボードの準備をします\n好きな文字を一度フリックしてください"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 0

        overlay.addSubview(label)
        view.addSubview(overlay)
        let labelCenterYConstraint = label.centerYAnchor.constraint(
            equalTo: overlay.topAnchor,
            constant: view.bounds.midY
        )
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -24),
            label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            labelCenterYConstraint
        ])
        keyboardWarmUpOverlay = overlay
        keyboardWarmUpLabel = label
        keyboardWarmUpLabelCenterYConstraint = labelCenterYConstraint
        updateKeyboardWarmUpLabelPosition()
    }

    private func updateKeyboardWarmUpLabelPosition() {
        guard let constraint = keyboardWarmUpLabelCenterYConstraint else { return }

        let availableTop = view.bounds.minY + view.safeAreaInsets.top
        let availableBottom: CGFloat
        if let keyboardRect {
            let keyboardFrame = view.convert(keyboardRect, from: nil)
            availableBottom = min(max(keyboardFrame.minY, availableTop), view.bounds.maxY)
        } else {
            availableBottom = view.bounds.maxY
        }
        let availableCenterY = availableTop + (availableBottom - availableTop) / 2
        constraint.constant = availableCenterY - view.bounds.minY
    }

    private func requestInitialGameStart() {
        let startGame = { [weak self] in
            guard let self else { return }
            if self.savingPlayMovie {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.maeCount_keyboardBackground = 0
                    self.setKeyboardImage()
                    self.startRecording {
                        self.startPlaybackFromBeginning()
                    }
                }
            } else {
                self.startPlaybackFromBeginning()
            }
        }

        if isWaitingForKeyboardWarmUp {
            pendingInitialGameStart = startGame
        } else {
            startGame()
        }
    }

    private func finishKeyboardWarmUp() {
        Self.hasWarmedUpKeyboardInput = true
        isWaitingForKeyboardWarmUp = false

        let overlay = keyboardWarmUpOverlay
        keyboardWarmUpOverlay = nil
        keyboardWarmUpLabel = nil
        keyboardWarmUpLabelCenterYConstraint = nil
        UIView.animate(withDuration: 0.2, animations: {
            overlay?.alpha = 0
        }, completion: { _ in
            overlay?.removeFromSuperview()
        })

        let startGame = pendingInitialGameStart
        pendingInitialGameStart = nil
        DispatchQueue.main.async {
            startGame?()
        }
    }

    private func startPlaybackFromBeginning() {
        guard let player = moviePlayerViewController?.player else { return }

        let startTime = CMTime(seconds: 0, preferredTimescale: Int32(NSEC_PER_SEC))
        player.seek(
            to: startTime,
            toleranceBefore: kCMTimeZero,
            toleranceAfter: kCMTimeZero
        ) { [weak self] finished in
            guard finished, let self else { return }

            DispatchQueue.main.async {
                guard !self.isGameMenuPresented else {
                    player.pause()
                    return
                }

                self.resetTimelineCursors(at: 0)
                self.firstAttack = true
                self.time3secMediaTime = nil
                self.isWaitingForMovieLoad = true
                player.pause()

                self.startDisplayLink()
                self.configureAutoPlayObserver(from: 0)
            }
        }
    }

    private func beginMoviePlayback() {
        guard let player = moviePlayerViewController?.player else { return }
        let playbackRate = practiceMode ? practiceRatebar.value : 1.0
        player.playImmediately(atRate: playbackRate)
    }

    private func resetJudgementEffectViews() {
        let judgementViews = greatViews + goodViews + safeViews + badViews + missViews
        for view in judgementViews {
            view.layer.removeAllAnimations()
            view.isHidden = true
        }

        for view in flickViews {
            view.layer.removeAllAnimations()
            view.transform = .identity
            view.alpha = flickView.alpha
            view.isHidden = true
        }
    }
    
    //画面遷移処理_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    @IBAction func returnToMe(segue: UIStoryboardSegue){
        if segue.identifier == "fromGameMenu" {
            isGameMenuPresented = false
            // ゲームメニュー設定反映
            if fitsMovieToKeyboardHeight != userData.fitsMovieToKeyboardHeight {
                // 動画サイズ設定値変更確認
                fitsMovieToKeyboardHeight = userData.fitsMovieToKeyboardHeight
                updateMovieLayout()
            }
            if judgeOffsetLabel.isHidden != !userData.showOffsetLabel {
                judgeOffsetLabel.isHidden = !userData.showOffsetLabel
            }
            
            let gameMenuPausedDuration = gameMenuPresentedMediaTime.map {
                $0.distance(to: CACurrentMediaTime())
            }
            gameMenuPresentedMediaTime = nil

            switch returnToMeData {
            case 0:
                if let gameMenuPausedDuration,
                   let preRollStartTime = time3secMediaTime {
                    time3secMediaTime = preRollStartTime + gameMenuPausedDuration
                }

                //se
                seSystemAudio.canselSePlay()
                // 再開
                textField.becomeFirstResponder() //キーボードを開く
                // 先行ノーツ中は、残り時間が終わるまで曲を再生しない
                if time3secMediaTime == nil {
                    beginMoviePlayback()
                }
                // ジャッジオフセットの再設定
                SetJudgeOffset()
                //
                self.SetBorderY()
                startDisplayLink()
                configureAutoPlayObserver()
                break
            case 1:
                //録画しなおし
                canselRecording()
                stopDisplayLink()
                removeAutoPlayObserver()
                moviePlayerViewController?.player?.pause()
                //se
                seSystemAudio.canselSePlay()
                //リトライ
                textField.becomeFirstResponder() //キーボードを開く
                noteData.noteReset() //データをリセットする
                self.comboView.isHidden = true //表示関係もリセット
                scoreLabel.text = "Score: "+String(noteData.score.totalScore)+" "
                // ジャッジオフセットの再設定
                SetJudgeOffset()
                //
                self.SetBorderY()
                
                //Labelを非表示かつ見えない位置に移動
                lastDisplayedNoteTime = nil
                for note in noteData.notes { //なんか前のが勝手に再利用される？ので苦肉の策
                    note.label.frame.origin.x = -200
                    note.label.isHidden = true
                }
                resetJudgementEffectViews()
                
                if self.savingPlayMovie {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.startRecording() {
                            self.startPlaybackFromBeginning()
                        }
                    }
                } else {
                    startPlaybackFromBeginning()
                }
                
                break
            case 2:
                //se
                seSystemAudio.cansel2SePlay()
                // print("戻る")
                canselRecording()
                recordPlayHistoryIfNeeded()
                
                if moviePlayerViewController != nil {
                    if moviePlayerViewController.player != nil {
                        //ムービー状況
                        let duration = CMTimeGetSeconds((moviePlayerViewController.player?.currentItem?.duration)!)
                        let currentTime = CMTimeGetSeconds((moviePlayerViewController.player?.currentTime())!)
                        self.moviePlayerViewController.player?.seek(to: CMTimeMakeWithSeconds(0.0, Int32(NSEC_PER_SEC)) ) //時間を戻しておく
                        if currentTime > (duration / 2) {
                            //カウンタを回す
                            // print("PlayCount")
                            //  プレイ回数データ
                            userData.PlayCount.addPlayCount(levelID: selectLevel.sqlID)
                            // playCount,like,dislike,musicFavorite の送信(成功したらカウントデータを初期化)
                            ServerDataHandler().postUserCountData()
                        }
                    }
                }
                
                //曲選択に戻る
                self.performSegue(withIdentifier: "fromGameView", sender: self)
                
                break
                
            case 3:
                //録画しなおし
                canselRecording()
                //se
                seSystemAudio.canselSePlay()
                //リロード
                userData.Time3secExitZureTime = 0.0
                textField.becomeFirstResponder() //キーボードを開く
                noteData.noteReset() //データをリセットする
                self.comboView.isHidden = true //表示関係もリセット
                scoreLabel.text = "Score: "+String(noteData.score.totalScore)+" "
                // ジャッジオフセットの再設定
                SetJudgeOffset()
                //
                self.SetBorderY()
                
                //Labelを非表示かつ見えない位置に移動
                lastDisplayedNoteTime = nil
                for note in noteData.notes { //なんか前のが勝手に再利用される？ので苦肉の策
                    note.label.frame.origin.x = -200
                    note.label.isHidden = true
                }
                
                //Movie呼び込み _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
                var ans:[String]=[]
                var smNum = ""
                if (self.selectMusic.movieURL.pregMatche(pattern: "watch/(.+)$", matches: &ans)){
                    smNum = ans[1]
                }
                //キャッシュ削除
                self.cachedMovies.remove(smNum: smNum)
                //movieView削除
                self.view.viewWithTag(5050)?.removeFromSuperview()
                
                MovieAccess.init().StreamingUrlNicoAccess(smNum: smNum){ nicodougaURL in
                    // print(nicodougaURL)
                    //session.dataTas後のサブスレッド内でviewを処理させると表示関連が後回しになるので、メインスレッドでaddSubviewする。
                    DispatchQueue.main.async {
                        //UI処理はメインスレッドの必要あり
                        guard let videoURL = URL(string: nicodougaURL) else { return }
                        self.moviePlayerViewController = self.cachedMovies.access(url: videoURL, smNum: smNum)
                        self.configureAutoPlayObserver()
                        self.startDisplayLink()
                        self.moviePlayerViewController?.view.tag = 5050
                        //  add
                        self.view.addSubview(self.moviePlayerViewController.view)
                        self.view.sendSubview(toBack: self.moviePlayerViewController.view)
                        
                        self.observeMoviePresentationSize()
                        // 動画が終了した時に呼ばれるnotificationを登録
                        NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil, queue: nil){ notification in
                            //再生終了したとき
                            // print("終了")
                            DispatchQueue.main.async {
                                //UI処理はメインスレッドの必要あり
                                self.performSegue(withIdentifier: "toResultView", sender: self)
                            }
                        }
                        self.loadedAndCurrentTimeBarView.isHidden = false
                        
                        if self.savingPlayMovie {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.startRecording() {
                                    self.startPlaybackFromBeginning()
                                }
                            }
                        } else {
                            self.startPlaybackFromBeginning()
                        }
                    }
                }
                
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
            isGameMenuPresented = true
            if time3secMediaTime != nil {
                gameMenuPresentedMediaTime = CACurrentMediaTime()
            } else {
                gameMenuPresentedMediaTime = nil
            }
            stopDisplayLink()
            
            //se
            seSystemAudio.gameMenuSePlay()
            
            if moviePlayerViewController != nil {
                if moviePlayerViewController.player != nil {
                    //一時停止
                    moviePlayerViewController.player?.pause()
                }
            }
            //キーボードを閉じる _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
            textField.resignFirstResponder()

            //Labelを非表示かつ見えない位置に移動
            lastDisplayedNoteTime = nil
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
            lastDisplayedNoteTime = nil
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
    
    var maeCount_keyboardBackground = 0
    var maeSubviewsDescriptions:[String] = []
    private let keyboardCaptureInterval: CFTimeInterval = 1.0 / 20.0
    private var lastKeyboardCaptureTime: CFTimeInterval = 0
    private var keyboardImageRenderer: UIGraphicsImageRenderer?
    private var keyboardImageRendererSize = CGSize.zero
    
    func setKeyboardImage() {
        guard
            savingPlayMovie,
            let keyboardWindow = Window_UIRemoteKeyboard,
            let keyboardRect
        else {
            return
        }

        let captureRect = keyboardWindow.convert(keyboardRect, from: nil)
            .intersection(keyboardWindow.bounds)

        guard !captureRect.isEmpty else { return }

        let currentTime = CACurrentMediaTime()
        guard currentTime - lastKeyboardCaptureTime >= keyboardCaptureInterval else {
            return
        }
        lastKeyboardCaptureTime = currentTime

        if keyboardImageRenderer == nil || keyboardImageRendererSize != captureRect.size {
            let format = UIGraphicsImageRendererFormat()
            // 録画用キーボード画像を最大2xで生成し、画質を保ちながら描画負荷を抑える。
            format.scale = min(UIScreen.main.scale, 2)
            format.opaque = false

            keyboardImageRenderer = UIGraphicsImageRenderer(
                size: captureRect.size,
                format: format
            )
            keyboardImageRendererSize = captureRect.size
        }

        guard let keyboardImageRenderer else { return }

        keyboardImageView.image = keyboardImageRenderer.image { context in
            context.cgContext.translateBy(
                x: -captureRect.minX,
                y: -captureRect.minY
            )
            keyboardWindow.layer.render(in: context.cgContext)
        }

        keyboardKeyView.subviews.forEach { $0.removeFromSuperview() }
    }
    
    func startRecording(callback :@escaping ()->Void) {
        // 既に録画中だと何もしない
        guard !RPScreenRecorder.shared().isRecording else { return }
        // 録画開始
        RPScreenRecorder.shared().startRecording { error in
            if error != nil {
                // print("recording failed")
                self.failedSavePlayMovie = true
            }
            callback()
        }
    }
    func canselRecording() {
        guard RPScreenRecorder.shared().isRecording else { return }
        RPScreenRecorder.shared().stopRecording(handler: nil)
    }
    
    @IBAction func practiceSeekbar_TouchDown(_ sender: UISlider) {
        practice_movieTimeSliding = true
        removeAutoPlayObserver()
        // Note
        // - 打ち済みNoteも復活させる(とりあえず見た目)
        for note in noteData.notes {
            if note.isFlickable && note.flicked {
                note.setFlickableFont()  // ジャッジ等はそのまま残す。
            }
        }
        // - コンボカウンタをゼロにする
        noteData.score.comboCounter = 0
        self.ComboAction()  // コンボ表示があれば消させる
    }
    @IBAction func practiceSeekbar_TouchUp(_ sender: UISlider) {
        practice_movieTimeSliding = false
        practice_waitingForFlickAfterMovieTimeSlide = true
        // print("practice_movieTimeSliding_afterFlick ",practice_waitingForFlickAfterMovieTimeSlide)
        if let duration = moviePlayerViewController?.player?.currentItem?.duration {
            let durationSeconds = CMTimeGetSeconds(duration)
            let time = min(durationSeconds * Double(sender.value), max(durationSeconds - 2.0, 0.0))
            if durationSeconds > 0.0 {
                sender.value = Float(time / durationSeconds)
            }
            moviePlayerViewController?.player?.seek(to:
                CMTime(seconds: time, preferredTimescale: Int32(NSEC_PER_SEC)),
                                                   toleranceBefore: kCMTimeZero,
                                                   toleranceAfter: kCMTimeZero
            )
            // Note
            for note in noteData.notes {
                if !note.isFlickable { continue }
                if note.flicked {
                    note.flickedTime = -1.0
                    note.flicked = false
                    //note.judge = Note.NORMAL
                    note.setFlickableFont()  // 押下のときもしているが一応
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
            resetTimelineCursors(at: time)
            configureAutoPlayObserver(from: time)
            // print("TouchUppp")
        }
    }
    @IBAction func practiceSeekbar_ValueChanged(_ sender: UISlider) {
//        practice_movieTimeSliding_value = sender.value
//        if let duration = moviePlayerViewController?.player?.currentItem?.duration {
//            movieCurrentTimeLabel.text = String.secondsToTimetag(seconds: (CMTimeGetSeconds(duration) * Double(sender.value)), noBrackets: true)
//        }
    }
    
    @IBAction func practiceRatebar(_ sender: UISlider) {
        let rate = Float(Int(round(sender.value * 10))) / 10
        setMovieRate(rate: rate)
    }
    func setMovieRate(rate:Float){
        practiceRatebar.value = rate
        if time3secMediaTime == nil,
           !isGameMenuPresented,
           moviePlayerViewController?.player?.rate != rate {
            moviePlayerViewController?.player?.rate = rate
        }
        practiceRateLabel.text = "× " + String(format:"%.01f",rate)
    }
    @IBAction func practiceAutoPlaySwitch(_ sender: UISwitch) {
        if sender.isOn {
            configureAutoPlayObserver()
        } else {
            removeAutoPlayObserver()
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
