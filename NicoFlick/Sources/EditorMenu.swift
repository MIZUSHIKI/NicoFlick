//
//  EditorMenu.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2018/12/31.
//  Copyright © 2018年 i.MIZUSHIKI. All rights reserved.
//

import UIKit

class EditorMenu: UIViewController {
    
    @IBOutlet private var levelSelectionContainer: UIView!
    private let levelSelectionButton = UIButton(type: .system)
    private var selectedLevelRow = 10

    private var selectedLevel: Int {
        selectedLevelRow == 10 ? 100 : selectedLevelRow + 1
    }
    @IBOutlet var creatorTextField: UITextField!
    @IBOutlet var descriptionTextfield: UITextField!
    @IBOutlet var speedTextField: UITextField!
    @IBOutlet var deleteButton: UIButton!
    
    //Indicator（ネット処理中 画面中央でくるくるさせる）
    private var activityIndicator:UIActivityIndicatorView!
    
    //遷移時受け取り
    var editorViewController:EditorView!
    
    let dataList = [
        "(1)★☆☆☆☆☆☆☆☆☆",
        "(2)★★☆☆☆☆☆☆☆☆",
        "(3)★★★☆☆☆☆☆☆☆",
        "(4)★★★★☆☆☆☆☆☆",
        "(5)★★★★★☆☆☆☆☆",
        "(6)★★★★★★☆☆☆☆",
        "(7)★★★★★★★☆☆☆",
        "(8)★★★★★★★★☆☆",
        "(9)★★★★★★★★★☆",
        "(10)★★★★★★★★★★",
        "FULL"]
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        for notificationName in [NSNotification.Name.UIKeyboardDidShow,
                                 .UIKeyboardDidChangeFrame, .UIKeyboardDidHide] {
            NotificationCenter.default.addObserver(
                self, selector: #selector(restoreMovieAfterKeyboardChange),
                name: notificationName, object: nil
            )
        }
        if let value = editorViewController.mySpoon.atTag["Level"],
           let level = Int(value), (1...10).contains(level) {
            selectedLevelRow = level - 1
        }
        configureLevelSelection()
        var creator = editorViewController.selectLevel.creator!
        if let ca = editorViewController.mySpoon.atTag["Creator"] {
            creator = ca
        }
        var description = ""
        if let dc = editorViewController.mySpoon.atTag["Description"] {
            description = dc
        }
        var speed = "\(editorViewController.selectLevel.speed!)"
        if let sp = editorViewController.mySpoon.atTag["Speed"] {
            speed = sp
        }
        creatorTextField.text = creator
        descriptionTextfield.text =  description
        speedTextField.text = speed
        
        if editorViewController.selectLevel.isEditing {
            deleteButton.setTitle("データベースから削除する", for: .normal)
        }
        //Indicatorを作成
        activityIndicator = Indicator(center: self.view.center).view
        self.view.addSubview(activityIndicator)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureLevelSelection() {
        // Storyboardの元の表示領域内で、選択行と同じ高さに収める。
        levelSelectionButton.frame = CGRect(
            x: 0,
            y: (levelSelectionContainer.bounds.height - 30) / 2,
            width: levelSelectionContainer.bounds.width,
            height: 30
        )
        levelSelectionButton.autoresizingMask = [.flexibleWidth, .flexibleTopMargin, .flexibleBottomMargin]
        levelSelectionButton.backgroundColor = .white
        levelSelectionButton.layer.cornerRadius = 4
        levelSelectionButton.layer.borderWidth = 1
        levelSelectionButton.layer.borderColor = UIColor.lightGray.cgColor
        levelSelectionButton.titleLabel?.font = .systemFont(ofSize: 16)
        levelSelectionButton.addTarget(self, action: #selector(showLevelSelection), for: .touchUpInside)
        levelSelectionButton.accessibilityLabel = "難易度"
        levelSelectionButton.accessibilityHint = "難易度の選択肢を表示します"
        levelSelectionContainer.addSubview(levelSelectionButton)
        updateLevelSelection()
    }

    private func updateLevelSelection() {
        let title = selectedLevel == 100 ? "FULL" : "Lv. \(selectedLevel)"
        levelSelectionButton.setTitle("\(title)  ▾", for: .normal)
        levelSelectionButton.accessibilityValue = title
    }

    @objc private func showLevelSelection() {
        view.endEditing(true)
        let alert = UIAlertController(title: "難易度を選択", message: nil, preferredStyle: .actionSheet)
        for (row, title) in dataList.enumerated() {
            let selectionMark = row == selectedLevelRow ? "✓ " : ""
            alert.addAction(UIAlertAction(title: selectionMark + title, style: .default) { [weak self] _ in
                self?.selectedLevelRow = row
                self?.updateLevelSelection()
            })
        }
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        alert.popoverPresentationController?.sourceView = levelSelectionButton
        alert.popoverPresentationController?.sourceRect = levelSelectionButton.bounds
        present(alert, animated: true)
    }

    @IBAction func postButton(_ sender: Any) {
        view.endEditing(true)
        let needsLevelReview = selectedLevel == 100
            && editorViewController.mySpoon.spoons.contains { $0.note }
        let levelTitle = selectedLevel == 100 ? "FULL" : "Lv. \(selectedLevel)"
        let message = needsLevelReview
            ? "ノーツが割り振られていますが、難易度はFULLです。\nFULLとして投稿しますか？"
            : "難易度：\(levelTitle)\nデータベースに送信します。"
        let alert = UIAlertController(title: "NicoFlick データベース", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: needsLevelReview ? "FULLで投稿" : "投稿する", style: UIAlertActionStyle.default, handler: {
            (action: UIAlertAction!) in
            //print("はいをタップした時の処理")
            
            //Indicator くるくる開始
            self.activityIndicator.startAnimating()
            
            let notesString = self.editorViewController.mySpoon.export(mode: .NicoFlickDB)
            //ゲームデータを更新する。
            let level = self.selectedLevel
            var speed = 0
            if let sp = self.speedTextField.text {
                speed = Int(sp)!
            }
            let aiSourceID = "\(self.editorViewController.selectMusic.sqlID ?? 0):\(self.editorViewController.selectLevel.sqlID ?? 0)"
            ServerDataHandler().postLevelUpdate(
                sqlID: self.editorViewController.selectLevel.sqlID,
                nicoURL: self.editorViewController.selectMusic.movieURL,
                level: level,
                creator: self.creatorTextField.text!,
                description: self.descriptionTextfield.text!,
                speed: speed,
                notes: notesString,
                userPASS: self.editorViewController.password,
                callback: { (retStr, error) in
                    if error != nil {
                        // print("DataPost error")
                        DispatchQueue.main.async {
                            //Indicator隠す
                            self.activityIndicator.stopAnimating()
                            let alert = UIAlertController(title:"NicoFlick データベース", message: "送信に失敗しました。", preferredStyle: UIAlertControllerStyle.alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler:nil))
                            self.present(alert, animated: true, completion: nil)
                        }
                        return
                    }
                    if retStr.pregMatche(pattern: "<!--EchoHtmlMes_OK-->"){
                        //送信成功したらuserDataを消す。
                        // print("DataPost OK")
                        DispatchQueue.main.async {
                            ExternalAIChartViewController.removeSavedData(sourceID: aiSourceID)
                        }
                        
                        //取得データの更新
                        ServerDataHandler().DownloadMusicDataAndUserNameData { (error) in
                            if let error = error {
                                // print(error) //なんか失敗した。けど、とりあえずスルーして次へ。
                            }
                            DispatchQueue.main.async {
                                //Indicator隠す
                                self.activityIndicator.stopAnimating()
                                let alert = UIAlertController(title:"NicoFlick データベース", message: "送信しました。\n\n投稿したデータは メニュー ＞ 編集 からいつでも編集/削除ができます", preferredStyle: UIAlertControllerStyle.alert)
                                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { (uiAlertAction) in
                                    
                                    self.dismiss(animated: true, completion: {
                                        if let con = self.editorViewController {
                                            //二段階戻る
                                            con.nidankaiModoru = true
                                            con.performSegue(withIdentifier: "fromEditView", sender: nil)
                                        }
                                    })
                                    
                                }))
                                self.present(alert, animated: true, completion: nil)
                            }
                            return
                        }
                    }else {
                        // print(retStr) //何らかの理由で失敗。
                        DispatchQueue.main.async {
                            //Indicator隠す
                            self.activityIndicator.stopAnimating()
                            // 楽曲登録できなかった！
                            let echo = retStr.pregMatche_firstString(pattern: "<!--echo-->(.*?)<!--/echo-->")
                            let echoMessage = echo.pregReplace(pattern: "<!--message=.*?-->", with: "")
                            let alert = UIAlertController(title:"NicoFlickデータベース", message: "投稿に失敗しました。\n***\n\(echoMessage)", preferredStyle: UIAlertControllerStyle.alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler:nil))
                            self.present(alert, animated: true, completion: nil)
                        }
                        return
                    }
            }
            )
        }))
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel, handler:nil))
        self.present(alert, animated: true, completion: nil)
    }
    @IBAction func deleteButton(_ sender: Any) {
        // print("delete")
        let alert = UIAlertController(title:"NicoFlick データベース", message: "本当に削除して良いですか？", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {
            (action: UIAlertAction!) in
            //print("はいをタップした時の処理")
            
            //Indicator くるくる開始
            self.activityIndicator.startAnimating()
            ServerDataHandler().postLevelDelete(
                sqlID: self.editorViewController.selectLevel.sqlID,
                userPASS: self.editorViewController.password,
                callback: { (retStr, error) in
                    
                    if error != nil {
                        // print("DataDelete error")
                        DispatchQueue.main.async {
                            //Indicator隠す
                            self.activityIndicator.stopAnimating()
                            let alert = UIAlertController(title:"NicoFlick データベース", message: "削除に失敗しました。", preferredStyle: UIAlertControllerStyle.alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler:nil))
                            self.present(alert, animated: true, completion: nil)
                        }
                        return
                    }
                    if retStr.pregMatche(pattern: "<!--EchoHtmlMes_OK-->"){
                        //送信成功したらuserDataを消す。
                        // print("DataDelete OK")
                        
                        //取得データの更新
                        ServerDataHandler().DownloadMusicDataAndUserNameData { (error) in
                            if let error = error {
                                // print(error) //なんか失敗した。けど、とりあえずスルーして次へ。
                            }
                            DispatchQueue.main.async {
                                //Indicator隠す
                                self.activityIndicator.stopAnimating()
                                let alert = UIAlertController(title:"NicoFlick データベース", message: "削除しました。", preferredStyle: UIAlertControllerStyle.alert)
                                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { (uiAlertAction) in
                                    
                                    self.dismiss(animated: true, completion: {
                                        if let con = self.editorViewController {
                                            //二段階戻る
                                            con.nidankaiModoru = true
                                            con.performSegue(withIdentifier: "fromEditView", sender: nil)
                                        }
                                    })
                                    
                                }))
                                self.present(alert, animated: true, completion: nil)
                            }
                            return
                        }
                    }else {
                        // print(retStr) //何らかの理由で失敗。
                        DispatchQueue.main.async {
                            //Indicator隠す
                            self.activityIndicator.stopAnimating()
                            // 楽曲登録できなかった！
                            let echo = retStr.pregMatche_firstString(pattern: "<!--echo-->(.*?)<!--/echo-->")
                            let echoMessage = echo.pregReplace(pattern: "<!--message=.*?-->", with: "")
                            let alert = UIAlertController(title:"NicoFlickデータベース", message: "削除に失敗しました。\n---\n\(echoMessage)", preferredStyle: UIAlertControllerStyle.alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler:nil))
                            self.present(alert, animated: true, completion: nil)
                        }
                        return
                    }
            }
            )
        }))
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel, handler:nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func showStarDialogButton(_ sender: UIButton) {
        let myspoon = editorViewController.mySpoon
        let star = myspoon.getLevelStarReferencevalue(FULL: !myspoon.spoons.contains { $0.note })
        let star_v2 = Int(min(20.0, myspoon.getLevelStarReferencevalueV2(FULL: !myspoon.spoons.contains { $0.note }).rounded()))
        let alert = UIAlertController(title:"難易度計算（参考）", message: "レベル\(star)\n\(dataList[star-1].pregReplace(pattern: "^\\(\\d+\\)", with: ""))\n\n---\n新しい難易度計算 = レベル\(star_v2)", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    private func saveEditorMetadata() {
        // 遷移前に保存
        let level = selectedLevel
        editorViewController.mySpoon.atTag["Level"] = "\(level)"
        editorViewController.mySpoon.atTag["Creator"] = creatorTextField.text
        editorViewController.mySpoon.atTag["Description"] = descriptionTextfield.text
        var speed = editorViewController.selectLevel.speed!
        if let sp = speedTextField.text, let value = Int(sp) {
            speed = value
        }
        if speed < 50 || 500 < speed { speed = 150 }
        editorViewController.mySpoon.atTag["Speed"] = "\(speed)"
        
    }

    @objc private func restoreMovieAfterKeyboardChange() {
        guard isViewLoaded, view.window != nil, presentedViewController == nil else { return }
        DispatchQueue.main.async { [weak self] in
            self?.editorViewController.restoreMovieLayout()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        editorViewController.restoreMovieLayout()
        transitionCoordinator?.animate(alongsideTransition: nil) { [weak self] _ in
            self?.editorViewController.restoreMovieLayout()
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // メニューが下がり始める前に、キーボードを閉じて動画サイズを即時補正する。
        view.endEditing(true)
        editorViewController.restoreMovieLayout()
        saveEditorMetadata()
        // 設定
        if segue.identifier == "toEditorSettings" {
            // print("toEditorSettings")
            let editorSettingsController:EditorSettings = segue.destination as! EditorSettings
            editorSettingsController.editorViewController = editorViewController
        }
    }
    //キーボード関連_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    //MARK: キーボードが出ている状態で、キーボード以外をタップしたらキーボードを閉じる
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for subview in self.view.subviews{
            for subview in subview.subviews{
                for subview in subview.subviews{
                    if let subview = subview as? UITextField {
                        //非表示にする。
                        if(subview.isFirstResponder){
                            subview.resignFirstResponder()
                        }
                    }
                }
            }
        }
        
    }
    
    @IBAction func returnToMe(segue: UIStoryboardSegue){
        //print(segue.identifier)
    }
}
