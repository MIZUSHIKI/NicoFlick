//
//  SpoonClass.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2018/12/23.
//  Copyright © 2018年 i.MIZUSHIKI. All rights reserved.
//


class Spoon {
    var word = "" {
        didSet{
            check = isCheckableWord
        }
    }
    private(set) var miriSec = -1
    var note = false {
        didSet {
            if note {
                label?.backgroundColor = UIColor(red: 1.0, green: 0.8, blue: 0.8, alpha: 1.0)
            }else {
                label?.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 0.8, alpha: 1.0)
            }
        }
    }
    private(set) var check = false
    var label:UILabel? = nil
    var wakuBorder:UIView? = nil
    var bottomBorder:UIView? = nil
    var oya:Spoons? = nil
    
    var isWiped = false {
        didSet {
            if isWiped {
                label?.textColor = UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0)
            }else {
                label?.textColor = UIColor.black
            }
        }
    }
    
    init(word:String = "", miriSec:Int = -1, note:Bool = false, oya:Spoons? = nil){
        self.word = word
        self.check = self.isCheckableWord
        self.miriSec = miriSec
        self.note = note
        self.oya = oya
    }
    deinit {
        print("deinit")
        label?.removeFromSuperview()
        wakuBorder?.removeFromSuperview()
        bottomBorder?.removeFromSuperview()
    }
    func setMirisec(mirisec:Int) {
        miriSec = mirisec
        if let waku = wakuBorder {
            waku.isHidden = (miriSec == -1)
        }
        
        guard let oyaSpoons = oya else {
            return
        }
        
        //gyotimeIndex
        if let label = label {
            oyaSpoons.GyoTimeKosin(gyo: oyaSpoons.posY(index: oyaSpoons.index(uiLabel: label) ) )
        }
        
        //isWiped nextIndex
        if miriSec == -1 {
            isWiped = false
            
        }else if miriSec <= oyaSpoons.currentMiriSec {
            isWiped = true
            
        }else if oyaSpoons.nextIndex >= 0 && oyaSpoons.spoons[oyaSpoons.nextIndex].miriSec <= mirisec {
            isWiped = false
            
        }else { // currentTime < mirisec < nextIndex.time
            isWiped = false
            if let label = label {
                oyaSpoons.nextIndex = oyaSpoons.index(uiLabel: label)
            }
        }
    }
    
    private var isCheckableWord: Bool {
        let wd = word.applyingTransform(.hiraganaToKatakana, reverse: true)!
        switch wd {
        case "ぁ":return false
        case "ぃ":return false
        case "ぅ":return false
        case "ぇ":return false
        case "ぉ":return false
        case "っ":return false
        case "ゃ":return false
        case "ゅ":return false
        case "ょ":return false
        case "ー":return false
        default: break
        }
        if word.isHiragana || word.isKatakana {
            return true
        }
        return false
    }
}
class Spoons {
    var spoons:[Spoon] = [] {
        didSet {
            print("spoons didset")
            if cursorIndex >= spoons.count {
                cursorIndex = spoons.count - 1
            }
        }
    }
    var gyotoIndex:[Int] = [0]
    class MinMaxIndex {
        var min = -1
        var max = -1
    }
    var gyotimeIndex:[MinMaxIndex] = []
    var atTag:[String:String] = [:]
    
    var nextIndex = -1
    var currentMiriSec = 0
    
    var cursorView:UIView?
    private(set) var cursorIndex:Int = 0
    
    var targetSelf:UIViewController?
    
    private var serialIndex = 0
    func getSerialIndex() -> Int {
        serialIndex += 1
        return serialIndex
    }
    
    init(timetagText:String = "") {
        
        if timetagText == "" {
            //word
            let spoon = Spoon(word: "\n", oya:self)
            self.spoons.append(spoon)
            return
        }
        var str_ = timetagText.pregReplace(pattern: "\r\n", with: "\n")
        //@tag
        var ans:[String]=[]
        if str_.pregMatche(pattern: "^@(.*?)\\s*=\\s*(.*?)$", matches:&ans) {
            for index in 0..<(ans.count/3) {
                print("あっと\(ans[index*3+1]) = \(ans[index*3+2])")
                self.atTag[ ans[index*3+1] ] = ans[index*3+2]
            }
            str_ = str_.pregReplace(pattern: "^@(.*?)\\s*=\\s*(.*?)$", with: "")
        }
        var maeTimetag = ""
        ans = []
        if !str_.pregMatche(pattern: "\\[\\d\\d\\:\\d\\d[\\:\\.]\\d\\d\\]|.", matches: &ans){
            return
        }
        print(ans)
        for an in ans {
            print(an)
            if an.count == 10 {//Timetag
                if maeTimetag != "" {
                    let spoon = Spoon(word: "",
                                      miriSec: Int(maeTimetag.timetagToSeconds()*1000),
                                      note: maeTimetag.isDotTimetag,
                                      oya: self)
                    self.spoons.append(spoon)
                }
                maeTimetag = an
                continue
            }
            //word
            if maeTimetag == "" {
                let spoon = Spoon(word: an, oya: self)
                self.spoons.append(spoon)
                
            }else {
                let spoon = Spoon(word: an,
                                  miriSec: Int(maeTimetag.timetagToSeconds()*1000),
                                  note: maeTimetag.isDotTimetag,
                                  oya: self)
                maeTimetag = ""
                self.spoons.append(spoon)
            }
        }
        //テキスト末尾の連続改行を削る
        print(self.spoons.count)
        if self.spoons.count >= 2 {
            for _ in 2...self.spoons.count {
                if self.spoons[self.spoons.count - 2].word == "\n" && self.spoons[self.spoons.count - 1].word == "\n" {
                    self.spoons.remove(at: self.spoons.count - 1)
                    continue
                }
                break
            }
        }
        GyoDataKosin()
        SetNextIndex()
        return
    }
    func insert( spoons:Spoons, index:Int ) {
        for spoon in spoons.spoons.reversed() {
            spoon.oya = self
            self.spoons.insert(spoon, at: index)
        }
        GyoDataKosin()
    }
    func backDelete( cursorIndex:Int ) -> Bool {
        if cursorIndex <= 0 || spoons.count <= cursorIndex {
            return false
        }
        print("remove")
        spoons.remove(at: cursorIndex-1)
        GyoDataKosin()
        return true
    }
    private func GyoDataKosin() {
        //gyoto更新
        gyotoIndex = [0]
        var maeIndexRetrun = false
        for (index, spoon) in self.spoons.enumerated() {
            if maeIndexRetrun {
                gyotoIndex.append(index)
                maeIndexRetrun = false
            }
            if spoon.word == "\n" {
                maeIndexRetrun = true
            }
        }
        //gyotime更新
        gyotimeIndex = []
        for _ in gyotoIndex {
            gyotimeIndex.append(.init()) //全初期化
        }
        for y in 0..<maxGyo {
            GyoTimeKosin(gyo: y)
        }
    }
    func GyoTimeKosin(gyo:Int) {
        var minTime = 99*60*1000+99*1000+991
        var maxTime = -1
        for index in rangeIndex(gyo: gyo) {
            let mirisec = spoons[index].miriSec
            if mirisec == -1 {
                continue
            }
            if minTime > mirisec {
                minTime = mirisec
                gyotimeIndex[gyo].min = index
            }
            if maxTime < mirisec {
                maxTime = mirisec
                gyotimeIndex[gyo].max = index
            }
        }
    }
    func SetNextIndex() {
        var nowTime = -1
        var nextTime = 99*60*1000+99*1000+991
        if nextIndex != -1 {
            nowTime = spoons[nextIndex].miriSec
        }
        for (gyo,minmax) in gyotimeIndex.enumerated() {
            if minmax.min == -1 || minmax.max == -1 {
                continue
            }
            if spoons[minmax.max].miriSec < nowTime {
                continue
            }
            if nextTime < spoons[minmax.min].miriSec {
                continue
            }
            for index in rangeIndex(gyo: gyo) {
                if spoons[index].miriSec != -1 && nextTime >= spoons[index].miriSec && spoons[index].isWiped == false {
                    nextTime = spoons[index].miriSec
                    nextIndex = index
                }
            }
        }
        if nextTime ==  99*60*1000+99*1000+991 {
            nextIndex = -2
        }
    }
    func SetPrevIndex() {
        var nowTime = 99*60*1000+99*1000+991
        var nextTime = -1
        if nextIndex != -2 {
            nowTime = spoons[nextIndex].miriSec
        }
        for (gyo,minmax) in gyotimeIndex.enumerated() {
            if minmax.min == -1 || minmax.max == -1 {
                continue
            }
            if spoons[minmax.min].miriSec > nowTime {
                continue
            }
            if nextTime > spoons[minmax.max].miriSec {
                continue
            }
            for index in rangeIndex(gyo: gyo) {
                if spoons[index].miriSec != -1 && nextTime <= spoons[index].miriSec && spoons[index].isWiped == true {
                    nextTime = spoons[index].miriSec
                    nextIndex = index
                }
            }
        }
        if nextTime == -1 {
            nextIndex = -1
        }
    }
    
    enum atTagExpMode {
        case UserData
        case PreNicoFlickDB
        case NicoFlickDB
    }
    func export(mode:atTagExpMode) -> String {
        // @tag 先処理分
        var tags = self.atTag
        var offset = 0
        switch mode {
        case atTagExpMode.UserData:
            //制限なし
            tags["NicoFlick"] = "3"
            break
        case atTagExpMode.PreNicoFlickDB:
            for (tag,_) in tags {
                if tag != "NicoFlick" && tag != "Description" && tag != "Offset" {
                    tags[tag] = nil
                }
            }
            tags["NicoFlick"] = "2"
            break
        default:
            if let os = tags["Offset"] {
                offset = Int(os)!
            }
            tags = ["NicoFlick":"1"]
        }
        //Notes
        var text = ""
        for spoon in self.spoons {
            // timetag
            if spoon.miriSec != -1 {
                if spoon.note {
                    text += String.secondsToDotTimetag(seconds: Double(spoon.miriSec + offset)/1000)
                }else {
                    text += String.secondsToTimetag(seconds: Double(spoon.miriSec + offset)/1000)
                }
            }
            // word
            text += spoon.word
        }
        if text.suffix(1) != "\n" {
            text += "\n"
        }
        //@tag
        for (key,value) in tags {
            if value == "" { continue }
            text += "@\(key)=\(value)\n"
        }
        return text
    }
    
    func posY(index:Int) -> Int {
        for (y,i) in self.gyotoIndex.enumerated() {
            if i > index {
                return y-1
            }
        }
        return self.gyotoIndex.count - 1
    }
    func posX(index:Int) -> Int {
        let y = posY(index: index)
        return index - self.gyotoIndex[y]
    }
    func pos(index:Int) -> (Int,Int) {
        return ( posX(index: index), posY(index: index) )
    }
    var maxGyo:Int {
        return self.gyotoIndex.count
    }
    var maxRetu:Int {
        var max = 0
        var maeGyoto = 0
        for gyoto in self.gyotoIndex {
            if max < (gyoto - maeGyoto) {
                max = gyoto - maeGyoto
            }
            maeGyoto = gyoto
        }
        if max < (self.spoons.count - maeGyoto) {
            max = self.spoons.count - maeGyoto
        }
        return max
    }
    func maxRetu(y:Int) -> Int {
        if y >= (self.gyotoIndex.count - 1) {
            return self.spoons.count - self.gyotoIndex[self.gyotoIndex.count - 1] - 1
        }else {
            return self.gyotoIndex[y+1] - self.gyotoIndex[y]
        }
    }
    func index(uiLabel:UILabel) -> Int {
        for (index,spoon) in self.spoons.enumerated() {
            if let tag = spoon.label?.tag {
                if uiLabel.tag == tag {
                    return index
                }
            }
        }
        return -1
    }
    func rangeIndex(gyo:Int) -> ClosedRange<Int> {
        return gyotoIndex[gyo] ... gyotoIndex[gyo] + maxRetu(y: gyo)
    }
    
    func setCursor(index:Int, scroll:Bool = false, scrollView:UIScrollView? = nil, animated:Bool = true){
        cursorIndex = index
        if cursorIndex < 0 { cursorIndex = 0 }
        if cursorIndex >= spoons.count { cursorIndex = spoons.count - 1 }
        if let view = cursorView {
            if cursorIndex < spoons.count {
                view.center = spoons[cursorIndex].label!.center
            }
        }
        if scroll == false {
            return
        }
        guard let view = scrollView else {
            return
        }
        guard let label = spoons[cursorIndex].label else {
            return
        }
        print("x: \(label.frame.origin.x - 50 / view.zoomScale),y: \(label.frame.origin.y - 50 / view.zoomScale),width:\(label.frame.size.width + 200 / view.zoomScale),height: \(label.frame.size.height + 200 / view.zoomScale)")
        view.scrollRectToVisible(
            CGRect(x: label.frame.origin.x * view.zoomScale - 50,
                   y: label.frame.origin.y * view.zoomScale - 50,
                   width: label.frame.size.width * view.zoomScale + 200,
                   height: label.frame.size.height * view.zoomScale + 300
        ), animated: animated)
    }
    
    func setCursorNextCheck(scrollView:UIScrollView? = nil, animated:Bool = false) -> Bool{
        for index in cursorIndex + 1 ..< spoons.count {
            if spoons[index].check {
                setCursor(index: index, scroll: true, scrollView: scrollView, animated: animated)
                return true
            }
        }
        return false
    }
    func setCursorPrevTimetaged(scrollView:UIScrollView? = nil, animated:Bool = false) -> Bool{
        for i in 0 ... cursorIndex {
            let index = cursorIndex - i
            if spoons[index].miriSec != -1 {
                setCursor(index: index, scroll: true, scrollView: scrollView, animated: animated)
                return true
            }
        }
        return false
    }
    func setCursorPrevNoted(scrollView:UIScrollView? = nil, animated:Bool = false) -> Bool{
        for i in 0 ... cursorIndex {
            let index = cursorIndex - i
            if spoons[index].note == true {
                setCursor(index: index, scroll: true, scrollView: scrollView, animated: animated)
                return true
            }
        }
        return false
    }
    enum CursorMode {
        case box
        case line
    }
    func changeCursor(mode:CursorMode){
        guard let view = cursorView else {
            return
        }
        view.viewWithTag(1)?.isHidden = !(mode == CursorMode.box)
        view.viewWithTag(2)?.isHidden = !(mode == CursorMode.line)
    }
    
    func setNotes_NearTimePos(mirisec:Int) -> Int?{
        var getIndex = -1
        var sitaGyo = -1
        var ueGyo = -1
        var minestIndex = -1
        var maxestIndex = -1
        for (gyo,minmax) in gyotimeIndex.enumerated() {
            if minmax.min == -1 || minmax.max == -1 {
                continue
            }
            if mirisec <= spoons[minmax.max].miriSec {
                ueGyo = gyo
            }
            if spoons[minmax.min].miriSec <= mirisec {
                sitaGyo = gyo
            }
            if minestIndex == -1 || spoons[minestIndex].miriSec > spoons[minmax.min].miriSec {
                minestIndex = minmax.min
            }
            if maxestIndex == -1 || spoons[maxestIndex].miriSec < spoons[minmax.max].miriSec {
                maxestIndex = minmax.max
            }
        }
        if sitaGyo == -1 || ueGyo == -1 {
            
            if minestIndex != -1 {
                if (spoons[minestIndex].miriSec - 1000) <= mirisec && mirisec <= spoons[minestIndex].miriSec {
                    spoons[minestIndex].note = true
                    return minestIndex
                }
            }
            if maxestIndex != -1 {
                if spoons[maxestIndex].miriSec <= mirisec && mirisec <= (spoons[maxestIndex].miriSec + 1000) {
                    spoons[maxestIndex].note = true
                    return maxestIndex
                }
            }
            
            return nil
        }
        if sitaGyo > ueGyo {
            (sitaGyo,ueGyo) = (ueGyo,sitaGyo)
        }
        for index in gyotoIndex[sitaGyo] ... gyotoIndex[ueGyo] + maxRetu(y: ueGyo){
            if spoons[index].miriSec == -1 { continue }
            if getIndex == -1 {
                getIndex = index
                continue
            }
            if abs(spoons[index].miriSec - mirisec) < abs(spoons[getIndex].miriSec - mirisec) {
                getIndex = index
            }
        }
        if getIndex == -1 {
            return nil
        }
        spoons[getIndex].note = true
        return getIndex
    }
    
    func pushCurrentTime(mirisec:Int){
        //print(mirisec)
        if currentMiriSec <= mirisec {
            if nextIndex < 0 {
                if nextIndex == -2 {
                    return
                }
                SetNextIndex()
            }
            //正方向の色変更
            while(nextIndex >= 0 && spoons[nextIndex].miriSec <= mirisec){
                spoons[nextIndex].isWiped = true
                SetNextIndex()
            }
        }else{
            if nextIndex < 0 {
                if nextIndex == -1 {
                    return
                }
                SetPrevIndex()
            }
            //逆方向の色変更
            while(nextIndex >= 0 && spoons[nextIndex].miriSec > mirisec){
                spoons[nextIndex].isWiped = false
                SetPrevIndex()
            }
        }
        currentMiriSec = mirisec
    }
    
    func getLevelStarReferencevalue() -> Int {
        var maeMirisec = 0
        var count = 0
        var sumJikanSa = 0
        for spoon in spoons {
            /*
            if spoon.word == "\n" {
                maeMirisec = 0
                continue
            }
            */
            if spoon.miriSec == -1 { continue }
            if spoon.note == false { continue }
            if maeMirisec == 0 {
                maeMirisec = spoon.miriSec
                continue
            }
            let jikanSa = spoon.miriSec - maeMirisec
            maeMirisec = spoon.miriSec
            if jikanSa >= 3000 { continue }
            sumJikanSa += jikanSa
            count += 1
        }
        if count == 0 { return 1 }
        let avgJikanSa = Double(sumJikanSa / count)
        var speed = 150
        if let sp = atTag["speed"] {
            speed = Int(sp)!
        }
        var hoshi = Int(round( (15 - sqrt((avgJikanSa + 50) / 10)) * (1.0 + Double(speed - 150) / 500) ))
        if hoshi < 1 { hoshi = 1 }
        if hoshi > 10 { hoshi = 10 }
        return hoshi
    }
}
