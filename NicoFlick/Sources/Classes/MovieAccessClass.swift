//
//  MovieAccessClass.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/04/30.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//

import UIKit

class MovieAccess{
    
    let session = URLSession(configuration: URLSessionConfiguration.default)
    var firstAttack = true
    
    
    //StreamingPlay用getflv→ニコページアクセス（→再生） 処理
    func StreamingUrlNicoAccess(smNum: String, callback: @escaping (String) -> Void ) -> Void {
        var smNum = smNum
        let reachability = AMReachability()
        if (reachability?.isReachable)! {
            print("インターネット接続あり")
            if (reachability?.isReachableViaWiFi)!{
                print("Wifi接続有り")
            }else {
                print("Wifi接続なし")
                if smNum.hasSuffix("?eco=1") == false {
                    smNum += "?eco=1"
                }
            }
        } else {
            print("インターネット接続なし")
        }
        print("smNum=\(smNum)")
        
        
        //いつの間にかアカウント処理が上手くいかなくなったから一時的にやめる
        //let userData = UserData.sharedInstance
        //アカウントなしの場合
        if true/*userData.NicoMail == "" || userData.NicoPass == ""*/ {
            let strURL = String.init(format: "http://www.nicovideo.jp/watch/%@",smNum);
            let url = URL(string: strURL)
            
            let task2 = self.session.dataTask(with: url!){  (data, responce, error) in
                if data != nil{
                    //動画ページにアクセス。動画URLを取得
                    let str:String = String(data: data!, encoding: String.Encoding.utf8)!
                    var st = str.pregMatche_firstString(pattern: "<div id=\"js-initial-watch-data\" data-api-data=\"(.*?)</div>")
                    st.htmlDecode()
                    let wI = NSMutableString( string: st )
                    CFStringTransform( wI, nil, "Any-Hex/Java" as NSString, true )
                    let s = wI as String
                    let es = s.pregReplace(pattern: "\\\\", with: "")
                    //print(es)
                    let nicoDougaURL = es.pregMatche_firstString(pattern: "\"smileInfo\":\\{\"url\":\"(.*?)\"")
                    print(nicoDougaURL)
                    
                    //動画 拡張子の確認
                    var m = ""
                    var ansM:[String]=[]
                    if nicoDougaURL.pregMatche(pattern: "(.)=", matches: &ansM){
                        m = ansM[1]
                    }
                    
                    switch m {
                    case "v":  //.flv
                        print("!!FLV")
                        //もしflvならエコノミーを試してみる
                        if smNum.hasSuffix("?eco=1") == false {
                            self.StreamingUrlNicoAccess(smNum: smNum+"?eco=1", callback: callback)
                        }
                        break
                        
                    case "s": //.swf
                        //何も出来ない
                        break
                        
                    default: //case "m"->.mp4
                        
                        callback(nicoDougaURL)
                    }
                }
            }
            task2.resume()
            return
        }

        //ニコニコ動画 getflvAPIを利用（アカウントでアクセス）
        let urlGetflv = URL(string:String.init(format: "http://flapi.nicovideo.jp/api/getflv/%@",smNum))
        let task = session.dataTask(with: urlGetflv!){(data,responce,error) in
            if data != nil {
                let str:String = String(data: data!, encoding: String.Encoding.utf8)!
                print(str)
                //getflvAPIで情報取得できたか
                if (str as NSString).substring(to: 9) == "thread_id" {
                    //getflvAPIでニコニコにアクセス出来た → 取得データから動画URLを抽出
                    var nicoDougaURL = ""
                    var ansUrl: [String] = []
                    if str.pregMatche(pattern: "&url=(.*?)&", matches: &ansUrl){
                        nicoDougaURL = ansUrl[1]
                    }
                    nicoDougaURL = nicoDougaURL.removingPercentEncoding!
                    //動画のURLが取得できた
                    print("nicoDougaURL:"+nicoDougaURL)
                    
                    //動画 拡張子の確認
                    var m = ""
                    var ansM:[String]=[]
                    if nicoDougaURL.pregMatche(pattern: "(.)=", matches: &ansM){
                        m = ansM[1]
                    }
                    
                    switch m {
                    case "v":  //.flv
                        print("!!FLV")
                        //もしflvならエコノミーを試してみる
                        if smNum.hasSuffix("?eco=1") == false {
                            self.StreamingUrlNicoAccess(smNum: smNum+"?eco=1", callback: callback)
                        }
                        break
                        
                    case "s": //.swf
                        //何も出来ない
                        break
                        
                    default: //case "m"->.mp4
                        
                        //動画URL取得->ニコニコアクセス
                        //動画ファイルへのアクセスは、動画ページへのアクセスしたキャッシュがないと403になるのでページにアクセスする。
                        let strURL = String.init(format: "http://www.nicovideo.jp/watch/%@",smNum);
                        let url = URL(string: strURL)
                        
                        let task2 = self.session.dataTask(with: url!){  (data, responce, error) in
                            if data != nil{
                                //これで動画ページにアクセスしたことになった。あとは動画URLにアクセスすれば再生できる
                                callback(nicoDougaURL)
                            }
                        }
                        task2.resume()
                    }

                    
                }else {
                    //thread_idじゃない==getflvAPIでニコニコにアクセスできなかった
                    
                    //一回目だったらログインしなおしてもう一回試す
                    if self.firstAttack==true {
                        self.firstAttack=false
                        let url = URL(string: "https://secure.nicovideo.jp/secure/login")
                        var req = URLRequest.init(url: url!)
                        
                        //保存データ
                        let userData = UserData.sharedInstance
                        
                        let postData = String.init(format: "site=niconico&mail=%@&password=%@&submit=アカウントのロック解除申請",
                                                   userData.NicoMail,
                                                   userData.NicoPass)
                        req.httpMethod = "POST"
                        req.httpBody = postData.data(using: .utf8)
                        let task2 = self.session.dataTask(with: req){  (data, responce, error) in
                            if data != nil{
                                //これで動画ページにアクセスしたことになった。あとは動画URLにアクセスすれば再生できる
                                
                                //let str:String = String(data: data!, encoding: String.Encoding.utf8)!
                                print("niconico アカウントアクセス")
                                self.StreamingUrlNicoAccess(smNum: smNum, callback: callback )
                            }else {
                                print("アクセスできなかった")
                            }
                        }
                        task2.resume()
                        
                    }
                    

                }
                
            }
            
        }
        task.resume()
    }    
}
