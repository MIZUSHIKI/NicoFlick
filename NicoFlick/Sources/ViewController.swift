//
//  ViewController.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/04/29.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var designCoopLabel: UILabel!
    
    //音楽データ
    var musicDatas:MusicDataLists = MusicDataLists.sharedInstance
    //各ユーザーのネームデータ
    var userNameDatas:userNameDataLists = userNameDataLists.sharedInstance
    //効果音プレイヤー(シングルトン)
    var seSystemAudio:SESystemAudio = SESystemAudio.sharedInstance
    
    //遷移中フラグ
    var segueing = false
    //Indicator（ネット処理中 画面中央でくるくるさせる）
    private var activityIndicator:UIActivityIndicatorView!
    
    var slashView:SlashShadeView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        //最初期処理
        //  ユニークユーザーIDの作成
        let userData = UserData.sharedInstance
        print( "uuid = \(userData.UserID)" ) //ユーザーID 初めてなら自動で生成される
        
        musicDatas.userID = userData.UserID //levelが自分の編集中のものであるか判別するためにmusicDatasで持っておく

        //Indicatorを作成
        activityIndicator = Indicator(center: self.view.center).view
        self.view.addSubview(activityIndicator)
        
        //バージョンアップ時に必要な処理があれば実行
        self.migration()
        userData.MyVersion = AppDelegate.Version
        
        //「デザイン募集中」が気になる人は消せるように
        designCoopLabel.isHidden = userData.lookedDesignCoop_v1900
        
        //上昇斜め背景
        let frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height + 15.0)
        slashView = SlashShadeView.init(frame: frame, color: UIColor.init(red: 0.60, green: 0.70, blue: 1.0, alpha: 0.035), lineWidth: 1.5, space: 15)
        self.view.addSubview(slashView!)
        self.view.sendSubview(toBack: slashView!)
        
        UIView.animate(withDuration: 0.75, delay: 0.0, options: [.repeat, .curveLinear], animations: {self.slashView?.frame.origin.y = -15}, completion: {_ in self.slashView?.frame.origin.y = 0})
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.viewWillEnter), name: .UIApplicationWillEnterForeground, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        UIView.animate(withDuration: 0.75, delay: 0.0, options: [.repeat, .curveLinear], animations: {self.slashView?.frame.origin.y = -15}, completion: {_ in self.slashView?.frame.origin.y = 0})
    }
    @objc func viewWillEnter(notification: NSNotification){
        UIView.animate(withDuration: 0.75, delay: 0.0, options: [.repeat, .curveLinear], animations: {self.slashView?.frame.origin.y = -15}, completion: {_ in self.slashView?.frame.origin.y = 0})
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func infoButton(_ sender: UIButton) {
        let alert = UIAlertController(title:"NicoFlickはフリック入力リズムゲーである 故「ミクフリック」の パクリ、オマージュ、リスペクト、難民先 作品です。", message: """

−2016年7月19日−
ミクフリック/02 サービス終了

−2017年9月29日−
ミクフリック(初代) サービス終了

−2017年9月20日−
　iOS11リリース（32bitアプリなので両方起動できなくなる）
""", preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addAction( UIAlertAction(title: "アプリレビューを見る", style: .default, handler: {_ in
            
            guard let url = URL(string: "https://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=1415478437&pageNumber=0&sortOrdering=2&type=Purple+Software&mt=8") else { return }
            UIApplication.shared.open(url)
        }) )
        alert.addAction( UIAlertAction(title: "デザイン協力募集中(GitHub)", style: .default, handler: {_ in
            
            guard let url = URL(string: "https://github.com/MIZUSHIKI/NicoFlick/blob/master/README.md") else { return }
            UIApplication.shared.open(url)
        }) )
        alert.addAction( UIAlertAction(title: "OK", style: .default, handler: nil) )
        self.present(alert, animated: true, completion: nil)
        //
        UserData.sharedInstance.lookedDesignCoop_v1900 = false
        designCoopLabel.isHidden = false
    }
    @IBAction func TapDesignCoopLabel(_ sender: UITapGestureRecognizer) {
        UserData.sharedInstance.lookedDesignCoop_v1900 = true
        designCoopLabel.isHidden = true
    }
    //画面遷移処理_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    
    @IBAction func returnToMe(segue: UIStoryboardSegue){
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toSelector" {
            print("toSelector")
        }
    }
    //遷移の許可
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if segueing {
            //遷移中。２回目タップは受け付けないようにする。
            return false
        }
        
        if identifier == "toSelector" || identifier == "toUserCard" {
            //se
            seSystemAudio.start2SePlay()
            //データをロードした後に遷移させるため、一度、遷移キャンセル。
            segueing = true //遷移中であることを記憶。しないと遷移中に連続タップで何回もデータロードされる。
            //Indicator くるくる開始
            activityIndicator.startAnimating()

            //サーバから music,level,userName データを順次取得。
            ServerDataHandler().DownloadMusicDataAndUserNameData { (error) in
                if let error = error {
                    print(error) //なんか失敗した。けど、とりあえずスルーして次へ。
                }
                DispatchQueue.main.async {
                    //UI処理はメインスレッドの必要あり
                    //Indicator隠す
                    self.activityIndicator.stopAnimating()
                    if AppDelegate.ServerErrorMessage != "" {
                        let alert = UIAlertController(title:"サーバエラー", message: AppDelegate.ServerErrorMessage, preferredStyle: UIAlertControllerStyle.alert)
                        alert.addAction( UIAlertAction(title: "OK", style: .default, handler: {_ in
                            AppDelegate.ServerErrorMessage = ""
                            //エラーメッセージ確認後、遷移指示
                            self.segueing = false
                            self.performSegue(withIdentifier: identifier, sender: self)
                        }) )
                        self.present(alert, animated: true, completion: nil)
                    }else {
                        //特にエラーなし遷移指示
                        self.segueing = false
                        self.performSegue(withIdentifier: identifier, sender: self)
                    }
                }
            }
            return false
            
        }else {
            //settingsへ
            //se
            seSystemAudio.startSePlay()
        }
        return true
    }
    //\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
    
    
    //マイグレーション
    func migration(){
        print("migration")
        if UserData.sharedInstance.MyVersion < 1430 {
            //データベースの初期データが上手く記録できていない時期があったため music,level を初期化して再取得
            MusicDataLists.sharedInstance.reset()
            UserData.sharedInstance.MusicsJson = ""
            UserData.sharedInstance.LevelsJson = ""
            print("music,level Reset")
        }
        if UserData.sharedInstance.MyVersion < 1500 {
            if UserData.sharedInstance.MyFavorite.count > 0 {
                print("お気に入り仕様変更を見せる")
                UserData.sharedInstance.lookedChangeFavoSpec_v1500 = false
            }
        }
        if UserData.sharedInstance.MyVersion < 1802 {
            //notesの頭16文字だけ拾ってthumbMovieに使用するため music,level を初期化して再取得
            MusicDataLists.sharedInstance.reset()
            UserData.sharedInstance.MusicsJson = ""
            UserData.sharedInstance.LevelsJson = ""
            print("music,level Reset")
        }
        if UserData.sharedInstance.MyVersion < 1810 {
            //avplayerを34個くらい配列(Cacheとして)で持ったらそれ以上アクセスできなくなったからThumbMovieと動画キャッシュで合計30までにしとこうということで動画保持件数の最大を10に引き下げ
            if UserData.sharedInstance.cachedMovieNum > 10 {
                UserData.sharedInstance.cachedMovieNum = 10
            }
        }
    }
}

