
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

class SlashShadeView:UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.clear
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func draw(_ rect: CGRect) {
        
        let w = self.frame.width
        let h = self.frame.height
        for y in 0 ... Int(w + h) / 2 {
            let line = UIBezierPath()
            line.move(to: CGPoint(x: 0, y: y * 2))
            line.addLine(to: CGPoint(x: w, y: CGFloat(y * 2) - w))
            line.close()
            UIColor.white.setStroke()
            line.lineWidth = 1.0
            line.stroke()
        }
    }
}

@IBDesignable
class UIDecorationLabel: UILabel {
    @IBInspectable var strokeSize: CGFloat = 0
    @IBInspectable var strokeColor: UIColor = UIColor.clear
    
    override func drawText(in rect: CGRect) {
        // stroke
        let cr = UIGraphicsGetCurrentContext()
        let textColor = self.textColor
        
        cr!.setLineWidth(self.strokeSize)
        cr!.setLineJoin(.round)
        cr!.setTextDrawingMode(.stroke)
        self.textColor = self.strokeColor
        super.drawText(in: rect)
        
        cr!.setTextDrawingMode(.fill)
        self.textColor = textColor
        super.drawText(in: rect)
    }
}
