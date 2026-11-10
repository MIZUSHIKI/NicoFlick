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
    func copy() -> Spoon {
        let instance = Spoon()
        instance.word  = self.word
        instance.miriSec  = self.miriSec
        instance.note = self.note
        instance.check = self.check
        return instance
    }
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
        // print("deinit")
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
    
    var isCheckableWord: Bool {
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
            // print("spoons didset")
            if cursorIndex >= spoons.count {
                cursorIndex = spoons.count - 1
            }
        }
    }
    private(set) var rirekiSpoonSets:[RirekiSpoonSet] = []
    private(set) var rirekiNowIndex = 0
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
    
    var rirekiUndoButton:UIButton?
    var rirekiRedoButton:UIButton?
    
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
        var ofs = 0
        if str_.pregMatche(pattern: "^@(.*?)\\s*=\\s*(.*?)$", matches:&ans) {
            for index in 0..<(ans.count/3) {
                // print("あっと\(ans[index*3+1]) = \(ans[index*3+2])")
                if ans[index*3+1] == "OffsetWhenPosted" {
                    ofs = Int( ans[index*3+2] ) ?? 0
                }
                self.atTag[ ans[index*3+1] ] = ans[index*3+2]
            }
            str_ = str_.pregReplace(pattern: "^@(.*?)\\s*=\\s*(.*?)$", with: "")
        }
        var maeTimetag = ""
        ans = []
        if !str_.pregMatche(pattern: "\\[[\\d\\*][\\d\\*]\\:[\\d\\*][\\d\\*][\\:\\.][\\d\\*][\\d\\*]\\]|.", matches: &ans){
            // [**:**.**]とかでnoteだけの記録にも対応しとく
            return
        }
        // print(ans)
        for an in ans {
            // print(an)
            if an.count == 10 {//Timetag
                if maeTimetag != "" {
                    let spoon = Spoon(word: "",
                                      miriSec: Int(maeTimetag.timetagToSeconds()*1000) - ofs,
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
                                  miriSec: Int(maeTimetag.timetagToSeconds()*1000) - ofs,
                                  note: maeTimetag.isDotTimetag,
                                  oya: self)
                maeTimetag = ""
                self.spoons.append(spoon)
            }
        }
        //テキスト末尾の連続改行を削る
        // print(self.spoons.count)
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
        // print("remove")
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
            if offset != 0 {
                tags["OffsetWhenPosted"] = "\(offset)"
            }
        }
        //Notes
        var text = ""
        for spoon in self.spoons {
            // timetag
            if spoon.miriSec != -1 {
                let exportMilliseconds = max(0, spoon.miriSec + offset)
                text += String.secondsToTimetag(
                    seconds: Double(exportMilliseconds) / 1000,
                    dot: spoon.note
                )
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
        // print("x: \(label.frame.origin.x - 50 / view.zoomScale),y: \(label.frame.origin.y - 50 / view.zoomScale),width:\(label.frame.size.width + 200 / view.zoomScale),height: \(label.frame.size.height + 200 / view.zoomScale)")
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
    
    func setNotes_NearTimePos(mirisec:Int) -> (Int?,Spoon?){
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
                    let maeSpoon = spoons[minestIndex].copy()
                    spoons[minestIndex].note = true
                    return (minestIndex, maeSpoon)
                }
            }
            if maxestIndex != -1 {
                if spoons[maxestIndex].miriSec <= mirisec && mirisec <= (spoons[maxestIndex].miriSec + 1000) {
                    let maeSpoon = spoons[maxestIndex].copy()
                    spoons[maxestIndex].note = true
                    return (maxestIndex, maeSpoon)
                }
            }
            
            return (nil,nil)
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
            return (nil,nil)
        }
        let maeSpoon = spoons[getIndex].copy()
        spoons[getIndex].note = true
        return (getIndex, maeSpoon)
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
    
    func getLevelStarReferencevalue(FULL:Bool = false) -> Int {
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
            if spoon.isCheckableWord && spoon.note == false && FULL == false { continue }
            if maeMirisec == 0 {
                maeMirisec = spoon.miriSec
                continue
            }
            let jikanSa = spoon.miriSec - maeMirisec
            maeMirisec = spoon.miriSec
            // 時系列を逆行する不正なタイムタグと、3秒以上の休符は平均から除外する。
            if jikanSa < 0 || jikanSa >= 3000 { continue }
            sumJikanSa += jikanSa
            count += 1
        }
        if count == 0 { return 1 }
        let avgJikanSa = Double(sumJikanSa / count)
        var hoshi = Int(round(15 - sqrt((avgJikanSa + 50) / 10)))
        if hoshi < 1 { hoshi = 1 }
        if hoshi > 10 { hoshi = 10 }
        return hoshi
    }
    
    /// ノーツ間隔・入力内容・密集の頻度から、譜面の参考難易度を実数で求める（上限なし）。
    ///
    /// 計算仕様バージョン: ver.2.0
    /// - ver.1.0: 四捨五入し、上限20の整数を返す。
    /// - ver.2.0:
    ///   ・星8〜20に相当する難易度の計算式を調整。
    ///   ・丸め前の実数を上限なしで返す形式に変更。
    ///   ・整数化・上限20への制限は呼び出し側で行う。
    ///   ・星1〜7を旧式で求める仕様は維持。
    ///
    /// 同期先: リポジトリ直下の LevelStarReference.php。
    /// 旧式の分岐を含む係数・集計・丸めを変更する際はPHP版も同時に更新し、同じ譜面で結果を比較すること。
    ///
    /// 要点:
    /// - 星1〜7は旧式を返し、星8以上をこの密度評価で細分化する。
    /// - 通常の忙しさ50%、難所35%、繰り返し現れる2秒密集15%で基礎点を作る。
    /// - タップ文字と反復入力は少し易しく扱う。
    /// - 星8を起点に星14まで細かな直線、それ以降は平方根曲線で評価する。
    ///
    /// 詳細:
    /// 1. FULLがfalseなら、旧式と同じ条件でゲーム対象ノーツだけを抽出する。
    /// 2. 入力の重みは通常フリック1.0、中央タップ0.82、同字連続はさらに0.78倍、
    ///    2〜4文字周期の反復はさらに0.90倍とする。
    /// 3. 隣接ノーツ間隔を1秒あたりの重み付き入力数へ変換する。
    ///    80ms未満は80msとして上限を設け、3秒以上の間隔は休符として除外する。
    /// 4. 間隔密度の75パーセンタイル（持続的な忙しさ）と90パーセンタイル
    ///    （上位10%の難所）を求める。
    /// 5. 曲全体を500ms刻みで走査し、直前2秒間の密度の90パーセンタイルを求める。
    ///    最大値ではないため、一度だけの密集より繰り返す密集を高く評価する。
    /// 6. difficulty = P75×0.50 + P90×0.35 + 2秒窓P90×0.15。
    ///    丸め前8までは1 + difficulty×1.75、その先は傾き3.5で星14まで評価する（1Lvあたりの基礎点増加は元の50%）。
    ///    星14超は固定係数0.58の平方根曲線で圧縮し、下限8の実数を返す。
    ///    整数化と上限20への制限は呼び出し側で行う。
    func getLevelStarReferencevalueV2(FULL: Bool = false) -> Double {
        // 星1〜7は旧式の値をそのまま返し、不要なV2計算を省略する。
        let currentStar = getLevelStarReferencevalue(FULL: FULL)
        if currentStar <= 7 {
            return Double(currentStar)
        }

        // 実譜面との比較で調整する値は、ここに集約する。
        let tapWeight = 0.82
        let sameCharacterWeight = 0.78
        let repeatedPhraseWeight = 0.90
        let minimumInterval = 80
        let ignoredInterval = 3000
        let burstWindow = 2000
        let burstSampleInterval = 500

        var latestTargetTime = -1
        let targetSpoons = spoons.filter {
            if $0.miriSec < 0 {
                return false
            }
            if !(FULL || !$0.isCheckableWord || $0.note) {
                return false
            }
            // 2秒窓は時刻昇順が前提。末尾の[00:00.00]など、逆行する異常値を除外する。
            if $0.miriSec < latestTargetTime {
                return false
            }
            latestTargetTime = $0.miriSec
            return true
        }
        guard targetSpoons.count >= 2 else {
            return 1
        }

        func normalizedWord(_ word: String) -> String {
            return word.applyingTransform(.hiraganaToKatakana, reverse: true) ?? word
        }

        // かな入力で中央をタップする文字。濁音・半濁音も同じ操作量として扱う。
        let tapCharacters = "あかさたなはまやらわがざだばぱアカサタナハマヤラワガザダバパ"
        func inputWeight(at index: Int) -> Double {
            let word = normalizedWord(targetSpoons[index].word)
            var weight = tapCharacters.contains(word) ? tapWeight : 1.0

            if index > 0 && word == normalizedWord(targetSpoons[index - 1].word) {
                weight *= sameCharacterWeight
            } else {
                // 「はいはい」のような2〜4文字周期の反復を、初見の文字列より少し易しくする。
                for distance in 2...4 where index >= distance {
                    if word == normalizedWord(targetSpoons[index - distance].word) {
                        weight *= repeatedPhraseWeight
                        break
                    }
                }
            }
            return weight
        }

        var strains: [Double] = []
        var timedWeights: [(time: Int, weight: Double)] = []

        for index in targetSpoons.indices {
            let weight = inputWeight(at: index)
            timedWeights.append((targetSpoons[index].miriSec, weight))

            guard index > 0 else {
                continue
            }
            let interval = targetSpoons[index].miriSec - targetSpoons[index - 1].miriSec
            guard interval >= 0 && interval < ignoredInterval else {
                continue
            }

            // 前後両方の操作を考慮し、異常に短い同時刻ノーツは上限付きで評価する。
            let transitionWeight = (inputWeight(at: index - 1) + weight) / 2.0
            let actionsPerSecond = 1000.0 / Double(max(interval, minimumInterval))
            strains.append(actionsPerSecond * transitionWeight)
        }
        guard !strains.isEmpty else {
            return 1
        }

        let sortedStrains = strains.sorted()
        func percentile(of sortedValues: [Double], at value: Double) -> Double {
            let position = Int(round(Double(sortedValues.count - 1) * value))
            return sortedValues[position]
        }

        // 曲全体を一定間隔で走査し、各時点から直前2秒間の重み付き入力密度を求める。
        // ノーツごとの窓ではなく時間軸上の窓にすることで、密集の回数と継続時間を反映する。
        var burstRates: [Double] = []
        var burstStart = 0
        var burstEnd = 0
        var burstWeight = 0.0
        var sampleTime = timedWeights[0].time
        let lastTime = timedWeights[timedWeights.count - 1].time

        while sampleTime <= lastTime {
            while burstEnd < timedWeights.count && timedWeights[burstEnd].time <= sampleTime {
                burstWeight += timedWeights[burstEnd].weight
                burstEnd += 1
            }
            while burstStart < burstEnd
                && timedWeights[burstStart].time < sampleTime - burstWindow {
                burstWeight -= timedWeights[burstStart].weight
                burstStart += 1
            }
            burstRates.append(
                burstWeight * 1000.0 / Double(burstWindow)
            )
            sampleTime += burstSampleInterval
        }

        // 最後のノーツがサンプル時刻と一致しない場合も、終端の2秒窓を評価する。
        if (lastTime - timedWeights[0].time) % burstSampleInterval != 0 {
            while burstEnd < timedWeights.count {
                burstWeight += timedWeights[burstEnd].weight
                burstEnd += 1
            }
            while burstStart < burstEnd
                && timedWeights[burstStart].time < lastTime - burstWindow {
                burstWeight -= timedWeights[burstStart].weight
                burstStart += 1
            }
            burstRates.append(
                burstWeight * 1000.0 / Double(burstWindow)
            )
        }

        let sortedBurstRates = burstRates.sorted()

        // 持続力50%、難所35%、繰り返し現れる2秒密集15%。
        let difficulty = percentile(of: sortedStrains, at: 0.75) * 0.50
            + percentile(of: sortedStrains, at: 0.90) * 0.35
            + percentile(of: sortedBurstRates, at: 0.90) * 0.15

        // Lv8（基礎点4）から等しい刻みで評価。middleSlopeを大きくすると1Lvあたりの必要密度が小さくなる。
        let preservedBoundaryStar = 8.0
        let preservedBoundaryDifficulty = (preservedBoundaryStar - 1.0) / 1.75
        let middleSlope = 3.5
        let linearStar = difficulty < preservedBoundaryDifficulty
            ? 1.0 + difficulty * 1.75
            : preservedBoundaryStar + (difficulty - preservedBoundaryDifficulty) * middleSlope

        // 星14までは直線、その先は値と傾きが連続する平方根曲線。
        // 調整目安: difficulty = 4 → 8、約4.286 → 9、5.714 → 14、12.329 → 20.10（丸め前）。
        // 高難度側は係数0.58を維持。係数は固定値とし、実行時の逆算はしない。
        // highDifficultyCurveを大きくすると高難度側の評価値が下がり、同じ星に必要な密度が増す。
        // middleSlope・curveStartStarを変えた場合も、上記基礎点を比較の目安にする。
        let curveStartStar = 14.0
        let highDifficultyCurve = 0.58
        let excessOverCurveStart = max(0.0, linearStar - curveStartStar)
        let curvedStar = linearStar <= curveStartStar
            ? linearStar
            : curveStartStar + excessOverCurveStart
                / sqrt(1.0 + highDifficultyCurve * excessOverCurveStart)
        return max(8.0, curvedStar)
    }
    
    /// タイムタグとレベルを保ったまま、振り分けだけを一括削除する。
    func clearFlickNotes() {
        guard spoons.contains(where: { $0.note }) else { return }
        let previous = spoons.map { $0.copy() }
        for spoon in spoons {
            spoon.note = false
        }
        _setRireki(index: max(0, cursorIndex), changedID: .NoteBatch,
                   maeSpoons: previous, newSpoons: spoons)
        rirekiSpoonSets.last?.oldLevel = atTag["Level"]
        rirekiSpoonSets.last?.newLevel = atTag["Level"]
    }

    /// Apply one generated chart as a single undoable edit, including its displayed level.
    func applyExternalAISelection(_ selected: Set<Int>, level: Int) {
        guard !spoons.isEmpty, (1...20).contains(level) else { return }
        let previous = spoons.map { $0.copy() }
        let oldLevel = atTag["Level"]
        for (index, spoon) in spoons.enumerated() {
            spoon.note = selected.contains(index) && spoon.isCheckableWord && spoon.miriSec >= 0
        }
        _setRireki(index: max(0, cursorIndex), changedID: .NoteBatch,
                   maeSpoons: previous, newSpoons: spoons)
        rirekiSpoonSets.last?.oldLevel = oldLevel
        // レベルUIへの自動設定値だけを上限10にし、難易度の計算値は変更しない。
        let displayedLevel = String(min(level, 10))
        rirekiSpoonSets.last?.newLevel = displayedLevel
        atTag["Level"] = displayedLevel
    }

    func externalAISnapshot(sourceID: String) -> ExternalAIChartExchange.Snapshot {
        ExternalAIChartExchange.Snapshot(
            sourceID: sourceID,
            nodes: spoons.map {
                ExternalAIChartExchange.Node(word: $0.word, timeMs: $0.miriSec,
                                            selectable: $0.isCheckableWord, note: $0.note)
            },
            level: atTag["Level"], offset: atTag["Offset"])
    }

    func externalAILevel(for selected: Set<Int>) -> Int {
        let preview = Spoons()
        preview.spoons = spoons.map { $0.copy() }
        for (index, spoon) in preview.spoons.enumerated() {
            spoon.note = selected.contains(index)
        }
        return Int(min(20.0, preview.getLevelStarReferencevalueV2(FULL: false).rounded()))
    }

    //履歴
    func setRireki(index:Int, changedID:RirekiSpoonSet.changed, maeSpoon:Spoon, newSpoon:Spoon?) {
        let mae:[Spoon] = [maeSpoon]
        var new:[Spoon] = []
        if let spoon = newSpoon {
            new += [spoon]
        }
        self._setRireki(index: index, changedID: changedID, maeSpoons: mae, newSpoons: new)
    }
    func setRireki(index:Int, changedID:RirekiSpoonSet.changed, maeSpoon:Spoon?, newSpoonS:Spoons) {
        var mae:[Spoon] = []
        var new:[Spoon] = []
        if let spoon = maeSpoon {
            mae += [spoon]
        }
        for spoon in newSpoonS.spoons {
            new += [spoon]
        }
        self._setRireki(index: index, changedID: changedID, maeSpoons: mae, newSpoons: new)
    }
    private func _setRireki(index:Int, changedID:RirekiSpoonSet.changed, maeSpoons:[Spoon], newSpoons:[Spoon]) {
        let rirekiSpoonSet = RirekiSpoonSet(index: index, changedID: changedID, maeSpoons: maeSpoons, newSpoons: newSpoons)
        if rirekiSpoonSets.count == rirekiNowIndex {
            //末尾に追加
            rirekiSpoonSets.append(rirekiSpoonSet)
            rirekiNowIndex += 1
        }else {
            //上書きして、以降を削除
            rirekiSpoonSets[rirekiNowIndex] = rirekiSpoonSet
            rirekiNowIndex += 1
            for _ in rirekiNowIndex ..< rirekiSpoonSets.count {
                rirekiSpoonSets.removeLast()
            }
        }
        //
        if let button = rirekiUndoButton {
            button.alpha = 0.7
        }
        if let button = rirekiRedoButton {
            button.alpha = 0.35
        }
    }
    
    var getNextUndoChangedID:RirekiSpoonSet.changed {
        if !rirekiUndoAble {
            return RirekiSpoonSet.changed.None
        }
        let rirekiSpoon = rirekiSpoonSets[rirekiNowIndex-1]
        return rirekiSpoon.changedID
    }
    var rirekiUndoAble:Bool {
        return !(rirekiNowIndex <= 0)
    }
    func rirekiUndo() -> Int {
        if !rirekiUndoAble {
            return -1
        }
        rirekiNowIndex -= 1
        let rirekiSpoon = rirekiSpoonSets[rirekiNowIndex]
        // print("rireki \(rirekiSpoon.index-1)")
        let ri = rirekiSpoon.index-1
        var retIndex = rirekiSpoon.index
        
        switch rirekiSpoon.changedID {
        case .MiriSec:
            spoons[rirekiSpoon.index].setMirisec(mirisec: rirekiSpoon.mae[0].miriSec)
        case .NoteBatch:
            for (spoon, saved) in zip(spoons, rirekiSpoon.mae) {
                spoon.note = saved.note
            }
            atTag["Level"] = rirekiSpoon.oldLevel
        case .Note:
            spoons[rirekiSpoon.index].note = rirekiSpoon.mae[0].note
        case .Word:
            if rirekiSpoon.new.count == 0 {
                // BackDeleteをした（から追加）
                var timetagText = ""
                for rirekiSpoon in rirekiSpoon.mae {
                    timetagText += String.secondsToTimetag(seconds: Double(rirekiSpoon.miriSec) / 1000, noBrackets: false, dot: rirekiSpoon.note) + rirekiSpoon.word
                }
                //Spoon追加
                let tempSpoons = Spoons(timetagText: timetagText)
                // print("ri \(ri)")
                // print("ret \(retIndex)")
                // print("undo \(rirekiSpoon.index-1)")
                self.insert(spoons: tempSpoons, index: rirekiSpoon.index-1)
                retIndex -= 1
            }else {
                // 文字列追加をした（から削除）
                for _ in 0 ..< rirekiSpoon.new.count {
                    self.spoons.remove(at: rirekiSpoon.index)
                }
                GyoDataKosin()
                retIndex -= 1
            }
            // print("word")
        default:
            break
        }
        
        if let button = rirekiUndoButton {
            if rirekiNowIndex <= 0 {
                button.alpha = 0.35
            }else {
                button.alpha = 0.7
            }
        }
        if let button = rirekiRedoButton {
            button.alpha = 0.7
        }
        return retIndex
    }

    var getNextRedoChangedID:RirekiSpoonSet.changed {
        if !rirekiRedoAble {
            return RirekiSpoonSet.changed.None
        }
        let rirekiSpoon = rirekiSpoonSets[rirekiNowIndex]
        return rirekiSpoon.changedID
    }
    var rirekiRedoAble:Bool {
        return !(rirekiNowIndex >= rirekiSpoonSets.count)
    }
    func rirekiRedo() -> Int {
        if !rirekiRedoAble {
            return -1
        }
        let rirekiSpoon = rirekiSpoonSets[rirekiNowIndex]
        var retIndex = rirekiSpoon.index
        rirekiNowIndex += 1
        
        switch rirekiSpoon.changedID {
        case .MiriSec:
            spoons[rirekiSpoon.index].setMirisec(mirisec: rirekiSpoon.new[0].miriSec)
        case .NoteBatch:
            for (spoon, saved) in zip(spoons, rirekiSpoon.new) {
                spoon.note = saved.note
            }
            atTag["Level"] = rirekiSpoon.newLevel
        case .Note:
            spoons[rirekiSpoon.index].note = rirekiSpoon.new[0].note
        case .Word:
            // print("word")
            if rirekiSpoon.new.count == 0 {
                // BackDeleteをした（から削除）
                for _ in 0 ..< rirekiSpoon.mae.count {
                    self.spoons.remove(at: rirekiSpoon.index-1)
                }
                GyoDataKosin()
                retIndex -= 1
            }else {
                // 文字列追加をした（から追加）
                var timetagText = ""
                for rirekiSpoon in rirekiSpoon.new {
                    timetagText += String.secondsToTimetag(seconds: Double(rirekiSpoon.miriSec) / 1000, noBrackets: false, dot: rirekiSpoon.note) + rirekiSpoon.word
                }
                //Spoon追加
                let tempSpoons = Spoons(timetagText: timetagText)
                self.insert(spoons: tempSpoons, index: retIndex)
            }
        default:
            break
        }
        //
        if let button = rirekiUndoButton {
            button.alpha = 0.7
        }
        if let button = rirekiRedoButton {
            if rirekiNowIndex >= rirekiSpoonSets.count {
                button.alpha = 0.35
            }else {
                button.alpha = 0.7
            }
        }
        return retIndex
    }
}

class RirekiSpoon {
    var word = ""
    var miriSec = -1
    var note = false
    
    init(spoon:Spoon) {
        self.word = spoon.word
        self.miriSec = spoon.miriSec
        self.note = spoon.note
    }
}
class RirekiSpoonSet {
    
    enum changed {
        case None
        case Word
        case MiriSec
        case Note
        case NoteBatch
    }
    var index = -1
    var changedID = changed.None
    var oldLevel: String?
    var newLevel: String?
    var mae:[RirekiSpoon] = []
    var new:[RirekiSpoon] = []
    
    init(index:Int, changedID:RirekiSpoonSet.changed, maeSpoons:[Spoon], newSpoons:[Spoon]){
        for spoon in maeSpoons {
            self.mae += [RirekiSpoon(spoon: spoon)]
        }
        for spoon in newSpoons {
            self.new += [RirekiSpoon(spoon: spoon)]
        }
        self.changedID = changedID
        self.index = index
    }
}
