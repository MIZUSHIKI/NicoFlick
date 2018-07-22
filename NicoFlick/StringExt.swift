
extension String {
    //絵文字など(2文字分)も含めた文字数を返します
    var count: Int {
        let string_NS = self as NSString
        return string_NS.length
    }
    
    //正規表現の検索をします
    func pregMatche(pattern: String, options: NSRegularExpression.Options = []) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return false
        }
        let matches = regex.matches(in: self, options: [], range: NSMakeRange(0, self.count))
        return matches.count > 0
    }
    
    //正規表現の検索結果を利用できます
    func pregMatche(pattern: String, options: NSRegularExpression.Options = [], matches: inout [String]) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return false
        }
        let targetStringRange = NSRange(location: 0, length: self.count)
        let results = regex.matches(in: self, options: [], range: targetStringRange)
        for i in 0 ..< results.count {
            for j in 0 ..< results[i].numberOfRanges {
                let range = results[i].range(at: j)
                matches.append((self as NSString).substring(with: range))
            }
        }
        return results.count > 0
    }
    //正規表現の検索結果を利用できます
    func pregMatche_firstString(pattern: String, options: NSRegularExpression.Options = []) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return ""
        }
        var matches:[String] = []
        let targetStringRange = NSRange(location: 0, length: self.count)
        let results = regex.matches(in: self, options: [], range: targetStringRange)
        for i in 0 ..< results.count {
            for j in 0 ..< results[i].numberOfRanges {
                let range = results[i].range(at: j)
                matches.append((self as NSString).substring(with: range))
            }
        }
        if matches.count == 0 {
            return ""
        }else if matches.count == 1 {
            return matches[0]
        }
        return matches[1]
    }
    
    //正規表現の置換をします
    func pregReplace(pattern: String, with: String, options: NSRegularExpression.Options = []) -> String {
        let regex = try! NSRegularExpression(pattern: pattern, options: options)
        return regex.stringByReplacingMatches(in: self, options: [], range: NSMakeRange(0, self.count), withTemplate: with)
    }
    
    func isHiragana() -> Bool {
        for c in unicodeScalars {
            if c.value >= 0x3041 && c.value <= 0x3096 {
                //ひらがな
            }else {
                //それ以外
                return false
            }
        }
        return true
    }
    
    func isKatakana() -> Bool {
        for c in unicodeScalars {
            if (c.value >= 0x30A1 && c.value <= 0x30F6) || c.value == 0x30FC {
                //カタカナ
            }else {
                //それ以外
                return false
            }
        }
        return true
    }

    mutating func htmlDecode() {
        guard let encodedData = self.data(using: .utf8) else {
            return
        }
        
        let attributedOptions: [NSAttributedString.DocumentReadingOptionKey : Any] = [
            NSAttributedString.DocumentReadingOptionKey(rawValue: NSAttributedString.DocumentAttributeKey.documentType.rawValue): NSAttributedString.DocumentType.html,
            NSAttributedString.DocumentReadingOptionKey(rawValue: NSAttributedString.DocumentAttributeKey.characterEncoding.rawValue): String.Encoding.utf8.rawValue
        ]
        
        do {
            let attributedString = try NSAttributedString(data: encodedData, options: attributedOptions, documentAttributes: nil)
            self = attributedString.string
        } catch {
            print("Error: \(error)")
            
        }
    }
}

fileprivate func convertHex(_ s: String.UnicodeScalarView, i: String.UnicodeScalarIndex, appendTo d: [UInt8]) -> [UInt8] {
    
    let skipChars = CharacterSet.whitespacesAndNewlines
    
    guard i != s.endIndex else { return d }
    
    let next1 = s.index(after: i)
    
    if skipChars.contains(s[i]) {
        return convertHex(s, i: next1, appendTo: d)
    } else {
        guard next1 != s.endIndex else { return d }
        let next2 = s.index(after: next1)
        
        let sub = String(s[i..<next2])
        
        guard let v = UInt8(sub, radix: 16) else { return d }
        
        return convertHex(s, i: next2, appendTo: d + [ v ])
    }
}

extension String {
    
    /// Convert Hexadecimal String to Array<UInt>
    ///     "0123".hex                // [1, 35]
    ///     "aabbccdd 00112233".hex   // 170, 187, 204, 221, 0, 17, 34, 51]
    var hex : [UInt8] {
        return convertHex(self.unicodeScalars, i: self.unicodeScalars.startIndex, appendTo: [])
    }
    
    /// Convert Hexadecimal String to Data
    ///     "0123".hexData                    /// 0123
    ///     "aa bb cc dd 00 11 22 33".hexData /// aabbccdd 00112233
    var hexData : Data {
        return Data(convertHex(self.unicodeScalars, i: self.unicodeScalars.startIndex, appendTo: []))
    }
}

/*
 サンプル
 探索
 var text = "Swwwwift"
 
 if text.pregMatche(pattern: "Sw*ift"){
 print("マッチしました")
 }else{
 print("マッチしていません")
 }
 　　↓
 マッチしました
 
 
 
 探索の結果
 var text = "Swwwwift"
 var ans: [String] = []
 if text.pregMatche(pattern: "S(w+)ift", matches: &ans) {
 print("マッチしました")
 }else {
 print("マッチしていません")
 }
 print(ans)
 　　↓
 マッチしました
 ["Swwwwift","wwww"]
 
 
 置換
 var text = "SwwwwiftLove"
 let ans = text.pregReplace(pattern: "Sw*ift", with: "")
 print(ans)
 　　↓
 Love
 */
