
//MARK: - UIView Extensions
extension UIView
{
    func copyView<T: UIView>() -> T {
        let data = NSKeyedUnarchiver.unarchiveObject(with: NSKeyedArchiver.archivedData(withRootObject: self)) as! T
        for view in self.subviews{
            print(view.classForCoder)
            print(String(describing: view))
        }
        return data
    }
    
    func GetImage() -> UIImage{
        
        let isHide = self.isHidden
        
        isHidden = false
        
        // キャプチャする範囲を取得.
        let rect = self.bounds
        
        // ビットマップ画像のcontextを作成.
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        let context: CGContext = UIGraphicsGetCurrentContext()!
        
        // 対象のview内の描画をcontextに複写する.
        self.layer.render(in: context)
        
        // 現在のcontextのビットマップをUIImageとして取得.
        let capturedImage : UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        
        // contextを閉じる.
        UIGraphicsEndImageContext()
        
        self.isHidden = isHide
        
        return capturedImage
    }
    
    func GetImageView() -> UIImageView {
        
        let imageView = UIImageView(frame: self.frame)
        
        imageView.isHidden = self.isHidden
        imageView.alpha = self.alpha
        
        imageView.image = self.GetImage()
        
        return imageView
    }
}
