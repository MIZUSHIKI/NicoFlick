//
//  Select.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/04/29.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation

class Selector: UIViewController,UIPickerViewDelegate, UIPickerViewDataSource, iCarouselDataSource, iCarouselDelegate, CAAnimationDelegate {
    
    @IBOutlet var musicTitle: UILabel!
    @IBOutlet var musicArtist: UILabel!
    @IBOutlet var musicLength: UILabel!
    @IBOutlet var musicTags: UILabel!
    @IBOutlet var levelSpeed: UILabel!
    @IBOutlet var musicNum: UILabel!
    @IBOutlet weak var musicSortButton: UIButton!
    
    @IBOutlet var carousel: iCarousel!
    @IBOutlet var levelSelectPicker: UIPickerView!
    @IBOutlet var buttonRankingComment: UIButton!
    @IBOutlet var labelRankingComment: UILabel!
    @IBOutlet var EditButtonView: UIView!
    @IBOutlet weak var rankingTimeLabel: UILabel!
    @IBOutlet weak var commentTimeLabel: UILabel!
    
    @IBOutlet weak var blackHeart: UIImageView!
    @IBOutlet weak var edgeHeart: UIImageView!
    @IBOutlet weak var colorHeart: UIImageView!
    @IBOutlet weak var likeNum: UILabel!
    
    @IBOutlet weak var colorMusicStar: UIImageView!
    @IBOutlet weak var musicFavoriteNum: UILabel!
    
    @IBOutlet weak var thumbMoviePlay: UIImageView!
    @IBOutlet weak var thumbMoviePlay_Color: UIImageView!
    
    var timer:Timer?
    var hitViews:[UIView] = []
    var hitRow = -1
    var numberRoll_index = -1
    
    //保存データ
    let userData = UserData.sharedInstance
    var userScore = UserScore() //読み取り用で保存データから取り出しておく
    //音楽データ(シングルトン)
    var musicDatas:MusicDataLists = MusicDataLists.sharedInstance
    let scoreDatas:ScoreDataLists = ScoreDataLists.sharedInstance
    let commentDatas:CommentDataLists = CommentDataLists.sharedInstance
    //効果音プレイヤー(シングルトン)
    var seSystemAudio:SESystemAudio = SESystemAudio.sharedInstance
    
    //表示する楽曲を tag で抽出する
    var currentMusics:[musicData] = [] //tagによって選択されている楽曲
    var currentLevels:[levelData] = [] //iCarouselで選択されているcurrentMusicのLevelが入る
    var indexCarousel = 0
    var indexPicker = 0
    var maeMusic:musicData? = nil
    private var isReloadingCarousel = false
    
    //遷移中フラグ
    var segueing = false
    //Indicator
    private var activityIndicator:UIActivityIndicatorView!
    
    //遷移時に受け取り
    var returnToMeString:String = ""
    var returnToMeData:Int = 0
    var password = ""
    
    var moviePlayerViewController:AVPlayerViewController?
    var nowPlayingThumbMovieURL:URL?
    var flgThumbMovieStopping = false //曲選択後0.5秒遅延再生にしているためGame遷移後に再生始まったりするのを防ぐフラグ
    var flgThumbMovieTopMost = false //ムービー再生を薄バックからサムネ全面に移動させたフラグ
    var volumeForceInResult:Float = 1.0
    let ReducedVolumeForceInResult:Float = 0.5
    private let japaneseKeyboardGuidePromptedKey = "JapaneseKeyboardGuidePrompted_v1"
    private var didScheduleJapaneseKeyboardGuide = false
    private var pendingFlickOnlyReminder = false
    private var flickOnlyReminderWorkItem: DispatchWorkItem?

    func queueFlickOnlyReminder() {
        pendingFlickOnlyReminder = true
        print("reminder")
    }

    private func scheduleFlickOnlyReminderIfNeeded() {
        guard pendingFlickOnlyReminder, flickOnlyReminderWorkItem == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.flickOnlyReminderWorkItem = nil
            self.showFlickOnlyReminderIfReady()
        }
        flickOnlyReminderWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    private func showFlickOnlyReminderIfReady() {
        guard pendingFlickOnlyReminder else { return }
        guard !UserDefaults.standard.bool(forKey: FlickOnlyReminder.shownKey) else {
            pendingFlickOnlyReminder = false
            return
        }
        // 既存案内、通信、unwind、サムネイルの音量復帰を優先する。
        guard viewIfLoaded?.window != nil,
              presentedViewController == nil,
              transitionCoordinator == nil,
              !isBeingDismissed, !segueing,
              returnToMeString.isEmpty,
              !activityIndicator.isAnimating,
              view.isUserInteractionEnabled,
              volumeForceInResult == 1.0,
              UIApplication.shared.applicationState == .active else {
            scheduleFlickOnlyReminderIfNeeded()
            return
        }
        guard let image = UIImage(named: "howto2.png") else {
            pendingFlickOnlyReminder = false
            return
        }
        let previousPlayback = pauseThumbMovieForJapaneseKeyboardGuide()
        let guide = FlickOnlyReminderViewController(guideImage: image)
        guide.onDismiss = { [weak self] in
            self?.restoreThumbMoviePlayback(to: previousPlayback)
        }
        guide.modalPresentationStyle = .overFullScreen
        guide.modalTransitionStyle = .crossDissolve
        pendingFlickOnlyReminder = false
        present(guide, animated: true) {
            // 予約時ではなく、実際に表示できた時点で一度限りのフラグを保存。
            UserDefaults.standard.set(true, forKey: FlickOnlyReminder.shownKey)
        }
    }
    
    enum ForceInResultType {
        case none
        case play
        case loadOnly
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        //carouselの設定
        carousel.type = .coverFlow
        carousel.bounceDistance = 0.3
        
        //Indicatorを作成
        activityIndicator = Indicator(center: self.view.center).view
        self.view.addSubview(activityIndicator)
        
        //保存しているスコアデータの読み込み
        userScore = userData.Score
        
        //se対策
        if UIScreen.main.bounds.size.height <= 568 {
            musicTitle.frame.origin.y -= 12
            musicArtist.frame.origin.y -= 12
            musicLength.frame.origin.y -= 12
            musicTags.frame.origin.y -= 12
            levelSpeed.frame.origin.y -= 12
            musicNum.frame.origin.y -= 12
        }
        //
        thumbMoviePlay.isHidden = userData.thumbMoviePlay
        thumbMoviePlay_Color.isHidden = !userData.thumbMoviePlay
        //
        let view = SlashShadeView.init(frame: self.view.frame, color: .white, lineWidth: 1, space: 2)
        self.view.addSubview(view)
        self.view.sendSubview(toBack: view)
        
        // バージョンアップ時の処理
        migration()
        
        //現在設定されているタグで選択された楽曲を保持する
        //currentMusics = musicDatas.getSelectMusics()
        //現在選択されている曲を保持する
        self.setCurrentLevels(index:-1)
        //iCarousel再描画
        carousel.reloadData()

        self.SetMusicToCarousel(thumbMovieForcePlay: true)
        
        //self.showChangeFavoSpecView() //もういいか (ver.1500お気に入り仕様変更案内)
        self.showHowToExtendView()
    }
    private var hasJapaneseKeyboard: Bool {
        return UITextInputMode.activeInputModes.contains {
            $0.primaryLanguage?.hasPrefix("ja") == true
        }
    }

    var shouldOfferJapaneseKeyboardGuide: Bool {
        return !hasJapaneseKeyboard
    }

    private func scheduleJapaneseKeyboardGuideIfNeeded() {
        guard !didScheduleJapaneseKeyboardGuide,
              !hasJapaneseKeyboard,
              !UserDefaults.standard.bool(forKey: japaneseKeyboardGuidePromptedKey) else {
            return
        }

        didScheduleJapaneseKeyboardGuide = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            self?.showJapaneseKeyboardGuidePrompt()
        }
    }

    private func showJapaneseKeyboardGuidePrompt() {
        guard presentedViewController == nil else {
            didScheduleJapaneseKeyboardGuide = false
            return
        }

        UserDefaults.standard.set(true, forKey: japaneseKeyboardGuidePromptedKey)
        let thumbMoviePlayBeforeGuide = pauseThumbMovieForJapaneseKeyboardGuide()

        let alert = UIAlertController(
            title: "Set up Japanese Flick Input",
            message: "NicoFlick is designed for the Japanese Kana flick keyboard. Set it up for the best gameplay experience.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Show Setup Guide", style: .default) { [weak self] _ in
            DispatchQueue.main.async {
                self?.showJapaneseKeyboardGuide(restoringThumbMoviePlayTo: thumbMoviePlayBeforeGuide)
            }
        })
        alert.addAction(UIAlertAction(title: "I’ve Already Set It Up", style: .cancel) { [weak self] _ in
            self?.restoreThumbMoviePlayback(to: thumbMoviePlayBeforeGuide)
        })
        alert.addAction(UIAlertAction(title: "Not Now", style: .default) { [weak self] _ in
            self?.restoreThumbMoviePlayback(to: thumbMoviePlayBeforeGuide)
        })
        present(alert, animated: true)
    }

    @objc func showJapaneseKeyboardGuide() {
        showJapaneseKeyboardGuide(restoringThumbMoviePlayTo: nil)
    }

    private func showJapaneseKeyboardGuide(restoringThumbMoviePlayTo previousValue: Bool?) {
        let guide = JapaneseKeyboardSetupViewController()
        guide.onDismiss = { [weak self] in
            guard let previousValue = previousValue else { return }
            self?.restoreThumbMoviePlayback(to: previousValue)
        }
        guide.modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *) {
            guide.sheetPresentationController?.detents = [.medium(), .large()]
            guide.sheetPresentationController?.selectedDetentIdentifier = .large
            guide.sheetPresentationController?.prefersGrabberVisible = true
        }
        present(guide, animated: true)
    }

    private func pauseThumbMovieForJapaneseKeyboardGuide() -> Bool {
        let previousValue = userData.thumbMoviePlay
        userData.thumbMoviePlay = false
        thumbMoviePlay.isHidden = false
        thumbMoviePlay_Color.isHidden = true
        ThumbMovieStop()
        return previousValue
    }

    private func restoreThumbMoviePlayback(to previousValue: Bool) {
        userData.thumbMoviePlay = previousValue
        thumbMoviePlay.isHidden = previousValue
        thumbMoviePlay_Color.isHidden = !previousValue
        if previousValue {
            ThumbMoviePlay()
        } else {
            ThumbMovieStop()
        }
    }

    func SetMusicToCarousel(thumbMovieForcePlay:Bool = false) {
        //Indicator くるくる開始
        DispatchQueue.main.async {
            self.activityIndicator.startAnimating()
        }
        //現在設定されているタグ・ソートで選択された楽曲を保持。
        // ネット接続処理を挟む可能性があるからコールバック。（あとクルクルさせとく）
        musicDatas.getSelectMusics(callback: { (musics) in
            self.currentMusics = musics
            
            DispatchQueue.main.async {
                //UI処理はメインスレッドの必要あり
                //Indicator隠す
                self.activityIndicator.stopAnimating()
                
                // iCarouselの再描画では、選択曲が変わっていなくても
                // carouselCurrentItemIndexDidChange が呼ばれるため、動画の再開を抑止する。
                self.isReloadingCarousel = true
                self.carousel.reloadData()

                guard !self.currentMusics.isEmpty else {
                    self.isReloadingCarousel = false
                    self.ThumbMovieStop()
                    self.currentLevels = []
                    self.levelSelectPicker.reloadAllComponents()
                    return
                }

                //前回選択していた曲に飛べれば飛ぶ
                var sameMovieURLAsMaeMusic = false
                var selectIndex = 0
                if self.numberRoll_index == -1 {
                    // print("mae \(self.maeMusic?.movieURL)")
                    if let selectMusic = self.maeMusic {
                        if let firstIndex = self.currentMusics.firstIndex(where: {$0.movieURL == selectMusic.movieURL}){
                            // print("fi \(firstIndex)")
                            selectIndex = firstIndex
                            sameMovieURLAsMaeMusic = true
                        }
                    }
                }else {
                    selectIndex = self.numberRoll_index
                    self.numberRoll_index = -1
                }
                self.carousel.currentItemIndex = selectIndex
                //現在選択されている曲を保持する
                self.setCurrentLevels(index:self.carousel.currentItemIndex)
                self.isReloadingCarousel = false
                
                if thumbMovieForcePlay || sameMovieURLAsMaeMusic == false {
                    self.ThumbMoviePlay()
                }
            }
        })
        
        // sortボタンに画像を適用
        let sortItem = UserData.sharedInstance.SelectedMusicCondition.sortItem
            .pregReplace(pattern: " [★☆]{10}[■□]$", with: "")
        let sortItemNum = SelectConditions.SortItems.firstIndex(of: sortItem) ?? -1
        let sortIconNames = [
            "music-new.png",
            "music-old.png",
            "flick-new.png",
            "flick-old.png",
            "plays-new.png",
            "plays-old.png",
            "favorites-many.png",
            "favorites-few.png",
            "video-id-large.png",
            "video-id-small.png",
            "highscore-recent.png",
            "comment-recent.png",
            "plays-recent.png",
            "plays-user.png"
        ]
        let sortIconName = sortIconNames.indices.contains(sortItemNum)
            ? sortIconNames[sortItemNum]
            : "cursor-lr.png"
        musicSortButton.setImage(UIImage(named: sortIconName), for: .normal)
    }
    
    var first_attack = true
    override func viewDidLayoutSubviews() {
        if !first_attack {
            return
        }
        first_attack = false
        //iOS14用
        if #available(iOS 14.0, *) {
            let pickerSubView = self.levelSelectPicker.subviews[1]
            pickerSubView.backgroundColor = UIColor.clear
            let borderTop = CALayer()
            borderTop.frame = CGRect(x: 0, y: 0, width: pickerSubView.frame.width, height: 1)
            borderTop.backgroundColor = UIColor.init(red: 0, green: 0, blue: 0, alpha: 0.1).cgColor
            pickerSubView.layer.addSublayer(borderTop)
            let borderBottom = CALayer()
            borderBottom.frame = CGRect(x: 0, y: pickerSubView.frame.height - 1, width: pickerSubView.frame.width, height: 1)
            borderBottom.backgroundColor = UIColor.init(red: 0, green: 0, blue: 0, alpha: 0.1).cgColor
            pickerSubView.layer.addSublayer(borderBottom)
        }
        //iOS16以降?
        if let oyaView = levelSelectPicker.superview {
            // print("kitayo")
            levelSelectPicker.frame = oyaView.bounds
        }
        
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scheduleJapaneseKeyboardGuideIfNeeded()
        scheduleFlickOnlyReminderIfNeeded()
        if timer == nil {
            timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.update), userInfo: nil, repeats: true)
            timer?.fire()
            RunLoop.main.add(timer!, forMode: .commonModes)
        }
        if returnToMeString != "" {
            //returnToMe from では処理できなくて、ここで遅延させてから処理する
            // print("selector return :\(returnToMeString)")
            
            // ゲームから戻ったときに名前変え提案 (ver.2.0)
            if returnToMeString == "showNameRegistrationPromptIfNoName" {
                self.showNameRegistrationPromptIfNoName_exec()
                
            // StartWiki からの戻りで、タグとソートを設定する [上記以外のreturnToMeStringは wikiからの戻り文字]
            }else if returnToMeString != "BackButton" {
                // - wikiのPLAYボタンからでtagsort文字列が入る
                // - Back to MusicSelect ボタンでブラウザを閉じると"BackButton"が入っている
                let retStr = returnToMeString.removingPercentEncoding
                if var retTag = retStr?.pregMatche_firstString(pattern: "tag=(.*?)(&sort=|$)"),
                   let retSort = retStr?.pregMatche_firstString(pattern: "sort=(.*?)(&tag=|$)"){
                    var jikanSitei = ""
                    let array = retTag.components(separatedBy: " ") //タグ文字列を空白で分割
                    if (array.contains(where: {$0.hasPrefix("@t:")})) {
                        if let a = array.first(where: {$0.hasPrefix("@t:")}){
                            jikanSitei = a
                        }
                        //時間指定が機能するように一度削除して最後に持っていく
                        retTag = retTag.pregReplace(pattern: "\\s?@t:(\\d+:\\d+)?-?(\\d+:\\d+)?", with: "")
                    }
                    retTag = retTag.trimmingCharacters(in: .whitespaces)
                    retTag = retTag.pregReplace(pattern: "\\s*/(and|AND)/\\s*", with: "/and/")
                    retTag = retTag.pregReplace(pattern: "\\s+", with: " or ")
                    retTag = retTag.pregReplace(pattern: "/and/", with: " ")
                    if retTag != "" && jikanSitei != ""{
                        jikanSitei = " " + jikanSitei
                    }
                    userData.SelectedMusicCondition.tags = retTag + jikanSitei
                    if retSort != "" {
                        userData.SelectedMusicCondition.sortItem = retSort
                    }

                    self.maeMusic = nil
                    self.SetMusicToCarousel(thumbMovieForcePlay: true)
                }
            }else {
                ThumbMoviePlay()
            }
            returnToMeString = ""
        }
    }
    override func viewWillDisappear(_ animated: Bool) {
        flickOnlyReminderWorkItem?.cancel()
        flickOnlyReminderWorkItem = nil
        timer?.invalidate()
        timer = nil
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    //iCarousel処理_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    func numberOfItems(in carousel: iCarousel) -> Int {
        //print(String(format: "items.count = %d", currentMusics.count))
        return currentMusics.count
    }
    
    //ビューの作成
    func carousel(_ carousel: iCarousel, viewForItemAt index: Int, reusing view: UIView?) -> UIView {
        
        var itemView: AsyncImageView
        
        //if let view = view as? AsyncImageView {
        //    itemView = view
        //} else {
            itemView = AsyncImageView(frame: CGRect(x: 0, y: 0, width: 315, height: 175));
        guard currentMusics.indices.contains(index) else { return itemView }
        let music = currentMusics[index]
        itemView.loadImage(urlString: music.thumbnailURL, contentMode: .scaleAspectFill) { result in
            if case .failure(let error) = result, error.shouldRepairThumbnailURL {
                self.repairThumbnailURLIfNeeded(for: music, imageView: itemView)
            }
        }
            itemView.contentMode = .center
        //}
        return itemView
    }

    private func repairThumbnailURLIfNeeded(for music: musicData, imageView: AsyncImageView) {
        guard let musicID = music.sqlID else {
            return
        }
        guard !AppDelegate.thumbnailRepairAttemptedMusicIDs.contains(musicID) else {
            return
        }
        AppDelegate.thumbnailRepairAttemptedMusicIDs.insert(musicID)

        guard let movieURL = music.movieURL else {
            return
        }
        guard let movieURLComponents = URLComponents(string: movieURL) else {
            return
        }
        let videoID = movieURLComponents.path.split(separator: "/").last.map(String.init) ?? ""
        guard !videoID.isEmpty else {
            return
        }
        guard let url = URL(string: AppDelegate.NicoApiURL_GetThumbInfo + videoID) else {
            return
        }

        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                return
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                return
            }
            guard let data else {
                return
            }

            let responseText = String(decoding: data, as: UTF8.self)
            guard responseText.pregMatche(pattern: "<nicovideo_thumb_response status=\"ok\">") else {
                return
            }
            let thumbnailURL = responseText.pregMatche_firstString(pattern: "<thumbnail_url>(.*?)</thumbnail_url>").htmlDecoded
            guard !thumbnailURL.isEmpty else {
                return
            }

            ServerDataHandler().postMusicThumbnailUpdate(
                id: musicID,
                thumbnailURL: thumbnailURL,
                userID: UserData.sharedInstance.UserID
            ) { success in
                guard success else {
                    return
                }
                DispatchQueue.main.async {
                    music.thumbnailURL = thumbnailURL
                    imageView.loadImage(urlString: thumbnailURL, contentMode: .scaleAspectFill)
                }
            }
        }.resume()
    }
    
    func carousel(_ carousel: iCarousel, valueFor option: iCarouselOption, withDefault value: CGFloat) -> CGFloat {
        if (option == .spacing) {
            return value * 1.1
        }
        return value
    }
    
    //カバーフローを動かした
    func carouselCurrentItemIndexDidChange(_ carousel: iCarousel) {
        //現在選択されている曲を保持する
        indexCarousel = carousel.currentItemIndex
        self.setCurrentLevels(index:indexCarousel)
        
        if self.currentMusics.indices.contains(self.indexCarousel) {
            //前回の選択曲を保存
            self.maeMusic = self.currentMusics[self.indexCarousel]
        }
        hitViews = []
        hitRow = -1
        
        if !isReloadingCarousel {
            ThumbMoviePlay()
        }
        // print("carousel.isDraggingAndThenDecelerating=\(carousel.isDraggingAndThenDecelerating)")
        if carousel.isDraggingAndThenDecelerating {
            //se
            seSystemAudio.shuffleSePlay()
        }
    }
    func setCurrentLevels(index:Int){
        if !currentMusics.indices.contains(index) {
            //曲が１つもないとき
            self.musicTitle.text = ""
            self.musicArtist.text = ""
            self.musicLength.text = ""
            self.musicTags.text = ""
            self.levelSpeed.text = ""
            self.musicNum.text = ""
            currentLevels = []
            self.buttonRankingComment.isHidden = true
            self.labelRankingComment.isHidden = true
            self.levelSelectPicker.reloadAllComponents()
            rankingTimeLabel.isHidden = true
            commentTimeLabel.isHidden = true
            EditButtonView.isHidden = true
            colorMusicStar.isHidden = true
            musicFavoriteNum.isHidden = true
            colorHeart.isHidden = true
            blackHeart.isHidden = true
            edgeHeart.isHidden = true
            likeNum.isHidden = true
            return
        }
        let currentMusic = currentMusics[index]
        self.musicTitle.text = currentMusic.title
        self.musicArtist.text = currentMusic.artist
        self.musicLength.text = currentMusic.movieLength
        let tags = currentMusic.tags
        self.musicTags.text = tags
        let attrText = NSMutableAttributedString(string: tags!)
        for tagp in userData.SelectedMusicCondition.tag {
            let tag = tagp.word
            // print(tag)
            let regTag = NSRegularExpression.escapedPattern(for: tag)
            if let regex = try? NSRegularExpression(pattern: "(^|\\s)\(regTag)(\\s|$)", options: []) {
                let targetStringRange = NSRange(location: 0, length: tags!.count)
                let result = regex.firstMatch(in: tags!, options: [], range: targetStringRange)
                if result != nil {
                    for j in 0 ..< result!.numberOfRanges {
                        let range = result!.range(at: j)
                        attrText.addAttribute(.foregroundColor, value: UIColor.black, range: range)
                        // print(range)
                    }
                }
            }
        }
        self.musicTags.attributedText = attrText
        self.musicNum.text = "\(index+1) / \(currentMusics.count)"
        if (musicDatas.levels[currentMusic.movieURL]==nil){
            currentLevels = []
            self.buttonRankingComment.isHidden = true
            self.labelRankingComment.isHidden = true
        }else {
            currentLevels = musicDatas.getSelectMusicLevels(selectMovieURL: currentMusic.movieURL)
            self.buttonRankingComment.isHidden = false
            self.labelRankingComment.isHidden = false
        }
        self.colorMusicStar.isHidden = !userData.MyFavorite3.contains(currentMusic.sqlID)
        let favoriteCount = Int(currentMusic.favoriteCount / 5) * 5
        musicFavoriteNum.text = String(favoriteCount)
        musicFavoriteNum.isHidden = ( favoriteCount == 0 )
        // print("favoriteCount:",favoriteCount)
        let previouslySelectedRow = levelSelectPicker.selectedRow(inComponent: 0)
        self.levelSelectPicker.reloadAllComponents()
        if !currentLevels.isEmpty {
            let safeRow = currentLevels.indices.contains(previouslySelectedRow) ? previouslySelectedRow : 0
            self.levelSelectPicker.selectRow(safeRow, inComponent: 0, animated: false)
            UpdateObject_Level(currentLevel: currentLevels[safeRow])
        }
    }

    func currentSelectedLevel() -> levelData? {
        guard !currentLevels.isEmpty else { return nil }

        let selectedRow = levelSelectPicker.selectedRow(inComponent: 0)
        let safeRow = currentLevels.indices.contains(selectedRow) ? selectedRow : 0
        if safeRow != selectedRow {
            levelSelectPicker.selectRow(safeRow, inComponent: 0, animated: false)
        }
        indexPicker = safeRow
        return currentLevels[safeRow]
    }

    func currentSelectedMusic() -> musicData? {
        guard currentMusics.indices.contains(indexCarousel) else { return nil }
        return currentMusics[indexCarousel]
    }
    //Add TapGesture
    func carouselDidTap(_ carousel: iCarousel) {
        // print("did tap!!")
        if !userData.thumbMoviePlay { return }
        if flgThumbMovieStopping { return }
        // print("did tap!! st")
        if flgThumbMovieTopMost { return }
        // print("did tap!! top")
        guard let view = self.view.viewWithTag(5050) else { return }
        // print("did tap!! 50")
        guard let carouselView = self.view.viewWithTag(5000) else { return }
        // print("did tap!! 00")
        flgThumbMovieTopMost = true //thumbMovieを最前面再生しているか

        //ViewのZ位置は入れ替えしかできないからtempViewをinsertする
        let tempView = UIView()
        tempView.tag = 5051
        tempView.isHidden = true
        self.view.insertSubview(tempView, aboveSubview: carouselView)
        // print(view.frame)
        var index_thumbMovie = -1
        var index_tempView = -1
        for (i,v) in self.view.subviews.enumerated() {
            if v.tag == 5050 {
                index_thumbMovie = i
            }
            if v.tag == 5051 {
                index_tempView = i
            }
            if index_thumbMovie != -1 && index_tempView != -1 {
                //ViewのZ位置を入れ替え
                self.view.exchangeSubview(at: index_thumbMovie, withSubviewAt: index_tempView)
                break
            }
        }
        tempView.removeFromSuperview() //tempView削除

        // CABasicAnimationでアニメーションさせる。ただしLayerでサイズ、位置をアニメーションしてる(?)から元のサイズに戻したい時はframeとかではなくLayerを戻さなくてはならない(?)
        let animationGroup = CAAnimationGroup()
        animationGroup.duration = 0.5
        animationGroup.isRemovedOnCompletion = false
        animationGroup.fillMode = kCAFillModeForwards

        //大きさ(transform.scale)を1.5倍にする
        let animation1 = CABasicAnimation(keyPath: "bounds")
        animation1.fromValue = NSValue(cgRect: view.bounds)
        animation1.toValue = NSValue(cgRect: carouselView.bounds)
        animation1.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        
        let animation2 = CABasicAnimation(keyPath: "transform.scale")
        animation2.fromValue = 1.0
        animation2.toValue = carouselView.frame.width / view.frame.width
        animation2.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        let b = carouselView.frame.width / view.frame.width
        // print("carouselView.frame.width / view.frame.width = \(carouselView.frame.width) / \(view.frame.width)")
        // print("b= \(b)")


        //位置(position.x)を変更する
        let animation3 = CABasicAnimation(keyPath: "position")
        animation3.fromValue = view.center
        animation3.toValue = carouselView.center
        animation3.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)

        //透明度(opacity)を1から0にする
        let animation4 = CABasicAnimation(keyPath: "opacity")
        animation4.fromValue = 0.05
        animation4.toValue = 1.0
        animation4.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)

        //アンカーポイントを設定（※viewの位置も変わるため、frameを事前に変数に格納する）
        //let frm = view.frame
        //view.layer.anchorPoint = CGPoint(x: 0.0, y: 0.5)
        //view.frame = frm

        animationGroup.animations = [animation2,animation3,animation4]
        animationGroup.delegate = self
        view.layer.add(animationGroup, forKey: nil)
        
        self.volumeForceInResult = 1.0
        self.moviePlayerViewController?.player?.volume = 0.9 * userData.SoundVolumeMovie * self.volumeForceInResult
    }
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        // print("did stop")
        if !flgThumbMovieTopMost { return }
        guard let view = self.view.viewWithTag(5050) else { return }
        guard let carouselView = self.view.viewWithTag(5000) else { return }
    }
    //\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
    
    
    //レベルセレクト ピッカービュー処理 _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        if pickerView.tag == 123 { //ナンバーロール
            return 30
        }
        return 80
    }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView.tag == 123 { //ナンバーロール
            return currentMusics.count
        }
        return currentLevels.count
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        if pickerView.tag == 123 { //ナンバーロール
            let label = UILabel()
            label.textAlignment = .center
            label.text = String(currentMusics.indices[row]+1)
            return label
        }
        return self.UIViewForLevelSelectPicker(row: row)
    }
    @objc func update(tm: Timer) {
        for hitView:UIView in hitViews {
            if let view:UIView = hitView.superview {
                let a = view.convert(view.bounds, to: levelSelectPicker)
                let b = a.origin.y + a.height/2
                //print("\(hitView.tag) \(b) \(a)")
                if levelSelectPicker.frame.height/2.3 - 30 < b && b < levelSelectPicker.frame.height/2.3 + 30 {
                    //
                    let row = hitView.tag
                    
                    if currentLevels.count > row {
                        if hitRow != row {
                            hitRow = row
                            // print("hitRow=\(hitRow)")
                            UpdateObject_Level(currentLevel: currentLevels[row])
                        }
                    }
                }
            }
        }
    }
    func UpdateObject_Level( currentLevel:levelData ){
        //スピード反映
        levelSpeed.text = "speed: "+String(currentLevel.speed)
        //like反映
        colorHeart.isHidden = true
        edgeHeart.isHidden = true
        blackHeart.isHidden = true
        if let likeValue = userData.MyLike[currentLevel.sqlID] {
            switch likeValue {
            case -2:
                edgeHeart.isHidden = false
            case -1:
                blackHeart.isHidden = false
            case 0:
                break
            default: // 0より大きい
                colorHeart.isHidden = false
            }
        }
        let likeCount = Int((currentLevel.likeCount - currentLevel.dislikeCount) / 5) * 5
        likeNum.text = String(likeCount)
        likeNum.isHidden = ( likeCount == 0 )
        likeNum.textColor = likeCount < 0 ? .red : .black
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy.MM.dd"
        if (userData.SelectedMusicCondition.sortItem.hasPrefix("最近ハイスコアが更新された曲順") || (Int(Date().timeIntervalSince1970) -  currentLevel.scoreTime)<2592000) && currentLevel.scoreTime > 0 {
            rankingTimeLabel.text = dateFormatter.string(for: Date(timeIntervalSince1970: TimeInterval(currentLevel.scoreTime)))
            rankingTimeLabel.isHidden = false
        }else{
            rankingTimeLabel.isHidden = true
        }
        // print("currentLevel.scoreTime=\(currentLevel.scoreTime)")
        if (userData.SelectedMusicCondition.sortItem.hasPrefix("最近コメントされた曲順") || (Int(Date().timeIntervalSince1970) -  currentLevel.commentTime)<2592000) && currentLevel.commentTime > 0 {
            commentTimeLabel.text = dateFormatter.string(for: Date(timeIntervalSince1970: TimeInterval(currentLevel.commentTime)))
            commentTimeLabel.isHidden = false
        }else{
            commentTimeLabel.isHidden = true
        }
        // print("currentLevel.commentTime=\(currentLevel.commentTime)")
        
        if !currentLevel.isEditing/*isMyEditing()*/ {
            EditButtonView.isHidden = true
            labelRankingComment.isHidden = false
        }else {
            EditButtonView.isHidden = false
            labelRankingComment.isHidden = true
        }
    }
    
    //レベルセレクト　ピッカービュー デザイン
    func UIViewForLevelSelectPicker(row :Int) -> UIView {
        let myView = UILabel()
        myView.tag = row
        hitViews.insert(myView, at: 0)
        if hitViews.count > 5 {
            hitViews.remove(at: 5)
        }
        //myView1.backgroundColor = UIColor.red
        //難易度
        let labelView1 = UILabel()
        labelView1.text = currentLevels[row].getLevelAsString()
        labelView1.frame = CGRect(x: 5, y: 10  + 10, width: UIScreen.main.bounds.size.width-10, height: 20)
        if labelView1.text == "FULL" {
            labelView1.font = UIFont(name: "NicoKaku", size: 20)
        }
        labelView1.textAlignment = NSTextAlignment.center
        myView.addSubview(labelView1)
        //難易度2
        let labelView1_2 = UILabel()
        if UserDefaults.standard.bool(forKey: "UseNewLevelCalculation") && currentLevels[row].calcLv > 0 {
            labelView1_2.text = "★"+String(currentLevels[row].calcLv)
            labelView1_2.frame = CGRect(x: labelView1.center.x, y: 20 + 20, width: 100, height: 15)
            labelView1_2.font = labelView1_2.font.withSize(12)
            labelView1_2.textColor = .systemGray
            labelView1_2.textAlignment = .right
        }
        myView.addSubview(labelView1_2)
        //製作者
        let labelView2 = UILabel()
        labelView2.text = currentLevels[row].creator
        labelView2.frame = CGRect(x: 5, y: 10+20+5  + 10, width: UIScreen.main.bounds.size.width-10, height: 20)
        labelView2.textColor = UIColor.gray
        labelView2.font = UIFont.systemFont(ofSize:10)
        //labelView2.font = UIFont(name: "NicoKaku", size: 10)
        labelView2.textAlignment = NSTextAlignment.center
        myView.addSubview(labelView2)
        /*
        //コメント
        let labelView3 = UILabel()
        labelView3.text = "「"+currentLevels[row].description+"」"
        labelView3.frame = CGRect(x: 5, y: 10+20+5+15+5, width: UIScreen.main.bounds.size.width-10, height: 20)
        labelView3.textColor = UIColor.gray
        labelView3.font = UIFont.systemFont(ofSize:10)
        labelView3.textAlignment = NSTextAlignment.center
        myView.addSubview(labelView3)
         */
        //ランク
        var rank=""
        var score=""
        if !currentLevels[row].isEditing/*isMyEditing()*/ {
            if let us = userScore.scores[currentLevels[row].sqlID] {
                score = "HighScore: "+String(us[0])
                rank = Score.RankStr[us[1]]
                if rank == "False" {
                    rank = ""
                }
            }
        }else{
            rank = "編集中"
            score = "only you can see."
        }
        /*
        if currentLevels.count > levelSelectPicker.selectedRow(inComponent: 0)
            && currentLevels[levelSelectPicker.selectedRow(inComponent: 0)].isEditing/*isMyEditing()*/ {
            EditButtonView.isHidden = false
            labelRankingComment.isHidden = true
        }else {
            EditButtonView.isHidden = true
            labelRankingComment.isHidden = false
        }
         */
        let labelView4 = UILabel()
        labelView4.text = rank
        labelView4.frame = CGRect(x: 10, y: 25, width: 90, height: 30)
        labelView4.textColor = UIColor.black
        if rank == Score.RankStr[0] {
            labelView4.textColor = UIColor.red
        }
        //labelView4.font = UIFont.systemFont(ofSize:30)
        //labelView4.font = UIFont(name: "NicoKaku", size: 30)
        labelView4.font = UIFont(name: "HiraginoSans-W7", size: 30)
        labelView4.adjustsFontSizeToFitWidth = true
        labelView4.textAlignment = NSTextAlignment.center
        myView.addSubview(labelView4)
        //HighScore
        let labelView5 = UILabel()
        labelView5.text = score
        labelView5.frame = CGRect(x: 10, y: 0/*10+20+5+15+5+5*/, width: UIScreen.main.bounds.size.width-10, height: 20)
        labelView5.textColor = UIColor.gray
        //labelView5.font = UIFont.systemFont(ofSize:10)
        labelView5.font = UIFont(name: "NicoKaku", size: 10)
        labelView5.textAlignment = NSTextAlignment.left
        myView.addSubview(labelView5)
        //スコアとコメの最新日時
        let sqlID = currentLevels[row].sqlID
        var newDate = 0
        /*
        for scoreData in scoreDatas.scores {
            if scoreData.levelID == sqlID && newDate < scoreData.sqlUpdateTime! {
                newDate = scoreData.sqlUpdateTime!
            }
        }
        for commentData in commentDatas.comments {
            if commentData.levelID == sqlID && newDate < commentData.sqlUpdateTime! {
                newDate = commentData.sqlUpdateTime!
            }
        }
 */
        if newDate != 0 {
            let dateUnix: TimeInterval = Double(newDate)
            let date = Date(timeIntervalSince1970: dateUnix)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy.MM.dd"
            
            let labelView6 = UILabel()
            labelView6.text = formatter.string(from: date)
            labelView6.frame = CGRect(x: 5, y: 10+20+5  + 20, width: UIScreen.main.bounds.size.width-10, height: 20)
            labelView6.textColor = UIColor.lightGray
            labelView6.font = UIFont.systemFont(ofSize:8)
            labelView6.textAlignment = NSTextAlignment.right
            myView.addSubview(labelView6)
        }
        /*
        let labelView7 = UILabel()
        labelView7.text = "play: \(currentLevels[row].playCount!)"
        labelView7.frame = CGRect(x: 5, y: 2, width: UIScreen.main.bounds.size.width-10, height: 20)
        labelView7.textColor = UIColor.lightGray
        labelView7.font = UIFont.systemFont(ofSize:8)
        labelView7.textAlignment = NSTextAlignment.right
        myView.addSubview(labelView7)
        */
        //myView1.alpha = 0.3
        
        return myView
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView.tag == 123 {
            //ナンバーロール
            numberRoll_index = row
            return
        }
        //timerでループ確認するようにしたけど、一応残しておく
        if currentLevels.count > row {
            UpdateObject_Level(currentLevel: currentLevels[row])
        }
    }
    
    @IBAction func SortButton(_ sender: Any) {
        self.TapSortableLabel()
    }
    @IBAction func TapTagLabel(_ sender: UITapGestureRecognizer) {
        self.TapTagableLabel()
    }
    func TapSortableLabel() {
        //se
        seSystemAudio.openSePlay()
        self.performSegue(withIdentifier: "toTableViewForSortFromSelector", sender: self)
    }
    func TapTagableLabel() {
        if currentMusics.count == 0 {
            return
        }
        //se
        seSystemAudio.openSePlay()
        self.performSegue(withIdentifier: "toTableViewForTagFromSelector", sender: self)
    }
    @IBAction func TapMusicNumLabel(_ sender: UITapGestureRecognizer) {
        if currentMusics.count == 0 {
            return
        }
        //se
        seSystemAudio.openSePlay()
        let title = "曲の選択"
        let message = "\n\n\n\n\n\n\n\n\n\n" //改行入れないとOKCancelがかぶる

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler:{
          (action: UIAlertAction!) -> Void in
            if self.numberRoll_index == -1 { return }
            if self.indexCarousel == self.numberRoll_index {
                self.numberRoll_index = -1
                return
            }
            self.SetMusicToCarousel()
        })

        // PickerView
        let pv = UIPickerView()
        pv.alpha = 0
        pv.tag = 123
        pv.frame = CGRect(x: 0, y: 60, width: alert.view.bounds.width * 0.7, height: 150) // 配置、サイズ
        pv.dataSource = self
        pv.delegate = self
        pv.selectRow(indexCarousel, inComponent: 0, animated: true) // 初期値
        // print("indexC = \(indexCarousel)")
        alert.view.addSubview(pv)

        let firstButton = UIButton(type: .system, primaryAction: UIAction { _ in
            pv.selectRow(0, inComponent: 0, animated: true)
            self.numberRoll_index = 0
        })
        firstButton.setTitle("▲", for: .normal)
        firstButton.backgroundColor = .systemGray5
        firstButton.layer.cornerRadius = 18
        firstButton.accessibilityLabel = "先頭に移動"
        firstButton.alpha = 0
        alert.view.addSubview(firstButton)

        let lastButton = UIButton(type: .system, primaryAction: UIAction { _ in
            let lastRow = self.currentMusics.count - 1
            pv.selectRow(lastRow, inComponent: 0, animated: true)
            self.numberRoll_index = lastRow
        })
        lastButton.setTitle("▼", for: .normal)
        lastButton.backgroundColor = .systemGray5
        lastButton.layer.cornerRadius = 18
        lastButton.accessibilityLabel = "最後尾に移動"
        lastButton.alpha = 0
        alert.view.addSubview(lastButton)

        alert.addAction(okAction)
        present(alert, animated: true) {
            let pickerY = (alert.view.bounds.height - 150) / 3
            pv.frame = CGRect(
                x: 0,
                y: pickerY,
                width: alert.view.bounds.width,
                height: 150
            )
            firstButton.frame = CGRect(
                x: alert.view.bounds.width - 44,
                y: pickerY - 13,
                width: 36,
                height: 36
            )
            lastButton.frame = CGRect(
                x: alert.view.bounds.width - 44,
                y: pickerY + 127,
                width: 36,
                height: 36
            )
            UIView.animate(withDuration: 0.1) {
                pv.alpha = 1
                firstButton.alpha = 1
                lastButton.alpha = 1
            }
        }
        //present(alert, animated: true, completion: nil)
    }
    @IBAction func ThumbMoviePlayButton(_ sender: UIButton) {
        // print("ThumbMoviePlayButton")
        userData.thumbMoviePlay = !userData.thumbMoviePlay
        thumbMoviePlay.isHidden = userData.thumbMoviePlay
        thumbMoviePlay_Color.isHidden = !userData.thumbMoviePlay
        if userData.thumbMoviePlay {
            ThumbMovieStart(index: self.indexCarousel)
        }else {
            ThumbMovieStop()
        }
    }
    func ThumbMoviePlay(forceType: ForceInResultType = .none){
        if forceType == .none && !userData.thumbMoviePlay {
            return
        }
        var typeLoadOnly = false
        if !(forceType == .none) {
            volumeForceInResult = ReducedVolumeForceInResult
            if forceType == .loadOnly {
                typeLoadOnly = true
            }
        }
        //THumbMovie呼び込み _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
        //ThumbMovieを最前面再生していたら奥に引っ込める
        self.ThumbMovieReturnToBottom(opacity: 0.25)
        //一度すべて止める
        //ThumbMovieStop() //カバーフロー動かしたあとすぐ消さないで次の再生まで遅延させるようにするためコメントアウト
        //裏側で再生
        ThumbMovieStart(index: self.indexCarousel, loadOnly: typeLoadOnly)
    }
    func ThumbMovieStop() {
        // print("ThumbMovieStop")
        //ThumbMovieを最前面再生していたら奥に引っ込める
        ThumbMovieReturnToBottom(opacity: 0.01)
        flgThumbMovieStopping = true
        //一度すべて止める
        for avPlayerVC in CachedThumbMovies.sharedInstance.cachedMovies {
            avPlayerVC.avPlayerViewController.player?.pause()
        }
        //Viewを取り除く
        if let view = self.view.viewWithTag(5050) {
            view.removeFromSuperview()
        }
    }
    private func ThumbMovieStart(index:Int, loadOnly:Bool = false) {
        flgThumbMovieStopping = false
        flgThumbMovieTopMost = false
        guard self.currentMusics.indices.contains(index) else { return }
        guard let movieURL = self.currentMusics[index].movieURL else { return }
        var ans:[String]=[]
        var smNum = ""
        if (movieURL.pregMatche(pattern: "watch/(.+)$", matches: &ans)){
            smNum = ans[1]
        }else{
            return
        }
        //let index = self.indexCarousel
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5){
            //print("\(smNum) => \(index) / \(self.indexCarousel)")
            if index == self.indexCarousel || loadOnly == true {
                MovieAccess.init().StreamingUrlNicoAccessForThumbMovie(smNum: smNum){ (nicodougaURL) in
                // print("smNum=\(smNum), loadOnly=\(loadOnly), nicodougaURL=\(nicodougaURL)")
                    if self.flgThumbMovieStopping == true {
                        // print("ThumbMovieStopping")
                        return
                    }
                    if loadOnly == true && nicodougaURL == "cached" {
                        return
                    }
                    //session.dataTas後のサブスレッド内でviewを処理させると表示関連が後回しになるので、メインスレッドでaddSubviewする。
                    DispatchQueue.main.async {
                        //print("\(smNum) <= \(index) / \(self.indexCarousel)")
                        if index != self.indexCarousel && loadOnly == false {
                            return
                        }
                        guard let nicoUrl = URL(string: nicodougaURL) else {
                            return
                        }
                        let mpvc = CachedThumbMovies.sharedInstance.access(url: nicoUrl, smNum: smNum)
                        if loadOnly == false {
                            self.ThumbMovieStop()
                            self.flgThumbMovieStopping = false
                            self.flgThumbMovieTopMost = false
                            
                            self.moviePlayerViewController = mpvc
                            self.moviePlayerViewController?.view.backgroundColor = UIColor.white
                            self.moviePlayerViewController?.view.alpha = 0.01
                            self.moviePlayerViewController?.view.tag = 5050
                            self.nowPlayingThumbMovieURL = CachedThumbMovies.sharedInstance.cachedMovies.last?.url
                            //cachedMovie.accessで返してもらった直後はソレがcachedMovies配列の末尾になっている
                            //  add
                            self.view.addSubview(self.moviePlayerViewController!.view)
                            self.view.sendSubview(toBack: self.moviePlayerViewController!.view)
                            //  動画Viewの位置
                            self.moviePlayerViewController?.view.frame.size = CGSize(width: self.view.frame.size.height * 16 / 9, height: self.view.frame.size.height)
                            // print("wi = \(self.view.frame.size.height * 16 / 9)")
                            self.moviePlayerViewController!.view.center.x = self.view.center.x
                        }
                        var t30 = self.musicDatas.getNotesFirstTime(movieURL: movieURL)
                        if t30 < 0.0 {
                            t30 = 30.0
                        }else {
                            t30 -= 3.0
                            if t30 < 0.0 {
                                t30 = 0.0
                            }
                        }
                        // print("t30=\(t30)")
                        // print(self.currentMusics[index].movieURL)
                        if loadOnly == false{
                            //フェードイン・アウト・ループ設定
                            var firstRun = true
                            var runed = false
                            let myMovieURL = self.nowPlayingThumbMovieURL
                            for i in 1 ... 10 {
                                self.moviePlayerViewController!.player?.addBoundaryTimeObserver(forTimes: [NSValue(time: CMTimeMakeWithSeconds(t30 + 0.05 * Double(i), Int32(NSEC_PER_SEC)))], queue: nil){
                                    if myMovieURL != self.nowPlayingThumbMovieURL {
                                        //print("私じゃない！！")
                                        return
                                    }
                                    if self.flgThumbMovieTopMost { return }
                                    //resultで音量下げてたら戻す
                                    if self.volumeForceInResult > self.ReducedVolumeForceInResult {
                                        self.volumeForceInResult = 1.0
                                    }
                                    if self.volumeForceInResult >= self.ReducedVolumeForceInResult {
                                        //print("フェードイン \(i)")
                                        let animation4 = CABasicAnimation(keyPath: "opacity")
                                        animation4.fromValue = CGFloat(0.25 *  Double(i) / 10.0)
                                        animation4.toValue = CGFloat(0.25 *  Double(i) / 10.0)
                                        // print("in \(i) alpha")
                                        animation4.isRemovedOnCompletion = false
                                        animation4.fillMode = kCAFillModeForwards
                                        self.moviePlayerViewController?.view.layer.add(animation4, forKey: nil)
                                        //self.moviePlayerViewController?.view.alpha = CGFloat(0.25 *  Double(i) / 10.0)
                                        self.moviePlayerViewController?.player?.volume = Float(0.45 * Double(i) / 10.0) * self.userData.SoundVolumeMovie * self.volumeForceInResult
                                        //再生できたらcheckを入れる（キャッシュ分で再生できなくなってニコニコとのHeartBeatも切れるとCachedThumbMovies-avPlayerViewControllerじゃ再生できなくなるからアクセスからやり直させるフラグ）
                                    }
                                    if i==1 {
                                        if let a = CachedThumbMovies.sharedInstance.cachedMovies.first(where: {$0.smNum == smNum}){
                                            a.check = 1
                                            //print("set \(smNum) - a.check= \(a.check)")
                                        }
                                        if firstRun {
                                            firstRun = false
                                            //前後の曲も読み込んどく
                                            self.ThumbMovieStart(index: index + 1 ,loadOnly: true)
                                            self.ThumbMovieStart(index: index - 1 ,loadOnly: true)
                                        }
                                    }
                                    if i==10 { runed = true }
                                }
                                self.moviePlayerViewController!.player?.addBoundaryTimeObserver(forTimes: [NSValue(time: CMTimeMakeWithSeconds(t30 + 29.0 + 0.1 * Double(i), Int32(NSEC_PER_SEC)))], queue: nil){
                                    if myMovieURL != self.nowPlayingThumbMovieURL {
                                        //print("私じゃない！！")
                                        return
                                    }
                                    if self.flgThumbMovieTopMost { return }
                                    //resultで音量下げてたら戻す
                                    if self.volumeForceInResult > self.ReducedVolumeForceInResult {
                                        self.volumeForceInResult = 1.0
                                    }
                                    if self.volumeForceInResult >= self.ReducedVolumeForceInResult {
                                        //print("フェードアウト \(i)")
                                        let animation4 = CABasicAnimation(keyPath: "opacity")
                                        animation4.fromValue = CGFloat(0.25 *  Double(10 - i) / 10.0)
                                        animation4.toValue = CGFloat(0.25 *  Double(10 - i) / 10.0)
                                        animation4.isRemovedOnCompletion = false
                                        animation4.fillMode = kCAFillModeForwards
                                        self.moviePlayerViewController?.view.layer.add(animation4, forKey: nil)
                                        //self.moviePlayerViewController?.view.alpha = CGFloat(0.25 *  Double(10 - i) / 10.0)
                                        self.moviePlayerViewController?.player?.volume = Float(0.45 * Double(10 - i) / 10.0) * self.userData.SoundVolumeMovie * self.volumeForceInResult
                                    }
                                }
                            }
                            for i in 1 ... 28 {
                                self.moviePlayerViewController!.player?.addBoundaryTimeObserver(forTimes: [NSValue(time: CMTimeMakeWithSeconds(t30 +  1.0 * Double(i), Int32(NSEC_PER_SEC)))], queue: nil){
                                    if runed { return }
                                    if myMovieURL != self.nowPlayingThumbMovieURL {
                                        //print("私じゃない！！")
                                        return
                                    }
                                    //resultで音量下げてたら戻す
                                    if self.volumeForceInResult > self.ReducedVolumeForceInResult {
                                        self.volumeForceInResult = 1.0
                                    }
                                    if self.volumeForceInResult >= self.ReducedVolumeForceInResult {
                                        //print("フェードアウト \(i)")
                                        //self.moviePlayerViewController?.view.alpha = 0.25
                                        if self.flgThumbMovieTopMost {
                                            self.moviePlayerViewController?.player?.volume = 0.9 * self.userData.SoundVolumeMovie * self.volumeForceInResult
                                        }else {
                                            self.moviePlayerViewController?.player?.volume = 0.45 * self.userData.SoundVolumeMovie * self.volumeForceInResult
                                        }
                                        runed = true
                                        if self.flgThumbMovieTopMost { return }
                                        
                                        let animation4 = CABasicAnimation(keyPath: "opacity")
                                        animation4.fromValue = 0.25
                                        animation4.toValue = 0.25
                                        // print("naka alpha")
                                        animation4.isRemovedOnCompletion = false
                                        animation4.fillMode = kCAFillModeForwards
                                        self.moviePlayerViewController?.view.layer.add(animation4, forKey: nil)
                                    }
                                }
                            }
                            self.moviePlayerViewController!.player?.addBoundaryTimeObserver(forTimes: [NSValue(time: CMTimeMakeWithSeconds(t30 + 30.0 + 0.1, Int32(NSEC_PER_SEC)))], queue: nil){
                                if myMovieURL != self.nowPlayingThumbMovieURL {
                                    //print("私じゃない！！")
                                    return
                                }
                                if self.flgThumbMovieTopMost { return }
                                // print("30秒でループ")
                                self.moviePlayerViewController?.player?.seek(to: CMTimeMakeWithSeconds(t30, Int32(NSEC_PER_SEC)) )
                            }
                            // 動画が終了した時に呼ばれるnotificationを登録
                            NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil, queue: nil){ notification in
                                //もし再生終了したときもループ
                                // print("終了でループ")
                                if self.flgThumbMovieStopping == true {
                                    // print("ThumbMovieStopping")
                                    return
                                }
                                DispatchQueue.main.async {
                                    //UI処理はメインスレッドの必要あり
                                    if self.flgThumbMovieTopMost {
                                        t30 = 0
                                    }
                                    self.moviePlayerViewController?.player?.seek(to: CMTimeMakeWithSeconds(t30, Int32(NSEC_PER_SEC)) )
                                    self.moviePlayerViewController?.player?.play()
                                }
                            }
                            //5秒たって実際ムービー再生できたか確認する
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0){
                                //print("\(smNum) => \(index) / \(self.indexCarousel)")
                                if index == self.indexCarousel {
                                    if let a = CachedThumbMovies.sharedInstance.cachedMovies.first(where: {$0.smNum == smNum}){
                                        //5秒たって再生(a.check==1)されていなかったらcheckフラグ=2にしてCachedThumbMoviesからの削除を促す
                                        //print("5s - a.check = \(a.check)")
                                        if a.check == 0 {
                                            a.check = 2
                                            //print("set5s - a.check = \(a.check)")
                                        }
                                    }
                                }
                            }
                        }else {
                            //読み込みのみ
                            mpvc.player?.addBoundaryTimeObserver(forTimes: [NSValue(time: CMTimeMakeWithSeconds(t30 + 0.5, Int32(NSEC_PER_SEC)))], queue: nil){
                                guard let selectedMusic = self.currentSelectedMusic() else {
                                    mpvc.player?.pause()
                                    return
                                }
                                if selectedMusic.movieURL.pregMatche_firstString(pattern: "watch/(.+)$") != smNum {
                                    //選択中indexではない。両サイドの読み込みのみのとき
                                    // print("再生された形跡見つけたらムービーを止める")
                                    mpvc.player?.pause()
                                    // print(self.currentMusics[self.indexCarousel].movieURL.pregMatche_firstString(pattern: "watch/(.+)$"))
                                    // print(smNum)
                                }
                            }
                        }
                        //  動画再生
                        mpvc.player?.volume = 0.001
                        var t30_ = t30 - 0.5
                        if t30_ < 0 { t30_ = 0.0 }
                        mpvc.player?.seek(to: CMTimeMakeWithSeconds(t30_, Int32(NSEC_PER_SEC)) )
                        mpvc.player?.play()
                    }
                }
            }
        }
    }
    func ThumbMovieReturnToBottom(opacity: Double) {
        if flgThumbMovieStopping { return }
        //if !flgThumbMovieTopMost { return }
        guard let view = self.view.viewWithTag(5050) else { return }
        
        let animationGroup = CAAnimationGroup()
        animationGroup.duration = 0.0
        animationGroup.isRemovedOnCompletion = false
        animationGroup.fillMode = kCAFillModeForwards
        //
        let animation2 = CABasicAnimation(keyPath: "transform.scale")
        animation2.fromValue = 1.0
        animation2.toValue = 1.0
        //位置(position.x)を変更する
        let animation3 = CABasicAnimation(keyPath: "position")
        animation3.fromValue = self.view.center
        animation3.toValue = self.view.center
        //透明度(opacity)を1から0にする
        let animation4 = CABasicAnimation(keyPath: "opacity")
        animation4.fromValue = opacity
        animation4.toValue = opacity

        animationGroup.animations = [animation2,animation3,animation4]
        view.layer.add(animationGroup, forKey: nil)
        
        self.view.sendSubview(toBack: view)
    }
    
    //\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
    func showHowToExtendView() -> Bool{
        // 3曲以上プレイしたら初期楽曲以外のプレイ方法を表示する
        if userData.lookedExtend == false {
            var musicIDSet:Set<Int> = []
            // プレイを開始したことがあるlevelIDから、プレイ済みの楽曲数を数える
            for levelID in userData.LevelPlayHistories.keys {
                for ms in musicDatas.musics {
                    // どの楽曲に含まれるか確認して記憶
                    if ms.levelIDs.contains(levelID) {
                        musicIDSet.insert(ms.sqlID)
                    }
                }
            }
            if  musicIDSet.count >= 3 {
                userData.lookedExtend = true
                DispatchQueue.main.async {
                    //UI処理はメインスレッドの必要あり
                    // print("HowToを表示")
                    self.performSegue(withIdentifier: "toHowToExtendView", sender: self)
                }
                return true
            }
        }
        return false
    }
    func showChangeFavoSpecView() {
        if userData.lookedChangeFavoSpec_v1500 {
            return
        }
        userData.lookedChangeFavoSpec_v1500 = true
//        DispatchQueue.main.async {
//            //UI処理はメインスレッドの必要あり
//            self.performSegue(withIdentifier: "toChangeFavoSpecView_v1500", sender: self)
//        }
    }
    func showNameRegistrationPromptIfNoName() -> Bool{
        if userData.lookedNameRegistrationIfNoName_v2000 { return false }
        if userData.Score.scores.count < 10 { return false }
        userData.lookedNameRegistrationIfNoName_v2000 = true
        if userData.UserName != "NO_NAME" { return false }
        
        // returnToMeが unwind segue の遷移完了前に呼ばれるため遅延して実行させる（viewDidAppear内で処理）
        returnToMeString = "showNameRegistrationPromptIfNoName"
        return true
    }
    func showNameRegistrationPromptIfNoName_exec(){
        let alert = UIAlertController(title:"プレイヤー名を付けてみませんか？", message: "名前はあとから設定でも変更できます", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {
            (action: UIAlertAction!) in
            if alert.textFields![0].text == UserData.sharedInstance.UserName {
                // print("field")
                return
            }
            let submittedName = alert.textFields?[0].text ?? ""
            // 通信中の重複操作や画面遷移を防ぐ
            self.view.isUserInteractionEnabled = false
            self.activityIndicator.startAnimating()
            //データベースに登録
            ServerDataHandler().postUserName(name: submittedName, userID: UserData.sharedInstance.UserID, callback: { bool in
                DispatchQueue.main.async {
                    //UI処理はメインスレッドの必要あり
                    self.view.isUserInteractionEnabled = true
                    self.activityIndicator.stopAnimating()
                    if bool {
                        //  データ保存
                        UserData.sharedInstance.UserName = submittedName
                        let alert = UIAlertController(title:"名前を登録しました", message: nil, preferredStyle: UIAlertControllerStyle.alert)
                        alert.addAction( UIAlertAction(title: "OK", style: .default, handler: nil) )
                        self.present(alert, animated: true, completion: nil)
                    }
                }
            })
        }))
        alert.addAction((UIAlertAction(title: "キャンセル", style: UIAlertActionStyle.cancel, handler: nil)))
        //textfiledの追加
        alert.addTextField(configurationHandler: {(textField: UITextField!) in
            textField.text = UserData.sharedInstance.UserName
            textField.placeholder = "プレイヤー名"
            textField.autocorrectionType = .no
            textField.autocapitalizationType = .none
        })
        self.present(alert, animated: true, completion: nil)
    }
    
    //画面遷移処理_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    @IBAction func returnToMe(segue: UIStoryboardSegue){
        // print("returnToMe: " + (segue.identifier ?? "???"))
        if segue.identifier == "fromSelectorMenu" {
            // print("back from menu")
            seSystemAudio.canselSePlay()
            //現在設定されているタグで選択された楽曲を保持する
            //currentMusics = musicDatas.getSelectMusics()
            //iCarousel再描画
            //carousel.reloadData()
            //現在選択されている曲を保持する
            //self.setCurrentLevels(index:carousel.currentItemIndex)

            self.SetMusicToCarousel()
        }else if segue.identifier == "fromGameView" {
            // print("back from gameview")
            //ゲームスコアをピッカービューに反映するためCurrentLevelsを更新
            userScore = userData.Score //保存しているスコアデータの読み込み
            self.setCurrentLevels(index:self.carousel.currentItemIndex)
            // ３曲以上プレイしたら拡張方法を表示する -> 表示なければfalse
            if !self.showHowToExtendView() {
                // ver.2.0アプデでまだNO_NAMEだったら名前変更の案内を表示 -> 表示なければfalse
                if !self.showNameRegistrationPromptIfNoName() {
                    // ユーザーネームデータの残りを取得する必要がある場合は実行
                    if userNameDataLists.sharedInstance.usernameJsonNumCount != -1 {
                        //ユーザーネームデータをロードをするため、遷移させないようにする。
                        segueing = true
                        //Indicator くるくる開始
                        activityIndicator.startAnimating()
                        //サーバから music,level,userName データを順次取得。
                        ServerDataHandler().Chance_DownloadUserNameData_FirstData { (error) in
                            self.segueing = false
                            if let error = error {
                                // print(error) //なんか失敗した。けど、とりあえずスルーして次へ。
                            }
                            DispatchQueue.main.async {
                                //UI処理はメインスレッドの必要あり
                                //Indicator隠す
                                self.activityIndicator.stopAnimating()
                            }
                        }
                    }
                }
            }
            //リザルトで再生したthumbMovieの音量を元に戻す
            // print("確認")
            if userData.thumbMoviePlay {
                self.volumeForceInResult += 0.01
                // print(self.volumeForceInResult)
                if self.volumeForceInResult >= 1.0 {
                    self.volumeForceInResult = 1.0
                }
                // print(self.volumeForceInResult)
                if self.volumeForceInResult != 1.0 {
                    // print("timer")
                    Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { timer in
                        guard let player = self.moviePlayerViewController?.player else {
                            self.volumeForceInResult = 1.0
                            timer.invalidate()
                            return
                        }
                        // print("self.volumeForceInResult=\(self.volumeForceInResult)")
                        if self.volumeForceInResult >= 1.0 {
                            self.volumeForceInResult = 1.0
                            timer.invalidate()
                            return
                        }
                        self.volumeForceInResult += (1.0 - self.ReducedVolumeForceInResult) / 15 // 1.5秒で戻す
                        if self.volumeForceInResult >= 1.0 {
                            self.volumeForceInResult = 1.0
                        }
                        player.volume = 0.45 * self.userData.SoundVolumeMovie * self.volumeForceInResult
                    })
                }else {
                    // print("play")
                    self.ThumbMoviePlay()
                }
            }else {
                // print("stop")
                //self.ThumbMovieStop()
                self.volumeForceInResult -= 0.01
                // print(self.volumeForceInResult)
                if self.volumeForceInResult >= self.ReducedVolumeForceInResult {
                    self.volumeForceInResult = 1.0
                    // print(self.volumeForceInResult)
                }else {
                    // print(self.volumeForceInResult)
                    
                    self.ThumbMovieReturnToBottom(opacity: 0.01)
                    // print("timer")
                    Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { timer in
                        guard let player = self.moviePlayerViewController?.player else {
                            self.volumeForceInResult = 1.0
                            timer.invalidate()
                            return
                        }
                        // print("self.volumeForceInResult=\(self.volumeForceInResult)")
                        if self.volumeForceInResult <= 0.0 {
                            self.ThumbMovieStop()
                            self.volumeForceInResult = 1.0
                            timer.invalidate()
                            return
                        }
                        self.volumeForceInResult -= self.ReducedVolumeForceInResult / 10 // 1.0秒で戻す
                        if self.volumeForceInResult <= 0.0 {
                            self.volumeForceInResult = 0.0
                        }
                        player.volume = 0.45 * self.userData.SoundVolumeMovie * self.volumeForceInResult
                        self.ThumbMovieReturnToBottom(opacity: 0.01)
                    })
                }
            }
            
        }else if segue.identifier == "fromEditView" {
            // print("back from editview")
            self.SetMusicToCarousel(thumbMovieForcePlay: true)
        }else if segue.identifier == "fromTableViewForTag" {
            // print("back from tableView for tag")
            self.SetMusicToCarousel()
        }else if segue.identifier == "fromTableViewForSort" {
            // print("back from tableView for Sort")
            self.SetMusicToCarousel()
        }
        //print(segue.identifier)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // print("prepare: " + (segue.identifier ?? "???"))
        
        indexCarousel = carousel.currentItemIndex
        _ = currentSelectedLevel()
        
        if segue.identifier == "toGameView" {
            //現在選択中のデータをGameViewに渡す
            /*
            let selectMovieURL:String = currentMusics[indexCarousel].movieURL
            if (musicDatas.levels[selectMovieURL]==nil){
                currentLevels = []
            }else {
                currentLevels = musicDatas.getSelectMusicLevels(selectMovieURL: selectMovieURL)
            }
             */
            //let destinationNavigationController = segue.destination as! UINavigationController
            //let gameViewController:GameView = destinationNavigationController.topViewController as! GameView
            guard let selectedMusic = currentSelectedMusic(),
                  let selectedLevel = currentSelectedLevel() else { return }
            let gameViewController:GameView = segue.destination as! GameView
            gameViewController.selectMusic = selectedMusic
            gameViewController.selectLevel = selectedLevel
            gameViewController.selectorController = self
            
            ThumbMovieStop()
            
        }else if segue.identifier == "toRankingTabBar" {
            seSystemAudio.openSePlay()
            //現在選択中のデータをRankingTabBarに渡す
            /*
            let selectMovieURL:String = currentMusics[indexCarousel].movieURL
            if (musicDatas.levels[selectMovieURL]==nil){
                currentLevels = []
            }else {
                currentLevels = musicDatas.getSelectMusicLevels(selectMovieURL: selectMovieURL)
            }
            */
            guard let selectedMusic = currentSelectedMusic(),
                  let selectedLevel = currentSelectedLevel() else { return }
            let destinationTabBarController = segue.destination as! UITabBarController
            let rankingViewController:RankingView = destinationTabBarController.viewControllers?.first as! RankingView
            //let gameViewController:GameView = segue.destination as! GameView
            rankingViewController.selectMusic = selectedMusic
            rankingViewController.selectLevel = selectedLevel
            let commentViewController:CommentView = destinationTabBarController.viewControllers?[1] as! CommentView
            //let gameViewController:GameView = segue.destination as! GameView
            commentViewController.selectMusic = selectedMusic
            commentViewController.selectLevel = selectedLevel
            commentViewController.commentPostable = false
            commentViewController.rankingViewController = rankingViewController
            
            
        }else if segue.identifier == "toSelectorMenu" {
            seSystemAudio.openSelectorMenuSePlay()
            
            let selectorMenuController:SelectorMenu = segue.destination as! SelectorMenu
            //let selectorMenuController:SelectorMenu = destinationNavigationController.topViewController as! SelectorMenu
            //let resultViewController:ResultView = segue.destination as! ResultView
            selectorMenuController.selectorController = self
            
        }else if segue.identifier == "toEditor" {
            //現在選択中のデータをEditorViewに渡す
            guard let selectedMusic = currentSelectedMusic(),
                  let selectedLevel = currentSelectedLevel() else { return }
            let editorViewController:EditorView = segue.destination as! EditorView
            editorViewController.selectMusic = selectedMusic
            editorViewController.selectLevel = selectedLevel
            editorViewController.password = password
            
            ThumbMovieStop()
            
        }else if segue.identifier == "toTableViewForTagFromSelector" {
            //遷移先のTableViewにデータを渡す
            guard let selectedMusic = currentSelectedMusic() else { return }
            let tableViewController:TableViewForTag = segue.destination as! TableViewForTag
            tableViewController.list = selectedMusic.tag
            tableViewController.currentMusic = selectedMusic
            
        }else if segue.identifier == "toWikipageWebkit" {
            //遷移先にデータを渡す
            let wikipageWibkitController:WikipageWebkitView = segue.destination as! WikipageWebkitView
            wikipageWibkitController.selectorController = self
            
            ThumbMovieStop()
            seSystemAudio.openSePlay()
            
        }else if segue.identifier == "toFavoriteView" {
            seSystemAudio.openSePlay()
            let selectorFavoriteController:SelectorFavoriteView = segue.destination as! SelectorFavoriteView
            selectorFavoriteController.selectorController = self
            // 戻ってきたときの処理
            selectorFavoriteController.onDismiss = { [weak self] changed in
                // print("onDismiss:", changed)
                guard let self else { return }
                // 本体で処理
                self.fromFavoriteView(changed: changed)
            }
            
        }else if segue.identifier == "toLikeView" {
            seSystemAudio.openSePlay()
            let selectorLikeController:SelectorLikeView = segue.destination as! SelectorLikeView
            selectorLikeController.selectorController = self
            // 戻ってきたときの処理
            selectorLikeController.onDismiss = { [weak self] changed in
                // print("onDismiss:", changed)
                guard let self else { return }
                // 本体で処理
                self.fromLikeView(changed: changed)
            }
            
        }else if segue.identifier == "fromSelector" {
            // print("titleへ")
            ThumbMovieStop()
            seSystemAudio.canselSePlay()
        }
    }
    // from処理
    func fromFavoriteView(changed: Bool){
        // print("indexCarousel: ", indexCarousel)
        if changed {
            self.SetMusicToCarousel()
            ServerDataHandler().postUserCountData()
        }
    }
    func fromLikeView(changed: Bool){
        // print("indexCarousel: ", indexCarousel)
        if changed {
            self.SetMusicToCarousel()
            ServerDataHandler().postUserCountData()
        }
    }
    //遷移の許可
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if segueing {
            return false
        }
        
        if(identifier == "toGameView"){
            guard let selectedLevel = currentSelectedLevel() else {
                //レベルが一個もなかったら遷移なし
                return false
            }
            //se
            seSystemAudio.goSePlay()
            
            //levels.noteDataにデータが入っているか確認。なければ先に取得する _/_/_/_/_/_/_/_/_/_/_/
            //(ViewControllerの初期データ取得でタイムタグも入手してると通信量大きそうだから個別に取得する)
            indexCarousel = carousel.currentItemIndex
            /*
            let selectMovieURL:String = currentMusics[indexCarousel].movieURL
            if (musicDatas.levels[selectMovieURL]==nil){
                currentLevels = []
            }else {
                currentLevels = musicDatas.getSelectMusicLevels(selectMovieURL: selectMovieURL)
            }
             */
            // 初期データにnoteData先頭16文字を含めるようにした（thumbMovie再生に最初のタイムタグを使うため）
            if selectedLevel.noteData.count <= 20 {
                // データが入っていなかったので取得する //
                //データをロードした後に遷移させるため、一度、遷移キャンセル。
                segueing = true
                
                ServerDataHandler().DownloadTimetag(level: selectedLevel) { (error) in
                    self.segueing = false
                    DispatchQueue.main.async {
                        //UI処理はメインスレッドの必要あり
                        //  Indicator隠す
                        self.activityIndicator.stopAnimating()
                        if let error = error {
                            // print(error)
                            let alert = UIAlertController(
                                title: "ゲームデータ取得エラー",
                                message: "ゲームデータを取得できませんでした。時間をおいて、もう一度お試しください。",
                                preferredStyle: .alert
                            )
                            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                            self.present(alert, animated: true, completion: nil)
                            return
                        }
                        //  遷移指示。
                        self.performSegue(withIdentifier: "toGameView", sender: self)
                    }
                }
                //Indicator くるくる開始
                activityIndicator.startAnimating()
                
                return false
            }
            
        }else if identifier == "toEditor" {
            guard let selectedLevel = currentSelectedLevel() else { return false }
            password = ""
            let alert = UIAlertController(title:"パスワード", message: nil, preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {
                (action: UIAlertAction!) in
                //print("はいをタップした時の処理")
                //Indicator くるくる開始
                self.activityIndicator.startAnimating()
                ServerDataHandler().checkLevelPassword(id: selectedLevel.sqlID, pass: alert.textFields![0].text!, userID: self.userData.UserID, callback: { (bool) in
                    //passCheck
                    DispatchQueue.main.async {
                        //  Indicator隠す
                        self.activityIndicator.stopAnimating()
                        if bool {
                            self.password = alert.textFields![0].text!
                            self.performSegue(withIdentifier: "toEditor", sender: self)
                        }else {
                            let alert = UIAlertController(title:nil, message: "パスワードが違います", preferredStyle: UIAlertControllerStyle.alert)
                            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                            self.present(alert, animated: true, completion: nil)
                        }
                    }
                })
                
            }))
            alert.addAction((UIAlertAction(title: "キャンセル", style: UIAlertActionStyle.cancel, handler: nil)))
            //textfiledの追加
            alert.addTextField(configurationHandler: {(textField: UITextField!) in
                textField.isSecureTextEntry = true // for password input
            })
            self.present(alert, animated: true, completion: nil)
            return false
            
        }else if identifier == "toRankingTabBar" {
            guard currentSelectedLevel() != nil else { return false }
        }else if identifier == "toFavoriteView" {
            if(currentLevels.count<1){
                //レベルが一個もなかったら遷移なし
                return false
            }
            
        }else if identifier == "toLikeView" {
            if(currentLevels.count<1){
                //レベルが一個もなかったら遷移なし
                return false
            }
        }
        return true
    }
    //\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
    
    // バージョンアップ時の処理
    func migration(){
        if userData.doneJustPlayedScoreLevelMigration == false {
            let savedLevelIDs = userData.JustPlayedScore.scores.keys
            // 既存の未送信スコアがある場合は、musicデータの読み込み完了後に移行する。
            if savedLevelIDs.isEmpty || musicDatas.levels.isEmpty == false {
                let forcedFullLevelIDs: Set<Int> = [
                    6751, 9009, 4533, 3346, 3575, 3831, 794, 3143, 3145, 3322,
                    3500, 3501, 3523, 3524, 4919, 5253, 6370, 7374, 4035, 8344,
                    8190, 7684, 6082, 1486, 2745, 3925, 6376, 6462, 7342, 7343,
                    7845, 8973, 8970, 9481, 9477, 9005, 9007, 6459, 708, 704,
                    688, 5985, 6325, 4423, 7580, 5522, 9383
                ]
                var currentLevels: [Int:Int] = [:]

                for levels in musicDatas.levels.values {
                    for levelData in levels {
                        guard let levelID = levelData.sqlID,
                              let level = levelData.level else {
                            continue
                        }
                        currentLevels[levelID] = level
                    }
                }

                var scoreLevels = userData.JustPlayedScoreLevel
                for levelID in savedLevelIDs where scoreLevels[levelID] == nil {
                    if forcedFullLevelIDs.contains(levelID) {
                        scoreLevels[levelID] = 100
                    } else {
                        // DBから削除済みなど、musicデータにない譜面はFULLとして保持する。
                        scoreLevels[levelID] = currentLevels[levelID] ?? 100
                    }
                }

                userData.JustPlayedScoreLevel = scoreLevels
                userData.doneJustPlayedScoreLevelMigration = true
            }
        }

        if userData.doneScoreLevelMigration == false {
            let savedLevelIDs = userData.Score.scores.keys
            // 既存スコアがある場合は、musicデータの読み込み完了後に移行する。
            if savedLevelIDs.isEmpty || musicDatas.levels.isEmpty == false {
                let forcedFullLevelIDs: Set<Int> = [
                    6751, 9009, 4533, 3346, 3575, 3831, 794, 3143, 3145, 3322,
                    3500, 3501, 3523, 3524, 4919, 5253, 6370, 7374, 4035, 8344,
                    8190, 7684, 6082, 1486, 2745, 3925, 6376, 6462, 7342, 7343,
                    7845, 8973, 8970, 9481, 9477, 9005, 9007, 6459, 708, 704,
                    688, 5985, 6325, 4423, 7580, 5522, 9383
                ]
                var currentLevels: [Int:Int] = [:]

                for levels in musicDatas.levels.values {
                    for levelData in levels {
                        guard let levelID = levelData.sqlID,
                              let level = levelData.level else {
                            continue
                        }
                        currentLevels[levelID] = level
                    }
                }

                var scoreLevels = userData.ScoreLevel
                for levelID in savedLevelIDs where scoreLevels[levelID] == nil {
                    if forcedFullLevelIDs.contains(levelID) {
                        scoreLevels[levelID] = 100
                    } else {
                        // DBから削除済みなど、musicデータにない譜面はFULLとして保持する。
                        scoreLevels[levelID] = currentLevels[levelID] ?? 100
                    }
                }

                userData.ScoreLevel = scoreLevels
                userData.doneScoreLevelMigration = true
            }
        }

        if userData.doneFavoriteUpdate_v2000 == false {  // まだ済んでない。done変数なので default は true
            if musicDatas.levels.count > 0 {  // もしかしたらver.2.0にしてmusicDatas空のまま突破して来られたら困るので、その場合updateフラグが消されないようにする
                var favoriteMusicIDs = userData.MyFavorite3
                var likedLevelIDs = userData.MyLike
                
                for level_sqlID in userData.MyFavoriteAll_v1500 {
                    for (movieURL, levels) in musicDatas.levels {
                        guard levels.contains(where: { $0.sqlID == level_sqlID }) else {
                            continue
                        }
                        // print("level_sqlID=",level_sqlID)
                        likedLevelIDs[level_sqlID] = -2
                        
                        if let music = musicDatas.musics.first(where: { $0.movieURL == movieURL }) {
                            favoriteMusicIDs.insert(music.sqlID)
                            // print("music_sqlID=",music.sqlID)
                        }
                        
                        break
                    }
                }
                
                userData.MyFavorite3 = favoriteMusicIDs
                userData.MyLike = likedLevelIDs
                userData.doneFavoriteUpdate_v2000 = true
            }
        }
    }
}
