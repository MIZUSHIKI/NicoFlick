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
    @IBOutlet weak var reportButton: UIButton!
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var reportNum: UIButton!
    
    
    //音楽データ(シングルトン)
    var musicDatas:MusicDataLists = MusicDataLists.sharedInstance
    //効果音プレイヤー(シングルトン)
    var seSystemAudio:SESystemAudio = SESystemAudio.sharedInstance
    //保存データ
    let userData = UserData.sharedInstance
    //Indicator
    private var activityIndicator:UIActivityIndicatorView!

    //遷移時に受け取り
    var selectorController:Selector!
    var password = ""
    
    var selectMusics:[musicData]?
    var selectMusic:musicData?
    
    var reportComment = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        //Indicatorを作成
        activityIndicator = Indicator(center: self.view.center).view
        self.view.addSubview(activityIndicator)
        
        // 格納
        if selectorController.currentMusics.count > 0 {
            selectMusics = selectorController.currentMusics
        }
        if let musics = selectMusics {
            if selectorController.indexCarousel >= 0 && musics.count > selectorController.indexCarousel{
                selectMusic = musics[selectorController.indexCarousel]
            }
        }
        
        if let music = selectMusic {
            if userData.ReportedMusicID.contains("\(music.sqlID!)"){
                reportButton.backgroundColor = UIColor.gray
                reportButton.isEnabled = false
            }
            let selectLevels = selectorController.currentLevels
            if selectorController.indexPicker >= 0 && selectLevels.count > selectorController.indexPicker {
                let selectLevel = selectLevels[selectorController.indexPicker]
                if let mid = music.sqlID, let gid = selectLevel.sqlID {
                    idLabel.text = "musicID=\(mid), gameID=\(gid)"
                    //開発者用
                    if userData.UserIDxxx == AppDelegate.MIZUSHIKI_IDxxx {
                        let eco = (self.selectorController.nowNicoDMC?.eco ?? false) ? "eco" : "normal"
                        idLabel.text! +=  " - \(eco)"
                    }
                }
            }
            //開発者用 通報数、コメント確認。
            if userData.UserIDxxx == AppDelegate.MIZUSHIKI_IDxxx {
                ServerDataHandler().getReport(musicID: music.sqlID) { (num, comments) in
                    DispatchQueue.main.async {
                        self.reportNum.setTitle("\(num)", for: .normal)
                        self.reportNum.isHidden = false
                        self.reportComment = comments
                    }
                }
            }
        }else {
            reportButton.backgroundColor = UIColor.gray
            reportButton.isEnabled = false
        }
        
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
    
    @IBAction func goMovieUrlButton(_ sender: UIButton) {
        if selectMusic == nil { return }
        let url = URL(string: selectMusic!.movieURL)
        if UIApplication.shared.canOpenURL(url!) {
            UIApplication.shared.open(url!, options: [:], completionHandler: nil)
        }
    }
    @IBAction func ReportButton(_ sender: UIButton) {
        if selectMusic == nil { return }
        let ac = UIAlertController(title: "違反報告", message: "この動画の使用が著作者の権利を侵害していることを報告します。\n\n・無断でアップロードされた楽曲\n・二次三次創作がある程度許容されうるジャンル(環境)ではない 等", preferredStyle: .alert)
               let ok = UIAlertAction(title: "報告", style: .default, handler: {[weak ac] (action) -> Void in
                   guard let textFields = ac?.textFields else {
                       return
                   }

                   guard !textFields.isEmpty else {
                       return
                   }

                   for text in textFields {
                       if text.tag == 1 {
                        let musicID = self.selectMusic!.sqlID!
                        ServerDataHandler().postReport(musicID: musicID, comment: text.text!, userID: self.userData.UserID) { (bool) in
                            if bool {
                                DispatchQueue.main.async {//UI処理はメインスレッドの必要あり
                                    self.userData.ReportedMusicID.append("\(musicID)")
                                    self.reportButton.backgroundColor = UIColor.gray
                                    self.reportButton.isEnabled = false
                                }
                            }
                        }
                       }
                   }
               })
               let cancel = UIAlertAction(title: "キャンセル", style: .cancel, handler: nil)

               //textfiled1の追加
               ac.addTextField(configurationHandler: {(text:UITextField!) -> Void in
                   text.tag  = 1
                text.placeholder = "具体的な違反内容を記入"
               })

               ac.addAction(ok)
               ac.addAction(cancel)

               present(ac, animated: true, completion: nil)
    }
    //開発者用 楽曲削除
    @IBAction func ReportNumButton(_ sender: UIButton) {
        var comm = self.reportComment
        if comm == "" {
            comm = "コメントなし"
        }
        let alert = UIAlertController(title:"report-comment", message: comm, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "削除", style: UIAlertActionStyle.default, handler: {
            (action: UIAlertAction!) in
            //print("はいをタップした時の処理")
            
            print(alert.textFields![0].text!)
            // データの削除
            if let music = self.selectMusic  {
                ServerDataHandler().postMusicDelete(musicID: music.sqlID, masterPass: alert.textFields![0].text!) {
                    DispatchQueue.main.async {//UI処理はメインスレッドの必要あり
                        let alert = UIAlertController(title:"music delete", message: "成功", preferredStyle: UIAlertControllerStyle.alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                    }
                }
            }
            
        }))
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel, handler: nil))
        //textfiledの追加
        alert.addTextField(configurationHandler: {(textField: UITextField!) in
            textField.isSecureTextEntry = true // for password input
            textField.placeholder = "マスターパスワード"
        })
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func goExtLink(_ sender: UIButton) {
        
        let alert = UIAlertController(title:nil, message: "Safariで開く", preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addAction( UIAlertAction(title: "NicoFlickデータベース", style: .default, handler: {_ in
            guard let url = URL(string: "http://timetag.main.jp/nicoflick/index.php") else { return }
            UIApplication.shared.open(url)
        }) )
        alert.addAction( UIAlertAction(title: "NicoFlick紹介 動画", style: .default, handler: {_ in
            guard let url = URL(string: "https://www.nicovideo.jp/watch/sm33685683") else { return }
            UIApplication.shared.open(url)
        }) )
        alert.addAction( UIAlertAction(title: "ゲームデータ作成・投稿の仕方 動画", style: .default, handler: {_ in
            guard let url = URL(string: "https://www.nicovideo.jp/watch/sm35113435") else { return }
            UIApplication.shared.open(url)
        }) )
        alert.addAction( UIAlertAction(title: "キャンセル", style: .cancel, handler: nil) )
        self.present(alert, animated: true, completion: nil)
    }
    
    
    @IBAction func postLevelDataButton(_ sender: UIButton) {
        if selectMusic == nil { return }
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
            if noteData.count <= 20 {
                //基としたカレントlevelはNotesデータをまだ取得していない（遅延させてる）。
                //その場合、エディタ画面に行った一発目にダウンロードさせるようにする。
                noteData = "@NicoFlick=2\n@BaseDataNo=\(level.sqlID!)"
            }else {
                if noteData.pregMatche(pattern: "NicoFlick\\s*=\\s*\\d+") {
                    noteData = noteData.pregReplace(pattern: "NicoFlick\\s*=\\s*\\d+", with: "NicoFlick=2")
                }else {
                    noteData += "\n@NicoFlick=2"
                }
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
                userID: UserData.sharedInstance.UserID,
                callback: { (retStr, error) in
                    if error != nil {
                        return
                    }
                    if retStr.pregMatche(pattern: "<!--EchoHtmlMes_OK-->"){
                        DispatchQueue.main.async {//UI処理はメインスレッドの必要あり
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
            //se
            seSystemAudio.openSePlay()
            
        }else if segue.identifier == "toTableViewForSort" {
            //遷移先のTableViewにデータを渡す
            let tableViewController:TableViewForSort = segue.destination as! TableViewForSort
            
            tableViewController.selectorMenuController = self
            //se
            seSystemAudio.openSePlay()
            
        }else if segue.identifier == "toMusicAddView" {
            //遷移先のTableViewにデータを渡す
            let musicAddViewController:MusicAddView = segue.destination as! MusicAddView
            
            musicAddViewController.selectorMenuController = self
            
        }else if segue.identifier == "toEditor" {
            //現在選択中のデータをEditorViewに渡す
            let editorViewController:EditorView = segue.destination as! EditorView
            editorViewController.selectMusic = selectorController.currentMusics[selectorController.indexCarousel]
            editorViewController.selectLevel = selectorController.currentLevels[selectorController.indexPicker]
            editorViewController.password = password
            
            selectorController.ThumbMovieStop()
            
        }else if segue.identifier == "toJasracRevalidationWebkitView" {
            if let music = selectMusic {
                let jasracSearchWebkitViewController:JasracSearchWebkitView = segue.destination as! JasracSearchWebkitView
                jasracSearchWebkitViewController.titleText = music.title
            }
        }
    }
    //遷移の許可
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        
        if identifier == "toEditor" {
            if selectMusic == nil { return false }
            password = ""
            let level = selectorController.currentLevels[selectorController.indexPicker]
            let hoshi = level.level == 100 ? "FULL" : "☆\(level.level!)"
            
            let alert = UIAlertController(title:"ゲームデータの編集", message: "難易度：\(hoshi)\ncreator：\(level.creator!)", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {
                (action: UIAlertAction!) in
                //print("はいをタップした時の処理")
                //Indicator くるくる開始
                self.activityIndicator.startAnimating()
                ServerDataHandler().checkLevelPassword(id: level.sqlID, pass: alert.textFields![0].text!, userID: self.userData.UserID, callback: { (bool) in
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
