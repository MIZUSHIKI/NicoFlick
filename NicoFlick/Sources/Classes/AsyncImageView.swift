//
//  AsyncImageView.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/04/30.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//

import UIKit

enum AsyncImageLoadError: Error {
    case invalidURL
    case network(Error)
    case invalidHTTPResponse
    case httpStatus(Int)
    case invalidImageData

    var shouldRepairThumbnailURL: Bool {
        switch self {
        case .invalidURL, .invalidHTTPResponse, .invalidImageData:
            return true
        case .httpStatus(let statusCode):
            return statusCode != 408 && statusCode != 429 && (400...499).contains(statusCode)
        case .network:
            return false
        }
    }
}

class AsyncImageView: UIImageView {
    let CACHE_SEC : TimeInterval = 60*24*7 * 60; //一週間キャッシュ
    
    var resizeX = 315.0
    var resizeY = 175.0
    
    //画像を非同期で読み込む
    func loadImage(urlString: String, contentMode:UIImageView.ContentMode = .scaleAspectFit, completion: ((Result<Void, AsyncImageLoadError>) -> Void)? = nil){
        loadImage(urlString: urlString, contentMode: contentMode, tryLargeThumbnail: true, completion: completion)
    }

    private func loadImage(urlString: String, contentMode: UIImageView.ContentMode, tryLargeThumbnail: Bool, completion: ((Result<Void, AsyncImageLoadError>) -> Void)?) {
        var urlString_ = urlString
        var ans:[String]=[]
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
        if flg && tryLargeThumbnail {
            urlString_ = urlString + ".L"
        }
        let retryWithoutLargeThumbnail: (AsyncImageLoadError) -> Void = { error in
            if flg && tryLargeThumbnail {
                self.loadImage(urlString: urlString, contentMode: contentMode, tryLargeThumbnail: false, completion: completion)
            } else {
                completion?(.failure(error))
            }
        }
        // print(urlString_)
        guard let url = URL(string: urlString_),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else {
            retryWithoutLargeThumbnail(.invalidURL)
            return
        }
        let req = URLRequest(url: url,
                             cachePolicy: .returnCacheDataElseLoad,
                             timeoutInterval: CACHE_SEC);
        let conf =  URLSessionConfiguration.default;
        let session = URLSession(configuration: conf, delegate: nil, delegateQueue: OperationQueue.main);
        
        session.dataTask(with: req, completionHandler:
            { (data, resp, err) in
                if let err {
                    completion?(.failure(.network(err)))
                    return
                }
                guard let httpResponse = resp as? HTTPURLResponse else {
                    retryWithoutLargeThumbnail(.invalidHTTPResponse)
                    return
                }
                guard (200...299).contains(httpResponse.statusCode) else {
                    retryWithoutLargeThumbnail(.httpStatus(httpResponse.statusCode))
                    return
                }
                guard let data, let image = UIImage(data: data) else {
                    retryWithoutLargeThumbnail(.invalidImageData)
                    return
                }

                //最初にサムネ比率にカット
                let trimmedImage = image.TrimUIImage(
                    width: image.size.width,
                    height: image.size.width * self.resizeY / self.resizeX
                )
                //次にリサイズ
                let resizedImage = trimmedImage?.ResizeUIImage(
                    width: self.frame.size.width,
                    height: self.frame.size.height,
                    contentMode: contentMode
                )
                //最後にまたトリミング(Viewサイズにカット)
                self.image = resizedImage?.TrimUIImage(
                    width: self.frame.size.width,
                    height: self.frame.size.height
                )
                completion?(.success(()))
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
