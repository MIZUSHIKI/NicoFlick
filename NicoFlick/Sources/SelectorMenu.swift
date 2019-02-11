//
//  SelectorMenu.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/09/25.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//


import UIKit

class SelectorMenu: UIViewController {

    @IBOutlet var tagLabel: UILabel!
    @IBOutlet var sortLabel: UILabel!
    
    //音楽データ(シングルトン)
    var musicDatas:MusicDataLists = MusicDataLists.sharedInstance
    //保存データ
    let userData = UserData.sharedInstance
    //Indicator
    private var activityIndicator:UIActivityIndicatorView!

    //遷移時に受け取り
    var selectorController:Selector!
    var password = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        //Indicatorを作成
        activityIndicator = Indicator(center: self.view.center).view
        self.view.addSubview(activityIndicator)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        tagLabel.text = userData.SelectedMusicCondition.tags
        sortLabel.text = userData.SelectedMusicCondition.sortItem
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //オブジェクトアクション_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    @IBAction func goDataBaseButton(_ sender: UIButton) {
        let url = URL(string: "http://timetag.main.jp/nicoflick/index.php")
        if UIApplication.shared.canOpenURL(url!) {
            UIApplication.shared.open(url!, options: [:], completionHandler: nil)
        }
    }
    
    @IBAction func goMovieUrlButton(_ sender: UIButton) {
        let url = URL(string: selectorController.currentMusics[selectorController.indexCarousel].movieURL)
        if UIApplication.shared.canOpenURL(url!) {
            UIApplication.shared.open(url!, options: [:], completionHandler: nil)
        }
    }
    
    @IBAction func postLevelDataButton(_ sender: UIButton) {
        //let music = selectorController.currentMusics[selectorController.indexCarousel]
        let level = selectorController.currentLevels[selectorController.indexPicker]
        let hoshi = level.level == 100 ? "FULL" : "☆\(level.level!)"
        let alert = UIAlertController(title:"ゲームデータの作成", message: "この楽曲の\n\n難易度：\(hoshi)\ncreator：\(level.creator!)\n\nを基にゲームデータの仮登録を行います。", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {
            (action: UIAlertAction!) in
            //print("はいをタップした時の処理")
            
            self.password = alert.textFields![0].text!
            
            var name = UserData.sharedInstance.UserName
            if name == "" {
                name = "NO_NAME"
            }
            var noteData = level.noteData!
            if noteData.pregMatche(pattern: "NicoFlick\\s*=\\s*\\d+") {
                noteData = noteData.pregReplace(pattern: "NicoFlick\\s*=\\s*\\d+", with: "NicoFlick=2")
            }else {
                noteData += "\n@NicoFlick=2"
            }
            // ゲームデータの仮登録
            ServerDataHandler().postLevelInsert(
                nicoURL: self.selectorController.currentMusics[self.selectorController.indexCarousel].movieURL,
                level: level.level,
                creator: name,
                description: "【編集中:\(UserData.sharedInstance.UserID.prefix(8))】",
                speed: level.speed,
                notes: noteData,
                userPASS: self.password,
                callback: { (retStr, error) in
                    if error != nil {
                        return
                    }
                    if retStr.pregMatche(pattern: "<!--EchoHtmlMes_OK-->"){
                        DispatchQueue.main.async {//UI処理はメインスレッドの必要あり
                            let alert = UIAlertController(title:nil, message: "『ゲームデータの仮登録』を行いました。\nミュージックセレクト画面の◁Editからゲームデータの作成/本登録をしてください。", preferredStyle: UIAlertControllerStyle.alert)
                            
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
                                            self.performSegue(withIdentifier: "fromSelectorMenu", sender: nil)
                                        }
                                    }
                                }
                                
                            }))
                            self.present(alert, animated: true, completion: nil)
                        }
                    }
            }
            )
            
        }))
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel, handler: nil))
        //textfiledの追加
        alert.addTextField(configurationHandler: {(textField: UITextField!) in
            textField.isSecureTextEntry = true // for password input
            textField.placeholder = "パスワードを設定して下さい。"
        })
        self.present(alert, animated: true, completion: nil)
    }
    
    //画面遷移処理_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    @IBAction func returnToMe(segue: UIStoryboardSegue){
        print("return")
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toTableViewForTag" {
            //遷移先のTableViewにデータを渡す
            let tableViewController:TableViewForTag = segue.destination as! TableViewForTag
            tableViewController.list = selectorController.musicDatas.taglist.sorted(by: { $0.value > $1.value }).map{$0.0}
            //tableViewController.list.append("@初期楽曲")
            tableViewController.selectorMenuController = self
            
        }else if segue.identifier == "toTableViewForSort" {
            //遷移先のTableViewにデータを渡す
            let tableViewController:TableViewForSort = segue.destination as! TableViewForSort
            
            tableViewController.selectorMenuController = self
            
        }else if segue.identifier == "toEditor" {
            //現在選択中のデータをEditorViewに渡す
            let editorViewController:EditorView = segue.destination as! EditorView
            editorViewController.selectMusic = selectorController.currentMusics[selectorController.indexCarousel]
            editorViewController.selectLevel = selectorController.currentLevels[selectorController.indexPicker]
            editorViewController.password = password
            
        }
    }
    //遷移の許可
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        
        if identifier == "toEditor" {
            password = ""
            let level = selectorController.currentLevels[selectorController.indexPicker]
            let hoshi = level.level == 100 ? "FULL" : "☆\(level.level!)"
            
            let alert = UIAlertController(title:"ゲームデータの編集", message: "難易度：\(hoshi)\ncreator：\(level.creator!)", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {
                (action: UIAlertAction!) in
                //print("はいをタップした時の処理")
                //Indicator くるくる開始
                self.activityIndicator.startAnimating()
                ServerDataHandler().checkLevelPassword(id: level.sqlID, pass: alert.textFields![0].text!, callback: { (bool) in
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
                textField.placeholder = "パスワード"
            })
            self.present(alert, animated: true, completion: nil)
            return false
        }
        return true
    }
}
