//
//  VerticalSlider.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2018/12/15.
//  Copyright © 2018年 i.MIZUSHIKI. All rights reserved.
//

class VerticalSlider: UISlider {
    override func awakeFromNib() {
        super.awakeFromNib()
        transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 2)
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        frame = superview!.bounds
    }
}
