//
//  WikipageWebkitView.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2021/01/19.
//  Copyright © 2021 i.MIZUSHIKI. All rights reserved.
//


import UIKit
import WebKit

class WikipageWebkitView: UIViewController, WKUIDelegate, WKNavigationDelegate, UITabBarDelegate {
    
    let wkWebView = WKWebView()
    @IBOutlet weak var mainView: UIView!
    @IBOutlet weak var tabBar: UITabBar!
    
    //遷移時に受け取り
    var selectorController:Selector!
    
    var backButton: UIButton!
    var forwadButton: UIButton!
    var targetUrl = AppDelegate.NICOFLICK_PATH + "wiki/index.php"
    var titleText = ""
    var artistText = ""
    var postedTags:[String] = []
    
    //音楽データ(シングルトン)
    var musicDatas:MusicDataLists = MusicDataLists.sharedInstance
    //効果音プレイヤー(シングルトン)
    var seSystemAudio:SESystemAudio = SESystemAudio.sharedInstance
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //遷移元への返り値を初期化
        selectorController.returnToMeString = ""
        // Do any additional setup after loading the view, typically from a nib.
        mainView.frame = CGRect(x: self.view.frame.origin.x,
                                y: UIApplication.shared.keyWindow?.safeAreaInsets.top ?? 44.0,
                                width: self.view.frame.size.width,
                                height: self.view.frame.size.height - (UIApplication.shared.keyWindow?.safeAreaInsets.top ?? 44.0))
        wkWebView.frame = CGRect(x: 0, y: 0, width: mainView.frame.size.width, height: mainView.frame.size.height)
        wkWebView.navigationDelegate = self
        wkWebView.uiDelegate = self
        
        // スワイプでの「戻る・すすむ」を有効にする
        wkWebView.allowsBackForwardNavigationGestures = true
        
        let urlRequest = URLRequest(url:URL(string:targetUrl)!)
        wkWebView.load(urlRequest)
        mainView.addSubview(wkWebView)
        
        createWebControlParts()
    }
    override func viewDidLayoutSubviews() {
        if UIApplication.shared.keyWindow?.rootViewController?.view.safeAreaInsets.bottom == 0 {
            tabBar.frame.origin.y += 34
        }
        /*
        print("UIApplication.shared.keyWindow?.rootViewController?.view.safeAreaInsets.bottom=\(UIApplication.shared.keyWindow?.rootViewController?.view.safeAreaInsets.bottom)")
        print("tabBar.frame.origin.y=\(tabBar.frame.origin.y)")
        print("tabBar.frame.height")
        tabBar.frame.origin.y = (UIApplication.shared.keyWindow?.rootViewController?.view.safeAreaInsets.bottom ?? 0) - tabBar.frame.height
         */
        /*
        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: Date(timeIntervalSince1970: 0), completionHandler: {})
         */
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // ウェブのロード完了時に呼び出される
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        
        backButton.isEnabled = (webView.canGoBack) ? true : false
        forwadButton.isEnabled = (webView.canGoForward) ? true : false
        
        if backButton.isEnabled {
            if #available(iOS 13.0, *) {
                backButton.tintColor = .link
            } else {
                // Fallback on earlier versions
                backButton.setTitleColor(.systemBlue, for: .normal)
            }
        }else {
            if #available(iOS 13.0, *) {
                backButton.tintColor = .lightGray
            } else {
                // Fallback on earlier versions
                backButton.setTitleColor(.lightGray, for: .normal)
            }
            
        }
        if forwadButton.isEnabled {
            if #available(iOS 13.0, *) {
                forwadButton.tintColor = .link
            } else {
                // Fallback on earlier versions
                forwadButton.setTitleColor(.systemBlue, for: .normal)
            }
        }else {
            if #available(iOS 13.0, *) {
                forwadButton.tintColor = .lightGray
            } else {
                // Fallback on earlier versions
                forwadButton.setTitleColor(.lightGray, for: .normal)
            }
            
        }
        
        webView.evaluateJavaScript(
            "document.body.innerHTML",
            completionHandler: { (html: Any?, error: Error?) in
                guard let html = html as? String else { return }
                var ans:[String]=[]
                if (html.pregMatche(pattern: "<!-- NicoFlickRankingTag=\"(.*?)\" num=\"(\\d+)\" -->", matches: &ans)){
                    let tags = ans[1]
                    let num = ans[2]
                    var retTag = tags
                    retTag = retTag.trimmingCharacters(in: .whitespaces)
                    self.postedTags.append(retTag)
                    
                    retTag = retTag.pregReplace(pattern: "\\s*/(and|AND)/\\s*", with: "/and/")
                    retTag = retTag.pregReplace(pattern: "\\s+", with: " or ")
                    
                    let condition = SelectConditions.init(tags: retTag, sortItem: "")
                    let musics = self.musicDatas._getSelectMusics(selectCondition: condition, isMe: false)
                    //print(musics)
                    let musicsStr = musics.compactMap{String($0.sqlID)}.joined(separator: ",")
                    if musicsStr != "" {
                        ServerDataHandler().postTagsToMusics(tags: "\(num):"+tags, musicsStr: musicsStr, callback: {})
                    }
                }
            }
        )
        //
        webView.evaluateJavaScript("""
            var element = document.getElementById('\(UserData.sharedInstance.UserIDxxx)');
            if( element != null ){ element.style.color='#F00'; }
            var elements = document.getElementsByClassName('\(UserData.sharedInstance.UserIDxxx)');
            if( elements != null ){
                for( let i = 0; i < elements.length; i++ ){
                    elements[i].style.color='#F00';
                }
            }
        """, completionHandler: nil)
        
        let music = selectorController.currentMusics[selectorController.indexCarousel]
        webView.evaluateJavaScript(
            "document.getElementById('SetMusicDataBtn_NicoFlick').id",
            completionHandler: { (html: Any?, error: Error?) in
                guard let html = html as? String else { return }
                print("html=\(html)")
                if !(html == "SetMusicDataBtn_NicoFlick") { return }
                
                webView.evaluateJavaScript("""
                    if( document.getElementById('SettedMusicDataBtn_NicoFlick') == null ){
                        var cre = document.createElement('input');
                        cre.type = 'button';
                        cre.id = 'SettedMusicDataBtn_NicoFlick';
                        cre.value = '選択中の楽曲情報を入力ボックスに代入';
                        cre.addEventListener('click', buttonClick);
                        var ele = document.getElementById('SetMusicDataBtn_NicoFlick');
                        ele.appendChild(cre);
                        ele.appendChild(document.createElement('br'));
                    }
                
                    function buttonClick(){
                        document.getElementById('_p_comment_comment_0').value = '[[\(music.title!)>nicoflick://tag=@m:\(music.sqlID!)]]&br;[[&ref(\(music.thumbnailURL!));>nicoflick://tag=@m:\(music.sqlID!)]]&br;';
                    }

                """,completionHandler: nil)
            }
        )
    }
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            //
            print(url.absoluteString)
            if url.absoluteString.hasPrefix("nicoflick://"){
                print("いっち")
                decisionHandler(.cancel)
                selectorController.returnToMeString = url.absoluteString.removingPercentEncoding ?? ""
                self.navigationController?.popViewController(animated: true)
                return
            }
            decisionHandler(.allow)
        }else{
            decisionHandler(.allow)
        }
    }

    /// 戻る・すすむボタン作成
    private func createWebControlParts() {
        
        let buttonSize = CGSize(width:40,height:40)
        let buttonPadding:CGFloat = 10
        var yPos = tabBar.frame.origin.y + buttonPadding
        if UIApplication.shared.keyWindow?.rootViewController?.view.safeAreaInsets.bottom == 0 {
            yPos += 30
        }
        
        let backButtonPos = CGPoint(x:UIScreen.main.bounds.width - (buttonSize.width*2 + buttonPadding*3), y:yPos)
        let forwardButtonPos = CGPoint(x:UIScreen.main.bounds.width - (buttonSize.width + buttonPadding*2), y:yPos)
        
        backButton = UIButton(frame: CGRect(origin: backButtonPos, size: buttonSize))
        forwadButton = UIButton(frame: CGRect(origin:forwardButtonPos, size:buttonSize))
        
        if #available(iOS 13.0, *) {
            backButton.setImage(UIImage(systemName: "chevron.backward"), for: .normal)
            backButton.tintColor = .lightGray
        } else {
            // Fallback on earlier versions
            backButton.setTitle("←", for: .normal)
            backButton.setTitleColor(.lightGray, for: .normal)
        }
        //backButton.layer.backgroundColor = UIColor.black.cgColor
        backButton.layer.opacity = 0.6
        backButton.layer.cornerRadius = 5.0
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        //backButton.isHidden = true
        backButton.isEnabled = true
        view.addSubview(backButton)
        
        if #available(iOS 13.0, *) {
            forwadButton.setImage(UIImage(systemName: "chevron.forward"), for: .normal)
            forwadButton.tintColor = .lightGray
        } else {
            // Fallback on earlier versions
            forwadButton.setTitle("→", for: .normal)
            forwadButton.setTitleColor(.lightGray, for: .normal)
        }
        //forwadButton.layer.backgroundColor = UIColor.black.cgColor
        forwadButton.layer.opacity = 0.6
        forwadButton.layer.cornerRadius = 5.0
        forwadButton.addTarget(self, action: #selector(goForward), for: .touchUpInside)
        //forwadButton.isHidden = true
        forwadButton.isEnabled = true
        view.addSubview(forwadButton)
        
    }
    
    @objc private func goBack() {
        wkWebView.goBack()
    }
    
    @objc private func goForward() {
        wkWebView.goForward()
    }
    
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        print("tabBarItem=\(item.tag)")
        //self.dismiss(animated: true, completion: nil)
        selectorController.returnToMeString = "BackButton"
        self.navigationController?.popViewController(animated: true)
        //se
        seSystemAudio.canselSePlay()
    }
    @IBAction func returnToMe(segue: UIStoryboardSegue){
        print("returnToMe")
    }
}

