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

    
    private var loadedGameSE = false
    
    func loadGameSE(){
        if loadedGameSE{
            return
        }
        loadedGameSE = true
        print("loadGameSE")
        
        //okJingles
        var soundFilePath = Bundle.main.path(forResource: (resourceOkJingleFile as NSString).deletingPathExtension,
                                             ofType: (resourceOkJingleFile as NSString).pathExtension)!
        var sound:URL = URL(fileURLWithPath: soundFilePath)
        // AVAudioPlayerのインスタンスを作成
        for _ in (0..<10){
            do {
                let audio = try AVAudioPlayer(contentsOf: sound, fileTypeHint:nil)
                audio.volume = 10.0
                okJingles.append(audio)

            } catch {
                print("AVAudioPlayerインスタンス作成失敗")
            }
            
        }
        //safeJingles
        soundFilePath = Bundle.main.path(forResource: (resourceSafeJingleFile as NSString).deletingPathExtension,
                                             ofType: (resourceSafeJingleFile as NSString).pathExtension)!
        sound = URL(fileURLWithPath: soundFilePath)
        // AVAudioPlayerのインスタンスを作成
        for _ in (0..<10){
            do {
                let audio = try AVAudioPlayer(contentsOf: sound, fileTypeHint:nil)
                audio.volume = 10.0
                safeJingles.append(audio)
                
            } catch {
                print("AVAudioPlayerインスタンス作成失敗")
            }
            
        }
        //badJingles
        soundFilePath = Bundle.main.path(forResource: (resourceBadJingleFile as NSString).deletingPathExtension,
                                             ofType: (resourceBadJingleFile as NSString).pathExtension)!
        sound = URL(fileURLWithPath: soundFilePath)
        // AVAudioPlayerのインスタンスを作成
        for _ in (0..<10){
            do {
                let audio = try AVAudioPlayer(contentsOf: sound, fileTypeHint:nil)
                audio.volume = 5.0
                badJingles.append(audio)
                
            } catch {
                print("AVAudioPlayerインスタンス作成失敗")
            }
            
        }

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

}
