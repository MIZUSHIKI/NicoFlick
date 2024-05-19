//
//  UserCard.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2022/12/22.
//  Copyright © 2022 i.MIZUSHIKI. All rights reserved.
//

import Foundation

class UserCard: UIViewController {
    
    @IBOutlet weak var userCardView: UICustomView!
    @IBOutlet weak var userImageView: UIImageView!
    @IBOutlet weak var userNameLabel: NicokakuMixFixLabel!
    @IBOutlet weak var userIdLabel: NicokakuMixFixLabel!
    @IBOutlet weak var userAverageStarLabel: UILabel!
    @IBOutlet weak var userMaxStarLabel: UILabel!
    @IBOutlet weak var userPlayMusicNumLabel: UILabel!
    @IBOutlet weak var userTotalPlayScoreLabel: UILabel!
    @IBOutlet weak var userTotalMusicScoreLabel: UILabel!
    @IBOutlet weak var userAverageMusicScoreLabel: UILabel!
    
    //効果音プレイヤー(シングルトン)
    var seAudio:SEAudio = SEAudio.sharedInstance
    var seSystemAudio:SESystemAudio = SESystemAudio.sharedInstance
    //保存データ
    let userData = UserData.sharedInstance
    
    //Indicator
    private var activityIndicator:UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        userNameLabel.text = userData.UserName
        userIdLabel.text = userData.UserIDxxx
        let score = userData.Score
        let StarText = { (n:Int) -> String in var t = ""; for _ in 0..<n { t += "★" }; for _ in 0..<(10-n) { t += "☆" }; return t }
        userAverageStarLabel.text = StarText(score.getClearedAverageStar())
        userMaxStarLabel.text = "\(score.getClearedMaxStar())"
        userPlayMusicNumLabel.text = "\(score.getPlayedMusicNum())"
        userTotalPlayScoreLabel.text = "\(score.getPlayedAllScore())"
        userTotalMusicScoreLabel.text = "\(score.getClearedAllMusicScore())"
        userAverageMusicScoreLabel.text = "\(score.getClearedAverageMusicScore())"
        
        let view = SlashShadeView.init(frame: userCardView.bounds, color: .white, lineWidth: 2, space: 5)
        userCardView.addSubview(view)
        userCardView.sendSubview(toBack: view)
        
    }
    
    //画面遷移処理 _/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    @IBAction func returnToMe(segue: UIStoryboardSegue){
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        //print("prepare")
        //print(segue.identifier as String!)

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
