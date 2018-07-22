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

    //遷移時に受け取り
    var selectorController:Selector!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
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
    
    @IBAction func resume(_ sender: Any) {
        self.selectorController.returnToMeData = 0
        self.performSegue(withIdentifier: "fromGameMenu", sender: self)
    }
    
    @IBAction func retry(_ sender: Any) {
        self.selectorController.returnToMeData = 1
        self.performSegue(withIdentifier: "fromGameMenu", sender: self)
    }
    
    @IBAction func musicSelect(_ sender: Any) {
        self.selectorController.returnToMeData = 2
        self.performSegue(withIdentifier: "fromGameMenu", sender: self)
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
    
    //画面遷移処理_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    @IBAction func returnToMe(segue: UIStoryboardSegue){
        print("return")
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toTableViewForTag" {
            //遷移先のTableViewにデータを渡す
            let tableViewController:TableViewForTag = segue.destination as! TableViewForTag
            tableViewController.list = selectorController.musicDatas.taglist.sorted(by: { $0.value > $1.value }).map{$0.0}
            tableViewController.list.append("@初期楽曲")
            tableViewController.selectorMenuController = self
            
        }else if segue.identifier == "toTableViewForSort" {
            //遷移先のTableViewにデータを渡す
            let tableViewController:TableViewForSort = segue.destination as! TableViewForSort
            
            tableViewController.selectorMenuController = self
        }
    }
}
