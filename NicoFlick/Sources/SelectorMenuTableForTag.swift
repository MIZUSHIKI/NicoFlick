//
//  TableView.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/09/26.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//

import Foundation

class TableViewForTag: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    
    @IBOutlet var textField: UITextField!
    @IBOutlet var xButton: UIButton!
    
    //音楽データ(シングルトン)
    var musicDatas:MusicDataLists = MusicDataLists.sharedInstance
    //保存データ
    let userData = UserData.sharedInstance
    
    //遷移時に受け取り
    var selectorMenuController:SelectorMenu!
    var list:[String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print(list)
        textField.text = userData.SelectedMusicCondition.tags
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // セルを作る
        let cell = UITableViewCell(style: UITableViewCellStyle.default, reuseIdentifier: "Cell")//tableView.dequeueReusableCell(withIdentifier: "rankCell", for: indexPath)
        cell.textLabel!.text = list[indexPath.row]
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // セルの数を設定
        print(list.count)
        return list.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    /*func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return ""
    }*/
    
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // セルがタップされた時の処理
        
        if(textField.isFirstResponder){
            textField.resignFirstResponder()
        }
        print("タップされたセルのindex番号: \(indexPath.row)")
        tableView.deselectRow(at: indexPath, animated: true)//選択を外す

        //テキストフィールド内に既にあるか確認
        let array = textField.text?.components(separatedBy: " ") //タグ文字列を空白で分割
        if (array?.contains(list[indexPath.row]))! {
            return //含まれていたらキャンセル
        }
        
        if textField.text != "" && !(textField.text?.hasSuffix("-"))! {
            //空欄じゃなかったら空白を足す。
            textField.text = textField.text! + " "
        }
        textField.text = textField.text! + list[indexPath.row]
        
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // セルの高さを設定
        return 50
    }
    
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        // アクセサリボタン（セルの右にあるボタン）がタップされた時の処理
        print("タップされたアクセサリがあるセルのindex番号: \(indexPath.row)")
    }
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        
        if(textField.isFirstResponder){
            textField.resignFirstResponder()
        }
    }
    
    //MARK: キーボードが出ている状態で、キーボード以外をタップしたらキーボードを閉じる
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        //非表示にする。
        if(textField.isFirstResponder){
            textField.resignFirstResponder()
        }
        
    }
    
    @IBAction func xButton(_ sender: UIButton) {
        textField.text = ""
    }
    @IBAction func atSyokiGakkyoku(_ sender: UIButton) {
        textField.text = "@初期楽曲"
    }
    
    //画面遷移処理_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("seg")
        userData.SelectedMusicCondition.tags = textField.text!

    }
}
