//
//  TableView.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/09/26.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//

import Foundation

class TableViewForTag: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource {
    
    @IBOutlet var textField: UITextField!
    @IBOutlet var xButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var editButton: UIBarButtonItem! //「＋時間指定」に変更
    @IBOutlet weak var editMaruButton: UICustomButton!
    
    
    //音楽データ(シングルトン)
    var musicDatas:MusicDataLists = MusicDataLists.sharedInstance
    //保存データ
    let userData = UserData.sharedInstance
    
    var numberRoll_index1_m = 0
    var numberRoll_index1_s = 0
    var numberRoll_index2_m = 0
    var numberRoll_index2_s = 0
    
    //遷移時に受け取り
    var selectorMenuController:SelectorMenu!
    var list:[String] = []
    var currentMusic:musicData! = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print(list)
        textField.text = userData.SelectedMusicCondition.tags
        editMaruButton.isHidden = ( currentMusic == nil )
    }
    
    override func viewDidAppear(_ animated: Bool) {
        tableView.reloadData()
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
        
        var jikanSitei = ""
        if (array!.contains(where: {$0.hasPrefix("@t:")})) {
            if let a = array?.first(where: {$0.hasPrefix("@t:")}){
                jikanSitei = " "+a
            }
            //含まれていたら一度削除
            self.textField.text = self.textField.text!.pregReplace(pattern: "\\s?@t:(\\d+:\\d+)?-?(\\d+:\\d+)?", with: "")
        }
        
        //時間指定が含まれていたら一度削除
        print(jikanSitei)
        if textField.text != "" && !(textField.text?.hasSuffix("-"))! {
            //空欄じゃなかったら空白を足す。
            textField.text = textField.text! + " "
        }
        textField.text = textField.text! + list[indexPath.row] + jikanSitei
        
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // セルの高さを設定
        return 50
    }
    
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        // アクセサリボタン（セルの右にあるボタン）がタップされた時の処理
        print("タップされたアクセサリがあるセルのindex番号: \(indexPath.row)")
    }
    
    // MARK: - UIPickerViewDelegate
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 30
    }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch pickerView.tag {
        case 123:
            return 100
        case 234:
            return 60
        case 567:
            return 100
        case 678:
            return 60
        default:
            return 0
        }
    }
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        if pickerView.tag == 123 || pickerView.tag == 567 { //ナンバーロール
            let label = UILabel()
            label.textAlignment = .center
            label.text = "\(row):"
            return label
        }else {
            let label = UILabel()
            label.textAlignment = .center
            label.text = String.init(format: "%02d", row)
            return label
        }
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch pickerView.tag {
        case 123:
            numberRoll_index1_m = row
        case 234:
            numberRoll_index1_s = row
        case 567:
            numberRoll_index2_m = row
        case 678:
            numberRoll_index2_s = row
        default:
            return
        }
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
    
    @IBAction func TimeFilter(_ sender: UIBarButtonItem) {
        
        let title = "時間指定"
        let message = "\n\n\n\n\n\n\n\n\n" //改行入れないとOKCancelがかぶる

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler:{
          (action: UIAlertAction!) -> Void in
            
            if self.numberRoll_index1_m*60 + self.numberRoll_index1_s > self.numberRoll_index2_m*60 + self.numberRoll_index2_s {
                swap(&self.numberRoll_index1_m, &self.numberRoll_index2_m)
                swap(&self.numberRoll_index1_s, &self.numberRoll_index2_s)
            }
            if self.numberRoll_index1_m == 0 && self.numberRoll_index1_s == 0 && self.numberRoll_index2_m == 99 && self.numberRoll_index2_s == 59 {
                return
            }
            
            //テキストフィールド内に既にあるか確認
            let array = self.textField.text?.components(separatedBy: " ") //タグ文字列を空白で分割
            if (array!.contains(where: {$0.hasPrefix("@t:")})) {
                //含まれていたら一度削除
                self.textField.text = self.textField.text!.pregReplace(pattern: "\\s?@t:(\\d+:\\d+)?-?(\\d+:\\d+)?", with: "")
            }
            
            if self.textField.text != "" {
                //空欄じゃなかったら空白を足す。
                self.textField.text! += " "
            }
            self.textField.text! += "@t:"
            if self.numberRoll_index1_m != 0 || self.numberRoll_index1_s != 0  {
                self.textField.text! += String.init(format: "%d:%02d", self.numberRoll_index1_m, self.numberRoll_index1_s)
            }
            self.textField.text! += "-"
            if self.numberRoll_index2_m != 99 || self.numberRoll_index2_s != 59  {
                self.textField.text! += String.init(format: "%d:%02d", self.numberRoll_index2_m, self.numberRoll_index2_s)
            }
            
        })
        let ngAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler:nil)
        
        numberRoll_index1_m = 0
        numberRoll_index1_s = 0
        numberRoll_index2_m = 3
        numberRoll_index2_s = 0
        // PickerView
        let w = 250//alert.view.bounds.width
        print(w)
        print(w*2/10)
        var pv = UIPickerView()
        pv.tag = 123
        pv.frame = CGRect(x: w*1/7, y: 60, width: 50, height: 100) // 配置、サイズ
        pv.dataSource = self
        pv.delegate = self
        pv.selectRow(numberRoll_index1_m, inComponent: 0, animated: true) // 初期値
        alert.view.addSubview(pv)
        //
        pv = UIPickerView()
        pv.tag = 234
        pv.frame = CGRect(x: w*2/7, y: 60, width: 50, height: 100) // 配置、サイズ
        pv.dataSource = self
        pv.delegate = self
        pv.selectRow(numberRoll_index1_s, inComponent: 0, animated: true) // 初期値
        alert.view.addSubview(pv)
        //
        let lb = UILabel()
        lb.text = "〜"
        lb.textAlignment = .center
        lb.frame = CGRect(x: w*3/7, y: 60, width: 50, height: 100) // 配置、サイズ
        alert.view.addSubview(lb)
        //
        pv = UIPickerView()
        pv.tag = 567
        pv.frame = CGRect(x: w*4/7, y: 60, width: 50, height: 100) // 配置、サイズ
        pv.dataSource = self
        pv.delegate = self
        pv.selectRow(numberRoll_index2_m, inComponent: 0, animated: true) // 初期値
        alert.view.addSubview(pv)
        //
        pv = UIPickerView()
        pv.tag = 678
        pv.frame = CGRect(x: w*5/7, y: 60, width: 50, height: 100) // 配置、サイズ
        pv.dataSource = self
        pv.delegate = self
        pv.selectRow(numberRoll_index2_s, inComponent: 0, animated: true) // 初期値
        alert.view.addSubview(pv)

        alert.addAction(okAction)
        alert.addAction(ngAction)
        present(alert, animated: true, completion: nil)
    }
    
    //画面遷移処理_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    @IBAction func returnToMe(segue: UIStoryboardSegue){
        print("returnToMe")
    }
    //画面遷移処理_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("seg")
        if segue.identifier == "toTagEditor" {
            //遷移先にデータを渡す
            let tagEditorController:TagEditor = segue.destination as! TagEditor
            tagEditorController.tableviewForTagController = self
        }else {
            //戻る
            SESystemAudio.sharedInstance.openSubSePlay()
            userData.SelectedMusicCondition.tags = textField.text!
        }
    }
}
