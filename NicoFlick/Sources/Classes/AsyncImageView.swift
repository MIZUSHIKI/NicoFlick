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
    func loadImage(urlString: String, contentMode:UIImageView.ContentMode = .scaleAspectFit){
        var urlString_ = urlString
        var ans:[String]=[]
        var trimRect = CGRect(x: 0, y: 13, width: 130, height: 74)
        var flg = false
        if (urlString_.pregMatche(pattern: "/thumbnails/(\\d+)/", matches: &ans)){
            if Int(ans[1])! >= 16371845 {
                flg = true
            }
        }else
        if (urlString_.pregMatche(pattern: "\\?i=(\\d+)", matches: &ans)){
            if Int(ans[1])! >= 16371845 {
                flg = true
            }
        }
        if flg {
            urlString_ = urlString + ".L"
            trimRect = CGRect(x: 0, y: 35, width: 360, height: 200)
        }
        print(urlString_)
        let req = URLRequest(url: NSURL(string:urlString_)! as URL,
                             cachePolicy: .returnCacheDataElseLoad,
                             timeoutInterval: CACHE_SEC);
        let conf =  URLSessionConfiguration.default;
        let session = URLSession(configuration: conf, delegate: nil, delegateQueue: OperationQueue.main);
        
        session.dataTask(with: req, completionHandler:
            { (data, resp, err) in
                if((err) == nil){ //Success
                    let _image = UIImage(data:data!)
                    if _image != nil {
                        //最初にサムネ比率にカット
                        let __image = _image!.TrimUIImage(width: _image!.size.width, height: _image!.size.width * self.resizeY / self.resizeX )
                        //次にリサイズ
                        let resizeImage = __image?.ResizeUIImage(width: self.frame.size.width, height: self.frame.size.height, contentMode: contentMode)
                        //最後にまたトリミング(Viewサイズにカット)
                        self.image = resizeImage?.TrimUIImage(width: self.frame.size.width, height: self.frame.size.height)
                    }
                    
                }else{ //Error
                    //print("AsyncImageView:Error \(err?.localizedDescription)");
                }
        }).resume();
    }

}

extension UIImage{
    
    // 画質を担保したままResizeするクラスメソッド.
    func ResizeUIImage(width : CGFloat, height : CGFloat, contentMode:UIImageView.ContentMode = .scaleAspectFit)-> UIImage!{
        
        var size = CGSize(width: width, height: height)
        
        var hikaku = (width / self.size.width) > (height / self.size.height)
        if contentMode == .scaleAspectFill { hikaku = !hikaku }
        if hikaku {
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
    
    func TrimUIImage(width : CGFloat, height : CGFloat)-> UIImage!{

        let trimPoint = CGPoint(x: -( self.size.width/2 - width/2 ),
                                y: -( self.size.height/2 - height/2 ) )
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 0.0)
        //_ = UIGraphicsGetCurrentContext()
        self.draw(at: trimPoint)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
    
}
