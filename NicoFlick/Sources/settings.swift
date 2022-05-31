//
//  settings.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/08/15.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation

class Settings: UIViewController {
    
    @IBOutlet var textfieldMail: UITextField!
    @IBOutlet var textfieldPass: UITextField!
    @IBOutlet var labelUserID: UILabel!
    @IBOutlet var textfieldName: UITextField!
    @IBOutlet var cachedMovieNum: UILabel!
    @IBOutlet var cachedMovieNumSlider: UISlider!
    
    @IBOutlet weak var movieVolumeLabel: UILabel!
    @IBOutlet weak var movieVolumeSlider: UISlider!
    @IBOutlet weak var gameSeVolumeLabel: UILabel!
    @IBOutlet weak var systemSeVolumeLabel: UILabel!
    @IBOutlet weak var gameSeVolumeSlider: UISlider!
    @IBOutlet weak var systemSeVolumeSlider: UISlider!
    
    @IBOutlet weak var playMovie: UIButton!
    
    //効果音プレイヤー(シングルトン)
    var seAudio:SEAudio = SEAudio.sharedInstance
    var seSystemAudio:SESystemAudio = SESystemAudio.sharedInstance
    //保存データ
    let userData = UserData.sharedInstance
    
    //Indicator
    private var activityIndicator:UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        //既に保存データが有れば入力欄に入れる
        textfieldMail.text = userData.NicoMail
        textfieldPass.text = userData.NicoPass
        labelUserID.text = userData.UserIDxxx
        textfieldName.text = userData.UserName
        cachedMovieNum.text = String(userData.cachedMovieNum)+" 件"
        cachedMovieNumSlider.value = Float(userData.cachedMovieNum)
        movieVolumeLabel.text = "\(Int(userData.SoundVolumeMovie * 100))%"
        gameSeVolumeLabel.text = "\(Int(userData.SoundVolumeGameSE * 100))%"
        systemSeVolumeLabel.text = "\(Int(userData.SoundVolumeSystemSE * 100))%"
        movieVolumeSlider.value = userData.SoundVolumeMovie
        gameSeVolumeSlider.value = userData.SoundVolumeGameSE
        systemSeVolumeSlider.value = userData.SoundVolumeSystemSE
        
        if #available(iOS 15.0, *){
            playMovie.configuration = nil
        }
        playMovie.titleLabel?.font = UIFont.systemFont(ofSize: 10)
        playMovie.titleLabel?.numberOfLines = 1
        playMovie.titleLabel?.lineBreakMode = NSLineBreakMode.byWordWrapping
        if let cache = CachedMovies.sharedInstance.cachedMovies.last {
            playMovie.setTitle("  動画再生：\(cache.smNum)", for: .normal)
        }else {
            playMovie.setTitle("  動画再生：キャッシュなし", for: .normal)
        }
        
        //Indicatorを作成
        activityIndicator = Indicator(center: self.view.center).view
        self.view.addSubview(activityIndicator)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.CloseKeyboard()
    }
    func CloseKeyboard() {
        let objects = [textfieldMail,
                       textfieldPass,
                       textfieldName]
        for object in objects {
            if(object?.isFirstResponder)!{
                object?.resignFirstResponder()
            }
        }
    }
    
    
    //オブジェクト処理_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    @IBAction func buttonRegistName(_ sender: Any) {
        self.CloseKeyboard()

        //Indicator くるくる開始
        activityIndicator.startAnimating()
        
        //データベースに登録
        ServerDataHandler().postUserName(name: textfieldName.text!, userID: userData.UserID, callback: { bool in
            
            DispatchQueue.main.async {
                //UI処理はメインスレッドの必要あり
                //  Indicator隠す
                self.activityIndicator.stopAnimating()
                if bool {
                    //  データ保存
                    self.userData.UserName = self.textfieldName.text!
                    
                    let alert = UIAlertController(title:"あなたの名前を登録しました", message: nil, preferredStyle: UIAlertControllerStyle.alert)
                    alert.addAction( UIAlertAction(title: "OK", style: .default, handler: nil) )
                    self.present(alert, animated: true, completion: nil)
                }else {
                    let alert = UIAlertController(title:"名前の登録に失敗しました", message: nil, preferredStyle: UIAlertControllerStyle.alert)
                    alert.addAction( UIAlertAction(title: "OK", style: .default, handler: nil) )
                    self.present(alert, animated: true, completion: nil)
                }
            }
        })
        

    }
    @IBAction func cachedMovieNumSlider(_ sender: UISlider) {
        userData.cachedMovieNum = Int(sender.value)
        sender.value = Float(userData.cachedMovieNum)
        cachedMovieNum.text = String(userData.cachedMovieNum)+" 件"
    }
    
    @IBAction func playMovieButton(_ sender: UIButton) {
        if let cache = CachedMovies.sharedInstance.cachedMovies.last {
            if cache.avPlayerViewController.player?.isPlaying == false {
                cache.avPlayerViewController.player?.seek(to: CMTimeMakeWithSeconds(0, Int32(NSEC_PER_SEC)) )
                cache.avPlayerViewController.player?.play()
            }else {
                cache.avPlayerViewController.player?.pause()
            }
        }
    }
    @IBAction func movieVolumeSlider_ValueChanged(_ sender: UISlider) {
        userData.SoundVolumeMovie = sender.value
        movieVolumeLabel.text = "\(Int(sender.value * 100))%"
        if let cache = CachedMovies.sharedInstance.cachedMovies.last {
            cache.avPlayerViewController.player?.volume = userData.SoundVolumeMovie
        }
    }
    @IBAction func movieVolumeSlider_TouchUp(_ sender: UISlider) {
        for cache in CachedMovies.sharedInstance.cachedMovies {
            cache.avPlayerViewController.player?.volume = userData.SoundVolumeMovie
        }
    }
    @IBAction func GameSeVolumeSlider_ValueChanged(_ sender: UISlider) {
        userData.SoundVolumeGameSE = sender.value
        gameSeVolumeLabel.text = "\(Int(sender.value * 100))%"
    }
    @IBAction func GameSeVolumeSlider_TouchUp(_ sender: UISlider) {
        seAudio.volume = userData.SoundVolumeGameSE
        seAudio.okJinglePlay()
    }
    @IBAction func systemSeVolumeSlider_ValueChanged(_ sender: UISlider) {
        userData.SoundVolumeSystemSE = sender.value
        systemSeVolumeLabel.text = "\(Int(sender.value * 100))%"
    }
    @IBAction func systemSeVolumeSlider_TouchUp(_ sender: UISlider) {
        seSystemAudio.volume = userData.SoundVolumeSystemSE
        seSystemAudio.startSePlay()
    }
    
    @IBAction func buttonDeleteLoadData(_ sender: UIButton) {

        //削除
        let alert = UIAlertController(title:"データベースからロードしたデータを全て削除", message: "何か不具合があった場合の初期化用です。", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction( UIAlertAction(title: "OK", style: .default, handler: {_ in
            MusicDataLists.sharedInstance.reset()
            self.userData.MusicsJson = ""
            self.userData.LevelsJson = ""
            userNameDataLists.sharedInstance.reset()
            self.userData.UserNamesJson = ""
            self.userData.UserNamesServerJsonNumCount = 0
            self.userData.UserNamesServerJsonCreateTime = 0
            ScoreDataLists.sharedInstance.reset()
            self.userData.ScoresJson = ""
            CommentDataLists.sharedInstance.reset()
            self.userData.CommentsJson = ""
        }) )
        alert.addAction( UIAlertAction(title: "キャンセル", style: .cancel, handler: nil) )
        self.present(alert, animated: true, completion: nil)
    }
    

    //画面遷移処理 _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    @IBAction func returnToMe(segue: UIStoryboardSegue){
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        //print("prepare")
        //print(segue.identifier as String!)
        //データ保存
        userData.NicoMail = textfieldMail.text!
        userData.NicoPass = textfieldPass.text!
        //動画ストップ
        for cache in CachedMovies.sharedInstance.cachedMovies {
            cache.avPlayerViewController.player?.pause()
        }

        seSystemAudio.canselSePlay()
    }
    //遷移の許可
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        //print("should")
        //print(identifier)
        return true
    }
    //\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
}

