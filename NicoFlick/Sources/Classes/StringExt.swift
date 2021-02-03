
extension String {
    //絵文字など(2文字分)も含めた文字数を返します
    var count: Int {
        let string_NS = self as NSString
        return string_NS.length
    }
    
    var urlEncoded: String {
        // 半角英数字 + "/?-._~" のキャラクタセットを定義
        let charset = CharacterSet.alphanumerics.union(.init(charactersIn: "/?-._~"))
        // 一度すべてのパーセントエンコードを除去(URLデコード)
        let removed = removingPercentEncoding ?? self
        // あらためてパーセントエンコードして返す
        return removed.addingPercentEncoding(withAllowedCharacters: charset) ?? removed
    }
    
    //正規表現の検索をします
    func pregMatche(pattern: String, options: NSRegularExpression.Options = [NSRegularExpression.Options.dotMatchesLineSeparators,NSRegularExpression.Options.anchorsMatchLines]) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return false
        }
        let matches = regex.matches(in: self, options: [], range: NSMakeRange(0, self.count))
        return matches.count > 0
    }
    
    //正規表現の検索結果を利用できます
    func pregMatche(pattern: String, options: NSRegularExpression.Options = [NSRegularExpression.Options.dotMatchesLineSeparators,NSRegularExpression.Options.anchorsMatchLines], matches: inout [String]) -> Bool {
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
    func pregMatche_firstString(pattern: String, options: NSRegularExpression.Options = [NSRegularExpression.Options.dotMatchesLineSeparators,NSRegularExpression.Options.anchorsMatchLines]) -> String {
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
    func pregReplace(pattern: String, with: String, options: NSRegularExpression.Options = [NSRegularExpression.Options.dotMatchesLineSeparators,NSRegularExpression.Options.anchorsMatchLines]) -> String {
        let regex = try! NSRegularExpression(pattern: pattern, options: options)
        return regex.stringByReplacingMatches(in: self, options: [], range: NSMakeRange(0, self.count), withTemplate: with)
    }
    
    var isHiragana: Bool {
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
    
    var isKatakana: Bool {
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
    /// 「漢字」かどうか
    var isKanji: Bool {
        let range = "^[\u{3005}\u{3007}\u{303b}\u{3400}-\u{9fff}\u{f900}-\u{faff}\u{20000}-\u{2ffff}]+$"
        return NSPredicate(format: "SELF MATCHES %@", range).evaluate(with: self)
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
    static func secondsToTimetag(seconds:Double, noBrackets:Bool = false, dot:Bool = false) -> String {
        if seconds == -0.001 {
            if noBrackets {
                if dot {
                    return "**:**.**"
                }else {
                    return "**:**:**"
                }
            }else {
                if dot {
                    return "[**:**.**]"
                }else {
                    return "[**:**:**]"
                }
            }
        }
        var format = dot ? "%02d:%02d.%02d" : "%02d:%02d:%02d"
        if !noBrackets {
            format = "[\(format)]"
        }
        let rmirisec = Int(round(seconds * 100)) * 10
        return String.init(format: format, Int(rmirisec/60000), Int((rmirisec % 60000) / 1000), Int((rmirisec % 1000) / 10) )
    }
    static func secondsToDotTimetag(seconds:Double, noBrackets:Bool = false) -> String {
        if seconds == -0.001 {
            if noBrackets {
                return "**:**.**"
            }else {
                return "[**:**.**]"
            }
        }
        let format = noBrackets ? "%02d:%02d.%02d" : "[%02d:%02d.%02d]"
        let rmirisec = Int(round(seconds * 100)) * 10
        return String.init(format: format, Int(rmirisec/60000), Int((rmirisec % 60000) / 1000), Int((rmirisec % 1000) / 10) )
    }
    func timetagToSeconds() -> Double {
        var ans:[String] = []
        print(self)
        if self.pregMatche(pattern: "\\[(\\d\\d)\\:(\\d\\d)[\\:|\\.](\\d\\d)\\]", matches: &ans){
            return Double(ans[1])!*60 + Double(ans[2])! + Double(ans[3])!/100
        }
        return -0.001
    }
    var isDotTimetag : Bool {
        return self.pregMatche(pattern: "\\[[\\d\\*][\\d\\*]\\:[\\d\\*][\\d\\*]\\.[\\d\\*][\\d\\*]\\]")
    }
    
    func kanjiToHiragana() -> String {
        var text = ""
        var tameoki = ""
        let words = self.map { String($0) }
        for word in words {
            print(word)
            if word.isKanji || word.isHiragana {
                tameoki += word
            }else{
                if tameoki != "" {
                    text += TextConverter.convert(tameoki, to: .hiragana)
                    tameoki = ""
                }
                text += word
            }
        }
        if tameoki != "" {
            text += TextConverter.convert(tameoki, to: .hiragana)
            tameoki = ""
        }
        return text
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

final class TextConverter {
    private init() {}
    enum JPCharacter {
        case hiragana
        case katakana
        fileprivate var transform: CFString {
            switch self {
            case .hiragana:
                return kCFStringTransformLatinHiragana
            case .katakana:
                return kCFStringTransformLatinKatakana
            }
        }
    }
    
    static func convert(_ text: String, to jpCharacter: JPCharacter) -> String {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var output = ""
        let locale = CFLocaleCreate(kCFAllocatorDefault, CFLocaleCreateCanonicalLanguageIdentifierFromString(kCFAllocatorDefault, "ja" as CFString))
        let range = CFRangeMake(0, input.utf16.count)
        let tokenizer = CFStringTokenizerCreate(
            kCFAllocatorDefault,
            input as CFString,
            range,
            kCFStringTokenizerUnitWordBoundary,
            locale
        )
        
        var tokenType = CFStringTokenizerGoToTokenAtIndex(tokenizer, 0)
        while (tokenType.rawValue != 0) {
            if let text = (CFStringTokenizerCopyCurrentTokenAttribute(tokenizer, kCFStringTokenizerAttributeLatinTranscription) as? NSString).map({ $0.mutableCopy() }) {
                CFStringTransform((text as! CFMutableString), nil, jpCharacter.transform, false)
                output.append(text as! String)
            }
            tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
        }
        return output
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
