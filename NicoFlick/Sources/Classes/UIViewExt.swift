
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
    var slashColor:UIColor = .white
    var slashSpace:CGFloat = 2
    var LineWidth:CGFloat = 1
    init(frame: CGRect, color: UIColor, lineWidth: CGFloat, space: CGFloat) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.clear
        self.slashColor = color
        self.LineWidth = lineWidth
        self.slashSpace = space
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func draw(_ rect: CGRect) {
        if Int(self.slashSpace) < 1 {
            return
        }
        let w = self.frame.width
        let h = self.frame.height
        for _y in 0 ... Int(w + h) / Int(self.slashSpace) {
            let line = UIBezierPath()
            let y = CGFloat(_y)
            line.move(to: CGPoint(x: 0, y: y * self.slashSpace))
            line.addLine(to: CGPoint(x: w, y: CGFloat(y * self.slashSpace) - w))
            line.close()
            slashColor.setStroke()
            line.lineWidth = self.LineWidth
            line.stroke()
        }
    }
}

@IBDesignable
class UIDecorationLabel: UILabel {
    @IBInspectable var strokeSize: CGFloat = 0
    @IBInspectable var strokeColor: UIColor = UIColor.clear
    @IBInspectable var strokeShadowX: CGFloat = 0
    @IBInspectable var strokeShadowY: CGFloat = 0
    @IBInspectable var strokeShadowColor: UIColor = UIColor.clear
    
    override func drawText(in rect: CGRect) {
        // stroke
        let cr = UIGraphicsGetCurrentContext()
        let textColor = self.textColor
        
        if strokeShadowColor != .clear {
            cr!.translateBy(x: self.strokeShadowX, y: self.strokeShadowY)
            cr!.setLineWidth(self.strokeSize)
            cr!.setLineJoin(.round)
            cr!.setTextDrawingMode(.stroke)
            self.textColor = self.strokeShadowColor
            super.drawText(in: rect)
            
            cr!.setTextDrawingMode(.fill)
            self.textColor = self.strokeShadowColor
            super.drawText(in: rect)
            
            cr!.translateBy(x: -self.strokeShadowX, y: -self.strokeShadowY)
        }
        
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

@IBDesignable
class UICustomButton: UIButton {
    @IBInspectable var _backgroundColor: UIColor = .clear
    @IBInspectable var borderColor: UIColor = .clear
    @IBInspectable var borderWidth: CGFloat = 0
    @IBInspectable var cornerRadius: CGFloat = 0
    @IBInspectable var shadowColor: UIColor = .clear
    @IBInspectable var shadowOffset: CGFloat = 0
    @IBInspectable var shadowOpacity: Float = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.backgroundColor = .clear
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.layer.backgroundColor = self._backgroundColor.cgColor
        self.layer.borderWidth = self.borderWidth
        self.layer.borderColor = self.borderColor.cgColor
        
        self.layer.cornerRadius = self.cornerRadius
        
        self.layer.shadowColor = self.shadowColor.cgColor
        self.layer.shadowRadius = 1
        self.layer.shadowOffset = CGSize(width: self.shadowOffset, height: self.shadowOffset)
        self.layer.shadowOpacity = self.shadowOpacity
    }
}
