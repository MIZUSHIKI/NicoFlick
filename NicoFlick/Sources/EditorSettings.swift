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
    
    private let aiAssistSwitch = UISwitch()
    private let aiAssistRow = UIStackView()
    private let betaSectionTitle = UILabel()

    //遷移時受け取り
    var editorViewController:EditorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        for notificationName in [NSNotification.Name.UIKeyboardDidShow,
                                 .UIKeyboardDidChangeFrame, .UIKeyboardDidHide] {
            NotificationCenter.default.addObserver(
                self, selector: #selector(restoreMovieAfterKeyboardChange),
                name: notificationName, object: nil
            )
        }
        betaSectionTitle.text = "β機能"
        betaSectionTitle.font = .preferredFont(forTextStyle: .headline)
        betaSectionTitle.adjustsFontForContentSizeCategory = true
        betaSectionTitle.textAlignment = .center
        betaSectionTitle.numberOfLines = 0
        betaSectionTitle.accessibilityTraits = UIAccessibilityTraitHeader
        view.addSubview(betaSectionTitle)
        let aiAssistLabel = UILabel()
        aiAssistLabel.text = "AI補助ボタンを表示"
        aiAssistLabel.font = .preferredFont(forTextStyle: .body)
        aiAssistLabel.adjustsFontForContentSizeCategory = true
        aiAssistLabel.numberOfLines = 0
        aiAssistSwitch.isOn = editorViewController.showsAIAssist
        aiAssistSwitch.accessibilityLabel = "AI補助ボタンを表示"
        aiAssistSwitch.accessibilityIdentifier = "editorSettings.showAIAssist"
        aiAssistSwitch.addTarget(self, action: #selector(aiAssistVisibilityChanged), for: .valueChanged)
        aiAssistRow.axis = .horizontal
        aiAssistRow.alignment = .center
        aiAssistRow.spacing = 12
        aiAssistRow.addArrangedSubview(aiAssistLabel)
        aiAssistRow.addArrangedSubview(aiAssistSwitch)
        view.addSubview(aiAssistRow)
        
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
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let fieldFrame = playingNoteSelectionOffsetMs.convert(playingNoteSelectionOffsetMs.bounds, to: view)
        let width = max(0, view.bounds.width - view.safeAreaInsets.left - view.safeAreaInsets.right - 32)
        let size = aiAssistRow.systemLayoutSizeFitting(
            CGSize(width: width, height: UILayoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        let titleHeight = betaSectionTitle.sizeThatFits(
            CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)).height
        betaSectionTitle.frame = CGRect(x: view.safeAreaInsets.left + 16, y: fieldFrame.maxY + 48,
                                        width: width, height: titleHeight)
        aiAssistRow.frame = CGRect(x: view.safeAreaInsets.left + 16, y: betaSectionTitle.frame.maxY + 20,
                                  width: width, height: max(44, size.height))
    }

    @objc private func aiAssistVisibilityChanged() {
        editorViewController.showsAIAssist = aiAssistSwitch.isOn
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func restoreMovieAfterKeyboardChange() {
        guard isViewLoaded, view.window != nil, presentedViewController == nil else { return }
        DispatchQueue.main.async { [weak self] in
            self?.editorViewController.restoreMovieLayout()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        editorViewController.restoreMovieLayout()
        transitionCoordinator?.animate(alongsideTransition: nil) { [weak self] _ in
            self?.editorViewController.restoreMovieLayout()
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // メニューが下がり始める前に、キーボードを閉じて動画サイズを即時補正する。
        view.endEditing(true)
        editorViewController.restoreMovieLayout()
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
