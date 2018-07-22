//
//  AsyncImageView.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/04/30.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//

import UIKit

class AsyncImageView: UIImageView {
    let CACHE_SEC : TimeInterval = 60*24*7 * 60; //一週間キャッシュ
    
    var resizeX = 315.0
    var resizeY = 175.0
    
    //画像を非同期で読み込む
    func loadImage(urlString: String){
        var urlString_ = urlString
        var ans:[String]=[]
        var trimRect = CGRect(x: 0, y: 13, width: 130, height: 74)
        if (urlString_.pregMatche(pattern: "\\?i=(\\d+)$", matches: &ans)){
            if Int(ans[1])! >= 16371845 {
                urlString_ = urlString + ".L"
                trimRect = CGRect(x: 0, y: 35, width: 360, height: 200)
            }
        }
        let req = URLRequest(url: NSURL(string:urlString_)! as URL,
                             cachePolicy: .returnCacheDataElseLoad,
                             timeoutInterval: CACHE_SEC);
        let conf =  URLSessionConfiguration.default;
        let session = URLSession(configuration: conf, delegate: nil, delegateQueue: OperationQueue.main);
        
        session.dataTask(with: req, completionHandler:
            { (data, resp, err) in
                if((err) == nil){ //Success
                    let image = UIImage(data:data!)
                    
                    let imgRef = image?.cgImage?.cropping(to: trimRect)
                    
                    let trimImage = UIImage(cgImage: imgRef!, scale: (image?.scale)!, orientation: (image?.imageOrientation)!)

                    // リサイズ
                    self.image = trimImage.ResizeUIImage(width: CGFloat(self.frame.size.width), height: CGFloat(self.frame.size.height))
                    
                    
                }else{ //Error
                    //print("AsyncImageView:Error \(err?.localizedDescription)");
                }
        }).resume();
    }

}

extension UIImage{
    
    // 画質を担保したままResizeするクラスメソッド.
    func ResizeUIImage(width : CGFloat, height : CGFloat)-> UIImage!{
        
        var size = CGSize(width: width, height: height)
        
        if (width / self.size.width) > (height / self.size.height) {
            size = CGSize(width: self.size.width * height/self.size.height, height: height)
        }else {
            size = CGSize(width: width, height: self.size.height * width/self.size.width)
        }
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        _ = UIGraphicsGetCurrentContext()
        
        self.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
    
}
