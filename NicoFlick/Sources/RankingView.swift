//
//  RankingView.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/08/18.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//

import Foundation

class RankingView: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet var musicTitle: UILabel!
    @IBOutlet var musicRank: UILabel!
    @IBOutlet var rankTable: UITableView!
    
    //遷移時に受け取り
    var selectMusic:musicData!
    var selectLevel:levelData!
    
    var userNameDatas:userNameDataLists = userNameDataLists.sharedInstance
    var rankingData:Array<Dictionary<String,String>> = []
    
    //Indicator
    private var activityIndicator:UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        musicTitle.text = selectMusic.title
        musicRank.text = selectLevel.getLevelAsString()
        
        //Indicatorを作成
        activityIndicator = Indicator(center: self.view.center).view
        self.view.addSubview(activityIndicator)
        //Indicator くるくる開始
        activityIndicator.startAnimating()
        
        //スコアデータの取得
        ServerDataHandler().getScoreData(levelID: selectLevel.sqlID!, callback: { (data) in
            DispatchQueue.main.async {
                //UI処理はメインスレッドの必要あり
                //Indicator隠す
                self.activityIndicator.stopAnimating()
                if let data = data {
                    self.rankingData = data
                    //テーブル再描画
                    self.rankTable.reloadData()
                }
            }
        })
 
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // セルを作る
        let cell = tableView.dequeueReusableCell(withIdentifier: "rankCell", for: indexPath)
        
        (cell.viewWithTag(1) as! UILabel).text = "\(indexPath.row+1)"
        (cell.viewWithTag(2) as! UILabel).text = userNameDatas.getUserName( userID: rankingData[indexPath.row]["userID"]! )
        (cell.viewWithTag(3) as! UILabel).text = rankingData[indexPath.row]["score"]
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // セルの数を設定
        return rankingData.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Ranking"
    }
    
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // セルがタップされた時の処理
        print("タップされたセルのindex番号: \(indexPath.row)")
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // セルの高さを設定
        return 50
    }
    
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        // アクセサリボタン（セルの右にあるボタン）がタップされた時の処理
        print("タップされたアクセサリがあるセルのindex番号: \(indexPath.row)")
    }
}
