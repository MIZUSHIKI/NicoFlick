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
    
    
    //編集データ
    var mySpoon = Spoons()
    var autoSaveMaeDate = Date()
    
    //動画
    var cachedMovies:CachedMovies = CachedMovies.sharedInstance
    var moviePlayerViewController:AVPlayerViewController!
    var timer:Timer!
    //Indicator（ネット処理中 画面中央でくるくるさせる）
    private var activityIndicator:UIActivityIndicatorView!

    //遷移時に受け取り
    var selectMusic:musicData!
    var selectLevel:levelData!
    var password:String!
    var nidankaiModoru = false
    
    var movieTimeSliderOriginWidth:CGFloat = 0.0
    
    //Slider Drag中
    var movieTimeSliding = false
    
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
        
        print(selectMusic)
        print(selectLevel)
        
        //タイマー発動 _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
        timer = Timer.scheduledTimer(timeInterval: 0.015, target: self, selector: #selector(self.update), userInfo: nil, repeats: true)
        
        RunLoop.current.add(timer, forMode: .commonModes)

        timer.fire()
        
        //Movie呼び込み _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
        var ans:[String]=[]
        var smNum = ""
        if (selectMusic.movieURL.pregMatche(pattern: "watch/(.+)$", matches: &ans)){
            smNum = ans[1]
        }
        MovieAccess.init().StreamingUrlNicoAccess(smNum: smNum){ nicodougaURL in
            print(nicodougaURL)
            //session.dataTas後のサブスレッド内でviewを処理させると表示関連が後回しになるので、メインスレッドでaddSubviewする。
            DispatchQueue.main.async {
                //UI処理はメインスレッドの必要あり
                self.moviePlayerViewController = self.cachedMovies.access(url: URL(string: nicodougaURL)!)
                self.moviePlayerViewController.player?.currentItem!.audioTimePitchAlgorithm = .spectral
                //  add
                self.movieView.addSubview(self.moviePlayerViewController.view)
                self.movieView.sendSubview(toBack: self.moviePlayerViewController.view)
                //  動画再生
                self.moviePlayerViewController.player?.seek(to: CMTimeMakeWithSeconds(0.0, Int32(NSEC_PER_SEC)) )
                //self.moviePlayerViewController.player?.play()
                //  動画Viewの位置
                self.moviePlayerViewController.view.frame.origin = CGPoint(x: 0, y: 0)
                self.moviePlayerViewController.view.frame.size = self.movieView.frame.size
                
                // 動画が終了した時に呼ばれるnotificationを登録
                NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil, queue: nil){ notification in
                    //再生終了したとき
                    print("終了")
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
            //ラベル等の画面表示
            self.CreateScrollViewContents()
        }else{
            // 特に編集データが残っていない。サーバからダウンロードして編集データとする。
            
            //Indicator くるくる開始
            activityIndicator.startAnimating()
            
            //サーバから music,level,userName データを順次取得。
            ServerDataHandler().DownloadMusicDataAndUserNameData { (error) in
                if let error = error {
                    print(error) //なんか失敗した。帰る。
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
                    DispatchQueue.main.async {
                        self.activityIndicator.stopAnimating()
                        if let error = error {
                            print(error) //なんか失敗した。
                            self.dismiss(animated: true, completion: nil)
                            return
                        }
                        //  データ取得成功
                        self.mySpoon = Spoons(timetagText: "\(self.selectLevel.noteData!)")
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
                        // ラベル等の画面表示
                        self.CreateScrollViewContents()
                    }
                }
            }
        }
        
        if userData.lookedHowToEditor == false {
            self.performSegue(withIdentifier: "toHowToEditor", sender: nil)
            userData.lookedHowToEditor = true
        }
    }
    func CreateScrollViewContents() {
        print("start")
        print(Date())
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
        
        
        print(Date())
        //scrollView.zoomScale = 1.0
        scrollView.minimumZoomScale = scrollView.frame.size.width / viewInScrollView.frame.size.width

        //
        print(mySpoon.spoons.count)
        if mySpoon.spoons.count <= 1 {
            scrollView.isHidden = true
            return
        }
        scrollView.isHidden = false
        
        print(Date())
        scrollView.setZoomScale(scale, animated: false)
        scrollView.setContentOffset(offset, animated: false)
        
        // スクロール範囲
        scrollView.contentSize = viewInScrollView.frame.size
        
        print(Date())
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
        
        print(Date())
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
        
        print(Date())
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
        print(Date())
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.configureObserver() //キーボード処理
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.removeObserver() // Notificationを画面が消えるときに削除
        if let player = moviePlayerViewController.player {
            player.pause()
        }
    }
    
    
    @objc func labelTap(sender: UITapGestureRecognizer){
        if sender.state != .ended {
            return
        }
        print("tap")
        mySpoon.setCursor(index: mySpoon.index(uiLabel: sender.view as! UILabel), scroll: true, scrollView: scrollView, animated: true)
        
        self.setText_CursorPosTimetagLabel()
        
        self.autoSave()
    }
    @objc func labelDoubleTap(sender: UITapGestureRecognizer){
        if sender.state != .ended {
            return
        }
        print("double tap")
        /*
        mySpoon.setCursor(index: mySpoon.index(uiLabel: sender.view as! UILabel), scroll: true, scrollView: scrollView, animated: true)
        
        self.setText_CursorPosTimetagLabel()
         */
        
        let mirisec = mySpoon.spoons[mySpoon.cursorIndex].miriSec
        if mirisec != -1 {
            moviePlayerViewController.player?.seek(to:
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
        print("longPress")
        mySpoon.setCursor(index: mySpoon.index(uiLabel: sender.view as! UILabel), scroll: true, scrollView: scrollView, animated: true)
        
        self.setText_CursorPosTimetagLabel()
        
        self.ShowAddWordsView1()
    }
    
    
    @IBAction func moviePlayButton(_ sender: UIButton) {
        print("タップ")
        if moviePlayerViewController == nil {
            return
        }
        guard let playing = moviePlayerViewController.player?.isPlaying else {
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
        self.moviePlayerViewController.player?.play()
        self.moviePlayerViewController.player?.rate = movieRateSlider.value
        moviePlayButton.alpha = 0.02
        moviePlayButton.setTitle("", for: .normal)
        
        setTimetagButton.isHidden = false
        minusTimetagButton.isHidden = false
        rewindButton.isHidden = false
        forwardButton.isHidden = false
    }
    func playerStop() {
        self.moviePlayerViewController.player?.pause()
        moviePlayButton.alpha = 0.5
        moviePlayButton.setTitle("▶", for: .normal)
        
        setTimetagButton.isHidden = true && !notesSwitch.isOn
        minusTimetagButton.isHidden = true && !notesSwitch.isOn
        rewindButton.isHidden = true
        forwardButton.isHidden = true
    }
    
    @IBAction func movieTimeSlider_TouchDown(_ sender: UISlider) {
        movieTimeSliding = true
    }
    
    @IBAction func movieTimeSlider_TouchUp(_ sender: UISlider) {
        movieTimeSliding = false
        if let duration = moviePlayerViewController.player?.currentItem?.duration {
            moviePlayerViewController.player?.seek(to:
                CMTime(seconds: CMTimeGetSeconds(duration) * Double(sender.value), preferredTimescale: Int32(NSEC_PER_SEC)),
                                                   toleranceBefore: kCMTimeZero,
                                                   toleranceAfter: kCMTimeZero
            )
        }
        self.autoSave()
    }
    @IBAction func movieTimeSlider_ValueChanged(_ sender: UISlider) {
        if let duration = moviePlayerViewController.player?.currentItem?.duration {
            movieCurrentTimeLabel.text = String.secondsToTimetag(seconds: (CMTimeGetSeconds(duration) * Double(sender.value)), noBrackets: true)
        }
    }
    @IBAction func movieRateSlider(_ sender: UISlider) {
        let rate = Float(Int(round(sender.value * 10))) / 10
        sender.value = rate
        if let playing =  moviePlayerViewController.player?.isPlaying {
            if playing {
                moviePlayerViewController.player?.rate = rate
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
        print("touch down")
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
        print("touch up")
        if let timer = timerBackDelete {
            timer.invalidate()
        }
    }
    func backDeleteLyrics(animated:Bool = true) {
        //作成済みLabel再配置用pos保存
        for (index,spoon) in mySpoon.spoons.enumerated() {
            guard let label = spoon.label else { continue }
            maeSpoonLabelXY[label.tag] = mySpoon.pos(index: index)
        }
        let indexCursor = mySpoon.cursorIndex
        if mySpoon.backDelete(cursorIndex: mySpoon.cursorIndex) == false {
            maeSpoonLabelXY = [:]
            return
        }
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
            let task = session.dataTask(with: url){(data,responce,error) in
                DispatchQueue.main.async {
                    //  Indicator隠す
                    self.activityIndicator.stopAnimating()
                    if error != nil {
                        print("getlyrics-error")//エラー。例えばオフラインとか
                        return
                    }
                    let str:String = String(data: data!, encoding: String.Encoding.utf8)!
                    print(str)
                    let t = self.extractLyrics_fromMikuWikiHtml(html: str)
                    self.addWordsTextView.text = t
                }
                
            }
            task.resume()
        }))
            
        alert.addAction((UIAlertAction(title: "キャンセル", style: UIAlertActionStyle.cancel, handler: nil)))
        //textfiledの追加
        alert.addTextField(configurationHandler: {(textField: UITextField!) in
            textField.text = "https://www5.atwiki.jp/hmiku/pages/"
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

        UIView.animate(withDuration: 0.5) {
            self.addWordsView.frame.origin.y = UIScreen.main.bounds.size.height - self.view.safeAreaInsets.bottom - self.addWordsTextView2.frame.origin.y
        }
    }
    func ShowAddWordsView2() -> Void {
        addWordsTextView2.isHidden = false
        //全体上げスクロール
        
        UIView.animate(withDuration: 0.5) {
            self.addWordsView.frame.origin.y = UIScreen.main.bounds.size.height - self.view.safeAreaInsets.bottom - self.addWordsView.frame.size.height
        }
    }
    
    
    @IBAction func setTimetagButton_TouchDown(_ sender: UIButton) {
        if moviePlayerViewController == nil {
            return
        }
        if notesSwitch.isOn == false {
            print("timetag")
            if let currentTime = moviePlayerViewController.player?.currentTime(),
                let rate = moviePlayerViewController.player?.rate {
                var mirisec = Int(CMTimeGetSeconds(currentTime) * 1000 - 40.0 * Double(rate - 0.5) / 0.5)
                if mirisec < 0 { mirisec = 0 }
                mySpoon.spoons[mySpoon.cursorIndex].setMirisec(mirisec: mirisec)
                _ = mySpoon.setCursorNextCheck(scrollView: scrollView, animated: false)
                
                self.setText_CursorPosTimetagLabel()
            }
        }else {
            print("note")
            guard let playing = moviePlayerViewController.player?.isPlaying else {
                return
            }
            if playing {
                if let currentTime = moviePlayerViewController.player?.currentTime() {
                    if let index = mySpoon.setNotes_NearTimePos(mirisec: Int(CMTimeGetSeconds(currentTime) * 1000 )) {
                        mySpoon.setCursor(index: index, scroll: true, scrollView: scrollView, animated: false)
                    }
                }
            }else {
                mySpoon.spoons[mySpoon.cursorIndex].note = true
            }
        }
    }
    
    @IBAction func minusTimetagButton_TouchDown(_ sender: UIButton) {
        print("minus")
        if notesSwitch.isOn == false {
            print("timetag")
            if mySpoon.setCursorPrevTimetaged(scrollView: scrollView, animated: false) {
                
                if let rate = moviePlayerViewController.player?.rate {
                    var seconds = Double(mySpoon.spoons[mySpoon.cursorIndex].miriSec)/1000 - Double(3 * rate)
                    if seconds < 0 {
                        seconds = 0.0
                    }
                    moviePlayerViewController.player?.seek(to:
                        CMTime(seconds: seconds, preferredTimescale: Int32(NSEC_PER_SEC)),
                                                           toleranceBefore: kCMTimeZero,
                                                           toleranceAfter: kCMTimeZero
                    )
                }
                mySpoon.spoons[mySpoon.cursorIndex].setMirisec(mirisec: -1)
                self.setText_CursorPosTimetagLabel()
            }
        }else {
            print("note")
            if mySpoon.setCursorPrevNoted(scrollView: scrollView, animated: false) {
                
                mySpoon.spoons[mySpoon.cursorIndex].note = false
                self.setText_CursorPosTimetagLabel()
            }
        }
        self.autoSave()
    }
    @IBAction func rewindButton(_ sender: UIButton) {
        if let currentTime = moviePlayerViewController.player?.currentTime(),
           let rate = moviePlayerViewController.player?.rate {
            
            var seconds = CMTimeGetSeconds(currentTime) - Double(3 * rate)
            if seconds < 0 {
                seconds = 0.0
            }
            moviePlayerViewController.player?.seek(to:
                CMTime(seconds: seconds, preferredTimescale: Int32(NSEC_PER_SEC)),
                toleranceBefore: kCMTimeZero,
                toleranceAfter: kCMTimeZero
            )
        }
        self.autoSave()
    }
    @IBAction func forwardButton_TouchDown(_ sender: UIButton) {
        if let currentTime = moviePlayerViewController.player?.currentTime(),
            let rate = moviePlayerViewController.player?.rate {
            moviePlayerViewController.player?.seek(to:
                CMTime(seconds: CMTimeGetSeconds(currentTime) + Double(3 * rate), preferredTimescale: Int32(NSEC_PER_SEC)),
                                                   toleranceBefore: kCMTimeZero,
                                                   toleranceAfter: kCMTimeZero
            )
        }
        self.autoSave()
    }
    
    @IBAction func notesSwitch(_ sender: UISwitch) {
        if moviePlayerViewController == nil {
            return
        }
        guard let playing = moviePlayerViewController.player?.isPlaying else {
            return
        }
        if playing {
            setTimetagButton.isHidden = false
            minusTimetagButton.isHidden = false
            rewindButton.isHidden = false
            forwardButton.isHidden = false
        }else {
            setTimetagButton.isHidden = true && !notesSwitch.isOn
            minusTimetagButton.isHidden = true && !notesSwitch.isOn
            rewindButton.isHidden = true
            forwardButton.isHidden = true
        }
        self.setText_CursorPosTimetagLabel()
    }
    
    
    //タイマー（ノート進行表示） _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    @objc func update(tm: Timer) {
        guard let controller = moviePlayerViewController else {
            return
        }
        guard let player = moviePlayerViewController.player else {
            return
        }
        
        //ムービーロード状況
        if let loadedTime = player.currentItem?.loadedTimeRanges.asTimeRanges.first?.end,
            let duration = player.currentItem?.duration,
            let currentTime = controller.player?.currentTime()
        {
            //print("\(CMTimeGetSeconds(currentTime))|\(CMTimeGetSeconds(loadedTime))/\(CMTimeGetSeconds(duration))")
            
            if !movieTimeSliding {
                if  movieTimeSlider.frame.size.width != movieTimeSliderOriginWidth {
                    // TimeSlider：ロードに応じて長さを伸ばす
                    movieTimeSlider.frame.size.width = movieTimeSliderOriginWidth * CGFloat(CMTimeGetSeconds(loadedTime)/CMTimeGetSeconds(duration))
                    movieTimeSlider.maximumValue = Float(CGFloat(CMTimeGetSeconds(loadedTime)/CMTimeGetSeconds(duration)))
                }
                if movieDurationTimeLabel.text == "/ 99:99:99" {
                    movieDurationTimeLabel.text = "/ " + String.secondsToTimetag(seconds: Double(CMTimeGetSeconds(duration)), noBrackets: true)
                }
                
                // 再生時間：スライダーとラベルの更新
                if CMTimeGetSeconds(currentTime) >= 0 {
                    movieTimeSlider.value = Float(CGFloat(CMTimeGetSeconds(currentTime)/CMTimeGetSeconds(duration)))
                    movieCurrentTimeLabel.text = String.secondsToTimetag(seconds: Double(CMTimeGetSeconds(currentTime)), noBrackets: true)
                }
            }
            if CMTimeGetSeconds(currentTime) >= 0 {
                mySpoon.pushCurrentTime(mirisec: Int(Double(CMTimeGetSeconds(currentTime))*1000))
            }
        }
        //let time = CMTimeGetSeconds(currentTime!)
        if notesSwitch.isOn && player.isPlaying {
            if let currentTime = controller.player?.currentTime() {
                
                self.setText_setTimetagButton(timetag: String.secondsToTimetag(seconds: CMTimeGetSeconds(currentTime), noBrackets: false))
                
            }
        }
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
    // キーボードが現れた時に、画面全体をずらす。
    @objc func keyboardWillShow(notification: Notification?) {
        let rect = (notification?.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue
        for subview in addWordsView.subviews{
            if let subview = subview as? UITextView {
                if(subview.isFirstResponder){
                    if (subview.superview?.frame.origin.y)! + subview.frame.origin.y + subview.frame.size.height > (rect?.origin.y)! - (rect?.size.height)! {
                        // ずらし処理
                        let duration: TimeInterval? = notification?.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? Double
                        UIView.animate(withDuration: duration!, animations: { () in
                            let transform = CGAffineTransform(translationX: 0, y: -(rect?.size.height)!)
                            self.view.transform = transform
                            
                        })
                    }
                    break
                }
            }
        }
    }
    
    // キーボードが消えたときに、画面を戻す
    @objc func keyboardWillHide(notification: Notification?) {
        
        let duration: TimeInterval? = notification?.userInfo?[UIKeyboardAnimationCurveUserInfoKey] as? Double
        UIView.animate(withDuration: duration!, animations: { () in
            
            self.view.transform = CGAffineTransform.identity
        })
    }
    //MARK: キーボードが出ている状態で、キーボード以外をタップしたらキーボードを閉じる
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("touchesBegan")
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
        
        if notesSwitch.isOn {
            setTimetagButton.setTitle("フリック ノーツ" + addWord, for: .normal)
            setTimetagButton.backgroundColor = UIColor(red: 0.0, green: 0.75, blue: 0.3, alpha: 1.0)
        }else {
            setTimetagButton.setTitle("Timetag", for: .normal)
            setTimetagButton.backgroundColor = UIColor(red: 0.0, green: 0.85, blue: 0.5, alpha: 1.0)
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
    
    func extractLyrics_fromMikuWikiHtml( html : String ) -> String {
        let h3_h3 = html.pregMatche_firstString(pattern:"<h3 id=\"id_\\w+\">歌詞</h3>(.*?)<h3")
        let h3_h4 = html.pregMatche_firstString(pattern:"<h3 id=\"id_\\w+\">歌詞</h3>(.*?)<h4")
        let h3_table = html.pregMatche_firstString(pattern:"<h3 id=\"id_\\w+\">歌詞</h3>(.*?)<table")
        
        // 歌詞を取り出す
        var lyrics = h3_h3
        if h3_h4 != "" && lyrics.count > h3_h4.count {
            lyrics = h3_h4
        }
        if h3_table != "" && lyrics.count > h3_table.count {
            lyrics = h3_table
        }
        
        //転載注釈を外す
        // ( )
        var kakko = lyrics.pregMatche_firstString(pattern: "(\\(.*?\\))") // if let 使えたんだかどうか
        if kakko != "" {
            if(kakko.pregMatche(pattern: "転載")
                || kakko.pregMatche(pattern: "動画")
                || kakko.pregMatche(pattern: "ブログ")
                || kakko.pregMatche(pattern: "歌詞")
                || kakko.pregMatche(pattern: "書き起こし")
                || kakko.pregMatche(pattern: "抜粋")
                || kakko.pregMatche(pattern: "PV")
            ){
                lyrics = lyrics.pregReplace(pattern: kakko, with: "")
            }
        }else {
            // （ ）
            kakko = lyrics.pregMatche_firstString(pattern: "(（.*?）)") // if let 使えたんだかどうか
            if kakko != "" {
                if(kakko.pregMatche(pattern: "転載")
                    || kakko.pregMatche(pattern: "動画")
                    || kakko.pregMatche(pattern: "ブログ")
                    || kakko.pregMatche(pattern: "歌詞")
                    || kakko.pregMatche(pattern: "書き起こし")
                    || kakko.pregMatche(pattern: "抜粋")
                    || kakko.pregMatche(pattern: "PV")
                ){
                    lyrics = lyrics.pregReplace(pattern: kakko, with: "")
                }
            }
        }
        
        // ルビを取り出し、歌詞本体にする
        lyrics = lyrics.pregReplace(pattern: "<ruby>.*?<rb>.*?</rb>.*?<rt>(.*?)</rt>.*?</ruby>", with: "$1")
        
        //HTMLテキストのdiv,改行,ルビ等を消す
        //\n\n</div>は改行とする
        lyrics = lyrics.pregReplace(pattern: "\n\n</div>", with: "<br />")
        lyrics = lyrics.pregReplace(pattern: "<div>", with: "")
        lyrics = lyrics.pregReplace(pattern: "</div>", with: "")
        lyrics = lyrics.pregReplace(pattern: "\r|(\r?\n)", with: "")
        lyrics = lyrics.pregReplace(pattern: "<rt>.*?</rt>", with: "")
        lyrics = lyrics.pregReplace(pattern: "<rp>.*?</rp>", with: "")
        lyrics = lyrics.pregReplace(pattern: "<rb>", with: "")
        lyrics = lyrics.pregReplace(pattern: "</rb>", with: "")
        lyrics = lyrics.pregReplace(pattern: "<ruby>", with: "")
        lyrics = lyrics.pregReplace(pattern: "</ruby>", with: "")
        lyrics = lyrics.pregReplace(pattern: "<span.*?>", with: "")
        lyrics = lyrics.pregReplace(pattern: "</span>", with: "")
        lyrics = lyrics.pregReplace(pattern: "<!\\-\\-.*?\\-\\->", with: "")
        lyrics = lyrics.pregReplace(pattern: "<a .*?>", with: "")
        lyrics = lyrics.pregReplace(pattern: "</a>", with: "")
        
        lyrics = lyrics.pregReplace(pattern: "<p>", with: "")
        lyrics = lyrics.pregReplace(pattern: "</p>", with: "")
        lyrics = lyrics.pregReplace(pattern: "<font .*?>", with: "")
        lyrics = lyrics.pregReplace(pattern: "</font>", with: "")
        lyrics = lyrics.pregReplace(pattern: "<big>", with: "")
        lyrics = lyrics.pregReplace(pattern: "</big>", with: "")
        lyrics = lyrics.pregReplace(pattern: "<small>", with: "")
        lyrics = lyrics.pregReplace(pattern: "</small>", with: "")
        lyrics = lyrics.pregReplace(pattern: "<b>", with: "")
        lyrics = lyrics.pregReplace(pattern: "</b>", with: "")
        lyrics = lyrics.pregReplace(pattern: "<i>", with: "")
        lyrics = lyrics.pregReplace(pattern: "</i>", with: "")
        lyrics = lyrics.pregReplace(pattern: "<s>", with: "")
        lyrics = lyrics.pregReplace(pattern: "</s>", with: "")
        lyrics = lyrics.pregReplace(pattern: "<strike>", with: "")
        lyrics = lyrics.pregReplace(pattern: "</strike>", with: "")
        lyrics = lyrics.pregReplace(pattern: "<u>", with: "")
        lyrics = lyrics.pregReplace(pattern: "</u>", with: "")
        lyrics = lyrics.pregReplace(pattern: "<tt>", with: "")
        lyrics = lyrics.pregReplace(pattern: "</tt>", with: "")
        lyrics = lyrics.pregReplace(pattern: "<em>", with: "")
        lyrics = lyrics.pregReplace(pattern: "</em>", with: "")
        lyrics = lyrics.pregReplace(pattern: "<strong>", with: "")
        lyrics = lyrics.pregReplace(pattern: "</strong>", with: "")
        lyrics = lyrics.pregReplace(pattern: "<sup>", with: "")
        lyrics = lyrics.pregReplace(pattern: "</sup>", with: "")
        lyrics = lyrics.pregReplace(pattern: "<sub>", with: "")
        lyrics = lyrics.pregReplace(pattern: "</sub>", with: "")
        lyrics = lyrics.pregReplace(pattern: "<blockquote>", with: "")
        lyrics = lyrics.pregReplace(pattern: "</blockquote>", with: "")
        lyrics = lyrics.pregReplace(pattern: "<q>", with: "")
        lyrics = lyrics.pregReplace(pattern: "</q>", with: "")
        lyrics = lyrics.pregReplace(pattern: "<pre>", with: "")
        lyrics = lyrics.pregReplace(pattern: "</pre>", with: "")
        lyrics = lyrics.pregReplace(pattern: "<code>", with: "")
        lyrics = lyrics.pregReplace(pattern: "</code>", with: "")
        //行末の空白文字を削除
        lyrics = lyrics.pregReplace(pattern: "\\s*$", with: "")
        lyrics = lyrics.pregReplace(pattern: "　*$", with: "")
        
        //<br />を改行にする
        lyrics = lyrics.pregReplace(pattern: "<br />", with: "\n")
        //行頭と行末の改行を削除
        while lyrics.prefix(1) == "\n" {
            lyrics = String(lyrics[lyrics.index(lyrics.startIndex, offsetBy: 1)...])
        }
        while lyrics.suffix(1) == "\n" {
            lyrics = String(lyrics[..<lyrics.index(lyrics.endIndex, offsetBy: -1)])
        }
        //特殊文字
        lyrics = lyrics.pregReplace(pattern: "&lt;", with: "<")
        lyrics = lyrics.pregReplace(pattern: "&gt;", with: ">")
        lyrics = lyrics.pregReplace(pattern: "&nbsp;", with: " ")
        lyrics = lyrics.pregReplace(pattern: "&quot;", with: "\"")
        lyrics = lyrics.pregReplace(pattern: "&amp;", with: "&")
        
        return lyrics
    }
    
    @IBAction func returnToMe(segue: UIStoryboardSegue){
        //print(segue.identifier)
        if segue.identifier == "fromEditMenu" {
            print("fromEditMenu")
            print(nidankaiModoru)
            if nidankaiModoru {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                    self.performSegue(withIdentifier: "fromEditView", sender: nil)
                })
            }
        }
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("prepare")
        //print(segue.identifier as String!)
        //データ保存
        if segue.identifier == "fromEditView" {
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
                        print("preDataPost error")
                        return
                    }
                    if retStr.pregMatche(pattern: "<!--EchoHtmlMes_OK-->"){
                        //送信成功したらuserDataを消す。
                        print("preDataPost OK")
                        self.userData.MySpoonSet[self.selectLevel.sqlID] = nil
                        //取得データの更新
                        ServerDataHandler().DownloadMusicDataAndUserNameData { (error) in
                            if let error = error {
                                print(error) //なんか失敗した。けど、とりあえずスルーして次へ。
                            }
                            if let vc = segue.destination as? Selector {
                                vc.SetMusicToCarousel()
                            }
                            return
                        }
                    }
                    print(retStr) //何らかの理由で失敗。userData残る。
                }
            )
            
        }else if segue.identifier == "toEditorMenu" {
            print("toEditorMenu")
            let editorMenuController:EditorMenu = segue.destination as! EditorMenu
            editorMenuController.editorViewController = self
            
        }else if segue.identifier == "toEditorGame" {
            print("toEditorGame")
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
            guard let playing = moviePlayerViewController.player?.isPlaying else {
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

