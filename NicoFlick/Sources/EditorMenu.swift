//
//  EditorMenu.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2018/12/31.
//  Copyright © 2018年 i.MIZUSHIKI. All rights reserved.
//

import UIKit

class EditorMenu: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    
    @IBOutlet var levelPicker: UIPickerView!
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
        // Delegate設定
        levelPicker.delegate = self
        levelPicker.dataSource = self
        //Level
        var level = 100 - 1
        if let lv = editorViewController.mySpoon.atTag["Level"] {
            level = Int(lv)! - 1
        }
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
        if level >= 10 { level = 10 }
        levelPicker.selectRow(level, inComponent: 0, animated: false)
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
    
    // UIPickerViewの列の数
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    // UIPickerViewの行数、リストの数
    func pickerView(_ pickerView: UIPickerView,
                    numberOfRowsInComponent component: Int) -> Int {
        return dataList.count
    }
    
    // UIPickerViewの最初の表示
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        
        var pickerLabel = view as? UILabel;
        
        if (pickerLabel == nil)
        {
            pickerLabel = UILabel()
            
            pickerLabel?.font = UIFont.systemFont(ofSize: 16)
            pickerLabel?.textAlignment = .center
            pickerLabel?.text = dataList[row]
        }
        
        return pickerLabel!;
    }
    
    // UIPickerViewのRowが選択された時の挙動
    func pickerView(_ pickerView: UIPickerView,
                    didSelectRow row: Int,
                    inComponent component: Int) {
        
        //label.text = dataList[row]
        
    }
    @IBAction func postButton(_ sender: Any) {
        print("post")
        let alert = UIAlertController(title:"NicoFlick データベース", message: "データベースに送信します。", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {
            (action: UIAlertAction!) in
            //print("はいをタップした時の処理")
            
            //Indicator くるくる開始
            self.activityIndicator.startAnimating()
            
            let notesString = self.editorViewController.mySpoon.export(mode: .NicoFlickDB)
            //ゲームデータを更新する。
            var level = self.levelPicker.selectedRow(inComponent: 0) + 1
            if level >= 11 { level = 100 }
            var speed = 0
            if let sp = self.speedTextField.text {
                speed = Int(sp)!
            }
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
                        print("DataPost error")
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
                        print("DataPost OK")
                        
                        //取得データの更新
                        ServerDataHandler().DownloadMusicDataAndUserNameData { (error) in
                            if let error = error {
                                print(error) //なんか失敗した。けど、とりあえずスルーして次へ。
                            }
                            DispatchQueue.main.async {
                                //Indicator隠す
                                self.activityIndicator.stopAnimating()
                                let alert = UIAlertController(title:"NicoFlick データベース", message: "送信しました。", preferredStyle: UIAlertControllerStyle.alert)
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
                        print(retStr) //何らかの理由で失敗。
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
        print("delete")
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
                        print("DataDelete error")
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
                        print("DataDelete OK")
                        
                        //取得データの更新
                        ServerDataHandler().DownloadMusicDataAndUserNameData { (error) in
                            if let error = error {
                                print(error) //なんか失敗した。けど、とりあえずスルーして次へ。
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
                        print(retStr) //何らかの理由で失敗。
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
        let star = editorViewController.mySpoon.getLevelStarReferencevalue()
        let alert = UIAlertController(title:"難易度計算（参考）", message: "レベル\(star)\n\(dataList[star-1].pregReplace(pattern: "^\\(\\d+\\)", with: ""))", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        //print("prepare")
        //print(segue.identifier as String!)
        //繊維前に保存
        var level = levelPicker.selectedRow(inComponent: 0) + 1
        if level >= 11 { level = 100 }
        editorViewController.mySpoon.atTag["Level"] = "\(level)"
        editorViewController.mySpoon.atTag["Creator"] = creatorTextField.text
        editorViewController.mySpoon.atTag["Description"] = descriptionTextfield.text
        var speed = editorViewController.selectLevel.speed!
        if let sp = speedTextField.text {
            speed = Int(sp)!
        }
        if speed < 50 || 500 < speed { speed = 150 }
        editorViewController.mySpoon.atTag["Speed"] = "\(speed)"
        
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
