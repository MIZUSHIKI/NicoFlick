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
        if segueing {
            //遷移中。２回目タップは受け付けないようにする。
            return false
        }
        if maeText != textView.text {
            let postText = textView.text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " ").pregReplace(pattern: "\\s+", with: " ")// replacingOccurrences(of: "  ", with: " ")
            tableviewForTagController.list = postText.components(separatedBy: " ")
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
                            self.dismiss(animated: true, completion: nil)
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
                            self.dismiss(animated: true, completion: nil)
                        }
                    }
                }
                return false
            }
        }
        return true
    }
}
