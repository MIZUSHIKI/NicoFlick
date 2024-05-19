//
//  SelectorMenuTagEditorView.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2021/01/21.
//  Copyright © 2021 i.MIZUSHIKI. All rights reserved.
//

import Foundation

class TagEditor: UIViewController {
    
    
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var nicoTagTextView: UITextView!
    //遷移時に受け取り
    var tableviewForTagController:TableViewForTag!
    
    //遷移中フラグ
    var segueing = false
    //Indicator（ネット処理中 画面中央でくるくるさせる）
    private var activityIndicator:UIActivityIndicatorView!
    
    var maeText:String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print(tableviewForTagController.list)
        maeText = tableviewForTagController.list.joined(separator: " ")
        textView.text = maeText
        //Indicatorを作成
        activityIndicator = Indicator(center: self.view.center).view
        self.view.addSubview(activityIndicator)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        
        if(textView.isFirstResponder){
            textView.resignFirstResponder()
        }
    }
    
    @IBAction func PostTags(_ sender: UIButton) {
        if segueing {
            //送信中。２回目タップは受け付けないようにする。
            return
        }
        if maeText != textView.text {
            maeText = textView.text
            let postText = textView.text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " ").pregReplace(pattern: "\\s+", with: " ")// replacingOccurrences(of: "  ", with: " ")
            print(textView.text)
            
            if let id = tableviewForTagController.currentMusic.sqlID {
                segueing = true //遷移中であることを記憶。しないと遷移中に連続タップで何回もデータロードされる。
                //Indicator くるくる開始
                activityIndicator.startAnimating()
                
                ServerDataHandler().postMusicTagUpdate(id: id, tags: postText, userID: UserData.sharedInstance.UserID) { (bool) in
                    if !bool {
                        DispatchQueue.main.async {
                            //UI処理はメインスレッドの必要あり
                            //Indicator隠す
                            self.activityIndicator.stopAnimating()
                            //遷移指示
                            self.segueing = false
                            let alert = UIAlertController(title:"登録できませんでした。", message: nil, preferredStyle: .alert)
                            alert.addAction( UIAlertAction(title: "OK", style: .default, handler: nil) )
                            self.present(alert, animated: true, completion: nil)
                        }
                    }
                    //データベース接続 1：まずmusicデータロード。
                    ServerDataHandler().DownloadMusicData { (error) in
                        if let error = error {
                            print(error)
                            //callback(error)
                            //return
                        }
                        DispatchQueue.main.async {
                            //UI処理はメインスレッドの必要あり
                            //Indicator隠す
                            self.activityIndicator.stopAnimating()
                            //遷移指示
                            self.segueing = false
                            self.tableviewForTagController.list = postText.components(separatedBy: " ")
                            self.dismiss(animated: true, completion: nil)
                        }
                    }
                }
            }
        }
    }
    
    
    @IBAction func CheckNicoTag(_ sender: UIButton) {
        
        //Indicator くるくる開始
        activityIndicator.startAnimating()
        
        let smNum = tableviewForTagController.currentMusic.movieURL.pregMatche_firstString(pattern: "watch/(\\w*\\d+)")
        if smNum == "" {
            return
        }
        
        //GetThumbInfo
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let url = URL(string:AppDelegate.NicoApiURL_GetThumbInfo+"/"+smNum)
        let req = URLRequest(url: url!, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 21.0)
        session.dataTask(with: req){(data,responce,error) in
            if (error != nil) {
                print("error") //エラー。例えばオフラインとか
                DispatchQueue.main.async {//UI処理はメインスレッドの必要あり
                    //Indicator隠す
                    self.activityIndicator.stopAnimating()
                }
                return
            }
            let resText = String(data: data!, encoding:.utf8)!
            if resText.pregMatche(pattern: "<nicovideo_thumb_response status=\"ok\">") {
                DispatchQueue.main.async {//UI処理はメインスレッドの必要あり
                    //self.movieURLTextField.text = resText.pregMatche_firstString(pattern: "<watch_url>(.*?)</watch_url>")
                    self.nicoTagTextView.text = resText.pregMatche_firstString(pattern: "<tags.*?>(.*?)</tags>").pregReplace(pattern: "<tag.*?>", with: "").pregReplace(pattern: "</tag>", with: " ").pregReplace(pattern: "\n|\r\n|\r", with: "").pregReplace(pattern: " +", with: " ").trimmingCharacters(in: .whitespaces).htmlDecoded
                    self.nicoTagTextView.isHidden = false
                }
            }
            DispatchQueue.main.async {//UI処理はメインスレッドの必要あり
                //Indicator隠す
                self.activityIndicator.stopAnimating()
            }
        }.resume()
    }
    
    
    //MARK: キーボードが出ている状態で、キーボード以外をタップしたらキーボードを閉じる
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        //非表示にする。
        if(textView.isFirstResponder){
            textView.resignFirstResponder()
        }
        
    }
    
    //画面遷移処理_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("seg")
    }
    //遷移の許可
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        return true
    }
}
