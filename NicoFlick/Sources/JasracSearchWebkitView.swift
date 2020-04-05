//
//  JasracSearchWebkitView.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2018/12/09.
//  Copyright © 2018年 i.MIZUSHIKI. All rights reserved.
//

import UIKit
import WebKit

class JasracSearchWebkitView: UIViewController, WKUIDelegate, WKNavigationDelegate {
    
    @IBOutlet var naviBar: UINavigationBar!
    
    let wkWebView = WKWebView()
    
    var backButton: UIButton!
    var forwadButton: UIButton!
    var targetUrl = "http://www2.jasrac.or.jp/eJwid/main?trxID=F00100"
    var titleText = ""
    var artistText = ""
    var firstAttack = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let naviBar_ly = naviBar.frame.origin.y + naviBar.frame.size.height
        wkWebView.frame = CGRect(x: view.frame.origin.x, y: view.frame.origin.y + naviBar_ly, width: view.frame.size.width, height: view.frame.size.height - naviBar_ly)
        wkWebView.navigationDelegate = self
        wkWebView.uiDelegate = self
        
        // スワイプでの「戻る・すすむ」を有効にする
        wkWebView.allowsBackForwardNavigationGestures = true
        
        let urlRequest = URLRequest(url:URL(string:targetUrl)!)
        wkWebView.load(urlRequest)
        view.addSubview(wkWebView)
        
        createWebControlParts()
        if titleText != "" {
            DispatchQueue.main.async {
                let alert = UIAlertController(title:nil, message: "タイトルにアーティスト名など余計な文字が含まれていたら除去して「再検索」して下さい", preferredStyle: UIAlertControllerStyle.alert)
                alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // ウェブのロード完了時に呼び出される
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        
        backButton.isHidden = (webView.canGoBack) ? false : true
        forwadButton.isHidden = (webView.canGoForward) ? false : true
        
        if !firstAttack { return }
        firstAttack = false
        let titleText_ = titleText.pregReplace(pattern: "【.*?】", with: "")
        webView.evaluateJavaScript(
            "document.getElementsByName('IN_WORKS_TITLE_NAME1')[0].value = '\(titleText_)'",
            completionHandler: { (value: Any?, error: Error?) in
                webView.evaluateJavaScript(
                    "document.getElementsByName('IN_WORKS_TITLE_OPTION1')[0].value = '2'",
                    completionHandler: { (value: Any?, error: Error?) in
                        
                        webView.evaluateJavaScript(
                            "document.forms[1].submit()",
                            completionHandler: nil)
                        /*
                        webView.evaluateJavaScript(
                            "document.getElementsByName('frame2')[0].contentDocument.getElementsByName('IN_ARTIST_NAME1')[0].value = '\(self.artistText)'",
                            completionHandler: { (value: Any?, error: Error?) in
                                webView.evaluateJavaScript(
                                    "document.getElementsByName('frame2')[0].contentDocument.getElementsByName('IN_ARTIST_NAME_OPTION1')[0].value = '2'",
                                    completionHandler: { (value: Any?, error: Error?) in
                                    }
                                )
                            }
                        )
                        */
                    }
                )
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
    
    /// 戻る・すすむボタン作成
    private func createWebControlParts() {
        
        let buttonSize = CGSize(width:40,height:40)
        let offseetUnderBottom:CGFloat = 60
        let yPos = (UIScreen.main.bounds.height - offseetUnderBottom)
        let buttonPadding:CGFloat = 10
        
        let backButtonPos = CGPoint(x:buttonPadding, y:yPos)
        let forwardButtonPos = CGPoint(x:(buttonPadding + buttonSize.width + buttonPadding), y:yPos)
        
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
    
}

