//
//  SelectorMenuTableForSort.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/09/29.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//

import Foundation

class TableViewForSort: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    
    @IBOutlet var textField: UITextField!
    
    //音楽データ(シングルトン)
    var musicDatas:MusicDataLists = MusicDataLists.sharedInstance
    //保存データ
    let userData = UserData.sharedInstance
    
    //遷移時に受け取り
    var selectorMenuController:SelectorMenu!
    //var list:[String] = []
    var mode = 0
    
    //テーブル表示項目
    var list = SelectConditions.SortItems

    private let sortIconNames = [
        "music-new.png",
        "music-old.png",
        "flick-new.png",
        "flick-old.png",
        "plays-new.png",
        "plays-old.png",
        "favorites-many.png",
        "favorites-few.png",
        "video-id-large.png",
        "video-id-small.png",
        "highscore-recent.png",
        "comment-recent.png",
        "plays-recent.png",
        "plays-user.png"
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textField.text = userData.SelectedMusicCondition.sortItem
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // セルを作る
        let cell = UITableViewCell(style: UITableViewCellStyle.default, reuseIdentifier: "Cell")//tableView.dequeueReusableCell(withIdentifier: "rankCell", for: indexPath)
        cell.textLabel!.text = list[indexPath.row]

        if indexPath.row < sortIconNames.count,
           let icon = UIImage(named: sortIconNames[indexPath.row]) {
            cell.imageView?.image = resizedImage(icon, size: CGSize(width: 32, height: 32))
            cell.imageView?.contentMode = .scaleAspectFit
        }
        
        return cell
    }

    private func resizedImage(_ image: UIImage, size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage ?? image
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // セルの数を設定
        // print(list.count)
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
        // print("タップされたセルのindex番号: \(indexPath.row)")
        tableView.deselectRow(at: indexPath, animated: true)
        

        if (textField.text?.contains(list[indexPath.row]))! {
            return
        }
        let hosi = textField.text!.pregMatche_firstString(pattern: " [★☆]{10}[■□]$")
        textField.text = list[indexPath.row] + hosi
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // セルの高さを設定
        return 50
    }
    
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        // アクセサリボタン（セルの右にあるボタン）がタップされた時の処理
        // print("タップされたアクセサリがあるセルのindex番号: \(indexPath.row)")
        
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
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    @IBAction func StarFilterButton(_ sender: UIBarButtonItem) {
        let sortStars = SelectConditions().getSortStars(containingStars: textField.text!) //う゛〜ん
        
        let alert = UIAlertController(title:"表示する難易度", message: "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n", preferredStyle: .alert)
        let h = 40.0//Double((alert.view.frame.size.height - 80) / 10)
        let x = 50.0//Double(alert.view.frame.size.width / 2 - 100)
        
        for i in 0 ... 10 {
            let sw = UISwitch(frame: CGRect(x: x + 30.0, y: 52.5 + h * Double(i), width: 10.0,height: 10.0))
            // print(40.0 + h * Double(i))
            sw.tag = i+1
            sw.isOn = sortStars[i]
            sw.alpha = 0
            let ll = UILabel(frame: CGRect(x: x + 100.0,y: 57.5 + h * Double(i), width: 50.0, height: 20.0))
            ll.tag = 100 + i
            ll.alpha = 0
            ll.text = "★\(i+1)"
            if i == 10 {
                ll.text = "FULL"
            }
            alert.view.addSubview(sw)
            alert.view.addSubview(ll)
        }
        
        // print("フレーム")
        // print(alert.view.frame)
        // print(h)
        alert.addAction((UIAlertAction(title: "OK", style: .cancel, handler: { [self] _ in
            var stars:[Bool] = [true,true,true,true,true,true,true,true,true,true,true]
            for view in alert.view.subviews {
                if let sw = view as? UISwitch {
                    stars[sw.tag-1] = sw.isOn
                }
            }
            var sortitem = textField.text!.pregReplace(pattern: " [★☆]{10}[■□]$", with: "")
            // print(stars)
            if stars.contains(false) {
                sortitem += " "
                for (num,star) in stars.enumerated() {
                    if num < 10 {
                        sortitem += star ? "★" : "☆"
                    }else {
                        sortitem += star ? "■" : "□"
                    }
                }
            }
            textField.text = sortitem
        })))
        self.present(alert, animated: true) {
            let groupWidth = 120.0
            let groupHeight = 431.0
            let startX = (alert.view.bounds.width - groupWidth) / 2
            let startY = (alert.view.bounds.height - groupHeight) / 2

            for i in 0 ... 10 {
                alert.view.viewWithTag(i + 1)?.frame = CGRect(
                    x: startX,
                    y: startY + h * Double(i),
                    width: 51,
                    height: 31
                )
                alert.view.viewWithTag(100 + i)?.frame = CGRect(
                    x: startX + 70,
                    y: startY + 5 + h * Double(i),
                    width: 50,
                    height: 20
                )
            }

            UIView.animate(withDuration: 0.1) {
                for i in 0 ... 10 {
                    alert.view.viewWithTag(i + 1)?.alpha = 1
                    alert.view.viewWithTag(100 + i)?.alpha = 1
                }
            }
        }
    }
    
    //画面遷移処理_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // print("seg")
        userData.SelectedMusicCondition.sortItem = textField.text!
        SESystemAudio.sharedInstance.openSubSePlay()
    }
}
