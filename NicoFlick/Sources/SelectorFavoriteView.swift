//
//  Untitled.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2026/09/21.
//  Copyright © 2026 i.MIZUSHIKI. All rights reserved.
//

import UIKit

class SelectorFavoriteView: UIViewController {
    
    //保存データ
    let userData = UserData.sharedInstance

    //遷移時に受け取り
    var selectorController:Selector!
    
    var selectMusics:[musicData]?
    var selectMusic:musicData?
    
    var mae_favorite:Bool = false
    var now_favorite:Bool = false
    var mae_musicSortCondition:Bool = false
    var now_musicSortCondition:Bool = false
    
    @IBOutlet weak var colorMusicStar: UIImageView!
    @IBOutlet weak var Switch_sortFavoritesFirst: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // 取得 : selectMusic
        if selectorController.currentMusics.count > 0 {
            selectMusics = selectorController.currentMusics
        }
        if let musics = selectMusics {
            if selectorController.indexCarousel >= 0 && musics.count > selectorController.indexCarousel{
                selectMusic = musics[selectorController.indexCarousel]
            }
        }
        
        // 各変数格納, UI処理
        if let music = selectMusic {
            mae_favorite = userData.MyFavorite3.contains(music.sqlID)
            mae_musicSortCondition = (userData.musicSortCondition != 0)
            now_favorite = mae_favorite
            now_musicSortCondition = mae_musicSortCondition
            
            update_favoriteIcon()
            Switch_sortFavoritesFirst.isOn = now_musicSortCondition
        }
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    //UIアクション処理_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    @IBAction func favoriteButton(_ sender: Any) {
        now_favorite = !now_favorite
        self.update_favoriteIcon()
    }
    func update_favoriteIcon(){
        colorMusicStar.isHidden = !now_favorite
    }
    
    @IBAction func sortFavoritesFirst(_ sender: UISwitch) {
        now_musicSortCondition = sender.isOn
    }
    
    
    //画面遷移処理_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
    var onDismiss: ((Bool) -> Void)?
    
    @IBAction func dismissFavorite(_ sender: UIButton) {
        var changed = false
        if now_favorite != mae_favorite {
            changed = true
            if let music = selectMusic {
                if now_favorite {
                    userData.MyFavorite3.insert(music.sqlID)
                    userData.MusicFavoriteCount.addMusicFavoriteCount(sqlID: music.sqlID)  // あとでデータベースに送信するフラグ兼カウンター
                }else {
                    userData.MyFavorite3.remove(music.sqlID)
                    userData.MusicFavoriteCount.subMusicFavoriteCount(sqlID: music.sqlID)  // あとでデータベースに送信するフラグ兼カウンター
                }
            }
        }
        if now_musicSortCondition != mae_musicSortCondition {
            changed = true
            userData.musicSortCondition = now_musicSortCondition ? 1 : 0
        }
        onDismiss?(changed)
        dismiss(animated: false)
    }
}
