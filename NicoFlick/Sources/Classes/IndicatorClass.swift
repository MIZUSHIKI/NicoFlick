//
//  IndicatorClass.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/10/01.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//

import Foundation

//初期設定を一元化

class Indicator {
    var view:UIActivityIndicatorView!
    init(center:CGPoint) {
        //Indicatorを作成
        view = UIActivityIndicatorView()
        view.frame = CGRect(x: 0, y: 0, width: 75, height: 75)
        view.backgroundColor = UIColor(white: 0, alpha: 0.6)
        view.layer.cornerRadius = 8
        view.center = center
        //  Indicatorの状態
        view.hidesWhenStopped = true
        view.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.white
        view.isHidden = true
        //  薄膜
        let v = UIView(frame: CGRect(x: 75/2-center.x, y: 75/2-center.y, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        v.backgroundColor = .black
        v.alpha = 0.05
        view.addSubview(v)
    }
}
