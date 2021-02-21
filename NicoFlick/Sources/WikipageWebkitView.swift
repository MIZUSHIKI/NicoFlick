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
    var targetUrl = "https://main-timetag.ssl-lolipop.jp/nicoflick/wiki/index.php"
    var titleText = ""
    var artistText = ""
    var postedTags:[String] = []
    
    //音楽データ(シングルトン)
    var musicDatas:MusicDataLists = MusicDataLists.sharedInstance
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //遷移元への返り値を初期化
        selectorController.returnToMeString = ""
        // Do any additional setup after loading the view, typically from a nib.
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
        
        backButton.isHidden = (webView.canGoBack) ? false : true
        forwadButton.isHidden = (webView.canGoForward) ? false : true
        
        webView.evaluateJavaScript(
            "document.body.innerHTML",
            completionHandler: { (html: Any?, error: Error?) in
                if let html = html as? String {
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
                        print(musics)
                        let musicsStr = musics.compactMap{String($0.sqlID)}.joined(separator: ",")
                        ServerDataHandler().postTagsToMusics(tags: "\(num):"+tags, musicsStr: musicsStr, callback: {})
                    }
                }
            }
        )
        webView.evaluateJavaScript("document.getElementById('\(UserData.sharedInstance.UserIDxxx)').style.color='#F00';", completionHandler: nil)
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
        
        backButton.setTitle("<", for: .normal)
        backButton.setTitle("< ", for: .highlighted)
        backButton.setTitleColor(.white, for: .normal)
        backButton.layer.backgroundColor = UIColor.black.cgColor
        backButton.layer.opacity = 0.6
        backButton.layer.cornerRadius = 5.0
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        backButton.isHidden = true
        view.addSubview(backButton)
        
        forwadButton.setTitle(">", for: .normal)
        forwadButton.setTitle(" >", for: .highlighted)
        forwadButton.setTitleColor(.white, for: .normal)
        forwadButton.layer.backgroundColor = UIColor.black.cgColor
        forwadButton.layer.opacity = 0.6
        forwadButton.layer.cornerRadius = 5.0
        forwadButton.addTarget(self, action: #selector(goForward), for: .touchUpInside)
        forwadButton.isHidden = true
        view.addSubview(forwadButton)
        
    }
    
    @objc private func goBack() {
        wkWebView.goBack()
    }
    
    @objc private func goForward() {
        wkWebView.goForward()
    }
    
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        print(item.tag)
        //self.dismiss(animated: true, completion: nil)
        self.navigationController?.popViewController(animated: true)
    }
    @IBAction func returnToMe(segue: UIStoryboardSegue){
        print("returnToMe")
    }
}

