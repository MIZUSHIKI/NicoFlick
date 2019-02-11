//
//  MusicAddView.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2018/11/24.
//  Copyright © 2018年 i.MIZUSHIKI. All rights reserved.
//

import UIKit

class MusicAddView: UIViewController, UITextFieldDelegate {
    
    @IBOutlet var movieURLTextField: UITextField!
    @IBOutlet var thumbnailURLTextField: UITextField!
    @IBOutlet var titleTextField: UITextField!
    @IBOutlet var artistTextField: UITextField!
    @IBOutlet var timeLengthTextField: UITextField!
    @IBOutlet var tagsTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    
    //Indicator（ネット処理中 画面中央でくるくるさせる）
    private var activityIndicator:UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        for subview in self.view.subviews{
            if let subview = subview as? UITextField {
                subview.delegate = self //textFieldShouldReturnで閉じるように
            }
        }
        //Indicatorを作成
        activityIndicator = Indicator(center: self.view.center).view
        self.view.addSubview(activityIndicator)
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
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    @IBAction func GetInfoButton(_ sender: UIButton) {
        
        //Indicator くるくる開始
        activityIndicator.startAnimating()
        
        let smNum = ((movieURLTextField.text?.pregMatche(pattern: "^http"))!) ? movieURLTextField.text?.pregMatche_firstString(pattern: "/(sm.*$)") : movieURLTextField.text
        
        //GetThumbInfo
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.NicoApiURL_GetThumbInfo+"/"+smNum!)
        session.dataTask(with: url!){(data,responce,error) in
            if (error != nil) {
                print("error") //エラー。例えばオフラインとか
                DispatchQueue.main.async {//UI処理はメインスレッドの必要あり
                    //Indicator隠す
                    self.activityIndicator.stopAnimating()
                }
                return
            }
            let resText = String(data: data!, encoding:.utf8)!
            if resText.pregMatche(pattern: "<nicovideo_thumb_response status=\"ok\">") {
                DispatchQueue.main.async {//UI処理はメインスレッドの必要あり
                    //self.movieURLTextField.text = resText.pregMatche_firstString(pattern: "<watch_url>(.*?)</watch_url>")
                    self.thumbnailURLTextField.text = resText.pregMatche_firstString(pattern: "<thumbnail_url>(.*?)</thumbnail_url>")
                    self.titleTextField.text = resText.pregMatche_firstString(pattern: "<title>(.*?)</title>")
                    self.artistTextField.text = resText.pregMatche_firstString(pattern: "<user_nickname>(.*?)</user_nickname>")
                    self.timeLengthTextField.text = resText.pregMatche_firstString(pattern: "<length>(.*?)</length>")
                    self.tagsTextField.text = resText.pregMatche_firstString(pattern: "<tags.*?>(.*?)</tags>").pregReplace(pattern: "</?tag.*?>", with: "").pregReplace(pattern: "\n", with: " ").pregReplace(pattern: " +", with: " ").trimmingCharacters(in: .whitespaces)
                }
            }
            DispatchQueue.main.async {//UI処理はメインスレッドの必要あり
                //Indicator隠す
                self.activityIndicator.stopAnimating()
            }
        }.resume()
    }
    @IBAction func PostButton(_ sender: UIButton) {
        for subview in self.view.subviews{
            if let subview = subview as? UITextField {
                //キーボード非表示にする。
                if(subview.isFirstResponder){
                    subview.resignFirstResponder()
                }
            }
        }
        let movieURLText = self.movieURLTextField.text!
        let thumbnailURLText = self.thumbnailURLTextField.text!
        let titleText = self.titleTextField.text!
        let artistText = self.artistTextField.text!
        let timeLengthText = self.timeLengthTextField.text!
        let tagsText = self.tagsTextField.text!
        let passwordText = self.passwordTextField.text!
        let alert = UIAlertController(title:"誓約", message: "私は「NicoFlickの楽曲著作権への対応」について理解し、楽曲の登録をします。\nまた、登録しようとしている楽曲は「著作権管理をJASRACに\"全信託\"されている楽曲ではない」ことを確認済みです。", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "はい", style: UIAlertActionStyle.default, handler: {
            (action: UIAlertAction!) in
            //print("はいをタップした時の処理")
            let nicoURL = ((movieURLText.pregMatche(pattern: "^http"))) ? movieURLText : "https://www.nicovideo.jp/watch/" + movieURLText
            ServerDataHandler().postMusicInsert(
                nicoURL: nicoURL,
                thumbnailURL: thumbnailURLText,
                title: titleText,
                artist: artistText,
                timeLength: timeLengthText,
                tags: tagsText,
                userPASS: passwordText,
                callback: { (retStr, error) in
                    if error != nil {
                        let alert = UIAlertController(title:nil, message: "登録できませんでした。", preferredStyle: UIAlertControllerStyle.alert)
                        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: nil))
                        DispatchQueue.main.async {//UI処理はメインスレッドの必要あり
                            self.present(alert, animated: true, completion: nil)
                        }
                        return
                    }
                    print(retStr)
                    if retStr.pregMatche(pattern: "<!--EchoHtmlMes_OK-->"){
                        //登録できた。->続けてゲームデータを仮登録する。
                        var name = UserData.sharedInstance.UserName
                        if name == "" {
                            name = "NO_NAME"
                        }
                        ServerDataHandler().postLevelInsert(
                            nicoURL: nicoURL,
                            level: 100,
                            creator: name,
                            description: "【編集中:\(UserData.sharedInstance.UserID.prefix(8))】",
                            speed: 150,
                            notes: "@NicoFlick%3d2",
                            userPASS: passwordText,
                            callback: { (retStr, error) in
                                if error != nil {
                                    return
                                }
                                if retStr.pregMatche(pattern: "<!--EchoHtmlMes_OK-->"){
                                    let alert = UIAlertController(title:"NicoFlick データベース", message: "『楽曲の追加』『ゲームデータの仮登録』を行いました。\nミュージックセレクト画面の ◁Edit からゲームデータの作成/本登録をしてください。", preferredStyle: UIAlertControllerStyle.alert)
                                    alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { (alertAction) in
                                        
                                        DispatchQueue.main.async {//UI処理はメインスレッドの必要あり
                                            //Indicator くるくる開始
                                            self.activityIndicator.startAnimating()
                                            //サーバから music,level,userName データを順次取得。
                                            ServerDataHandler().DownloadMusicDataAndUserNameData { (error) in
                                                if let error = error {
                                                    print(error) //なんか失敗した。けど、とりあえずスルーして次へ。
                                                }
                                                DispatchQueue.main.async {
                                                    //UI処理はメインスレッドの必要あり
                                                    //Indicator隠す
                                                    self.activityIndicator.stopAnimating()
                                                    if UserData.sharedInstance.SelectedMusicCondition.tags.pregMatche(pattern: "@初期楽曲") {
                                                        
                                                        let alert = UIAlertController(title:"NicoFlick設定", message: "メニュー ＞ tag の「@初期楽曲」を削除してください。", preferredStyle: UIAlertControllerStyle.alert)
                                                        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { (alertAction) in
                                                            //遷移指示
                                                            self.dismiss(animated: true, completion: nil)
                                                        }))
                                                        self.present(alert, animated: true, completion: nil)
                                                    }else {
                                                        //遷移指示
                                                        self.dismiss(animated: true, completion: nil)
                                                        
                                                    }
                                                }
                                            }
                                        }
                                        
                                    }))
                                    self.present(alert, animated: true, completion: nil)
                                    
                                }
                            }
                        )
                        
                    }else if retStr.pregMatche(pattern: "<!--EchoHtmlMes_Error-->"){
                        // 楽曲登録できなかった！
                        let echo = retStr.pregMatche_firstString(pattern: "<!--echo-->(.*?)<!--/echo-->")
                        let message = echo.pregMatche_firstString(pattern: "<!--message=(.*?)-->")
                        let echoMessage = echo.pregReplace(pattern: "<!--message=.*?-->", with: "")
                        
                        if message != "AlreadyRegisteredMusic" {
                            //特殊条件以外は返ってきたechoMessageをアラートして終わり
                            let alert = UIAlertController(title:"NicoFlick データベース", message: echoMessage, preferredStyle: UIAlertControllerStyle.alert)
                            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: nil))
                            DispatchQueue.main.async {//UI処理はメインスレッドの必要あり
                                self.present(alert, animated: true, completion: nil)
                            }
                            return
                        }
                        
                        //すでに楽曲が登録済み。もしゲームデータが無いか【編集中】のものだけだったら追加するか聞く
                        //音楽データ(シングルトン)
                        let musicDatas:MusicDataLists = MusicDataLists.sharedInstance
                        let levels = musicDatas.getSelectMusicLevels_noSort(selectMovieURL: nicoURL)
                        print("levels.count=\(levels.count)")
                        if levels.count > 0 {
                            //楽曲が登録済みだけどユーザーにも見えてる
                            let alert = UIAlertController(title:"NicoFlick データベース", message: echoMessage, preferredStyle: UIAlertControllerStyle.alert)
                            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: nil))
                            DispatchQueue.main.async {//UI処理はメインスレッドの必要あり
                                self.present(alert, animated: true, completion: nil)
                            }
                            return
                        }
                        //追加したいか聞く
                        let alert = UIAlertController(title:"既にデータベース登録済み", message: "楽曲は登録済みでした。\nただし、まだゲームデータの登録がありません。\nゲームデータの仮登録を行いますか？", preferredStyle: UIAlertControllerStyle.alert)
                        alert.addAction(UIAlertAction(title: "はい", style: UIAlertActionStyle.default, handler: {
                            (action: UIAlertAction!) in
                            //print("はいをタップした時の処理")
                            var name = UserData.sharedInstance.UserName
                            if name == "" {
                                name = "NO_NAME"
                            }
                            // ゲームデータの仮登録
                            ServerDataHandler().postLevelInsert(
                                nicoURL: nicoURL,
                                level: 100,
                                creator: name,
                                description: "【編集中:\(UserData.sharedInstance.UserID.prefix(8))】",
                                speed: 150,
                                notes: "\n@NicoFlick%3d2",
                                userPASS: passwordText,
                                callback: { (retStr, error) in
                                    if error != nil {
                                        return
                                    }
                                    if retStr.pregMatche(pattern: "<!--EchoHtmlMes_OK-->"){
                                        let alert = UIAlertController(title:"NicoFlick データベース", message: "『ゲームデータの仮登録』を行いました。\nミュージックセレクト画面の ◁Edit からゲームデータの作成/本登録をしてください。", preferredStyle: UIAlertControllerStyle.alert)
                                        
                                        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { (alertAction) in
                                            
                                            DispatchQueue.main.async {//UI処理はメインスレッドの必要あり
                                                //Indicator くるくる開始
                                                self.activityIndicator.startAnimating()
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
                                                        self.dismiss(animated: true, completion: nil)
                                                    }
                                                }
                                            }
                                        }))
                                        self.present(alert, animated: true, completion: nil)
                                    }
                            }
                            )
                            
                        }))
                        alert.addAction((UIAlertAction(title: "いいえ", style: UIAlertActionStyle.cancel, handler: nil)))
                        DispatchQueue.main.async {//UI処理はメインスレッドの必要あり
                            self.present(alert, animated: true, completion: nil)
                        }
                        return
                    }
                }
            )
            
        }))
        alert.addAction((UIAlertAction(title: "いいえ", style: UIAlertActionStyle.cancel, handler: nil)))
        DispatchQueue.main.async {//UI処理はメインスレッドの必要あり
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    @IBAction func AboutCopyrightButton(_ sender: UIButton) {
        
        let url = URL(string: "http://timetag.main.jp/nicoflick/music_copyright.html")
        if UIApplication.shared.canOpenURL(url!) {
            UIApplication.shared.open(url!, options: [:], completionHandler: nil)
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
        for subview in self.view.subviews{
            if let subview = subview as? UITextField {
                if(subview.isFirstResponder){
                    if subview.frame.origin.y + subview.frame.size.height > (rect?.origin.y)! - (rect?.size.height)! {
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
        for subview in self.view.subviews{
            if let subview = subview as? UITextField {
                //非表示にする。
                if(subview.isFirstResponder){
                    subview.resignFirstResponder()
                }
            }
        }
        
    }
    
    //画面遷移処理_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    
    @IBAction func returnToMe(segue: UIStoryboardSegue){
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "toJasracSearchWebkitView" {
            let jasracSearchWebkitViewController:JasracSearchWebkitView = segue.destination as! JasracSearchWebkitView
            jasracSearchWebkitViewController.titleText = self.titleTextField.text!
            jasracSearchWebkitViewController.artistText = self.artistTextField.text!
        }
    }
}
