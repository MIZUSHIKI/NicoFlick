//
//  SEAudioClass.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2017/06/12.
//  Copyright © 2017年 i.MIZUSHIKI. All rights reserved.
//
import AVFoundation

class SEAudio {
    
    static let sharedInstance = SEAudio()

    //ファイル
    private let resourceOkJingleFile = "okJingle.wav"
    private let resourceSafeJingleFile = "safeJingle.wav"
    private let resourceBadJingleFile = "badJingle.wav"
    
    var okJingles:[AVAudioPlayer] = []
    private var okJingleCount = 0
    var safeJingles:[AVAudioPlayer] = []
    private var safeJingleCount = 0
    var badJingles:[AVAudioPlayer] = []
    private var badJingleCount = 0
    
    var volume:Float = 1.0 {
        didSet {
            for i in 0..<10 {
                okJingles[i].volume = 10.0 * volume
                safeJingles[i].volume = 10.0 * volume
                badJingles[i].volume = 5.0 * volume
            }
        }
    }
    
    private var loadedGameSE = false
    
    init(){
        loadGameSE()
    }
    
    func loadGameSE(){
        if loadedGameSE{
            return
        }
        loadedGameSE = true
        print("loadGameSE")
        
        //okJingles
        for _ in (0..<10){
            do {
                let audio = try AVAudioPlayer(contentsOf: GetSoundPath(file: resourceOkJingleFile), fileTypeHint:nil)
                okJingles.append(audio)
            } catch {
                print("AVAudioPlayerインスタンス作成失敗")
            }
            
        }
        //safeJingles
        for _ in (0..<10){
            do {
                let audio = try AVAudioPlayer(contentsOf: GetSoundPath(file: resourceSafeJingleFile), fileTypeHint:nil)
                safeJingles.append(audio)
            } catch {
                print("AVAudioPlayerインスタンス作成失敗")
            }
            
        }
        //badJingles
        for _ in (0..<10){
            do {
                let audio = try AVAudioPlayer(contentsOf: GetSoundPath(file: resourceBadJingleFile), fileTypeHint:nil)
                badJingles.append(audio)
            } catch {
                print("AVAudioPlayerインスタンス作成失敗")
            }
            
        }
        //set Volume
        self.volume = UserData.sharedInstance.SoundVolumeGameSE
    }
    
    func okJinglePlay(){
        okJingles[okJingleCount].play()
        okJingleCount += 1
        okJingleCount = okJingleCount % 10
    }
    func safeJinglePlay(){
        safeJingles[safeJingleCount].play()
        safeJingleCount += 1
        safeJingleCount = safeJingleCount % 10
    }
    func badJinglePlay(){
        badJingles[badJingleCount].play()
        badJingleCount += 1
        badJingleCount = badJingleCount % 10
    }
    
    private func GetSoundPath(file:String) -> URL {
        let soundFilePath = Bundle.main.path(forResource: (file as NSString).deletingPathExtension,
                                             ofType: (file as NSString).pathExtension)!
        return URL(fileURLWithPath: soundFilePath)
    }
}

class SESystemAudio {
    
    static let sharedInstance = SESystemAudio()

    //ファイル
    private let resourceShuffleSeFile = "shuffle.mp3"
    private let resourceDrumRollSeFile = "LoopDrumRoll.wav"
    private let resourceRankSeFile = "RANK.mp3"
    private let resourceGoSeFile = "GO.mp3"
    private let resourceCanselSeFile = "cansel.mp3"
    private let resourceCansel2SeFile = "cansel2.mp3"
    private let resourceStartSeFile = "START.mp3"
    private let resourceStart2SeFile = "START2.mp3"
    private let resourceGameMenuSeFile = "GameMenu.mp3"
    private let resourceOpenSeFile = "OPEN.mp3"
    private let resourceOpenSubSeFile = "OpenSub.mp3"
    private let resourceOpenSelectorMenuSeFile = "OpenSelectorMenu.mp3"
    
    var shuffleSes:[AVAudioPlayer] = []
    private var shuffleSeCount = 0
    var drumRollSe:AVAudioPlayer?
    var rankSe:AVAudioPlayer?
    var goSe:AVAudioPlayer?
    var canselSe:AVAudioPlayer?
    var cansel2Se:AVAudioPlayer?
    var startSe:AVAudioPlayer?
    var start2Se:AVAudioPlayer?
    var gameMenuSe:AVAudioPlayer?
    var openSe:AVAudioPlayer?
    var openSubSe:AVAudioPlayer?
    var openSelectorMenuSe:AVAudioPlayer?
    
    var volume:Float = 1.0 {
        didSet {
            for i in 0..<10 {
                shuffleSes[i].volume = 1.0 * volume
            }
            drumRollSe?.volume = 1.0 * volume
            rankSe?.volume = 5.0 * volume
            goSe?.volume = 3.0 * volume
            canselSe?.volume = 1.0 * volume
            cansel2Se?.volume = 3.0 * volume
            startSe?.volume = 3.0 * volume
            start2Se?.volume = 1.0 * volume
            gameMenuSe?.volume = 3.0 * volume
            openSe?.volume = 0.8 * volume
            openSubSe?.volume = 0.6 * volume
            openSelectorMenuSe?.volume = 2.0 * volume
        }
    }
    
    private var loadedSystemSE = false
    
    init(){
        loadSystemSE()
    }
    
    func loadSystemSE(){
        if loadedSystemSE{
            return
        }
        loadedSystemSE = true
        print("loadedSystemSE")
        
        //shuffleSes
        // AVAudioPlayerのインスタンスを作成
        for _ in (0..<10){
            do {
                let audio = try AVAudioPlayer(contentsOf: GetSoundPath(file: resourceShuffleSeFile), fileTypeHint:nil)
                shuffleSes.append(audio)

            } catch {
                print("AVAudioPlayerインスタンス作成失敗")
            }
            
        }
        //drumRollSe
        do {
            drumRollSe = try AVAudioPlayer(contentsOf: GetSoundPath(file: resourceDrumRollSeFile), fileTypeHint:nil)
        } catch {
            print("AVAudioPlayerインスタンス作成失敗")
        }
        //rankSe
        do {
            rankSe = try AVAudioPlayer(contentsOf: GetSoundPath(file: resourceRankSeFile), fileTypeHint:nil)
        } catch {
            print("AVAudioPlayerインスタンス作成失敗")
        }
        //goSe
        do {
            goSe = try AVAudioPlayer(contentsOf: GetSoundPath(file: resourceGoSeFile), fileTypeHint:nil)
        } catch {
            print("AVAudioPlayerインスタンス作成失敗")
        }
        //canselSe
        do {
            canselSe = try AVAudioPlayer(contentsOf: GetSoundPath(file: resourceCanselSeFile), fileTypeHint:nil)
        } catch {
            print("AVAudioPlayerインスタンス作成失敗")
        }
        //canselSe
        do {
            cansel2Se = try AVAudioPlayer(contentsOf: GetSoundPath(file: resourceCansel2SeFile), fileTypeHint:nil)
        } catch {
            print("AVAudioPlayerインスタンス作成失敗")
        }
        //startSe
        do {
            startSe = try AVAudioPlayer(contentsOf: GetSoundPath(file: resourceStartSeFile), fileTypeHint:nil)
        } catch {
            print("AVAudioPlayerインスタンス作成失敗")
        }
        //start2Se
        do {
            start2Se = try AVAudioPlayer(contentsOf: GetSoundPath(file: resourceStart2SeFile), fileTypeHint:nil)
        } catch {
            print("AVAudioPlayerインスタンス作成失敗")
        }
        //gameMenuSe
        do {
            gameMenuSe = try AVAudioPlayer(contentsOf: GetSoundPath(file: resourceGameMenuSeFile), fileTypeHint:nil)
        } catch {
            print("AVAudioPlayerインスタンス作成失敗")
        }
        //openSe
        do {
            openSe = try AVAudioPlayer(contentsOf: GetSoundPath(file: resourceOpenSeFile), fileTypeHint:nil)
        } catch {
            print("AVAudioPlayerインスタンス作成失敗")
        }
        //openSubSe
        do {
            openSubSe = try AVAudioPlayer(contentsOf: GetSoundPath(file: resourceOpenSubSeFile), fileTypeHint:nil)
        } catch {
            print("AVAudioPlayerインスタンス作成失敗")
        }
        //openSelectorMenuSe
        do {
            openSelectorMenuSe = try AVAudioPlayer(contentsOf: GetSoundPath(file: resourceOpenSelectorMenuSeFile), fileTypeHint:nil)
        } catch {
            print("AVAudioPlayerインスタンス作成失敗")
        }
        //set Volume
        self.volume = UserData.sharedInstance.SoundVolumeSystemSE
    }
    
    func shuffleSePlay(){
        shuffleSes[shuffleSeCount].play()
        shuffleSeCount += 1
        shuffleSeCount = shuffleSeCount % 10
    }
    func drumRollSeLoop(){
        guard let se = drumRollSe else { return }
        se.numberOfLoops = -1
        se.play()
    }
    func drumRollSeStop(){
        guard let se = drumRollSe else { return }
        se.numberOfLoops = 0
    }
    func rankSePlay(){
        guard let se = rankSe else { return }
        if se.isPlaying { se.currentTime = 0 }
        se.play()
    }
    func goSePlay(){
        guard let se = goSe else { return }
        if se.isPlaying { se.currentTime = 0 }
        se.play()
    }
    func canselSePlay(){
        guard let se = canselSe else { return }
        if se.isPlaying { se.currentTime = 0 }
        se.play()
    }
    func cansel2SePlay(){
        guard let se = cansel2Se else { return }
        if se.isPlaying { se.currentTime = 0 }
        se.play()
    }
    func startSePlay(){
        guard let se = startSe else { return }
        if se.isPlaying { se.currentTime = 0 }
        se.play()
    }
    func start2SePlay(){
        guard let se = start2Se else { return }
        if se.isPlaying { se.currentTime = 0 }
        se.play()
    }
    func gameMenuSePlay(){
        guard let se = gameMenuSe else { return }
        if se.isPlaying { se.currentTime = 0 }
        se.play()
    }
    func openSePlay(){
        guard let se = openSe else { return }
        if se.isPlaying { se.currentTime = 0 }
        se.play()
    }
    func openSubSePlay(){
        guard let se = openSubSe else { return }
        if se.isPlaying { se.currentTime = 0 }
        se.play()
    }
    func openSelectorMenuSePlay(){
        guard let se = openSelectorMenuSe else { return }
        if se.isPlaying { se.currentTime = 0 }
        se.play()
    }
    
    private func GetSoundPath(file:String) -> URL {
        let soundFilePath = Bundle.main.path(forResource: (file as NSString).deletingPathExtension,
                                             ofType: (file as NSString).pathExtension)!
        return URL(fileURLWithPath: soundFilePath)
    }
}
