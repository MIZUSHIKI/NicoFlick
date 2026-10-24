//
//  EditorSettings.swift
//  NicoFlick
//
//  Created by MIZUSHIKI on 2026/09/30.
//  Copyright © 2026年 i.MIZUSHIKI. All rights reserved.
//

import UIKit

class EditorSettings: UIViewController {
    
    @IBOutlet weak var timetagOffsetMs: UITextField!
    @IBOutlet weak var timetagRateFactor: UITextField!
    @IBOutlet weak var playingNoteSelectionOffsetMs: UITextField!
    
    //遷移時受け取り
    var editorViewController:EditorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        timetagOffsetMs.text = String(editorViewController.timetagOffsetMs)
        timetagRateFactor.text = String(editorViewController.timetagRateFactor)
        playingNoteSelectionOffsetMs.text = String(editorViewController.playingNoteSelectionOffsetMs)
        
        let backgroundTap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        backgroundTap.cancelsTouchesInView = false
        view.addGestureRecognizer(backgroundTap)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame),
            name: NSNotification.Name.UIKeyboardWillChangeFrame,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: NSNotification.Name.UIKeyboardWillHide,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // 遷移前に代入
        let offsetMs = Int(timetagOffsetMs.text ?? "") ?? -115
        let rateFactor = Double(timetagRateFactor.text ?? "") ?? 0.07
        editorViewController.timetagOffsetMs = offsetMs
        editorViewController.timetagRateFactor = rateFactor
        UserData.sharedInstance.timetagOffsetMs = offsetMs
        UserData.sharedInstance.timetagRateFactor = rateFactor
        
        let noteSelectionOffsetMs = Int(playingNoteSelectionOffsetMs.text ?? "") ?? 50
        editorViewController.playingNoteSelectionOffsetMs = noteSelectionOffsetMs
        UserData.sharedInstance.playingNoteSelectionOffsetMs = noteSelectionOffsetMs
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let activeTextField = [timetagOffsetMs, timetagRateFactor, playingNoteSelectionOffsetMs]
            .compactMap({ $0 })
            .first(where: { $0.isFirstResponder }),
              let keyboardFrame = notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        
        let keyboardFrameInView = view.convert(keyboardFrame, from: nil)
        let bottomPadding: CGFloat = 20
        let overlap = activeTextField.frame.maxY + bottomPadding - keyboardFrameInView.minY
        animateViewTranslation(y: -max(0, overlap), notification: notification)
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        animateViewTranslation(y: 0, notification: notification)
    }
    
    private func animateViewTranslation(y: CGFloat, notification: Notification) {
        let duration = notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        UIView.animate(withDuration: duration) {
            self.view.transform = CGAffineTransform(translationX: 0, y: y)
        }
    }
}
