//
//  AVPlayerExt.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2018/12/16.
//  Copyright © 2018年 i.MIZUSHIKI. All rights reserved.
//

import AVKit

extension AVPlayer
{
    var isPlaying: Bool {
        return self.rate != 0 && self.error == nil
    }
}
