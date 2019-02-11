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
        let cancel = UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: {
            (action: UIAlertAction!) in
            print("キャンセルをタップした時の処理")
        })
        alert.addAction(cancel)
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
                    //遷移指示
                    self.segueing = false
                    self.performSegue(withIdentifier: "toSelector", sender: self)
                }
            }
            return false
        }
        return true
    }
    //\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
}

