//
//  GameMenu.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/06/12.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//

import UIKit

class GameMenu: UIViewController {
    
    @IBOutlet weak var settingsView: UIView!
    @IBOutlet var judgeOffsetLabel: UILabel!
    @IBOutlet var judgeOffsetSlider: UISlider!
    @IBOutlet weak var underbar: UIView!
    @IBOutlet weak var overbar: UIView!
    @IBOutlet weak var overbarButton: UIButton!
    
    @IBOutlet weak var fitsMovieSwitch: UISwitch!
    @IBOutlet weak var showOffsetSwitch: UISwitch!
    
    //遷移時に受け取り
    var gameViewController:GameView!
    
    //保存データ
    let userData = UserData.sharedInstance
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        var value:Float = 0.0
        if let jo = userData.JudgeOffset[gameViewController.selectLevel.sqlID] {
            value = jo
        }
        judgeOffsetSlider.value = value
        judgeOffsetLabel.text = String(format:"%0.02f",value)
        if userData.BorderY > 0 {
            underbar.isHidden = true
            overbar.isHidden = false
        }
        if gameViewController.selectLevel.level > 10 {
            underbar.isHidden = true
            overbar.isHidden = true
            overbarButton.isHidden = true
        }
        fitsMovieSwitch.isOn = userData.fitsMovieToKeyboardHeight
        showOffsetSwitch.isOn = userData.showOffsetLabel
        
        settingsView.isHidden = !userData.ShowGameSettings
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
// ゲームメニューボタン
    @IBAction func resume(_ sender: Any) {
        self.gameViewController.returnToMeData = 0
        self.performSegue(withIdentifier: "fromGameMenu", sender: self)
    }
    
    @IBAction func retry(_ sender: Any) {
        self.gameViewController.returnToMeData = 1
        self.performSegue(withIdentifier: "fromGameMenu", sender: self)
    }
    
    @IBAction func musicSelect(_ sender: Any) {
        self.gameViewController.returnToMeData = 2
        self.performSegue(withIdentifier: "fromGameMenu", sender: self)
    }
    
    @IBAction func musicReload(_ sender: UIButton) {
        self.gameViewController.returnToMeData = 3
        self.performSegue(withIdentifier: "fromGameMenu", sender: self)
    }
    @IBAction func practiceMode(_ sender: UIButton) {
        if self.gameViewController.practiceMode {
            self.gameViewController.returnToMeData = 0
            self.performSegue(withIdentifier: "fromGameMenu", sender: self)
            return
        }
        self.gameViewController.seSystemAudio.openSePlay()
        let alert = UIAlertController(title:"練習モード", message: "練習モードにするとスコアが記録されなくなります。よろしいですか？", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction( UIAlertAction(title: "OK", style: .default, handler: {_ in
            self.gameViewController.returnToMeData = 0
            self.gameViewController.practiceMode = true
            // UI
            self.gameViewController.practiceSeekbar.isHidden = false
            self.gameViewController.practiceRatebar.isHidden = false
            self.gameViewController.practiceRateLabel.isHidden = false
            self.gameViewController.practiceAutoPlaySwitch.isHidden = false
            self.gameViewController.practiceAutoPlayLabel.isHidden = false
            self.performSegue(withIdentifier: "fromGameMenu", sender: self)
        }) )
        alert.addAction( UIAlertAction(title: "キャンセル", style: .cancel, handler: nil) )
        self.present(alert, animated: true, completion: nil)
    }
    
// 設定表示
    @IBAction func showGameSettings(_ sender: UIButton) {
        userData.ShowGameSettings = !userData.ShowGameSettings
        settingsView.isHidden = !userData.ShowGameSettings
    }
    
// 各種設定
    @IBAction func JudgeOffsetSlider(_ sender: UISlider) {
        let value = Float(Int(round(sender.value*100)))/100
        sender.value = value
        judgeOffsetLabel.text = String(format:"%0.02f",value)
        userData.JudgeOffset[self.gameViewController.selectLevel.sqlID] = value
    }
    @IBAction func OverbarButton(_ sender: Any) {
        if userData.BorderY == 0 {
            underbar.isHidden = true
            overbar.isHidden = false
            userData.BorderY = overbar.frame.origin.y
        }else {
            underbar.isHidden = false
            overbar.isHidden = true
            userData.BorderY = 0
        }
    }
    @IBAction func fitsMovieToKeyboardHeight(_ sender: UISwitch) {
        userData.fitsMovieToKeyboardHeight = sender.isOn
    }
    @IBAction func showOffset(_ sender: UISwitch) {
        userData.showOffsetLabel = sender.isOn
    }
    
}

