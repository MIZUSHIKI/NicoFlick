//
//  Untitled.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2026/09/21.
//  Copyright © 2026 i.MIZUSHIKI. All rights reserved.
//

import UIKit

class SelectorLikeView: UIViewController {
    
    //保存データ
    let userData = UserData.sharedInstance

    //遷移時に受け取り
    var selectorController:Selector!
    
    var selectLevels:[levelData]?
    var selectLevel:levelData?
    
    var mae_like:Int = -3
    var now_like:Int = -3
    var mae_levelSortCondition:Bool = false
    var now_levelSortCondition:Bool = false
    
    var hasStartedPlaying:Bool = false
    var hasScore:Bool = false
    
    @IBOutlet weak var likeHeart: UIImageView!
    @IBOutlet weak var loveHeart: UIImageView!
    @IBOutlet weak var dislikeHeart: UIImageView!
    @IBOutlet weak var levelStar_normal: UILabel!
    @IBOutlet weak var levelStar_full: UILabel!
    @IBOutlet weak var creatorName: UILabel!
    @IBOutlet weak var Switch_sortLikesFirst: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // 取得 : selectLevel
        if selectorController.currentLevels.count > 0 {
            selectLevels = selectorController.currentLevels
        }
        if let levels = selectLevels {
            if levels.count > selectorController.levelSelectPicker.selectedRow(inComponent: 0) {
                selectLevel = levels[selectorController.levelSelectPicker.selectedRow(inComponent: 0)]
            }
        }
        
        // 各変数格納, UI処理
        if let level = selectLevel {
            if let like = userData.MyLike[level.sqlID] {
                mae_like = like
                now_like = mae_like
            }
            mae_levelSortCondition = (userData.LevelSortCondition != 0)
            now_levelSortCondition = mae_levelSortCondition
            
            hasStartedPlaying = userData.LevelPlayHistories[level.sqlID] != nil
            hasScore = userData.Score.scores.keys.contains(level.sqlID)
            
            update_likeIcon()
            Switch_sortLikesFirst.isOn = now_levelSortCondition
            levelStar_normal.isHidden = level.level > 10
            levelStar_full.isHidden = level.level <= 10
            levelStar_normal.text = level.getLevelAsString()
            creatorName.text = level.creator
        }
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //UIアクション処理_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    @IBAction func likeButton(_ sender: UIButton) {
        if !hasStartedPlaying {
            let alert = UIAlertController(title:nil, message: "プレイしたことがあると選択できるようになります", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            return
        }
        now_like = now_like == 1 ? 0 : 1
        self.update_likeIcon()
    }
    @IBAction func loveButton(_ sender: UIButton) {
        if !hasScore {
            let alert = UIAlertController(title:nil, message: "最後までプレイしたことがあると選択できるようになります", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            return
        }
        now_like = now_like == 2 ? 0 : 2
        self.update_likeIcon()
    }
    @IBAction func dislikeButton(_ sender: UIButton) {
        if !hasStartedPlaying {
            let alert = UIAlertController(title:nil, message: "まだプレイしたことがありません。プレイ後に選択できます。", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            return
        }
        now_like = now_like == -1 ? 0 : -1
        self.update_likeIcon()
    }
    func update_likeIcon(){
        switch now_like {
        case 2:
            loveHeart.isHidden = false
            likeHeart.isHidden = false
            dislikeHeart.isHidden = true
        case 1:
            loveHeart.isHidden = true
            likeHeart.isHidden = false
            dislikeHeart.isHidden = true
        case -1:
            loveHeart.isHidden = true
            likeHeart.isHidden = true
            dislikeHeart.isHidden = false
        default:
            loveHeart.isHidden = true
            likeHeart.isHidden = true
            dislikeHeart.isHidden = true
        }
    }
    
    @IBAction func sortLikesFirst(_ sender: UISwitch) {
        now_levelSortCondition = sender.isOn
    }
    
    //画面遷移処理_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    var onDismiss: ((Bool) -> Void)?
    
    @IBAction func dismissFavorite(_ sender: UIButton) {
        var changed = false
        if now_like != mae_like {
            changed = true
            if let level = selectLevel {
                // MyLike
                userData.MyLike[level.sqlID] = now_like
                // print(userData.MyLike)
                // LikeCounter, DislikeCounter : データベース送信用
                if mae_like == -1 || now_like == -1 {
                    // 前回がdislike済みで今回変更があったということはdislikeの数を減らすため-1
                    // 今回dislikeオンで前回と変更があったということはdislikeの数をふやすため+1
                    let changeNum = mae_like == -1 ? -1 : 1
                    userData.DislikeCount.changeLikeCount(sqlID: level.sqlID, change: changeNum)
                    // print("DislikeCount",userData.DislikeCount.counter)
                }
                if mae_like > 0 || now_like > 0 {
                    let now = now_like >= 0 ? now_like : 0
                    let mae = mae_like >= 0 ? mae_like : 0
                    let changeNum = now - mae
                    if changeNum != 0 {
                        userData.LikeCount.changeLikeCount(sqlID: level.sqlID, change: changeNum)
                        // print("LikeCount",userData.LikeCount.counter)
                    }
                }
            }
        }
        if now_levelSortCondition != mae_levelSortCondition {
            changed = true
            userData.LevelSortCondition = now_levelSortCondition ? 1 : 0
        }
        onDismiss?(changed)
        dismiss(animated: false)
    }
}
