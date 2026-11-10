//
//  ViewController.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/04/29.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var startButton: UICustomButton!
    @IBOutlet weak var settingsButton: UICustomButton!
    @IBOutlet weak var designCoopButton: UIButton!
    @IBOutlet weak var designCoopLabel: UILabel!
    @IBOutlet weak var youkosoButton: UIButton!
    @IBOutlet weak var youkosoLabel: UILabel!
    
    //音楽データ
    var musicDatas:MusicDataLists = MusicDataLists.sharedInstance
    //各ユーザーのネームデータ
    var userNameDatas:userNameDataLists = userNameDataLists.sharedInstance
    //効果音プレイヤー(シングルトン)
    var seSystemAudio:SESystemAudio = SESystemAudio.sharedInstance
    
    //遷移中フラグ
    var segueing = false
    //Indicator（ネット処理中 画面中央でくるくるさせる）
    private var activityIndicator:UIActivityIndicatorView!
    
    var slashView:SlashShadeView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        //最初期処理
        //  ユニークユーザーIDの作成
        let userData = UserData.sharedInstance
        // print( "uuid = \(userData.UserID)" ) //ユーザーID 初めてなら自動で生成される
        
        musicDatas.userID = userData.UserID //levelが自分の編集中のものであるか判別するためにmusicDatasで持っておく

        //Indicatorを作成
        activityIndicator = Indicator(center: self.view.center).view
        self.view.addSubview(activityIndicator)
        
        //初めてのNicoFlick
        self.firstNicoFlick()
        
        //バージョンアップ時に必要な処理があれば実行
        self.migration()
        // 失敗時は完了フラグを残し、次回起動時に再試行する。
        if !userData.donePersistentStorageMigrationV2000,
           userData.migratePersistentStorageV2000() {
            userData.donePersistentStorageMigrationV2000 = true
        }
        // データ移行の成否にかかわらず、起動したアプリのバージョンは毎回記録する。
        userData.MyVersion = AppDelegate.Version
        
        //「デザイン募集中」が気になる人は消せるように
        designCoopLabel.isHidden = userData.lookedDesignCoop_v1900
        
        //上昇斜め背景
        let frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height + 15.0)
        slashView = SlashShadeView.init(frame: frame, color: UIColor.init(red: 0.60, green: 0.70, blue: 1.0, alpha: 0.035), lineWidth: 1.5, space: 15)
        self.view.addSubview(slashView!)
        self.view.sendSubview(toBack: slashView!)
        
        UIView.animate(withDuration: 0.75, delay: 0.0, options: [.repeat, .curveLinear], animations: {self.slashView?.frame.origin.y = -15}, completion: {_ in self.slashView?.frame.origin.y = 0})
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.viewWillEnter), name: .UIApplicationWillEnterForeground, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        UIView.animate(withDuration: 0.75, delay: 0.0, options: [.repeat, .curveLinear], animations: {self.slashView?.frame.origin.y = -15}, completion: {_ in self.slashView?.frame.origin.y = 0})
    }
    @objc func viewWillEnter(notification: NSNotification){
        UIView.animate(withDuration: 0.75, delay: 0.0, options: [.repeat, .curveLinear], animations: {self.slashView?.frame.origin.y = -15}, completion: {_ in self.slashView?.frame.origin.y = 0})
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func infoButton(_ sender: UIButton) {
        let alert = UIAlertController(title:"NicoFlickはフリック入力リズムゲーである 故「ミクフリック」の パクリ、オマージュ、リスペクト、難民先 作品です。", message: """

−2016年7月19日−
ミクフリック/02 サービス終了

−2017年9月29日−
ミクフリック(初代) サービス終了

−2017年9月20日−
　iOS11リリース（32bitアプリなので両方起動できなくなる）
""", preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addAction( UIAlertAction(title: "アプリレビューを見る", style: .default, handler: {_ in
            
            guard let url = URL(string: "https://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=1415478437&pageNumber=0&sortOrdering=2&type=Purple+Software&mt=8") else { return }
            UIApplication.shared.open(url)
        }) )
        alert.addAction( UIAlertAction(title: "デザイン協力募集中(GitHub)", style: .default, handler: {_ in
            
            guard let url = URL(string: "https://github.com/MIZUSHIKI/NicoFlick/blob/master/README.md") else { return }
            UIApplication.shared.open(url)
        }) )
        alert.addAction( UIAlertAction(title: "OK", style: .default, handler: nil) )
        self.present(alert, animated: true, completion: nil)
        //
        UserData.sharedInstance.lookedDesignCoop_v1900 = false
        designCoopLabel.isHidden = false
    }
    @IBAction func TapDesignCoopLabel(_ sender: UITapGestureRecognizer) {
        UserData.sharedInstance.lookedDesignCoop_v1900 = true
        designCoopLabel.isHidden = true
    }
    //画面遷移処理_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    
    @IBAction func returnToMe(segue: UIStoryboardSegue){
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toSelector" {
            // print("toSelector")
        }
    }
    //遷移の許可
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if segueing {
            //遷移中。２回目タップは受け付けないようにする。
            return false
        }
        
        if identifier == "toSelector" || identifier == "toUserCard" {
            //se
            seSystemAudio.start2SePlay()
            //データをロードした後に遷移させるため、一度、遷移キャンセル。
            segueing = true //遷移中であることを記憶。しないと遷移中に連続タップで何回もデータロードされる。
            //Indicator くるくる開始
            activityIndicator.startAnimating()
            
            //ログアウト連打を防ぐためのフラグ
            AppDelegate.isNicoLogout = false

            // NicoFlickのデータ取得とニコニコ動画のメンテナンス確認を並行して行う。
            let downloadGroup = DispatchGroup()
            var isNicoMaintenance = false

            downloadGroup.enter()
            checkNicoMaintenance { isMaintenance in
                isNicoMaintenance = isMaintenance
                downloadGroup.leave()
            }

            //サーバから music,level,userName データを順次取得。
            downloadGroup.enter()
            ServerDataHandler().DownloadMusicDataAndUserNameData { (error) in
                if error != nil {
                    // print(error) //なんか失敗した。けど、とりあえずスルーして次へ。
                }
                downloadGroup.leave()
            }

            downloadGroup.notify(queue: .main) {
                //Indicator隠す
                self.activityIndicator.stopAnimating()
                if isNicoMaintenance {
                    let alert = UIAlertController(
                        title: "ニコニコ動画 メンテナンス",
                        message: "ニコニコ動画がメンテナンス中です。動画を再生できない可能性があります。",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "そのまま進む", style: .default, handler: { _ in
                        self.completeStartSegue(withIdentifier: identifier)
                    }))
                    alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel, handler: { _ in
                        self.segueing = false
                    }))
                    self.present(alert, animated: true, completion: nil)
                } else {
                    self.completeStartSegue(withIdentifier: identifier)
                }
            }
            return false
            
        }else {
            //settingsへ
            //se
            seSystemAudio.startSePlay()
        }
        return true
    }

    private func checkNicoMaintenance(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: AppDelegate.NicoApiURL_GetThumbInfo + "sm9") else {
            completion(false)
            return
        }

        let request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 6.0
        )
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let responseText = String(data: data, encoding: .utf8) else {
                completion(false)
                return
            }
            completion(responseText.range(of: "Maintenance", options: .caseInsensitive) != nil)
        }.resume()
    }

    private func completeStartSegue(withIdentifier identifier: String) {
        if AppDelegate.ServerErrorMessage != "" {
            let alert = UIAlertController(title: AppDelegate.serverErrorTitle, message: AppDelegate.ServerErrorMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "そのまま進む", style: .default, handler: { _ in
                AppDelegate.ServerErrorMessage = ""
                //エラーメッセージ確認後、遷移指示
                self.segueing = false
                self.performSegue(withIdentifier: identifier, sender: self)
            }))
            alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel, handler: { _ in
                AppDelegate.ServerErrorMessage = ""
                self.segueing = false
            }))
            present(alert, animated: true, completion: nil)
        } else {
            //特にエラーなし遷移指示
            segueing = false
            performSegue(withIdentifier: identifier, sender: self)
        }
    }
    //\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
    
    //初めての
    func firstNicoFlick(){
        if UserData.sharedInstance.MyVersion != 0 { return }
        startButton.isHidden = true
        settingsButton.isHidden = true
        designCoopButton.isHidden = true
        designCoopLabel.isHidden = true
        youkosoButton.isHidden = false
        youkosoLabel.isHidden = false
        UIView.animate(
            withDuration: 0.9,
            delay: 0,
            options: [.autoreverse, .repeat, .curveEaseIn],
            animations: {
                self.youkosoLabel.alpha = 0
            }
        )
    }
    @IBAction func firstNicoFlickButton(_ sender: UIButton) {
        youkosoButton.isHidden = true
        youkosoLabel.isHidden = true
        //se
        seSystemAudio.openSePlay()
        let alert = UIAlertController(title:"NicoFlickへようこそ！", message: "プレイヤー名を入力してください", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {
            (action: UIAlertAction!) in
            if alert.textFields![0].text == UserData.sharedInstance.UserName {
                //self.firstNicoFlick_finish()
                return
            }
            let submittedName = alert.textFields?[0].text ?? ""
            // 通信中の重複操作や画面遷移を防ぐ
            self.view.isUserInteractionEnabled = false
            self.activityIndicator.startAnimating()
            //データベースに登録
            ServerDataHandler().postUserName(name: submittedName, userID: UserData.sharedInstance.UserID, callback: { bool in
                DispatchQueue.main.async {
                    //UI処理はメインスレッドの必要あり
                    self.view.isUserInteractionEnabled = true
                    self.activityIndicator.stopAnimating()
                    if bool {
                        //  データ保存
                        UserData.sharedInstance.UserName = submittedName
                    }
                    //self.firstNicoFlick_finish()
                }
            })
            
        }))
        //textfiledの追加
        alert.addTextField(configurationHandler: {(textField: UITextField!) in
            textField.text = UserData.sharedInstance.UserName
            textField.placeholder = "プレイヤー名"
            textField.autocorrectionType = .no
            textField.autocapitalizationType = .none
        })
        self.present(alert, animated: true){
            self.firstNicoFlick_finish()  // キーボード表示中にすでに戻してても良いかもと思って
        }
    }
    func firstNicoFlick_finish(){
        startButton.isHidden = false
        settingsButton.isHidden = false
        designCoopButton.isHidden = false
        //designCoopLabel.isHidden = false
        youkosoLabel.layer.removeAllAnimations()
    }
    //マイグレーション
    func migration(){
        let previousVersion = UserData.sharedInstance.MyVersion
        //print("previousVersion",previousVersion)
        if previousVersion == 0 { return }
        if previousVersion < 1430 {
            //データベースの初期データが上手く記録できていない時期があったため music,level を初期化して再取得
            MusicDataLists.sharedInstance.reset()
            UserData.sharedInstance.MusicsJson = ""
            UserData.sharedInstance.LevelsJson = ""
            // print("music,level Reset")
        }
        if previousVersion < 1500 {
            if UserData.sharedInstance.MyFavorite.count > 0 {
                // print("お気に入り仕様変更を見せる")
                UserData.sharedInstance.lookedChangeFavoSpec_v1500 = false
            }
        }
        if previousVersion < 1802 {
            //notesの頭16文字だけ拾ってthumbMovieに使用するため music,level を初期化して再取得
            MusicDataLists.sharedInstance.reset()
            UserData.sharedInstance.MusicsJson = ""
            UserData.sharedInstance.LevelsJson = ""
            // print("music,level Reset")
        }
        if previousVersion < 1810 {
            //avplayerを34個くらい配列(Cacheとして)で持ったらそれ以上アクセスできなくなったからThumbMovieと動画キャッシュで合計30までにしとこうということで動画保持件数の最大を10に引き下げ
            if UserData.sharedInstance.cachedMovieNum > 10 {
                UserData.sharedInstance.cachedMovieNum = 10
            }
        }
        if previousVersion < 1911 {
            // ニコニコRe仮からの復帰
            if UserData.sharedInstance.SelectedMusicCondition.tags.pregMatche(pattern: "^@sm:\\d+\\-\\d+")
               || UserData.sharedInstance.SelectedMusicCondition.tags.pregMatche(pattern: "^人類には早すぎる動画")
               || UserData.sharedInstance.SelectedMusicCondition.tags.pregMatche(pattern: "^才能の無駄遣い")
            {
                if UserData.sharedInstance.lookedExtend == false {
                    UserData.sharedInstance.SelectedMusicCondition.tags = "@初期楽曲"
                    UserData.sharedInstance.SelectedMusicCondition.sortItem = "曲の投稿日時 降順"
                }else{
                    UserData.sharedInstance.SelectedMusicCondition.tags = ""
                    UserData.sharedInstance.SelectedMusicCondition.sortItem = "曲の投稿日時 降順"
                }
            }
        }
        if previousVersion < 2000 {
            let userData = UserData.sharedInstance
            // 既存ユーザーだけ永続ストレージ移行を必要とする。
            userData.donePersistentStorageMigrationV2000 = false
            // 保存済みの旧ソート名を新しい表示名へ移行する。難易度指定部分は維持する。
            let sortItemMigrations = [
                (old: "曲の投稿が古い順", new: "曲の投稿日時 昇順"),
                (old: "曲の投稿が新しい順", new: "曲の投稿日時 降順"),
                (old: "ゲームの投稿が古い曲順", new: "ゲームの投稿日時 昇順"),
                (old: "ゲームの投稿が新しい曲順", new: "ゲームの投稿日時 降順"),
                (old: "動画IDが小さい順", new: "動画ID 昇順"),
                (old: "動画IDが大きい順", new: "動画ID 降順"),
                (old: "ゲームプレイ回数が多い曲順", new: "みんなのプレイ回数が多い曲順"),
                (old: "ゲームプレイ回数が少ない曲順", new: "みんなのプレイ回数が少ない曲順")
            ]
            let selectedSortItem = userData.SelectedMusicCondition.sortItem
            if let migration = sortItemMigrations.first(where: { selectedSortItem.hasPrefix($0.old) }) {
                userData.SelectedMusicCondition.sortItem = selectedSortItem.replacingOccurrences(
                    of: migration.old,
                    with: migration.new
                )
            }
            // levelお気に入りを持って入れば、musicお気に入りに移行するフラグを立てる（移行処理はSelectorで）
            if userData.MyFavoriteAll_v1500.count > 0 {
                userData.doneFavoriteUpdate_v2000 = false
            }
            // 既存スコアがあるlevelは1回プレイ済みとして履歴へ取り込む。
            // 当時のプレイ日時は不明なため、最近プレイした曲順には影響しない値にする。
            var levelPlayHistories = userData.LevelPlayHistories
            for levelID in userData.Score.scores.keys where levelPlayHistories[levelID] == nil {
                levelPlayHistories[levelID] = LevelPlayHistory(playCount: 1, lastPlayedAt: 0)
            }
            userData.LevelPlayHistories = levelPlayHistories
            // NO_NAMEの場合、名前を変えてみないか を表示するフラグ
            userData.lookedNameRegistrationIfNoName_v2000 = false
            // 既存スコアの難易度をmusicデータ取得後にSelectorで移行する。
            userData.doneScoreLevelMigration = false
            userData.doneJustPlayedScoreLevelMigration = false
            
            MusicDataLists.sharedInstance.reset()
            UserData.sharedInstance.MusicsJson = ""
            UserData.sharedInstance.LevelsJson = ""
        }
        if previousVersion < 2100 {
            // calcLvを全体更新するため再ロード
            MusicDataLists.sharedInstance.reset()
            UserData.sharedInstance.MusicsJson = ""
            UserData.sharedInstance.LevelsJson = ""
        }
    }
}
