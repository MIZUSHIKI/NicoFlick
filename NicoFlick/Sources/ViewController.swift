//
//  ViewController.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/04/29.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    //音楽データ
    var musicDatas:MusicDataLists = MusicDataLists.sharedInstance
    //各ユーザーのネームデータ
    var userNameDatas:userNameDataLists = userNameDataLists.sharedInstance
    
    //遷移中フラグ
    var segueing = false
    //Indicator（ネット処理中 画面中央でくるくるさせる）
    private var activityIndicator:UIActivityIndicatorView!
    
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
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func infoButton(_ sender: UIButton) {
        let alert = UIAlertController(title:nil, message: """
NicoFlickはフリック入力リズムゲーである 故「ミクフリック」の パクリ、オマージュ、リスペクト、難民先 作品です。


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
        
        if identifier == "toSelector" {
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
                            self.performSegue(withIdentifier: "toSelector", sender: self)
                        }) )
                        self.present(alert, animated: true, completion: nil)
                    }else {
                        //特にエラーなし遷移指示
                        self.segueing = false
                        self.performSegue(withIdentifier: "toSelector", sender: self)
                    }
                }
            }
            return false
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

