//
//  settings.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/08/15.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//

import UIKit

class Settings: UIViewController {
    
    @IBOutlet var textfieldMail: UITextField!
    @IBOutlet var textfieldPass: UITextField!
    @IBOutlet var labelUserID: UILabel!
    @IBOutlet var textfieldName: UITextField!
    @IBOutlet var cachedMovieNum: UILabel!
    @IBOutlet var cachedMovieNumSlider: UISlider!
    
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
        activityIndicator.isHidden = false
        
        //データベースに登録
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.PHPURL)!
        var req = URLRequest(url: url)
        let body = "req=userName-add&id="+userData.UserID+"&name="+textfieldName.text!
        req.httpMethod = "POST"
        req.httpBody = body.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: req){(data,responce,error) in
            if error != nil {
                return
            }
            //let str:String = String(data: data!, encoding: String.Encoding.utf8)!
            //print(str)
            DispatchQueue.main.async {
                //UI処理はメインスレッドの必要あり
                //  Indicator隠す
                self.activityIndicator.stopAnimating()
                self.activityIndicator.isHidden=true
                //  データ保存
                self.userData.UserName = self.textfieldName.text!
            }
        }
        task.resume()

    }
    @IBAction func cachedMovieNumSlider(_ sender: UISlider) {
        userData.cachedMovieNum = Int(sender.value)
        sender.value = Float(userData.cachedMovieNum)
        cachedMovieNum.text = String(userData.cachedMovieNum)+" 件"
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

    }
    //遷移の許可
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        //print("should")
        //print(identifier)
        return true
    }
    //\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
}

