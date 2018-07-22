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
    
    
    //保存データ
    let userData = UserData.sharedInstance
    var userScore = UserScore() //読み取り用で保存データから取り出しておく
    //音楽データ(シングルトン)
    var musicDatas:MusicDataLists = MusicDataLists.sharedInstance
    
    //表示する楽曲を tag で抽出する
    var currentMusics:[musicData] = [] //tagによって選択されている楽曲
    var currentLevels:[levelData] = [] //iCarouselで選択されているcurrentMusicのLevelが入る
    var indexCarousel = 0
    var indexPicker = 0
    
    //遷移中フラグ
    var segueing = false
    //Indicator
    private var activityIndicator:UIActivityIndicatorView!
    
    //遷移時に受け取り
    var returnToMeData:Int = 0
    
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
        
        //現在設定されているタグで選択された楽曲を保持する
        //currentMusics = musicDatas.getSelectMusics()
        //現在選択されている曲を保持する
        self.setCurrentLevels(index:-1)
        //iCarousel再描画
        carousel.reloadData()

        self.SetMusicToCarousel()
    }
    func SetMusicToCarousel() {
        //Indicator くるくる開始
        activityIndicator.startAnimating()
        activityIndicator.isHidden = false
        //現在設定されているタグ・ソートで選択された楽曲を保持。
        // ネット接続処理を挟む可能性があるからコールバック。（あとクルクルさせとく）
        musicDatas.getSelectMusics(callback: { (musics) in
            self.currentMusics = musics
            
            DispatchQueue.main.async {
                //UI処理はメインスレッドの必要あり
                //Indicator隠す
                self.activityIndicator.stopAnimating()
                self.activityIndicator.isHidden=true
                
                //iCarousel再描画
                self.carousel.reloadData()
                //現在選択されている曲を保持する
                self.setCurrentLevels(index:self.carousel.currentItemIndex)
            }
        })
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
            return
        }
        self.musicTitle.text = currentMusics[index].title
        self.musicArtist.text = currentMusics[index].artist
        self.musicLength.text = currentMusics[index].movieLength
        self.musicTags.text = currentMusics[index].tags
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
                self.levelSpeed.text = "speed: "+String(currentLevels[levelSelectPicker.selectedRow(inComponent: 0)].speed)
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
        return 80
    }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return currentLevels.count
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        return self.UIViewForLevelSelectPicker(row: row)
    }
    
    //レベルセレクト　ピッカービュー デザイン
    func UIViewForLevelSelectPicker(row :Int) -> UIView {
        let myView: UIView = UIView()
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
        if let us = userScore.scores[currentLevels[row].sqlID] {
            score = "HighScore: "+String(us[0])
            rank = Score.RankStr[us[1]]
            if rank == "False" {
                rank = ""
            }
        }
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
        labelView5.frame = CGRect(x: 5, y: 0/*10+20+5+15+5+5*/, width: UIScreen.main.bounds.size.width-10, height: 20)
        labelView5.textColor = UIColor.gray
        labelView5.font = UIFont.systemFont(ofSize:10)
        labelView5.textAlignment = NSTextAlignment.left
        myView.addSubview(labelView5)
        
        //myView1.alpha = 0.3
        
        return myView
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        //スピード反映
        if currentLevels.count > row {
            levelSpeed.text = "speed: "+String(currentLevels[row].speed)
        }
    }
    //\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

    
    //画面遷移処理_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    @IBAction func returnToMe(segue: UIStoryboardSegue){
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
        }
        //print(segue.identifier)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        indexCarousel = carousel.currentItemIndex
        indexPicker = levelSelectPicker.selectedRow(inComponent: 0)
        
        if segue.identifier == "toGameView" {
            //現在選択中のデータをGameViewに渡す
            let selectMovieURL:String = currentMusics[indexCarousel].movieURL
            if (musicDatas.levels[selectMovieURL]==nil){
                currentLevels = []
            }else {
                currentLevels = musicDatas.getSelectMusicLevels(selectMovieURL: selectMovieURL)
            }
            //let destinationNavigationController = segue.destination as! UINavigationController
            //let gameViewController:GameView = destinationNavigationController.topViewController as! GameView
            let gameViewController:GameView = segue.destination as! GameView
            gameViewController.selectMusic = currentMusics[indexCarousel]
            gameViewController.selectLevel = currentLevels[levelSelectPicker.selectedRow(inComponent: 0)]
            
        }else if segue.identifier == "toRankingTabBar" {
            //現在選択中のデータをRankingTabBarに渡す
            let selectMovieURL:String = currentMusics[indexCarousel].movieURL
            if (musicDatas.levels[selectMovieURL]==nil){
                currentLevels = []
            }else {
                currentLevels = musicDatas.getSelectMusicLevels(selectMovieURL: selectMovieURL)
            }
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
            let selectMovieURL:String = currentMusics[indexCarousel].movieURL
            if (musicDatas.levels[selectMovieURL]==nil){
                currentLevels = []
            }else {
                currentLevels = musicDatas.getSelectMusicLevels(selectMovieURL: selectMovieURL)
            }
            //選択しているlevel
            indexPicker = levelSelectPicker.selectedRow(inComponent: 0)
            if( currentLevels[indexPicker].noteData == "" ){
                // データが入っていなかったので取得する //
                //データをロードした後に遷移させるため、一度、遷移キャンセル。
                segueing = true
                //データベース接続、noteDataロード。
                let session = URLSession(configuration: URLSessionConfiguration.default)
                let url = URL( string:AppDelegate.PHPURL+"?req=timetag&id="+String(currentLevels[indexPicker].sqlID) )!
                let task = session.dataTask(with: url){(data,responce,error) in
                    if error != nil {
                        print("notesLoad-error")
                        self.segueing = false
                        return
                    }
                    let jsonDic = (try! JSONSerialization.jsonObject(with: data!, options: [])) as! Dictionary<String,String>
                    //musicDatasに保存（次回からロードしなくなる）
                    self.musicDatas.levels[selectMovieURL]?.sorted{ $0.level < $1.level }[self.indexPicker].noteData = jsonDic["notes"]
                    
                    DispatchQueue.main.async {
                        //UI処理はメインスレッドの必要あり
                        //  Indicator隠す
                        self.activityIndicator.stopAnimating()
                        self.activityIndicator.isHidden=true
                        //  遷移指示。
                        self.performSegue(withIdentifier: "toGameView", sender: self)
                        self.segueing = false
                    }
                }
                task.resume()
                
                //Indicator くるくる開始
                activityIndicator.startAnimating()
                activityIndicator.isHidden = false
                
                return false
            }
        }
        return true
    }
    //\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
}
