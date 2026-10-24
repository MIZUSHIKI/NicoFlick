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
    var targetUrl = "https://www2.jasrac.or.jp/eJwid/main?trxID=F00100"
    var titleText = ""
    var artistText = ""
    var firstAttack = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        wkWebView.navigationDelegate = self
        wkWebView.uiDelegate = self
        wkWebView.translatesAutoresizingMaskIntoConstraints = false
        
        // スワイプでの「戻る・すすむ」を有効にする
        wkWebView.allowsBackForwardNavigationGestures = true
        
        let urlRequest = URLRequest(url:URL(string:targetUrl)!)
        wkWebView.load(urlRequest)
        view.addSubview(wkWebView)
        NSLayoutConstraint.activate([
            wkWebView.topAnchor.constraint(equalTo: naviBar.bottomAnchor),
            wkWebView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            wkWebView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            wkWebView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        createWebControlParts()
        if titleText != "" {
            DispatchQueue.main.async {
                let alert = UIAlertController(title:nil, message: "タイトルにアーティスト名など余計な文字が含まれていたら除去して「検索」して下さい", preferredStyle: UIAlertControllerStyle.alert)
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
                        
//                        webView.evaluateJavaScript(
//                            "document.forms[1].submit()",
//                            completionHandler: nil)
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
        
        let buttonSize: CGFloat = 40
        let buttonPadding: CGFloat = 10

        backButton = UIButton(type: .system)
        forwadButton = UIButton(type: .system)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        forwadButton.translatesAutoresizingMaskIntoConstraints = false
        
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

        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: buttonPadding),
            backButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -buttonPadding),
            backButton.widthAnchor.constraint(equalToConstant: buttonSize),
            backButton.heightAnchor.constraint(equalToConstant: buttonSize),

            forwadButton.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: buttonPadding),
            forwadButton.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            forwadButton.widthAnchor.constraint(equalToConstant: buttonSize),
            forwadButton.heightAnchor.constraint(equalToConstant: buttonSize)
        ])
    }
    
    @objc private func goBack() {
        wkWebView.goBack()
    }
    
    @objc private func goForward() {
        wkWebView.goForward()
    }
    
}
