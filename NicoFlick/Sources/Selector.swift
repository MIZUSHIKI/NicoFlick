//
//  Select.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/04/29.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//

import UIKit

class Selector: UIViewController,UIPickerViewDelegate, UIPickerViewDataSource, iCarouselDataSource, iCarouselDelegate {
    
    @IBOutlet var musicTitle: UILabel!
    @IBOutlet var musicArtist: UILabel!
    @IBOutlet var musicLength: UILabel!
    @IBOutlet var musicTags: UILabel!
    @IBOutlet var levelSpeed: UILabel!
    @IBOutlet var musicNum: UILabel!
    
    @IBOutlet var carousel: iCarousel!
    @IBOutlet var levelSelectPicker: UIPickerView!
    @IBOutlet var buttonRankingComment: UIButton!
    @IBOutlet var labelRankingComment: UILabel!
    @IBOutlet var EditButtonView: UIView!
    @IBOutlet weak var rankingTimeLabel: UILabel!
    @IBOutlet weak var commentTimeLabel: UILabel!
    
    @IBOutlet weak var colorStar: UIImageView!
    @IBOutlet weak var favoriteNum: UILabel!
    @IBOutlet weak var favoriteNum2: UILabel!
    @IBOutlet weak var levelSortButton: UIButton!
    @IBOutlet weak var musicSortButton: UIButton!
    
    
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
    
    //表示する楽曲を tag で抽出する
    var currentMusics:[musicData] = [] //tagによって選択されている楽曲
    var currentLevels:[levelData] = [] //iCarouselで選択されているcurrentMusicのLevelが入る
    var indexCarousel = 0
    var indexPicker = 0
    var maeMusic:musicData? = nil
    
    //遷移中フラグ
    var segueing = false
    //Indicator
    private var activityIndicator:UIActivityIndicatorView!
    
    //遷移時に受け取り
    var returnToMeString:String = ""
    var returnToMeData:Int = 0
    var password = ""
    
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
        //お気に入りソート関係
        levelSortButton.alpha = (userData.LevelSortCondition != 0) ? 0.6 : 0.2
        musicSortButton.alpha = (userData.musicSortCondition != 0) ? 0.6 : 0.2
        
        //現在設定されているタグで選択された楽曲を保持する
        //currentMusics = musicDatas.getSelectMusics()
        //現在選択されている曲を保持する
        self.setCurrentLevels(index:-1)
        //iCarousel再描画
        carousel.reloadData()

        self.SetMusicToCarousel()
        
        self.showHowToExtendView()
    }
    func SetMusicToCarousel() {
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
                
                //iCarousel再描画
                self.carousel.reloadData()
                //前回選択していた曲に飛べれば飛ぶ
                var selectIndex = 0
                if self.numberRoll_index == -1 {
                    print("mae \(self.maeMusic?.movieURL)")
                    if let selectMusic = self.maeMusic {
                        if let firstIndex = self.currentMusics.firstIndex(where: {$0.movieURL == selectMusic.movieURL}){
                            print("fi \(firstIndex)")
                            selectIndex = firstIndex
                        }
                    }
                }else {
                    selectIndex = self.numberRoll_index
                    self.numberRoll_index = -1
                }
                self.carousel.currentItemIndex = selectIndex
                //現在選択されている曲を保持する
                self.setCurrentLevels(index:self.carousel.currentItemIndex)
            }
        })
    }
    
    override func viewDidLayoutSubviews() {
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
    }
    override func viewDidAppear(_ animated: Bool) {
        if timer == nil {
            timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.update), userInfo: nil, repeats: true)
            timer?.fire()
            RunLoop.main.add(timer!, forMode: .commonModes)
        }
        if returnToMeString != "" {
            //returnToMe from できなくて
            print("selector return :\(returnToMeString)")
            let retStr = returnToMeString.removingPercentEncoding
            if var retTag = retStr?.pregMatche_firstString(pattern: "tag=(.*?)(&sort=|$)"),
               let retSort = retStr?.pregMatche_firstString(pattern: "sort=(.*?)(&tag=|$)"){
                
                retTag = retTag.trimmingCharacters(in: .whitespaces)
                retTag = retTag.pregReplace(pattern: "\\s*/(and|AND)/\\s*", with: "/and/")
                retTag = retTag.pregReplace(pattern: "\\s+", with: " or ")
                retTag = retTag.pregReplace(pattern: "/and/", with: " ")
                
                userData.SelectedMusicCondition.tags = retTag
                if retSort != "" {
                    userData.SelectedMusicCondition.sortItem = retSort
                }

                self.maeMusic = nil
                self.SetMusicToCarousel()
            }
            returnToMeString = ""
        }
    }
    override func viewWillDisappear(_ animated: Bool) {
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
        itemView.loadImage(urlString: currentMusics[index].thumbnailURL)
            itemView.contentMode = .center
        //}
        return itemView
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
    }
    func setCurrentLevels(index:Int){
        if index == -1 {
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
            colorStar.isHidden = true
            favoriteNum.isHidden = true
            favoriteNum2.isHidden = true
            rankingTimeLabel.isHidden = true
            commentTimeLabel.isHidden = true
            EditButtonView.isHidden = true
            return
        }
        self.musicTitle.text = currentMusics[index].title
        self.musicArtist.text = currentMusics[index].artist
        self.musicLength.text = currentMusics[index].movieLength
        let tags = currentMusics[index].tags
        self.musicTags.text = tags
        let attrText = NSMutableAttributedString(string: tags!)
        for tagp in userData.SelectedMusicCondition.tag {
            let tag = tagp.word
            print(tag)
            let regTag = NSRegularExpression.escapedPattern(for: tag)
            if let regex = try? NSRegularExpression(pattern: "(^|\\s)\(regTag)(\\s|$)", options: []) {
                let targetStringRange = NSRange(location: 0, length: tags!.count)
                let result = regex.firstMatch(in: tags!, options: [], range: targetStringRange)
                if result != nil {
                    for j in 0 ..< result!.numberOfRanges {
                        let range = result!.range(at: j)
                        attrText.addAttribute(.foregroundColor, value: UIColor.black, range: range)
                        print(range)
                    }
                }
            }
        }
        self.musicTags.attributedText = attrText
        self.musicNum.text = "\(index+1) / \(currentMusics.count)"
        if (musicDatas.levels[currentMusics[index].movieURL]==nil){
            currentLevels = []
            self.buttonRankingComment.isHidden = true
            self.labelRankingComment.isHidden = true
        }else {
            currentLevels = musicDatas.getSelectMusicLevels(selectMovieURL: currentMusics[index].movieURL)
            self.buttonRankingComment.isHidden = false
            self.labelRankingComment.isHidden = false
            if currentLevels.count > levelSelectPicker.selectedRow(inComponent: 0) {
                UpdateObject_Level(currentLevel: currentLevels[levelSelectPicker.selectedRow(inComponent: 0)])
            }
        }
        self.levelSelectPicker.reloadAllComponents()
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
                            print("hitRow=\(hitRow)")
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
        //favorite反映
        colorStar.isHidden = !userData.MyFavorite.contains(currentLevel.sqlID)
        let fc = Int(currentLevel.favoriteCount / 10) * 10
        favoriteNum.text = String(fc)
        favoriteNum2.text = String(fc)
        favoriteNum.isHidden = ( fc == 0 )
        favoriteNum2.isHidden = ( fc == 0 )
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy.MM.dd"
        if userData.SelectedMusicCondition.sortItem == "最近ハイスコアが更新された曲順" && currentLevel.scoreTime > 0 {
            rankingTimeLabel.text = dateFormatter.string(for: Date(timeIntervalSince1970: TimeInterval(currentLevel.scoreTime)))
            rankingTimeLabel.isHidden = false
        }else{
            rankingTimeLabel.isHidden = true
        }
        print("currentLevel.scoreTime=\(currentLevel.scoreTime)")
        if userData.SelectedMusicCondition.sortItem == "最近コメントされた曲順" && currentLevel.commentTime > 0 {
            commentTimeLabel.text = dateFormatter.string(for: Date(timeIntervalSince1970: TimeInterval(currentLevel.commentTime)))
            commentTimeLabel.isHidden = false
        }else{
            commentTimeLabel.isHidden = true
        }
        print("currentLevel.commentTime=\(currentLevel.commentTime)")
        
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
        labelView1.textAlignment = NSTextAlignment.center
        myView.addSubview(labelView1)
        //製作者
        let labelView2 = UILabel()
        labelView2.text = currentLevels[row].creator
        labelView2.frame = CGRect(x: 5, y: 10+20+5  + 10, width: UIScreen.main.bounds.size.width-10, height: 20)
        labelView2.textColor = UIColor.gray
        labelView2.font = UIFont.systemFont(ofSize:10)
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
        labelView4.frame = CGRect(x: 10, y: 25, width: 70, height: 30)
        labelView4.textColor = UIColor.black
        labelView4.font = UIFont.systemFont(ofSize:30)
        labelView4.adjustsFontSizeToFitWidth = true
        labelView4.textAlignment = NSTextAlignment.center
        myView.addSubview(labelView4)
        //HighScore
        let labelView5 = UILabel()
        labelView5.text = score
        labelView5.frame = CGRect(x: 10, y: 0/*10+20+5+15+5+5*/, width: UIScreen.main.bounds.size.width-10, height: 20)
        labelView5.textColor = UIColor.gray
        labelView5.font = UIFont.systemFont(ofSize:10)
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
    
    @IBAction func TapTitleLabel(_ sender: UITapGestureRecognizer) {
        self.TapSortableLabel()
    }
    @IBAction func TapArtistLabel(_ sender: UITapGestureRecognizer) {
        self.TapSortableLabel()
    }
    @IBAction func TapLengthLabel(_ sender: UITapGestureRecognizer) {
        self.TapSortableLabel()
    }
    @IBAction func TapSpeedLabel(_ sender: UITapGestureRecognizer) {
        self.TapSortableLabel()
    }
    func TapSortableLabel() {
        self.performSegue(withIdentifier: "toTableViewForSortFromSelector", sender: self)
    }
    @IBAction func TapMusicNumLabel(_ sender: UITapGestureRecognizer) {
        let title = "曲の選択"
        let message = "\n\n\n\n\n\n\n\n\n\n" //改行入れないとOKCancelがかぶる

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler:{
          (action: UIAlertAction!) -> Void in
            self.SetMusicToCarousel()
        })

        // PickerView
        let pv = UIPickerView()
        pv.tag = 123
        pv.frame = CGRect(x: 0, y: 60, width: alert.view.bounds.width * 0.7, height: 150) // 配置、サイズ
        pv.dataSource = self
        pv.delegate = self
        pv.selectRow(indexCarousel, inComponent: 0, animated: true) // 初期値
        print("indexC = \(indexCarousel)")
        alert.view.addSubview(pv)

        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }
    @IBAction func TapTagLabel(_ sender: UITapGestureRecognizer) {
        self.performSegue(withIdentifier: "toTableViewForTagFromSelector", sender: self)
    }
    @IBAction func favoriteButton(_ sender: UIButton) {
        if currentMusics.indices.contains(indexCarousel) == false {
            return
        }
        let selectMovieURL:String = currentMusics[indexCarousel].movieURL
        if musicDatas.levels.count > 0 && musicDatas.levels[selectMovieURL] == nil {
            return
        }
        let currentLevel = currentLevels[levelSelectPicker.selectedRow(inComponent: 0)]
        if userData.MyFavorite.contains(currentLevel.sqlID){
            userData.MyFavorite.remove(currentLevel.sqlID)
            userData.FavoriteCount.subFavoriteCount(levelID: currentLevel.sqlID)
        }else{
            userData.MyFavorite.insert(currentLevel.sqlID)
            userData.FavoriteCount.addFavoriteCount(levelID: currentLevel.sqlID)
        }
        colorStar.isHidden = !userData.MyFavorite.contains(currentLevel.sqlID)
        
    }
    @IBAction func levelSortButton(_ sender: UIButton) {
        
        let alert = UIAlertController(title:nil, message: "お気に入りソート", preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addAction( UIAlertAction(title: "なし", style: .default, handler: {_ in
            self.userData.LevelSortCondition = 0
            self.SetMusicToCarousel()
            self.levelSortButton.alpha = (self.userData.LevelSortCondition != 0) ? 0.6 : 0.2
        }) )
        alert.addAction( UIAlertAction(title: "お気に入りを上に集める", style: .default, handler: {_ in
            self.userData.LevelSortCondition = 1
            self.SetMusicToCarousel()
            self.levelSortButton.alpha = (self.userData.LevelSortCondition != 0) ? 0.6 : 0.2
        }) )
        alert.addAction( UIAlertAction(title: "キャンセル", style: .cancel, handler: nil) )
        self.present(alert, animated: true, completion: nil)
    }
    @IBAction func musicSortButton(_ sender: UIButton) {
        let alert = UIAlertController(title:nil, message: "お気に入りソート", preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addAction( UIAlertAction(title: "なし", style: .default, handler: {_ in
            self.userData.musicSortCondition = 0
            self.SetMusicToCarousel()
            self.musicSortButton.alpha = (self.userData.musicSortCondition != 0) ? 0.6 : 0.2
        }) )
        alert.addAction( UIAlertAction(title: "お気に入りを含む曲を先頭に集める", style: .default, handler: {_ in
            self.userData.musicSortCondition = 1
            self.SetMusicToCarousel()
            self.musicSortButton.alpha = (self.userData.musicSortCondition != 0) ? 0.6 : 0.2
        }) )
        alert.addAction( UIAlertAction(title: "キャンセル", style: .cancel, handler: nil) )
        self.present(alert, animated: true, completion: nil)
    }
    
    
    //\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
    func showHowToExtendView() -> Bool{
        // ５曲以上プレイしたら初期楽曲以外のプレイ方法を表示する
        if userData.lookedExtend == false {
            var musicIDSet:Set<Int> = []
            // スコアデータからプレイしたlevelIDを取得
            for (sKey,_) in userData.Score.scores {
                for ms in musicDatas.musics {
                    // どの楽曲に含まれるか確認して記憶
                    if ms.levelIDs.contains(sKey) {
                        musicIDSet.insert(ms.sqlID)
                    }
                }
            }
            if  musicIDSet.count >= 5 {
                userData.lookedExtend = true
                DispatchQueue.main.async {
                    //UI処理はメインスレッドの必要あり
                    print("HowToを表示")
                    self.performSegue(withIdentifier: "toHowToExtendView", sender: self)
                }
                return true
            }
        }
        return false
    }
    
    //画面遷移処理_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    @IBAction func returnToMe(segue: UIStoryboardSegue){
        print("returnToMe")
        if segue.identifier == "fromSelectorMenu" {
            print("back from menu")
            //現在設定されているタグで選択された楽曲を保持する
            //currentMusics = musicDatas.getSelectMusics()
            //iCarousel再描画
            //carousel.reloadData()
            //現在選択されている曲を保持する
            //self.setCurrentLevels(index:carousel.currentItemIndex)

            self.SetMusicToCarousel()
        }else if segue.identifier == "fromGameView" {
            print("back from gameview")
            //ゲームスコアをピッカービューに反映するためCurrentLevelsを更新
            userScore = userData.Score //保存しているスコアデータの読み込み
            self.setCurrentLevels(index:self.carousel.currentItemIndex)
            if !self.showHowToExtendView() {
                //ユーザーネームデータをロードをするため、遷移させないようにする。
                segueing = true
                //Indicator くるくる開始
                activityIndicator.startAnimating()
                //サーバから music,level,userName データを順次取得。
                ServerDataHandler().Chance_DownloadUserNameData_FirstData { (error) in
                    self.segueing = false
                    if let error = error {
                        print(error) //なんか失敗した。けど、とりあえずスルーして次へ。
                    }
                    DispatchQueue.main.async {
                        //UI処理はメインスレッドの必要あり
                        //Indicator隠す
                        self.activityIndicator.stopAnimating()
                    }
                }
            }
        }else if segue.identifier == "fromEditView" {
            print("back from editview")
            self.SetMusicToCarousel()
        }else if segue.identifier == "fromTableViewForTag" {
            print("back from tableView for tag")
            self.SetMusicToCarousel()
        }else if segue.identifier == "fromTableViewForSort" {
            print("back from tableView for Sort")
            self.SetMusicToCarousel()
        }
        //print(segue.identifier)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        indexCarousel = carousel.currentItemIndex
        indexPicker = levelSelectPicker.selectedRow(inComponent: 0)
        
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
            let gameViewController:GameView = segue.destination as! GameView
            gameViewController.selectMusic = currentMusics[indexCarousel]
            gameViewController.selectLevel = currentLevels[levelSelectPicker.selectedRow(inComponent: 0)]
            
        }else if segue.identifier == "toRankingTabBar" {
            //現在選択中のデータをRankingTabBarに渡す
            /*
            let selectMovieURL:String = currentMusics[indexCarousel].movieURL
            if (musicDatas.levels[selectMovieURL]==nil){
                currentLevels = []
            }else {
                currentLevels = musicDatas.getSelectMusicLevels(selectMovieURL: selectMovieURL)
            }
            */
            let destinationTabBarController = segue.destination as! UITabBarController
            let rankingViewController:RankingView = destinationTabBarController.viewControllers?.first as! RankingView
            //let gameViewController:GameView = segue.destination as! GameView
            rankingViewController.selectMusic = currentMusics[indexCarousel]
            rankingViewController.selectLevel = currentLevels[levelSelectPicker.selectedRow(inComponent: 0)]
            let commentViewController:CommentView = destinationTabBarController.viewControllers?[1] as! CommentView
            //let gameViewController:GameView = segue.destination as! GameView
            commentViewController.selectMusic = currentMusics[indexCarousel]
            commentViewController.selectLevel = currentLevels[levelSelectPicker.selectedRow(inComponent: 0)]
            commentViewController.commentPostable = false
            
        }else if segue.identifier == "toSelectorMenu" {
            
            let selectorMenuController:SelectorMenu = segue.destination as! SelectorMenu
            //let selectorMenuController:SelectorMenu = destinationNavigationController.topViewController as! SelectorMenu
            //let resultViewController:ResultView = segue.destination as! ResultView
            selectorMenuController.selectorController = self
            
        }else if segue.identifier == "toEditor" {
            //現在選択中のデータをEditorViewに渡す
            let editorViewController:EditorView = segue.destination as! EditorView
            editorViewController.selectMusic = currentMusics[indexCarousel]
            editorViewController.selectLevel = currentLevels[indexPicker]
            editorViewController.password = password
            
        }else if segue.identifier == "toTableViewForTagFromSelector" {
            //遷移先のTableViewにデータを渡す
            let tableViewController:TableViewForTag = segue.destination as! TableViewForTag
            tableViewController.list = currentMusics[indexCarousel].tag
            tableViewController.currentMusic = currentMusics[indexCarousel]
            
        }else if segue.identifier == "toWikipageWebkit" {
            //遷移先にデータを渡す
            let wikipageWibkitController:WikipageWebkitView = segue.destination as! WikipageWebkitView
            wikipageWibkitController.selectorController = self
        }
    }
    //遷移の許可
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if segueing {
            return false
        }
        
        if(identifier == "toGameView"){
            
            if(currentLevels.count<1){
                //レベルが一個もなかったら遷移なし
                return false
            }
            
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
            //選択しているlevel
            indexPicker = levelSelectPicker.selectedRow(inComponent: 0)
            if( currentLevels[indexPicker].noteData == "" ){
                // データが入っていなかったので取得する //
                //データをロードした後に遷移させるため、一度、遷移キャンセル。
                segueing = true
                
                ServerDataHandler().DownloadTimetag(level: currentLevels[indexPicker]) { (error) in
                    self.segueing = false
                    DispatchQueue.main.async {
                        //UI処理はメインスレッドの必要あり
                        //  Indicator隠す
                        self.activityIndicator.stopAnimating()
                        if let error = error {
                            print(error) //なんか失敗した。
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
            password = ""
            let alert = UIAlertController(title:"パスワード", message: nil, preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {
                (action: UIAlertAction!) in
                //print("はいをタップした時の処理")
                //Indicator くるくる開始
                self.activityIndicator.startAnimating()
                ServerDataHandler().checkLevelPassword(id: self.currentLevels[self.levelSelectPicker.selectedRow(inComponent: 0)].sqlID, pass: alert.textFields![0].text!, callback: { (bool) in
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
        }
        return true
    }
    //\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
}
