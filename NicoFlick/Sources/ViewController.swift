//
//  ViewController.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/04/29.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//

import UIKit
import CryptoSwift

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
        
        //Indicatorを作成
        activityIndicator = Indicator(center: self.view.center).view
        self.view.addSubview(activityIndicator)

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func infoButton(_ sender: UIButton) {
        let alert = UIAlertController(title:nil, message: "" +
            "NicoFlickはフリック入力リズムゲーである 故「ミクフリック」の パクリ、オマージュ、リスペクト、難民先 作品です。\n" +
            "\n\n" +
            "−2016年7月19日−\n　ミクフリック/02 サービス終了\n\n" +
            "−2017年9月29日−\n　ミクフリック(初代) サービス終了\n\n" +
            "−2017年9月20日−\n　iOS11リリース（32bitアプリなので両方起動できなくなる）", preferredStyle: UIAlertControllerStyle.alert)
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
            //初回設定メッセージ niconicoアカウント未登録なら促す
            // ->アカウントなしでも再生できるようになった。
            /*
            let userData = UserData.sharedInstance
            if userData.NicoMail == "" || userData.NicoPass == "" {
                //settingsへ誘導
                let alert = UIAlertController(title:nil, message: "ゲームを始める前にニコニコ動画のアカウントを入力してください", preferredStyle: UIAlertControllerStyle.alert)
                let cancel = UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: {
                    (action: UIAlertAction!) in
                    print("キャンセルをタップした時の処理")
                    self.performSegue(withIdentifier: "toSetting", sender: self)
                })
                alert.addAction(cancel)
                
                self.present(alert, animated: true, completion: nil)
                return false
            }
            */
            
            //データをロードした後に遷移させるため、一度、遷移キャンセル。
            segueing = true //遷移中であることを記憶。しないと遷移中に連続タップで何回もデータロードされる。
            //Indicator くるくる開始
            activityIndicator.startAnimating()
            activityIndicator.isHidden = false

            //データベース接続、まずmusicデータロード。
            let session = URLSession(configuration: URLSessionConfiguration.default)
            let url = URL(string:AppDelegate.PHPURL+"?req=music&time="+String(self.musicDatas.getLastUpdateTimeMusic()))!
            let task = session.dataTask(with: url){(data,responce,error) in
                if (error != nil) {
                    print("musicLoad-error") //エラー。例えばオフラインとか
                    DispatchQueue.main.async {
                        //UI処理はメインスレッドの必要あり
                        //Indicator隠す
                        self.activityIndicator.stopAnimating()
                        self.activityIndicator.isHidden=true
                        //遷移指示
                        self.segueing = false
                        self.performSegue(withIdentifier: "toSelector", sender: self)
                    }
                    return
                }
                //ロードしたmusicデータを処理
                if String(data: data!, encoding:.utf8)! != "latest" {
                    let jsonArray = (try! JSONSerialization.jsonObject(with: data!, options: [])) as! Array<Dictionary<String,String>>
                    for dic in jsonArray {
                        self.musicDatas.setMusic( sqlID: Int(dic["id"]!)!,
                                                  movieURL: dic["movieURL"]!,
                                                  thumbnailURL: dic["thumbnailURL"]!,
                                                  title: dic["title"]!,
                                                  artist: dic["artist"]!,
                                                  movieLength: dic["movieLength"]!,
                                                  tags: dic["tags"]!,
                                                  updateTime: Int(dic["updateTime"]!)!,
                                                  createTime: Int(dic["createTime"]!)!
                        )
                    }
                    self.musicDatas.createTaglist() //タグリストを更新
                }
                
                //データベース接続、次にlevelデータロード。
                let session = URLSession(configuration: URLSessionConfiguration.default)
                let url = URL(string:AppDelegate.PHPURL+"?req=level-noTimetag&time="+String(self.musicDatas.getLastUpdateTimeLevel()))!
                let task = session.dataTask(with: url){(data,responce,error) in
                    if (error != nil) {
                        print("levelLoad-error") //エラー
                        DispatchQueue.main.async {
                            //UI処理はメインスレッドの必要あり
                            //Indicator隠す
                            self.activityIndicator.stopAnimating()
                            self.activityIndicator.isHidden=true
                            //遷移指示
                            self.segueing = false
                            self.performSegue(withIdentifier: "toSelector", sender: self)
                        }
                        return
                    }
                    //ロードしたlevelデータを処理
                    if String(data: data!, encoding:.utf8)! != "latest" {
                        let jsonArray = (try! JSONSerialization.jsonObject(with: data!, options: [])) as! Array<Dictionary<String,String>>
                        for dic in jsonArray {
                            self.musicDatas.setLevel( sqlID: Int(dic["id"]!)!,
                                                      movieURL: dic["movieURL"]!,
                                                      level: Int(dic["level"]!)!,
                                                      creator: dic["creator"]!,
                                                      description: dic["description"]!,
                                                      speed: Int(dic["speed"]!)!,
                                                      noteData: "",
                                                      updateTime: Int(dic["updateTime"]!)!,
                                                      createTime: Int(dic["createTime"]!)!,
                                                      playCount: Int(dic["playCount"]!)!
                            )
                            //noteDataは最初に全部取得すると通信量が大きいからゲーム開始時に取得することにする
                        }
                    }
                    
                    //データベース接続、最後にusernameデータロード。
                    let session = URLSession(configuration: URLSessionConfiguration.default)
                    let url = URL(string:AppDelegate.PHPURL+"?req=username&time="+String(self.userNameDatas.getLastUpdateTimeUserName()))!
                    //print(url)
                    let task = session.dataTask(with: url){(data,responce,error) in
                        //print(data)
                        if (error != nil) {
                            print("usernameLoad-error") //エラー
                            DispatchQueue.main.async {
                                //UI処理はメインスレッドの必要あり
                                //Indicator隠す
                                self.activityIndicator.stopAnimating()
                                self.activityIndicator.isHidden=true
                                //遷移指示
                                self.segueing = false
                                self.performSegue(withIdentifier: "toSelector", sender: self)
                            }
                            return
                        }
                        //ロードしたusernameデータを処理
                        if String(data: data!, encoding:.utf8)! != "latest" {
                            let jsonArray = (try! JSONSerialization.jsonObject(with: data!, options: [])) as! Array<Dictionary<String,String>>
                            for dic in jsonArray {
                                self.userNameDatas.setUserName(sqlID: Int(dic["id"]!)!,
                                                               userID: dic["userID"]!,
                                                               userName: dic["name"]!,
                                                               updateTime: Int(dic["updateTime"]!)!
                                )
                            }
                        }
                        
                        //ロード処理完了。次画面へ遷移。
                        DispatchQueue.main.async {
                            //UI処理はメインスレッドの必要あり
                            //Indicator隠す
                            self.activityIndicator.stopAnimating()
                            self.activityIndicator.isHidden=true
                            //データロード後、遷移。
                            self.segueing = false
                            self.performSegue(withIdentifier: "toSelector", sender: self)
                        }

                    }
                    task.resume()
                }
                task.resume()
            }
            task.resume()
            
            return false
        }
        return true
    }
    //\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
}

