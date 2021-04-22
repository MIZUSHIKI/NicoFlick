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
    @IBOutlet weak var usumaku: UIView!
    @IBOutlet weak var usernameDownloadProgressLabel: UILabel!
    
    //遷移時に受け取り
    var selectMusic:musicData!
    var selectLevel:levelData!
    
    var scoreDatas:ScoreDataLists = ScoreDataLists.sharedInstance
    var userNameDatas:userNameDataLists = userNameDataLists.sharedInstance
    var rankingData:[scoreData] = []
    var myIndex:Int?
    
    //Indicator
    private var activityIndicator:UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        musicTitle.text = selectMusic.title
        musicRank.text = selectLevel.getLevelAsString()
        if userNameDatas.usernameJsonNumCount >= 0 {
            usernameDownloadProgressLabel.text = "ユーザーネームデータ分割\(userNameDatas.usernameJsonNumCount)まで取得済み"
            usernameDownloadProgressLabel.isHidden = false
        }
        
        //Indicatorを作成
        activityIndicator = Indicator(center: self.view.center).view
        self.view.addSubview(activityIndicator)
        //Indicator くるくる開始
        activityIndicator.startAnimating()
        
        //まずユーザーデータの取得
        ServerDataHandler().DownloadUserNameData{ (error) in
            if error != nil { /*何らかのエラー*/}
            //スコアデータの取得
            ServerDataHandler().DownloadScoreData(levelID: self.selectLevel.sqlID!){ (error) in
                DispatchQueue.main.async {
                    //UI処理はメインスレッドの必要あり
                    //Indicator隠す
                    self.activityIndicator.stopAnimating()
                    
                    if self.userNameDatas.usernameJsonNumCount == -1 {
                        self.usernameDownloadProgressLabel.isHidden = true
                    }
                    self.usernameDownloadProgressLabel.text = "ユーザーネームデータ分割\(self.userNameDatas.usernameJsonNumCount)まで取得済み"
                    
                    self.rankingData = self.scoreDatas.getSortedScores(levelID: self.selectLevel.sqlID!)
                    
                    let myID = UserData.sharedInstance.UserID
                    for (index,scoredata) in self.rankingData.enumerated() {
                        if scoredata.userID == myID {
                            self.myIndex = index
                            DispatchQueue.main.asyncAfter(deadline: .now()+0.3){
                                self.rankTable.scrollToRow(at: IndexPath(row: index, section: 0), at: .middle, animated: true)
                            }
                            break
                        }
                    }
                    //テーブル再描画
                    self.rankTable.reloadData()
                }
            }
            
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // セルを作る
        let cell = tableView.dequeueReusableCell(withIdentifier: "rankCell", for: indexPath)
        
        (cell.viewWithTag(1) as! UILabel).text = "\(indexPath.row+1)"
        if( indexPath.row == myIndex ){
            (cell.viewWithTag(2) as! UILabel).textColor = UIColor.red
            (cell.viewWithTag(2) as! UILabel).text = UserData.sharedInstance.UserName != "" ? UserData.sharedInstance.UserName : "NO_NAME"
        }else {
            (cell.viewWithTag(2) as! UILabel).textColor = UIColor.black
            (cell.viewWithTag(2) as! UILabel).text = userNameDatas.getUserName( userID: rankingData[indexPath.row].userID! )
        }
        (cell.viewWithTag(3) as! UILabel).text = String(rankingData[indexPath.row].score)
        
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
    
    
    @IBAction func Go_Top(_ sender: UIButton) {
        rankTable.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
    }
    @IBAction func Go_My(_ sender: UIButton) {
        if let myIndex = myIndex {
            rankTable.scrollToRow(at: IndexPath(row: myIndex, section: 0), at: .middle, animated: true)
        }
    }
    @IBAction func Go_Bottom(_ sender: Any) {
        rankTable.scrollToRow(at: IndexPath(row: rankingData.count - 1, section: 0), at: .bottom, animated: true)
    }
    
    //画面遷移処理 _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    //遷移の許可
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        print("should")
        print(identifier)

        usumaku.isHidden = false
        //Indicator くるくる開始
        activityIndicator.startAnimating()

        //サーバから music,level,userName データを順次取得。
        ServerDataHandler().Chance_DownloadUserNameData_FirstData { (error) in
            if let error = error {
                print(error) //なんか失敗した。けど、とりあえずスルーして次へ。
            }
            DispatchQueue.main.async {
                //UI処理はメインスレッドの必要あり
                //Indicator隠す
                self.activityIndicator.stopAnimating()
                //遷移指示
                self.navigationController?.popViewController(animated: true)
            }
        }
        return false
    }
    //\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
}
