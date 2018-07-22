//
//  CryptClass.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2018/06/03.
//  Copyright © 2018年 i.MIZUSHIKI. All rights reserved.
//

import CryptoSwift

//暗号化
class Crypt {
    func encriptx_urlsafe(plainText:String, pass:String) -> String {
        let random_salt = NSUUID().uuidString.prefix(8).lowercased() //妥協点(16進数だから大してrandom_saltじゃない)
        let key_data = pass + random_salt
        let raw_key = key_data.md5()
        //print(raw_key)
        let raw_key_hex = raw_key.hex
        //print(raw_key_hex)
        
        let iv_data = raw_key + pass + random_salt //妥協点(raw_keyが16進数)
        let iv = iv_data.md5()
        //print(iv)
        let iv_hex = iv.hex
        //print(iv_hex)
        
        do {
            let aes = try AES(key: raw_key_hex, blockMode: CBC(iv: iv_hex)) // aes128
            let encrypted = try aes.encrypt(Array(plainText.utf8))
            //print(encrypted)
            
            // バイト列（[UInt8]）をNSDataに変換し、Base64文字列にエンコード
            var strEnc = Data(bytes: (("Saltedx_" + random_salt).data(using: .utf8)?.bytes)! + encrypted).base64EncodedString(options: .lineLength64Characters) //妥協してるからSaltedx_にした
            strEnc = strEnc.replacingOccurrences(of: "+", with: "_")
            strEnc = strEnc.replacingOccurrences(of: "/", with: "-")
            strEnc = strEnc.replacingOccurrences(of: "=", with: ".")
            //print("encrypted:"+strEnc)  // 出力
            return strEnc

        } catch {}
        return ""
    }
}
