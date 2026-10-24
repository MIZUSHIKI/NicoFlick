//
//  RankingView.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/08/18.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//

import Foundation

class RankingCommentTabController: UITabBarController, UITabBarControllerDelegate {
    private var pendingOperations = 0
    private var savedGestureStates: [(UIGestureRecognizer, Bool)] = []
    private var savedNavigationInteraction: Bool?
    var isNetworkBusy: Bool { pendingOperations > 0 }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if isNetworkBusy { lockNavigation() }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if isNetworkBusy { lockNavigation() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Never leave the next screen's navigation disabled after an external dismissal.
        restoreNavigation()
    }

    func beginNetworkOperation() {
        pendingOperations += 1
        viewIfLoaded?.isUserInteractionEnabled = false
        tabBar.isUserInteractionEnabled = false
        if #available(iOS 13.0, *) { isModalInPresentation = true }
        lockNavigation()
    }

    func endNetworkOperation() {
        pendingOperations = max(0, pendingOperations - 1)
        guard !isNetworkBusy else { return }
        viewIfLoaded?.isUserInteractionEnabled = true
        tabBar.isUserInteractionEnabled = true
        if #available(iOS 13.0, *) { isModalInPresentation = false }
        restoreNavigation()
    }

    private func lockNavigation() {
        guard let navigationController else { return }
        if savedNavigationInteraction == nil {
            savedNavigationInteraction = navigationController.navigationBar.isUserInteractionEnabled
        }
        navigationController.navigationBar.isUserInteractionEnabled = false
        var gestures = [navigationController.interactivePopGestureRecognizer].compactMap { $0 }
        if #available(iOS 26.0, *) {
            if let gesture = navigationController.interactiveContentPopGestureRecognizer {
                gestures.append(gesture)
            }
        }
        for gesture in gestures {
            if !savedGestureStates.contains(where: { $0.0 === gesture }) {
                savedGestureStates.append((gesture, gesture.isEnabled))
            }
            gesture.isEnabled = false
        }
    }

    private func restoreNavigation() {
        for (gesture, wasEnabled) in savedGestureStates { gesture.isEnabled = wasEnabled }
        savedGestureStates.removeAll()
        if let wasEnabled = savedNavigationInteraction {
            navigationController?.navigationBar.isUserInteractionEnabled = wasEnabled
            savedNavigationInteraction = nil
        }
    }

    func tabBarController(_ tabBarController: UITabBarController,
                          shouldSelect viewController: UIViewController) -> Bool {
        return !isNetworkBusy
    }

    
    //効果音プレイヤー(シングルトン)
    var seSystemAudio:SESystemAudio = SESystemAudio.sharedInstance
    
    var maeTag = 0
    
    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        // print("tabbar select")
        if maeTag != item.tag {
            seSystemAudio.openSubSePlay()
            maeTag = item.tag
        }
    }
}

// Ranking and comment operations share the parent's navigation lock.
class RankingNetworkViewController: UIViewController {
    private(set) var isNetworkBusy = false
    private weak var operationContainer: RankingCommentTabController?

    func beginNetworkOperation() {
        guard !isNetworkBusy else { return }
        isNetworkBusy = true
        view.isUserInteractionEnabled = false
        operationContainer = tabBarController as? RankingCommentTabController
        operationContainer?.beginNetworkOperation()
    }

    func endNetworkOperation() {
        guard isNetworkBusy else { return }
        isNetworkBusy = false
        view.isUserInteractionEnabled = true
        operationContainer?.endNetworkOperation()
        operationContainer = nil
    }

    func showDownloadError(_ error: Error?) {
        guard error != nil, viewIfLoaded?.window != nil else { return }
        let alert = UIAlertController(title: "データ取得エラー",
                                      message: "データを取得できませんでした。時間をおいて開き直してください。",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        return !isNetworkBusy && !((tabBarController as? RankingCommentTabController)?.isNetworkBusy ?? false)
    }
}

class RankingView: RankingNetworkViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet var musicTitle: UILabel!
    @IBOutlet var musicRank: UILabel!
    @IBOutlet var rankTable: UITableView!
    @IBOutlet weak var usumaku: UIView!
    @IBOutlet weak var usernameDownloadProgressLabel: UILabel!
    @IBOutlet weak var tabBar: UITabBar!
    
    //効果音プレイヤー(シングルトン)
    var seSystemAudio:SESystemAudio = SESystemAudio.sharedInstance
    //遷移時に受け取り
    var selectMusic:musicData!
    var selectLevel:levelData!
    
    var scoreDatas:ScoreDataLists = ScoreDataLists.sharedInstance
    var userNameDatas:userNameDataLists = userNameDataLists.sharedInstance
    var rankingData:[scoreData] = []
    var myIndex:Int?
    var musicScoreMessage = ""
    
    //Indicator
    private var activityIndicator:UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        musicTitle.text = selectMusic.title
        musicRank.text = selectLevel.getLevelAsString()
        if musicRank.text != "FULL" {
            musicRank.font = UIFont.systemFont(ofSize: 17)
        }
        if userNameDatas.usernameJsonNumCount >= 0 {
            usernameDownloadProgressLabel.text = "ユーザーネームデータ分割\(userNameDatas.usernameJsonNumCount)まで取得済み"
            usernameDownloadProgressLabel.isHidden = false
        }
        if UIScreen.main.bounds.size.height <= 667 {
            tabBar.isHidden = true
        }
        
        //Indicatorを作成
        activityIndicator = Indicator(center: self.view.center).view
        self.view.addSubview(activityIndicator)
        //Indicator くるくる開始
        beginNetworkOperation()
        activityIndicator.startAnimating()
        
        //
        let view = SlashShadeView.init(frame: self.view.frame, color: UIColor.init(red: 204/255, green: 255/255, blue: 102/255, alpha: 1.0), lineWidth: 1, space: 2)
        self.view.addSubview(view)
        self.view.sendSubview(toBack: view)
        
        //サムネイル
        let backThumbView = AsyncImageView(frame: CGRect(x: 0, y: 0,
                                                    width: self.view.frame.size.width,
                                                    height: self.view.frame.size.height))
        backThumbView.loadImage(urlString: selectMusic.thumbnailURL, contentMode: .scaleAspectFill)
        backThumbView.alpha = 0.5
        backThumbView.tag = 36
        self.view.addSubview(backThumbView)
        self.view.sendSubview(toBack: backThumbView)
        
        
        //まずユーザーデータの取得
        ServerDataHandler().DownloadUserNameData{ (error) in
            if let error {
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    self.endNetworkOperation()
                    self.showDownloadError(error)
                }
                return
            }
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

                            break
                        }
                    }
                    //テーブル再描画
                    self.rankTable.reloadData()
                    self.rankTable.layoutIfNeeded()
                    if let index = self.myIndex, self.rankingData.indices.contains(index) {
                        self.rankTable.scrollToRow(at: IndexPath(row: index, section: 0), at: .middle, animated: false)
                    }
                    self.endNetworkOperation()
                    self.showDownloadError(error)
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
        // print("タップされたセルのindex番号: \(indexPath.row)")
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // セルの高さを設定
        return 50
    }
    
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        // アクセサリボタン（セルの右にあるボタン）がタップされた時の処理
        // print("タップされたアクセサリがあるセルのindex番号: \(indexPath.row)")
    }
    
    
    @IBAction func Go_Top(_ sender: UIButton) {
        if rankingData.count <= 0 { return }
        rankTable.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
    }
    @IBAction func Go_My(_ sender: UIButton) {
        if rankingData.count <= 0 { return }
        if let myIndex = myIndex {
            rankTable.scrollToRow(at: IndexPath(row: myIndex, section: 0), at: .middle, animated: true)
        }
    }
    @IBAction func Go_Bottom(_ sender: Any) {
        if rankingData.count <= 0 { return }
        rankTable.scrollToRow(at: IndexPath(row: rankingData.count - 1, section: 0), at: .bottom, animated: true)
    }
    @IBAction func GetDBScoreData(_ sender: UIButton) {
        guard !isNetworkBusy else { return }
        seSystemAudio.openSePlay()
        if !musicScoreMessage.isEmpty {
            showMusicScore()
            return
        }
        beginNetworkOperation()
        activityIndicator.startAnimating()
        ServerDataHandler().getMusicScoreData(musicID: selectMusic.sqlID, userID: UserData.sharedInstance.UserID) { data in
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                self.endNetworkOperation()
                guard let data else {
                    self.showDownloadError(URLError(.badServerResponse))
                    return
                }
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy/M/d"
                let periods = [("全期間", "score", "updateTime"), ("年間", "scoreYear", "updateTimeYear"),
                               ("月間", "scoreMonth", "updateTimeMonth"), ("週間", "scoreWeek", "updateTimeWeek")]
                self.musicScoreMessage = periods.compactMap { title, scoreKey, timeKey in
                    guard let score = data[scoreKey], let time = data[timeKey],
                          let timestamp = Double(time), timestamp.isFinite else { return nil }
                    return "\n\(title)：\(score) - \(formatter.string(from: Date(timeIntervalSince1970: timestamp)))"
                }.joined()
                if self.musicScoreMessage.isEmpty { self.musicScoreMessage = "\nあなたの記録はありません" }
                self.showMusicScore()
            }
        }
    }

    private func showMusicScore() {
        guard viewIfLoaded?.window != nil else { return }
        let alert = UIAlertController(title: "この楽曲の最大スコア", message: musicScoreMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    //画面遷移処理 _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    //遷移の許可
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        guard super.shouldPerformSegue(withIdentifier: identifier, sender: sender) else { return false }
        seSystemAudio.canselSePlay()
        // Back does not start another username download.
        navigationController?.popViewController(animated: true)
        return false
    }
    //\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
}
