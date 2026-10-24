//
//  EditorView.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2018/12/14.
//  Copyright © 2018年 i.MIZUSHIKI. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation

class EditorView: UIViewController, UITextViewDelegate, UIScrollViewDelegate {
    
    @IBOutlet var movieView: UIView!
    @IBOutlet var movieTimeSlider: UISlider!
    @IBOutlet var moviePlayButton: UIButton!
    @IBOutlet var movieRateSlider: VerticalSlider!
    @IBOutlet var movieRateSliderView: UIView!
    
    @IBOutlet var cursorPosTimeLabel: UILabel!
    @IBOutlet var movieCurrentTimeLabel: UILabel!
    @IBOutlet var movieDurationTimeLabel: UILabel!
    @IBOutlet var movieRateLabel: UILabel!
    
    @IBOutlet var scrollView: UIScrollView!
    
    
    @IBOutlet var setTimetagButton: UIButton!
    @IBOutlet var minusTimetagButton: UIButton!
    @IBOutlet var rewindButton: UIButton!
    @IBOutlet var forwardButton: UIButton!
    
    
    @IBOutlet var addWordsView: UIView!
    @IBOutlet var addWordsTextView: UITextView!
    @IBOutlet var addWordsTextView2: UITextView!
    
    @IBOutlet var notesSwitch: UISwitch!
    
    @IBOutlet var UndoButton: UIButton!
    @IBOutlet var RedoButton: UIButton!
    //編集データ
    var mySpoon = Spoons()
    var autoSaveMaeDate = Date()
    
    var timetagOffsetMs = UserData.sharedInstance.timetagOffsetMs
    var timetagRateFactor = UserData.sharedInstance.timetagRateFactor
    var playingNoteSelectionOffsetMs = UserData.sharedInstance.playingNoteSelectionOffsetMs
    
    //動画
    var cachedMovies:CachedMovies = CachedMovies.sharedInstance
    var moviePlayerViewController:AVPlayerViewController?
    private var periodicTimeObserver: Any?
    private weak var observedPlayer: AVPlayer?
    private var lastTextUpdateUptime: TimeInterval = 0
    //Indicator（ネット処理中 画面中央でくるくるさせる）
    private var activityIndicator:UIActivityIndicatorView!
    private var addWordsViewRestingY: CGFloat?
    private var keyboardOverlap: CGFloat = 0

    //遷移時に受け取り
    var selectMusic:musicData!
    var selectLevel:levelData!
    var password:String!
    var nidankaiModoru = false
    
    var movieTimeSliderOriginWidth:CGFloat = 0.0
    
    //Slider Drag中
    var movieTimeSliding = false
    
    // GameView用データ
    var practiceAutoPlay = false
    
    //UILabel サイズ、マージン
    let LabelSize:CGSize = CGSize(width: 24, height: 30)
    let LabelBoxSize:CGSize = CGSize(width: 24, height: 35)
    let MarginTop:CGFloat = 10.0
    let MarginLeft:CGFloat = 20.0
    let MarginRight:CGFloat = 20.0
    var MarginBottom:CGFloat = 670.0
    
    //保存データ
    let userData = UserData.sharedInstance
    var flgBackDelete = false
    var maeSpoonLabelXY:[Int:(Int,Int)] = [:]
    var timerBackDelete:Timer?
    var timerCnt = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // textFieldShouldReturnで閉じるように
        for subview in self.view.subviews{
            if let subview = subview as? UITextView {
                subview.delegate = self
            }
        }
        scrollView.delegate = self
        
        setTimetagButton.titleLabel!.textAlignment = .center
        //Indicatorを作成
        activityIndicator = Indicator(center: self.view.center).view
        self.view.addSubview(activityIndicator)
        
        movieTimeSliderOriginWidth = movieTimeSlider.frame.size.width
        movieTimeSlider.frame.size.width = 1
        
        scrollView.delegate = self
        MarginBottom = scrollView.frame.size.height
        
        //SE対策
        if UIScreen.main.nativeBounds.height <= 1136 {
            movieRateSliderView.center.x = movieView.frame.origin.x + movieView.frame.size.width
            
            rewindButton.center.x -= 15
            forwardButton.center.x += 15
        }
        
        // print(selectMusic)
        // print(selectLevel)
        
        //Movie呼び込み _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
        var ans:[String]=[]
        var smNum = ""
        if (selectMusic.movieURL.pregMatche(pattern: "watch/(.+)$", matches: &ans)){
            smNum = ans[1]
        }
        MovieAccess.init().StreamingUrlNicoAccess(smNum: smNum){ nicodougaURL in
            // print(nicodougaURL)
            //session.dataTas後のサブスレッド内でviewを処理させると表示関連が後回しになるので、メインスレッドでaddSubviewする。
            DispatchQueue.main.async {
                //UI処理はメインスレッドの必要あり
                guard let videoURL = URL(string: nicodougaURL) else { return }
                self.moviePlayerViewController = self.cachedMovies.access(url: videoURL, smNum: smNum)
                if let moviePlayerViewController = self.moviePlayerViewController {
                    moviePlayerViewController.player?.currentItem!.audioTimePitchAlgorithm = .spectral
                    if let player = moviePlayerViewController.player {
                        self.addPeriodicTimeObserver(to: player)
                    }
                    //  add
                    self.movieView.addSubview(moviePlayerViewController.view)
                    self.movieView.sendSubview(toBack: moviePlayerViewController.view)
                    //  動画再生
                    moviePlayerViewController.player?.seek(to: CMTimeMakeWithSeconds(0.0, Int32(NSEC_PER_SEC)) )
                    //self.moviePlayerViewController.player?.play()
                    //  動画Viewの位置
                    moviePlayerViewController.view.frame.origin = CGPoint(x: 0, y: 0)
                    moviePlayerViewController.view.frame.size = self.movieView.frame.size
                }
                
                // 動画が終了した時に呼ばれるnotificationを登録
                NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil, queue: nil){ notification in
                    //再生終了したとき
                    // print("終了")
                    self.playerStop()
                }

            }
        }
        
        //テキスト読み込み _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
        /*
         
         */
        if let maeSpoonString = userData.MySpoonSet[selectLevel.sqlID] {
            // 前回エラー等で編集中データが残っていたとき、復旧する。
            
            mySpoon = Spoons(timetagText: maeSpoonString)
            notesSwitch.isOn = mySpoon.spoons.contains { $0.note }
            //ラベル等の画面表示
            self.CreateScrollViewContents()
        }else{
            // 特に編集データが残っていない。サーバからダウンロードして編集データとする。
            
            //Indicator くるくる開始
            activityIndicator.startAnimating()
            
            //サーバから music,level,userName データを順次取得。
            ServerDataHandler().DownloadMusicDataAndUserNameData { (error) in
                if let error = error {
                    // print(error) //なんか失敗した。帰る。
                    DispatchQueue.main.async {
                        self.activityIndicator.stopAnimating()
                        let alert = UIAlertController(title:"NicoFlick データベース", message: "データ取得に失敗しました。", preferredStyle: UIAlertControllerStyle.alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { (_) in
                            self.dismiss(animated: true, completion: nil)
                        }))
                        self.present(alert, animated: true, completion: nil)
                    }
                    return
                }
                //
                ServerDataHandler().DownloadTimetag(level: self.selectLevel) { (error) in
                    if let error = error {
                        DispatchQueue.main.async {
                            self.activityIndicator.stopAnimating()
                            // print(error) //なんか失敗した。
                            self.dismiss(animated: true, completion: nil)
                            return
                        }
                    }
                    //  データ取得成功
                    let spoons = Spoons(timetagText: "\(self.selectLevel.noteData!)")
                    if spoons.atTag["BaseDataNo"] == nil {
                        // 「新しい難易度の追加」時に基とするレベルのNotesをまだ取得してなかった場合、@BaseDataNoのみ書かれて遅延取得するようにしている。
                        self.mySpoon = spoons
                        if self.mySpoon.atTag["NicoFlick"] == nil {
                            self.mySpoon.atTag["NicoFlick"] = "2"
                        }
                        if self.mySpoon.atTag["Description"] == nil {
                            self.mySpoon.atTag["Description"] = ""
                            
                            if !self.selectLevel.isEditing {
                                self.mySpoon.atTag["Description"] = self.selectLevel.description
                            }
                        }
                        if self.mySpoon.atTag["Level"] == nil {
                            self.mySpoon.atTag["Level"] = "\(self.selectLevel.level!)"
                        }
                        if self.mySpoon.atTag["Creator"] == nil {
                            self.mySpoon.atTag["Creator"] = "\(self.selectLevel.creator!)"
                        }
                        if self.mySpoon.atTag["Speed"] == nil {
                            self.mySpoon.atTag["Speed"] = "\(self.selectLevel.speed!)"
                        }
                        if self.mySpoon.atTag["Offset"] == nil {
                            self.mySpoon.atTag["Offset"] = "0"
                        }
                        if self.mySpoon.atTag["OffsetWhenPosted"] != nil {
                            self.mySpoon.atTag["Offset"] = self.mySpoon.atTag["OffsetWhenPosted"]
                            self.mySpoon.atTag["OffsetWhenPosted"] = nil
                        }
                        // ラベル等の画面表示
                        DispatchQueue.main.async {
                            self.activityIndicator.stopAnimating()
                            self.notesSwitch.isOn = self.mySpoon.spoons.contains { $0.note }
                            self.CreateScrollViewContents()
                        }
                    }else {
                        // @BaseDataNo: Notesの再取得。
                        let baseLevel = levelData()
                        baseLevel.sqlID = Int(spoons.atTag["BaseDataNo"]!)
                        baseLevel.noteData = ""
                        
                        ServerDataHandler().DownloadTimetag(level: baseLevel) { (error) in
                            if let error = error {
                                DispatchQueue.main.async {
                                    self.activityIndicator.stopAnimating()
                                    // print(error) //なんか失敗した。
                                    self.dismiss(animated: true, completion: nil)
                                    return
                                }
                            }
                            //  データ取得成功
                            self.mySpoon = Spoons(timetagText: "\(baseLevel.noteData!)")
                            self.mySpoon.atTag["NicoFlick"] = "2"
                            self.mySpoon.atTag["Description"] = ""
                            if !self.selectLevel.isEditing {
                                self.mySpoon.atTag["Description"] = self.selectLevel.description
                            }
                            self.mySpoon.atTag["Level"] = "\(self.selectLevel.level!)"
                            self.mySpoon.atTag["Creator"] = "\(self.selectLevel.creator!)"
                            self.mySpoon.atTag["Speed"] = "\(self.selectLevel.speed!)"
                            self.mySpoon.atTag["Offset"] = "0"
                            if self.mySpoon.atTag["OffsetWhenPosted"] != nil {
                                self.mySpoon.atTag["Offset"] = self.mySpoon.atTag["OffsetWhenPosted"]
                                self.mySpoon.atTag["OffsetWhenPosted"] = nil
                            }
                            // ラベル等の画面表示
                            DispatchQueue.main.async {
                                self.activityIndicator.stopAnimating()
                                self.notesSwitch.isOn = self.mySpoon.spoons.contains { $0.note }
                                self.CreateScrollViewContents()
                            }
                        }
                    }
                }
            }
        }
        
        if userData.lookedHowToEditor == false {
            // print("lhte-false")
            userData.lookedHowToEditor = true
            DispatchQueue.main.async { //？
                self.performSegue(withIdentifier: "toHowToEditor", sender: nil)
            }
        }
    }
    func CreateScrollViewContents() {
        // print("start")
        // print(Date())
        let scale = scrollView.zoomScale
        let offset = scrollView.contentOffset

        //for view in scrollView.subviews {
            //view.removeFromSuperview()
        //}
        
        scrollView.minimumZoomScale = scrollView.frame.size.width / (MarginLeft + LabelBoxSize.width * CGFloat(mySpoon.maxRetu) + MarginRight /*viewInScrollView.frame.size.width*/)
        MarginBottom = scrollView.frame.size.height / scrollView.minimumZoomScale
        
        if scrollView.viewWithTag(100) == nil {
            let viewInScrollView = UIView()
            viewInScrollView.tag = 100
            scrollView.addSubview(viewInScrollView)
        }
        let viewInScrollView:UIView = scrollView.viewWithTag(100)!
        viewInScrollView.frame = CGRect(x: 0, y: 0, width: MarginLeft + LabelBoxSize.width * CGFloat(mySpoon.maxRetu) + MarginRight, height: MarginTop + LabelBoxSize.height * CGFloat(mySpoon.maxGyo) + MarginBottom)
        
        
        // print(Date())
        //scrollView.zoomScale = 1.0
        scrollView.minimumZoomScale = scrollView.frame.size.width / viewInScrollView.frame.size.width

        //
        // print(mySpoon.spoons.count)
        if mySpoon.spoons.count <= 1 {
            scrollView.isHidden = true
            return
        }
        scrollView.isHidden = false
        
        // print(Date())
        scrollView.setZoomScale(scale, animated: false)
        scrollView.setContentOffset(offset, animated: false)
        
        // スクロール範囲
        scrollView.contentSize = viewInScrollView.frame.size
        
        // print(Date())
        //ラベルの作成
        for (index,spoon) in mySpoon.spoons.enumerated() {
            if let label = spoon.label {
                //もし既にラベルがあるなら前回のposと今回のposが異なるか確認。異なったら配置修正。
                guard let maePos = maeSpoonLabelXY[label.tag] else {
                    continue
                }
                if maePos.0 == mySpoon.posX(index: index) && maePos.1 == mySpoon.posY(index: index) {
                    //print("\(mySpoon.pos(index: index)) 一緒")
                }else {
                    //print("\(mySpoon.pos(index: index)) 違う")
                    let (x,y) = mySpoon.pos(index: index)
                    let point = CGPoint(x: MarginLeft + LabelBoxSize.width * CGFloat(x), y: MarginTop + LabelBoxSize.height * CGFloat(y))
                    label.frame = CGRect(origin: point, size: LabelSize)
                    if let bottomBorder = spoon.bottomBorder, let wakuBorder = spoon.wakuBorder {
                        bottomBorder.frame = CGRect(x: label.frame.origin.x,
                        y: label.frame.origin.y + label.frame.size.height - 2.0,
                        width: label.frame.size.width,
                        height: 2.0)
                        wakuBorder.frame = CGRect(x: label.frame.origin.x - 1,
                                          y: label.frame.origin.y,
                                          width: label.frame.size.width + 2,
                                          height: label.frame.size.height)
                        continue
                    }
                }
                continue
            }
            
            let (x,y) = mySpoon.pos(index: index)
            let point = CGPoint(x: MarginLeft + LabelBoxSize.width * CGFloat(x), y: MarginTop + LabelBoxSize.height * CGFloat(y))
            let label = UILabel(frame: CGRect(origin: point, size: LabelSize) )
            label.tag = mySpoon.getSerialIndex()
            label.text = spoon.word
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: 20)
            if spoon.note == false {
                label.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 0.8, alpha: 1.0)
            }else {
                label.backgroundColor = UIColor(red: 1.0, green: 0.8, blue: 0.8, alpha: 1.0)
            }
            label.isUserInteractionEnabled = true

            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.labelTap(sender:)))
            tapGesture.numberOfTapsRequired = 1
            let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(self.labelDoubleTap(sender:)))
            doubleTapGesture.numberOfTapsRequired = 2
            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.labelLongPress(sender:)))
            label.addGestureRecognizer(tapGesture)
            label.addGestureRecognizer(doubleTapGesture)
            label.addGestureRecognizer(longPressGesture)
            //tapGesture.require(toFail: doubleTapGesture)
            
            viewInScrollView.addSubview(label)
            spoon.label = label
            if maeSpoonLabelXY.count != 0 {
                //insertかbackDeleteのとき
                viewInScrollView.sendSubview(toBack: label)
            }
        }
        
        // print(Date())
        for (_,spoon) in mySpoon.spoons.enumerated() {
            if spoon.bottomBorder != nil && spoon.wakuBorder != nil {
                //viewInScrollView.bringSubview(toFront: bottomBorder)
                //viewInScrollView.bringSubview(toFront: wakuBorder)
                continue
            }
            
            if let label = spoon.label {
                //下線のviewを作成
                let bottomBorder = UIView(
                    frame: CGRect(x: label.frame.origin.x,
                                  y: label.frame.origin.y + label.frame.size.height - 2.0,
                                  width: label.frame.size.width,
                                  height: 2.0))
                bottomBorder.backgroundColor = UIColor.lightGray
                bottomBorder.isUserInteractionEnabled = false
                bottomBorder.isHidden = (!spoon.check)
                
                //枠のviewを作成
                let wakuBorder = UIView(
                    frame: CGRect(x: label.frame.origin.x - 1,
                                  y: label.frame.origin.y,
                                  width: label.frame.size.width + 2,
                                  height: label.frame.size.height))
                wakuBorder.backgroundColor = UIColor.clear
                wakuBorder.layer.borderColor = UIColor.red.cgColor
                wakuBorder.layer.borderWidth = 2
                wakuBorder.isUserInteractionEnabled = false
                wakuBorder.isHidden = (spoon.miriSec == -1)
                
                viewInScrollView.addSubview(bottomBorder)
                viewInScrollView.addSubview(wakuBorder)
                spoon.bottomBorder = bottomBorder
                spoon.wakuBorder = wakuBorder
            }
        }
        
        // print(Date())
        //カーソルの作成
        if mySpoon.cursorView == nil {
            let cursorView = UIView(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: LabelSize.width + 4, height: LabelSize.height)))
            cursorView.center = (mySpoon.spoons[0].label?.center)!
            cursorView.backgroundColor = UIColor.clear
            cursorView.alpha = 0.8
            cursorView.isUserInteractionEnabled = false
            
            let boxCursorView = UIView(frame: CGRect(origin: CGPoint(x: 4, y: 2), size: CGSize(width: LabelSize.width - 4, height: LabelSize.height - 4)))
            boxCursorView.backgroundColor = UIColor.clear
            boxCursorView.layer.borderColor = UIColor.green.cgColor
            boxCursorView.layer.borderWidth = 3
            boxCursorView.tag = 1
            boxCursorView.isHidden = !addWordsView.isHidden
            cursorView.addSubview(boxCursorView)
            
            let lineCursorView = UIView(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 5, height: LabelSize.height)))
            lineCursorView.backgroundColor = UIColor.green
            lineCursorView.tag = 2
            lineCursorView.isHidden = addWordsView.isHidden
            cursorView.addSubview(lineCursorView)
            
            viewInScrollView.addSubview(cursorView)
            mySpoon.cursorView = cursorView
        }
        // print(Date())
        //履歴ボタンの登録
        mySpoon.rirekiUndoButton = UndoButton
        mySpoon.rirekiRedoButton = RedoButton
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    deinit {
        removePeriodicTimeObserver()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.configureObserver() //キーボード処理
        if periodicTimeObserver == nil, let player = moviePlayerViewController?.player {
            addPeriodicTimeObserver(to: player)
        }
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.removeObserver() // Notificationを画面が消えるときに削除
        removePeriodicTimeObserver()
        if let player = moviePlayerViewController?.player {
            player.pause()
        }
    }
    
    
    @objc func labelTap(sender: UITapGestureRecognizer){
        if sender.state != .ended {
            return
        }
        // print("tap")
        mySpoon.setCursor(index: mySpoon.index(uiLabel: sender.view as! UILabel), scroll: true, scrollView: scrollView, animated: true)
        
        self.setText_CursorPosTimetagLabel()
        
        self.autoSave()
    }
    @objc func labelDoubleTap(sender: UITapGestureRecognizer){
        if sender.state != .ended {
            return
        }
        // print("double tap")
        /*
        mySpoon.setCursor(index: mySpoon.index(uiLabel: sender.view as! UILabel), scroll: true, scrollView: scrollView, animated: true)
        
        self.setText_CursorPosTimetagLabel()
         */
        
        let mirisec = mySpoon.spoons[mySpoon.cursorIndex].miriSec
        if mirisec != -1 {
            moviePlayerViewController?.player?.seek(to:
                CMTime(seconds: Double(mirisec)/1000, preferredTimescale: Int32(NSEC_PER_SEC)),
                                                   toleranceBefore: kCMTimeZero,
                                                   toleranceAfter: kCMTimeZero
            )
        }
    }
    
    @objc func labelLongPress(sender: UILongPressGestureRecognizer){
        if sender.state != .began {
            return
        }
        if addWordsView.isHidden == false {
            return
        }
        // print("longPress")
        mySpoon.setCursor(index: mySpoon.index(uiLabel: sender.view as! UILabel), scroll: true, scrollView: scrollView, animated: true)
        
        self.setText_CursorPosTimetagLabel()
        
        self.ShowAddWordsView1()
    }
    
    
    @IBAction func moviePlayButton(_ sender: UIButton) {
        // print("タップ")
        if moviePlayerViewController == nil {
            return
        }
        guard let playing = moviePlayerViewController?.player?.isPlaying else {
            return
        }
        if playing {
            self.playerStop()
        }else {
            self.playerPlay()
        }
        setText_CursorPosTimetagLabel()
        self.autoSave()
    }
    func playerPlay() {
        moviePlayerViewController?.player?.play()
        moviePlayerViewController?.player?.rate = movieRateSlider.value
        moviePlayButton.alpha = 0.02
        moviePlayButton.setTitle("", for: .normal)
        
        setTimetagButton.isHidden = false
        minusTimetagButton.isHidden = false
        UndoButton.isHidden = false
        RedoButton.isHidden = false
        rewindButton.isHidden = false
        forwardButton.isHidden = false
    }
    func playerStop() {
        moviePlayerViewController?.player?.pause()
        moviePlayButton.alpha = 0.5
        moviePlayButton.setTitle("▶", for: .normal)
        
        setTimetagButton.isHidden = true && !notesSwitch.isOn
        minusTimetagButton.isHidden = true && !notesSwitch.isOn
        UndoButton.isHidden = true && !notesSwitch.isOn
        RedoButton.isHidden = true && !notesSwitch.isOn
        rewindButton.isHidden = true
        forwardButton.isHidden = true
    }
    
    @IBAction func movieTimeSlider_TouchDown(_ sender: UISlider) {
        movieTimeSliding = true
    }
    
    @IBAction func movieTimeSlider_TouchUp(_ sender: UISlider) {
        movieTimeSliding = false
        if let duration = moviePlayerViewController?.player?.currentItem?.duration {
            moviePlayerViewController?.player?.seek(to:
                CMTime(seconds: CMTimeGetSeconds(duration) * Double(sender.value), preferredTimescale: Int32(NSEC_PER_SEC)),
                                                   toleranceBefore: kCMTimeZero,
                                                   toleranceAfter: kCMTimeZero
            )
        }
        self.autoSave()
    }
    @IBAction func movieTimeSlider_ValueChanged(_ sender: UISlider) {
        if let duration = moviePlayerViewController?.player?.currentItem?.duration {
            movieCurrentTimeLabel.text = String.secondsToTimetag(seconds: (CMTimeGetSeconds(duration) * Double(sender.value)), noBrackets: true)
        }
    }
    @IBAction func movieRateSlider(_ sender: UISlider) {
        let rate = Float(Int(round(sender.value * 10))) / 10
        setMovieRate(rate: rate)
    }
    func setMovieRate(rate:Float){
        movieRateSlider.value = rate
        if let playing =  moviePlayerViewController?.player?.isPlaying {
            if playing {
                moviePlayerViewController?.player?.rate = rate
            }
        }
        movieRateLabel.text = "再生速度：×" + String(format:"%.1f",rate)
    }
    @IBAction func addWordsButton(_ sender: Any) {
        if addWordsTextView.text == "" {
            return
        }
        //作成済みLabel再配置用pos保存
        for (index,spoon) in mySpoon.spoons.enumerated() {
            guard let label = spoon.label else { continue }
            maeSpoonLabelXY[label.tag] = mySpoon.pos(index: index)
        }
        let indexCursor = mySpoon.cursorIndex
        //Spoon追加
        let tempSpoons = Spoons(timetagText: addWordsTextView.text)
        mySpoon.insert(spoons: tempSpoons, index: mySpoon.cursorIndex)
        mySpoon.setRireki(index: mySpoon.cursorIndex, changedID: .Word, maeSpoon: nil, newSpoonS: tempSpoons)
        
        self.CreateScrollViewContents()
        maeSpoonLabelXY = [:] // maeSpoon削除
        mySpoon.setCursor(index: indexCursor)
        
        self.setText_CursorPosTimetagLabel()
        
        self.closeAddWordView()
    }
    @IBAction func lyricsBackDeleteButton_TouchDown(_ sender: UIButton) {
        if flgBackDelete == false {
            let alert = UIAlertController(title:"初回確認", message: "本文の歌詞を１文字削除します。", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (uiAlertAction) in
                self.flgBackDelete = true
                self.backDeleteLyrics()
            }))
            self.present(alert, animated: true, completion: nil)
            return
        }
        self.backDeleteLyrics()
        // print("touch down")
        timerCnt = 0
        let deleteFireTime = Date()
        timerBackDelete = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { (timer) in
            //print("timer = \(deleteFireTime.timeIntervalSinceNow)")
            self.timerCnt += 1
            if deleteFireTime.timeIntervalSinceNow > -1.0 {
                return
            }
            if deleteFireTime.timeIntervalSinceNow > -5.0 {
                if (self.timerCnt % 5) != 0 {
                    return
                }
            }
            self.backDeleteLyrics(animated: false)
        }
        timerBackDelete?.fire()
    }
    @IBAction func lyricsBackDeleteButton_TouchUp(_ sender: Any) {
        // print("touch up")
        if let timer = timerBackDelete {
            timer.invalidate()
        }
    }
    func backDeleteLyrics(animated:Bool = true) {
        if mySpoon.cursorIndex <= 0 {
            return
        }
        //作成済みLabel再配置用pos保存
        for (index,spoon) in mySpoon.spoons.enumerated() {
            guard let label = spoon.label else { continue }
            maeSpoonLabelXY[label.tag] = mySpoon.pos(index: index)
        }
        let indexCursor = mySpoon.cursorIndex
        let maeSpoon = mySpoon.spoons[mySpoon.cursorIndex-1].copy()
        // print("bd \(mySpoon.cursorIndex-1), \(maeSpoon.word)")
        if mySpoon.backDelete(cursorIndex: mySpoon.cursorIndex) == false {
            maeSpoonLabelXY = [:]
            return
        }
        mySpoon.setRireki(index: indexCursor, changedID: .Word, maeSpoon: maeSpoon, newSpoon: nil)
        self.CreateScrollViewContents()
        maeSpoonLabelXY = [:]
        mySpoon.setCursor(index: indexCursor - 1, scroll: true, scrollView: scrollView, animated: animated)
        
        self.setText_CursorPosTimetagLabel()
    }
    
    @IBAction func getLyricsButton(_ sender: Any) {
        
        for subview in addWordsView.subviews{
            if let subview = subview as? UITextView {
                //非表示にする。
                if(subview.isFirstResponder){
                    subview.resignFirstResponder()
                }
            }
        }
        let alert = UIAlertController(title:"歌詞の取得", message: "\n初音ミクWiki", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {
            (action: UIAlertAction!) in
            //print("はいをタップした時の処理")
            //Indicator くるくる開始
            self.activityIndicator.startAnimating()
            var urlStr = alert.textFields![0].text!
            if urlStr.pregMatche(pattern: "\\.html$") == false {
                urlStr += ".html"
            }
            let session = URLSession(configuration: URLSessionConfiguration.default)
            let url = URL(string:urlStr)!
            let req = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
            let task = session.dataTask(with: req){(data,responce,error) in
                DispatchQueue.main.async {
                    //  Indicator隠す
                    self.activityIndicator.stopAnimating()
                    if error != nil {
                        // print("getlyrics-error")//エラー。例えばオフラインとか
                        return
                    }
                    guard let data else { return }
                    let str = String(decoding: data, as: UTF8.self)
                    // print(str)
                    let t = self.extractLyrics_fromMikuWikiHtml(html: str)
                    self.addWordsTextView.text = t
                }
                
            }
            task.resume()
        }))
            
        alert.addAction((UIAlertAction(title: "キャンセル", style: UIAlertActionStyle.cancel, handler: nil)))
        //textfiledの追加
        alert.addTextField(configurationHandler: {(textField: UITextField!) in
            textField.text = "https://w.atwiki.jp/hmiku/pages/"
        })
        self.present(alert, animated: true, completion: nil)
    }
    @IBAction func addWordsKanjiToHiraganaButton(_ sender: Any) {
        addWordsTextView2.text = addWordsTextView.text
        addWordsTextView.text = addWordsTextView2.text.kanjiToHiragana()
        if addWordsTextView2.isHidden == false {
            return
        }
        self.ShowAddWordsView2()
    }
    
    @IBAction func closeAddWordViewButton(_ sender: Any) {
        self.closeAddWordView()
    }
    func closeAddWordView() {
        addWordsViewRestingY = nil
        keyboardOverlap = 0
        for subview in addWordsView.subviews{
            if let subview = subview as? UITextView {
                //非表示にする。
                if(subview.isFirstResponder){
                    subview.resignFirstResponder()
                }
            }
        }
        mySpoon.changeCursor(mode: .box)
        
        self.autoSave()

        UIView.animate(withDuration: 0.25, animations: {
            self.addWordsView.frame.origin.y = UIScreen.main.bounds.size.height
        }) { (bool) in
            self.addWordsView.isHidden = true
        }
    }
    @IBAction func showAddWordsViewButton(_ sender: Any) {
        if addWordsView.isHidden == false {
            return
        }
        self.ShowAddWordsView1()
    }
    func ShowAddWordsView1() -> Void {
        addWordsTextView.text = ""
        addWordsTextView2.text = ""
        addWordsView.frame.origin.y = UIScreen.main.bounds.size.height
        addWordsView.isHidden = false
        addWordsTextView2.isHidden = true
        
        mySpoon.changeCursor(mode: .line)
        //スクロールビューのスクロールをここでする。

        let restingY = view.bounds.height - view.safeAreaInsets.bottom - addWordsTextView2.frame.origin.y
        addWordsViewRestingY = restingY
        UIView.animate(withDuration: 0.5) {
            self.addWordsView.frame.origin.y = restingY - self.keyboardOverlap
        }
    }
    func ShowAddWordsView2() -> Void {
        addWordsTextView2.isHidden = false
        //全体上げスクロール
        
        let restingY = view.bounds.height - view.safeAreaInsets.bottom - addWordsView.frame.size.height
        addWordsViewRestingY = restingY
        UIView.animate(withDuration: 0.5) {
            self.addWordsView.frame.origin.y = restingY - self.keyboardOverlap
        }
    }
    
    
    private func currentPlaybackTime() -> CMTime? {
        return moviePlayerViewController?.player?.currentTime()
    }

    @IBAction func setTimetagButton_TouchDown(_ sender: UIButton) {
        if moviePlayerViewController == nil {
            return
        }
        if notesSwitch.isOn == false {
            // print("timetag")
            if let currentTime = currentPlaybackTime(), let rate = moviePlayerViewController?.player?.rate {
                //var mirisec = Int(CMTimeGetSeconds(currentTime) * 1000 - 40.0 * Double(rate - 0.5) / 0.5)
                var mirisec = Int( (CMTimeGetSeconds(currentTime) + timetagRateFactor * (1.0 - Double(rate))) * 1000 + Double(timetagOffsetMs) )
                if mirisec < 0 { mirisec = 0 }
                let maeSpoon = mySpoon.spoons[mySpoon.cursorIndex].copy()
                mySpoon.spoons[mySpoon.cursorIndex].setMirisec(mirisec: mirisec)
                mySpoon.setRireki(index: mySpoon.cursorIndex,
                                  changedID: .MiriSec,
                                  maeSpoon: maeSpoon,
                                  newSpoon: mySpoon.spoons[mySpoon.cursorIndex]
                )
                _ = mySpoon.setCursorNextCheck(scrollView: scrollView, animated: false)
                
                self.setText_CursorPosTimetagLabel()
            }
        }else {
            // print("note")
            guard let playing = moviePlayerViewController?.player?.isPlaying else {
                return
            }
            if playing {
                if let currentTime = currentPlaybackTime(), let rate = moviePlayerViewController?.player?.rate {
                    let judgeOffset = Int(self.mySpoon.atTag["Offset"] ?? "0")!
                    var mirisec = Int( (CMTimeGetSeconds(currentTime) + timetagRateFactor * (1.0 - Double(rate))) * 1000 + Double(timetagOffsetMs) ) - judgeOffset + playingNoteSelectionOffsetMs
                    if mirisec < 0 { mirisec = 0 }
                    let (retIndex, maeSpoon) = mySpoon.setNotes_NearTimePos(mirisec: mirisec)
                    if retIndex != nil && maeSpoon != nil {
                        mySpoon.setCursor(index: retIndex!, scroll: true, scrollView: scrollView, animated: false)
                        mySpoon.setRireki(index: mySpoon.cursorIndex,
                                          changedID: .Note,
                                          maeSpoon: maeSpoon!,
                                          newSpoon: mySpoon.spoons[mySpoon.cursorIndex]
                        )
                    }
                }
            }else {
                let maeSpoon = mySpoon.spoons[mySpoon.cursorIndex].copy()
                mySpoon.spoons[mySpoon.cursorIndex].note = true
                mySpoon.setRireki(index: mySpoon.cursorIndex,
                                  changedID: .Note,
                                  maeSpoon: maeSpoon,
                                  newSpoon: mySpoon.spoons[mySpoon.cursorIndex]
                )
            }
        }
    }
    
    @IBAction func minusTimetagButton_TouchDown(_ sender: UIButton) {
        // print("minus")
        if notesSwitch.isOn == false {
            // print("timetag")
            if mySpoon.setCursorPrevTimetaged(scrollView: scrollView, animated: false) {
                
                if let rate = moviePlayerViewController?.player?.rate {
                    var seconds = Double(mySpoon.spoons[mySpoon.cursorIndex].miriSec)/1000 - Double(3 * rate)
                    if seconds < 0 {
                        seconds = 0.0
                    }
                    moviePlayerViewController?.player?.seek(to:
                        CMTime(seconds: seconds, preferredTimescale: Int32(NSEC_PER_SEC)),
                                                           toleranceBefore: kCMTimeZero,
                                                           toleranceAfter: kCMTimeZero
                    )
                }
                let maeSpoon = mySpoon.spoons[mySpoon.cursorIndex].copy()
                mySpoon.spoons[mySpoon.cursorIndex].setMirisec(mirisec: -1)
                mySpoon.setRireki(index: mySpoon.cursorIndex,
                                  changedID: .MiriSec,
                                  maeSpoon: maeSpoon,
                                  newSpoon: mySpoon.spoons[mySpoon.cursorIndex]
                )
                self.setText_CursorPosTimetagLabel()
            }
        }else {
            // print("note")
            if mySpoon.setCursorPrevNoted(scrollView: scrollView, animated: false) {
                
                let maeSpoon = mySpoon.spoons[mySpoon.cursorIndex].copy()
                mySpoon.spoons[mySpoon.cursorIndex].note = false
                mySpoon.setRireki(index: mySpoon.cursorIndex,
                                  changedID: .Note,
                                  maeSpoon: maeSpoon,
                                  newSpoon: mySpoon.spoons[mySpoon.cursorIndex]
                )
                self.setText_CursorPosTimetagLabel()
            }
        }
        self.autoSave()
    }
    @IBAction func rewindButton(_ sender: UIButton) {
        _ = playerRewind()
    }
    func playerRewind() -> Double {
        var seconds = 0.0
        if let currentTime = moviePlayerViewController?.player?.currentTime(),
           let rate = moviePlayerViewController?.player?.rate {
            
            seconds = CMTimeGetSeconds(currentTime) - Double(3 * rate)
            if seconds < 0 {
                seconds = 0.0
            }
            moviePlayerViewController?.player?.seek(to:
                CMTime(seconds: seconds, preferredTimescale: Int32(NSEC_PER_SEC)),
                toleranceBefore: kCMTimeZero,
                toleranceAfter: kCMTimeZero
            )
        }
        self.autoSave()
        return seconds
    }
    @IBAction func forwardButton_TouchDown(_ sender: UIButton) {
        _ = playerForward()
    }
    func playerForward() -> Double {
        var seconds = 0.0
        if let currentTime = moviePlayerViewController?.player?.currentTime(),
            let rate = moviePlayerViewController?.player?.rate {
            seconds = CMTimeGetSeconds(currentTime) + Double(3 * rate)
            moviePlayerViewController?.player?.seek(to:
                CMTime(seconds: seconds, preferredTimescale: Int32(NSEC_PER_SEC)),
                                                   toleranceBefore: kCMTimeZero,
                                                   toleranceAfter: kCMTimeZero
            )
        }
        self.autoSave()
        return seconds
    }
    
    @IBAction func notesSwitch(_ sender: UISwitch) {
        if moviePlayerViewController == nil {
            return
        }
        guard let playing = moviePlayerViewController?.player?.isPlaying else {
            return
        }
        if playing {
            setTimetagButton.isHidden = false
            minusTimetagButton.isHidden = false
            UndoButton.isHidden = false
            RedoButton.isHidden = false
            rewindButton.isHidden = false
            forwardButton.isHidden = false
        }else {
            setTimetagButton.isHidden = true && !notesSwitch.isOn
            minusTimetagButton.isHidden = true && !notesSwitch.isOn
            UndoButton.isHidden = true && !notesSwitch.isOn
            RedoButton.isHidden = true && !notesSwitch.isOn
            rewindButton.isHidden = true
            forwardButton.isHidden = true
        }
        self.setText_CursorPosTimetagLabel()
    }
    
    @IBAction func UndoButton(_ sender: Any) {
        if !mySpoon.rirekiUndoAble {
            return
        }
        //.Wordのときだけ前後処理が必要。。。ぶさいく
        let changedID = mySpoon.getNextUndoChangedID
        if changedID == .Word {
            //作成済みLabel再配置用pos保存
            for (index,spoon) in mySpoon.spoons.enumerated() {
                guard let label = spoon.label else { continue }
                maeSpoonLabelXY[label.tag] = mySpoon.pos(index: index)
            }
        }
        // UNDO実行！
        let retIndex = mySpoon.rirekiUndo()
        
        if changedID == .Word {
            self.CreateScrollViewContents()
            maeSpoonLabelXY = [:] // maeSpoon削除
        }
        mySpoon.setCursor(index: retIndex, scroll: true, scrollView: scrollView, animated: true)
        self.setText_CursorPosTimetagLabel()
        
    }
    @IBAction func RedoButton(_ sender: Any) {
        if !mySpoon.rirekiRedoAble {
            return
        }
        //.Wordのときだけ前後処理が必要。。。ぶさいく
        let changedID = mySpoon.getNextRedoChangedID
        if changedID == .Word {
            //作成済みLabel再配置用pos保存
            for (index,spoon) in mySpoon.spoons.enumerated() {
                guard let label = spoon.label else { continue }
                maeSpoonLabelXY[label.tag] = mySpoon.pos(index: index)
            }
        }
        // REDO実行！
        let retIndex = mySpoon.rirekiRedo()
        
        if changedID == .Word {
            self.CreateScrollViewContents()
            maeSpoonLabelXY = [:] // maeSpoon削除
        }
        mySpoon.setCursor(index: retIndex, scroll: true, scrollView: scrollView, animated: true)
        self.setText_CursorPosTimetagLabel()
        
    }
    
    
    //AVPlayerの再生時刻に合わせたノート進行表示
    private func addPeriodicTimeObserver(to player: AVPlayer) {
        removePeriodicTimeObserver()

        let interval = CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600)
        observedPlayer = player
        periodicTimeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] currentTime in
            self?.updatePlayback(currentTime: currentTime)
        }
    }

    private func removePeriodicTimeObserver() {
        guard let observer = periodicTimeObserver else {
            return
        }
        observedPlayer?.removeTimeObserver(observer)
        periodicTimeObserver = nil
        observedPlayer = nil
    }

    private func updatePlayback(currentTime: CMTime) {
        guard let player = moviePlayerViewController?.player else {
            return
        }

        let uptime = ProcessInfo.processInfo.systemUptime
        let shouldUpdateText = uptime - lastTextUpdateUptime >= 1.0 / 15.0
        if shouldUpdateText {
            lastTextUpdateUptime = uptime
        }
        
        //ムービーロード状況
        if let loadedTime = player.currentItem?.loadedTimeRanges.asTimeRanges.first?.end,
            let duration = player.currentItem?.duration
        {
            //print("\(CMTimeGetSeconds(currentTime))|\(CMTimeGetSeconds(loadedTime))/\(CMTimeGetSeconds(duration))")
            
            if !movieTimeSliding {
                if movieTimeSlider.frame.size.width != movieTimeSliderOriginWidth {
                    // TimeSlider：ロードに応じて長さを伸ばす
                    movieTimeSlider.frame.size.width = movieTimeSliderOriginWidth * CGFloat(CMTimeGetSeconds(loadedTime)/CMTimeGetSeconds(duration))
                    movieTimeSlider.maximumValue = Float(CGFloat(CMTimeGetSeconds(loadedTime)/CMTimeGetSeconds(duration)))
                }

                // 再生位置スライダーの更新
                if CMTimeGetSeconds(currentTime) >= 0 {
                    let sliderValue = Float(CGFloat(CMTimeGetSeconds(currentTime)/CMTimeGetSeconds(duration)))
                    if movieTimeSlider.value != sliderValue {
                        movieTimeSlider.value = sliderValue
                    }
                }
                if shouldUpdateText {
                    if movieDurationTimeLabel.text == "/ 99:99:99" {
                        movieDurationTimeLabel.text = "/ " + String.secondsToTimetag(seconds: Double(CMTimeGetSeconds(duration)), noBrackets: true)
                    }
                    if CMTimeGetSeconds(currentTime) >= 0 {
                        let currentTimeText = String.secondsToTimetag(seconds: Double(CMTimeGetSeconds(currentTime)), noBrackets: true)
                        if movieCurrentTimeLabel.text != currentTimeText {
                            movieCurrentTimeLabel.text = currentTimeText
                        }
                    }
                }
            }
            if CMTimeGetSeconds(currentTime) >= 0 {
                updateTimelineProgress(currentTime: currentTime)
            }
        }
        if shouldUpdateText && notesSwitch.isOn && player.isPlaying {
            updateTimetagButtonDisplay(currentTime: currentTime)
        }
    }

    private func updateTimelineProgress(currentTime: CMTime) {
        mySpoon.pushCurrentTime(mirisec: Int(CMTimeGetSeconds(currentTime) * 1000))
    }

    private func updateTimetagButtonDisplay(currentTime: CMTime) {
        let judgeOffset = Int(self.mySpoon.atTag["Offset"] ?? "0")!
        var judgeOffsetText = ""
        if judgeOffset != 0 {
            judgeOffsetText = " \(-judgeOffset)ms"
            if judgeOffset < 0 {
                judgeOffsetText = " +\(-judgeOffset)ms"
            }
        }
        let currentTimeText = String.secondsToTimetag(
            seconds: CMTimeGetSeconds(currentTime),
            noBrackets: false
        )
        setText_setTimetagButton(timetag: currentTimeText + judgeOffsetText)
    }
    
    
    //キーボード関連_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    
    // Notificationを設定
    func configureObserver() {
        let notification = NotificationCenter.default
        notification.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        notification.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    // Notificationを削除
    func removeObserver() {
        let notification = NotificationCenter.default
        notification.removeObserver(self)
    }
    // 歌詞入力欄のキーボードが現れた時に、迫り出しViewだけをさらに上げる。
    @objc func keyboardWillShow(notification: Notification?) {
        guard !addWordsView.isHidden,
              addWordsTextView.isFirstResponder || addWordsTextView2.isFirstResponder,
              let restingY = addWordsViewRestingY,
              let keyboardScreenFrame = notification?.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue else {
            return
        }

        let keyboardFrame = view.convert(keyboardScreenFrame.cgRectValue, from: nil)
        keyboardOverlap = max(0, view.bounds.intersection(keyboardFrame).height - view.safeAreaInsets.bottom)
        animateWithKeyboard(notification: notification) {
            self.addWordsView.frame.origin.y = restingY - self.keyboardOverlap
        }
    }
    
    // キーボードが消えたときに、迫り出しViewを元の位置へ戻す。
    @objc func keyboardWillHide(notification: Notification?) {
        keyboardOverlap = 0
        guard !addWordsView.isHidden, let restingY = addWordsViewRestingY else {
            return
        }

        animateWithKeyboard(notification: notification) {
            self.addWordsView.frame.origin.y = restingY
        }
    }

    private func animateWithKeyboard(notification: Notification?, animations: @escaping () -> Void) {
        let userInfo = notification?.userInfo
        let duration = userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.25
        let curveValue = userInfo?[UIKeyboardAnimationCurveUserInfoKey] as? UInt ?? 0
        let options = UIViewAnimationOptions(rawValue: curveValue << 16)
        UIView.animate(withDuration: duration, delay: 0, options: options, animations: animations)
    }
    //MARK: キーボードが出ている状態で、キーボード以外をタップしたらキーボードを閉じる
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // print("touchesBegan")
        if addWordsView.isHidden {
            return
        }
        for subview in addWordsView.subviews{
            if let subview = subview as? UITextView {
                //非表示にする。
                if(subview.isFirstResponder){
                    subview.resignFirstResponder()
                }
            }
        }
        
    }
    
    func setText_CursorPosTimetagLabel() {
        if mySpoon.spoons.count <= mySpoon.cursorIndex {
            return
        }
        if mySpoon.spoons[mySpoon.cursorIndex].miriSec != -1 {
            cursorPosTimeLabel.text = String.secondsToTimetag(seconds: Double(mySpoon.spoons[mySpoon.cursorIndex].miriSec)/1000, noBrackets: false)
            
            self.setText_setTimetagButton(timetag: cursorPosTimeLabel.text!)
            
        }else {
            cursorPosTimeLabel.text = ""
            
            self.setText_setTimetagButton()
            
        }
    }
    func setText_setTimetagButton(timetag:String = "") {
        
        var addWord = ""
        if timetag != "" {
            addWord = "\n\(timetag)"
        }
        
        let title: String
        let backgroundColor: UIColor
        if notesSwitch.isOn {
            title = "フリック ノーツ" + addWord
            backgroundColor = UIColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0)
        }else {
            title = "Timetag"
            backgroundColor = UIColor(red: 0.0, green: 0.85, blue: 0.5, alpha: 1.0)
        }

        if setTimetagButton.title(for: .normal) != title {
            setTimetagButton.setTitle(title, for: .normal)
        }
        if setTimetagButton.backgroundColor?.isEqual(backgroundColor) != true {
            setTimetagButton.backgroundColor = backgroundColor
        }
        
    }
    
    
    func autoSave(forced:Bool = false) {
        if forced || autoSaveMaeDate.timeIntervalSinceNow < -10.0 {
            // userDataに現在編集中のデータを保存。 <- View閉じの際、DB送信成功後にnil消去する
            userData.MySpoonSet[selectLevel.sqlID] = mySpoon.export(mode: .UserData)
            autoSaveMaeDate = Date()
        }
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return scrollView.subviews[0]
    }
    
    func extractLyrics_fromMikuWikiHtml(html: String) -> String {
        guard var lyricsHTML = htmlSection(named: "歌詞", in: html) else {
            return ""
        }

        // 複数バージョンが掲載されている場合は、原曲を優先する。
        if let originalLyricsHTML = htmlSection(named: "原曲", in: lyricsHTML) {
            lyricsHTML = originalLyricsHTML
        }

        return plainLyrics(from: lyricsHTML)
    }

    /// 指定した見出しから、次の同じレベル以上の見出しまでを取り出す。
    /// h3「歌詞」の中にある h4「原曲」など、入れ子のセクションにも対応する。
    private func htmlSection(named sectionName: String, in html: String) -> String? {
        let options: NSRegularExpression.Options = [.caseInsensitive, .dotMatchesLineSeparators]
        guard let headingRegex = try? NSRegularExpression(
            pattern: #"<h([1-6])\b[^>]*>(.*?)</h\1\s*>"#,
            options: options
        ) else {
            return nil
        }

        let nsHTML = html as NSString
        let matches = headingRegex.matches(
            in: html,
            range: NSRange(location: 0, length: nsHTML.length)
        )

        for (index, match) in matches.enumerated() {
            guard match.numberOfRanges >= 3,
                  let level = Int(nsHTML.substring(with: match.range(at: 1))) else {
                continue
            }

            let headingHTML = nsHTML.substring(with: match.range(at: 2))
            let headingText = plainHeadingText(from: headingHTML)
            guard headingText == sectionName else {
                continue
            }

            let sectionStart = NSMaxRange(match.range)
            var sectionEnd = nsHTML.length

            for followingMatch in matches.dropFirst(index + 1) {
                guard let followingLevel = Int(nsHTML.substring(with: followingMatch.range(at: 1))) else {
                    continue
                }
                if followingLevel <= level {
                    sectionEnd = followingMatch.range.location
                    break
                }
            }

            guard sectionEnd >= sectionStart else {
                return nil
            }
            return nsHTML.substring(
                with: NSRange(location: sectionStart, length: sectionEnd - sectionStart)
            )
        }

        return nil
    }

    private func plainHeadingText(from html: String) -> String {
        let withoutTags = html.pregReplace(
            pattern: #"<[^>]+>"#,
            with: "",
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        )
        return withoutTags.htmlDecoded
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func plainLyrics(from html: String) -> String {
        let options: NSRegularExpression.Options = [.caseInsensitive, .dotMatchesLineSeparators]
        var lyrics = html

        lyrics = lyrics.pregReplace(pattern: #"<!--.*?-->"#, with: "", options: options)
        lyrics = lyrics.pregReplace(
            pattern: #"<(script|style|noscript)\b[^>]*>.*?</\1\s*>"#,
            with: "",
            options: options
        )

        // 表記ではなく読みを使う。rbタグがない新しいruby記法にも対応する。
        lyrics = lyrics.pregReplace(
            pattern: #"<ruby\b[^>]*>.*?<rt\b[^>]*>(.*?)</rt\s*>.*?</ruby\s*>"#,
            with: "$1",
            options: options
        )
        lyrics = lyrics.pregReplace(pattern: #"<rt\b[^>]*>.*?</rt\s*>"#, with: "", options: options)
        lyrics = lyrics.pregReplace(pattern: #"<rp\b[^>]*>.*?</rp\s*>"#, with: "", options: options)

        // HTMLデコードで改行が空白に畳み込まれないよう、意味のある改行を保護する。
        let lineBreakMarker = "\u{E000}"
        lyrics = lyrics.pregReplace(
            pattern: #"<br\s*/?\s*>"#,
            with: lineBreakMarker,
            options: options
        )
        lyrics = lyrics.pregReplace(
            pattern: #"</(?:p|div|li|blockquote|pre|h[1-6])\s*>"#,
            with: lineBreakMarker,
            options: options
        )
        lyrics = lyrics.pregReplace(pattern: #"<[^>]+>"#, with: "", options: options)

        // HTMLソースを整形するための改行は、歌詞の改行として扱わない。
        lyrics = lyrics.replacingOccurrences(of: "\r\n", with: "")
        lyrics = lyrics.replacingOccurrences(of: "\r", with: "")
        lyrics = lyrics.replacingOccurrences(of: "\n", with: "")
        lyrics = lyrics.htmlDecoded
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .replacingOccurrences(of: lineBreakMarker, with: "\n")

        let annotationWords = ["転載", "動画", "ブログ", "歌詞", "書き起こし", "抜粋", "PV"]
        var resultLines: [String] = []
        var previousLineWasEmpty = true
        var hasFoundLyricsLine = false

        for line in lyrics.components(separatedBy: "\n") {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            let isParenthesized = (trimmedLine.hasPrefix("(") && trimmedLine.hasSuffix(")"))
                || (trimmedLine.hasPrefix("（") && trimmedLine.hasSuffix("）"))
            let isLeadingAnnotation = !hasFoundLyricsLine
                && isParenthesized
                && annotationWords.contains {
                    trimmedLine.localizedCaseInsensitiveContains($0)
                }
            if isLeadingAnnotation {
                continue
            }

            if trimmedLine.isEmpty {
                if !previousLineWasEmpty {
                    resultLines.append("")
                }
                previousLineWasEmpty = true
            } else {
                resultLines.append(trimmedLine)
                previousLineWasEmpty = false
                hasFoundLyricsLine = true
            }
        }

        while resultLines.last?.isEmpty == true {
            resultLines.removeLast()
        }
        return resultLines.joined(separator: "\n")
    }
    
    @IBAction func returnToMe(segue: UIStoryboardSegue){
        //print(segue.identifier)
        if segue.identifier == "fromEditMenu" {
            // print("fromEditMenu")
            // print(nidankaiModoru)
            if nidankaiModoru {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                    self.performSegue(withIdentifier: "fromEditView", sender: nil)
                })
            }
        }
        
        // print("return to me")
        // print(timetagOffsetMs)
        // print(timetagRateFactor)
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // print("prepare")
        //print(segue.identifier as String!)
        //データ保存
        if segue.identifier == "fromEditView" {
            // Selectorへ戻すプレイヤーに編集時の再生位置を残さない
            if let player = moviePlayerViewController?.player {
                player.pause()
                player.seek(to: CMTime(seconds: 0, preferredTimescale: Int32(NSEC_PER_SEC)))
            }

            // userDataに現在編集中のデータを保存。 <- DB送信成功後にnil消去する
            self.autoSave() // userData.MySpoonSet[selectLevel.sqlID] = mySpoon.export(mode: .UserData)
            
            if nidankaiModoru {
                //登録完了して戻ってきたときだからデータを消す
                self.userData.MySpoonSet[self.selectLevel.sqlID] = nil
                
                if let vc = segue.destination as? Selector {
                    vc.SetMusicToCarousel()
                }
                return
            }
            
            if !selectLevel.isEditing {
                //歌詞全消しで編集中データを削除する。
                //（リセットされ、次回入ったときにデータベースの情報から再度始められる）
                if mySpoon.spoons.count <= 1 {
                    self.userData.MySpoonSet[self.selectLevel.sqlID] = nil
                }
                return
            }
            //selectorでEdit表示になってるやつは逐次DBにpre版を送信する。
            
            let notesString = mySpoon.export(mode: .PreNicoFlickDB)
            //ゲームデータを更新する。
            var level = selectLevel.level!
            if let lv = mySpoon.atTag["Level"] {
                level = Int(lv)!
            }
            var creator = selectLevel.creator!
            if let ca = mySpoon.atTag["Creator"]  {
                creator = ca
            }
            var speed = selectLevel.speed!
            if let sp = mySpoon.atTag["Speed"] {
                speed = Int(sp)!
            }
            // print("post note")
            ServerDataHandler().postLevelUpdate(
                sqlID: selectLevel.sqlID,
                nicoURL: selectMusic.movieURL,
                level: level,
                creator: creator,
                description: "【編集中:\(UserData.sharedInstance.UserID.prefix(8))】",
                speed: speed,
                notes: notesString,
                userPASS: password,
                callback: { (retStr, error) in
                    if error != nil {
                        // print("preDataPost error")
                        return
                    }
                    if retStr.pregMatche(pattern: "<!--EchoHtmlMes_OK-->"){
                        //送信成功したらuserDataを消す。
                        // print("preDataPost OK")
                        self.userData.MySpoonSet[self.selectLevel.sqlID] = nil
                        //取得データの更新
                        ServerDataHandler().DownloadMusicDataAndUserNameData { (error) in
                            if let error = error {
                                // print(error) //なんか失敗した。けど、とりあえずスルーして次へ。
                            }
                            if let vc = segue.destination as? Selector {
                                vc.SetMusicToCarousel()
                            }
                            return
                        }
                    }
                    // print(retStr) //何らかの理由で失敗。userData残る。
                }
            )
            
        }else if segue.identifier == "toEditorMenu" {
            // print("toEditorMenu")
            let editorMenuController:EditorMenu = segue.destination as! EditorMenu
            editorMenuController.editorViewController = self
            
        }else if segue.identifier == "toEditorGame" {
            // print("toEditorGame")
            self.autoSave()
            
            let editorGameController:EditorGame = segue.destination as! EditorGame
            let level_data = levelData()
            var level = selectLevel.level!
            if let lv = mySpoon.atTag["Level"] {
                level = Int(lv)!
            }
            if level == 100 {
                // テストプレイ時１つでもNote持ってるならFULLとして扱わない
                for spoon in mySpoon.spoons {
                    if spoon.note == true {
                        level = 1
                        break
                    }
                }
            }
            var speed = selectLevel.speed!
            if let sp = mySpoon.atTag["Speed"] {
                speed = Int(sp)!
            }
            level_data.level = level
            level_data.speed = speed
            level_data.noteData = mySpoon.export(mode: .UserData)
            editorGameController.selectLevel = level_data
            editorGameController.editorViewController = self
            
            if moviePlayerViewController == nil {
                return
            }
            guard let playing = moviePlayerViewController?.player?.isPlaying else {
                return
            }
            if playing == false {
                self.playerPlay()
            }
        }
    }
    //遷移の許可
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        
        if identifier == "toHowToNotes" {
            if userData.lookedHowToNotes == true {
                return false
            }
            userData.lookedHowToNotes = true
        }
        return true
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

