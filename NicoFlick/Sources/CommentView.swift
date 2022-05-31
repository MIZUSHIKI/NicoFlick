//
//  CommentView.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/09/03.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//

import Foundation

class CommentView: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextViewDelegate {
    
    @IBOutlet var musicTitle: UILabel!
    @IBOutlet var musicRank: UILabel!
    @IBOutlet var commentTable: UITableView!
    @IBOutlet var commentCharCountLabel: UILabel!
    @IBOutlet var commentTextView: UITextView!
    @IBOutlet var maku: UIView!
    @IBOutlet var commentPostButton: UIButton!
    @IBOutlet weak var usernameDownloadProgressLabel: UILabel!
    @IBOutlet weak var tabBar: UITabBar!
    
    //効果音プレイヤー(シングルトン)
    var seSystemAudio:SESystemAudio = SESystemAudio.sharedInstance
    //遷移時に受け取り
    var selectMusic:musicData!
    var selectLevel:levelData!
    var commentPostable:Bool!
    var resultViewController:ResultView!
    var rankingViewController:RankingView?
    
    var userNameDatas:userNameDataLists = userNameDataLists.sharedInstance
    var commentData:[commentData] = []
    let commentDatas:CommentDataLists = CommentDataLists.sharedInstance
    
    let myID = UserData.sharedInstance.UserID
    
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
        activityIndicator.startAnimating()
        
        //
        let view = SlashShadeView.init(frame: self.view.frame, color: UIColor.init(red: 204/255, green: 255/255, blue: 102/255, alpha: 1.0), lineWidth: 1, space: 2)
        self.view.addSubview(view)
        self.view.sendSubview(toBack: view)
        
        //サムネイル
        if let aiview = rankingViewController?.view.viewWithTag(36){
            let backThumbView = UIImageView(frame: self.view.frame)
            let image = (aiview as! UIImageView).image
            backThumbView.image = image
            backThumbView.alpha = 0.5
            self.view.addSubview(backThumbView)
            self.view.sendSubview(toBack: backThumbView)
        }else {
            let backThumbView = AsyncImageView(frame: CGRect(x: 0, y: 0,
                                                        width: self.view.frame.size.width,
                                                        height: self.view.frame.size.height))
            backThumbView.loadImage(urlString: selectMusic.thumbnailURL, contentMode: .scaleAspectFill)
            backThumbView.alpha = 0.5
            backThumbView.tag = 36
            self.view.addSubview(backThumbView)
            self.view.sendSubview(toBack: backThumbView)
        }
        
        //テーブルビュー設定
        commentTable.estimatedRowHeight = 50
        commentTable.rowHeight = UITableViewAutomaticDimension
        
        //
        commentTextView.delegate = self
        commentTextView.returnKeyType = .done
        
        //データベース接続

//        ServerDataHandler().DownloadScoreData(levelID: self.selectLevel.sqlID!){ (data) in
        ServerDataHandler().DownloadCommentData(levelID: selectLevel.sqlID){ (error) in
            DispatchQueue.main.async {
                //UI処理はメインスレッドの必要あり
                //Indicator隠す
                self.activityIndicator.stopAnimating()
                self.commentData = self.commentDatas.getSortedComments(levelID: self.selectLevel.sqlID)
                //テーブル再描画
                self.commentTable.reloadData()
            }
        }
        ServerDataHandler().getCommentData(levelID: selectLevel.sqlID) { (data) in
        }
        
        commentTable.reloadData()
        
        if commentPostable {
            
        }else {
            commentTextView.isEditable = false
            commentTextView.text = "ゲームクリア後リザルト画面からコメント出来ます。"
            commentTextView.backgroundColor = UIColor.gray
            commentPostButton.isEnabled = false
            commentPostButton.backgroundColor = UIColor.gray
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)
        self.configureObserver()
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        
        super.viewWillDisappear(animated)
        self.removeObserver() // Notificationを画面が消えるときに削除
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        print("tab select")
        seSystemAudio.openSePlay()
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // セルを作る
        let cell = tableView.dequeueReusableCell(withIdentifier: "commentCell", for: indexPath)
        var row = indexPath.row
        if selectLevel.description != "" {
            if indexPath.row == 0 {
                //投稿者コメント
                //(cell.viewWithTag(1) as! UILabel).text = "\(indexPath.row+1)"
                cell.contentView.backgroundColor = UIColor.init(red: 0.6, green: 0.9, blue: 0.2, alpha: 0.5)
                (cell.viewWithTag(2) as! UILabel).text = selectLevel.creator
                (cell.viewWithTag(2) as! UILabel).textColor = UIColor.init(red: 0.8, green: 0.3, blue: 0.3, alpha: 1.0)
                (cell.viewWithTag(3) as! UILabel).text = selectLevel.description
                (cell.viewWithTag(3) as! UILabel).sizeToFit()
                (cell.viewWithTag(4) as! UILabel).text = "投稿者コメント"
                return cell
            }
            row -= 1
        }
        //ユーザーコメント
        //(cell.viewWithTag(1) as! UILabel).text = "\(indexPath.row+1)"
        cell.contentView.backgroundColor = UIColor.init(red: 0, green: 0, blue: 0, alpha: 0.0)
        // -Name
        if( commentData[row].userID! == myID ){
            (cell.viewWithTag(2) as! UILabel).text = UserData.sharedInstance.UserName != "" ? UserData.sharedInstance.UserName : "NO_NAME"
        }else {
            (cell.viewWithTag(2) as! UILabel).text = userNameDatas.getUserName( userID: commentData[row].userID! )
        }
        (cell.viewWithTag(2) as! UILabel).textColor = UIColor.init(red: 0.8, green: 0.3, blue: 0.3, alpha: 1.0)
        // -Comment
        (cell.viewWithTag(3) as! UILabel).text = commentData[row].comment
        (cell.viewWithTag(3) as! UILabel).sizeToFit()
        let dateUnix: TimeInterval = Double(commentData[row].sqlUpdateTime!)
        let date = Date(timeIntervalSince1970: dateUnix)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        (cell.viewWithTag(4) as! UILabel).text = formatter.string(from: date)
        return cell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // セルの数を設定
        var haveDescription = 0
        if selectLevel.description != "" {
            haveDescription = 1
        }
        return commentData.count + haveDescription
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Comment"
    }
    
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // セルがタップされた時の処理
        print("タップされたセルのindex番号: \(indexPath.row)")
        //非表示にする。
        if(commentTextView.isFirstResponder){
            commentTextView.resignFirstResponder()
        }
    }
    /*
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // セルの高さを設定
        return 50
    }
    */
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        // アクセサリボタン（セルの右にあるボタン）がタップされた時の処理
        print("タップされたアクセサリがあるセルのindex番号: \(indexPath.row)")
    }
    
    //UITextView
    func textViewDidChange(_ textView: UITextView) {
        if textView.text.count > 64 {
            textView.text = String(textView.text.prefix(64))
        }
        commentCharCountLabel.text = "\(textView.text.count)/64文字"
        
    }
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange,
                   replacementText text: String) -> Bool {
        if text == "\n" {
            textView.resignFirstResponder() //キーボードを閉じる
            return false
        }
        return true
    }
    
    // Notificationを設定
    func configureObserver() {
        
        let notification = NotificationCenter.default
        notification.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        notification.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    
    // Notificationを削除
    func removeObserver() {
        
        let notification = NotificationCenter.default
        notification.removeObserver(self)
    }
    
    // キーボードが現れた時に、画面全体をずらす。
    @objc func keyboardWillShow(notification: Notification?) {
        
        let rect = (notification?.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue
        let duration: TimeInterval? = notification?.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? Double
        UIView.animate(withDuration: duration!, animations: { () in
            let transform = CGAffineTransform(translationX: 0, y: -(rect?.size.height)!)
            self.view.transform = transform
            
        })
        maku.isHidden = false
    }
    
    // キーボードが消えたときに、画面を戻す
    @objc func keyboardWillHide(notification: Notification?) {
        
        let duration: TimeInterval? = notification?.userInfo?[UIKeyboardAnimationCurveUserInfoKey] as? Double
        UIView.animate(withDuration: duration!, animations: { () in
            
            self.view.transform = CGAffineTransform.identity
        })
        maku.isHidden = true
    }
    
    //MARK: キーボードが出ている状態で、キーボード以外をタップしたらキーボードを閉じる
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        //非表示にする。
        if(commentTextView.isFirstResponder){
            commentTextView.resignFirstResponder()
        }
        
    }
    @IBAction func commentPostButton(_ sender: Any) {
        if commentTextView.text == "" {
            return
        }
        //非表示にする。
        if(commentTextView.isFirstResponder){
            commentTextView.resignFirstResponder()
        }
        //テキストボックスを使えなくする
        commentTextView.isEditable = false
        commentTextView.backgroundColor = UIColor.gray
        commentPostButton.isEnabled = false
        commentPostButton.backgroundColor = UIColor.gray
        
        //Indicator くるくる開始
        activityIndicator.startAnimating()
        
        //  ユーザーID
        let userData = UserData.sharedInstance
        // コメント投稿
        ServerDataHandler().postComment(comment: commentTextView.text, levelID: selectLevel.sqlID, userID: userData.UserID) {
            // 再度データベースからコメントデータを取得してリストを更新
            ServerDataHandler().DownloadCommentData(levelID: self.selectLevel.sqlID){ (error) in
                
            }
            ServerDataHandler().getCommentData(levelID: self.selectLevel.sqlID) { (data) in
                DispatchQueue.main.async {
                    //UI処理はメインスレッドの必要あり
                    //Indicator隠す
                    self.activityIndicator.stopAnimating()
                    self.commentData = self.commentDatas.getSortedComments(levelID: self.selectLevel.sqlID)
                    //テーブル再描画
                    self.commentTable.reloadData()
                }
            }
        }
    }
    
    //画面遷移処理 _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    //遷移の許可
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        print("should comment")
        print(identifier)
        seSystemAudio.canselSePlay()
        return true
    }
    //\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
}
