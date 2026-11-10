import UIKit

/// Exchanges text with the user's AI. This screen never calls an AI service.
final class ExternalAIChartViewController: UIViewController, UITextViewDelegate, UIGestureRecognizerDelegate {
    private let snapshot: () -> ExternalAIChartExchange.Snapshot
    private let evaluate: (Set<Int>) -> Int
    private let apply: (Set<Int>, Int) -> Void
    private let storageKey: String
    private var answerStorageKey: String { storageKey + ".answer" }
    private var targetStorageKey: String { storageKey + ".target" }

    private static func requestStorageKey(for sourceID: String) -> String {
        "ExternalAIChart.request.v6." + Data(sourceID.utf8).base64EncodedString()
    }

    /// 投稿済みの譜面は、再編集時に改めてAIへ依頼する。
    static func removeSavedData(sourceID: String) {
        let key = requestStorageKey(for: sourceID)
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: key + ".answer")
        UserDefaults.standard.removeObject(forKey: key + ".target")
    }

    /// Capture the answer before registration so later edits cannot change the copy.
    static func savedAnswerData(sourceID: String, defaults: UserDefaults = .standard) -> Data? {
        let key = requestStorageKey(for: sourceID) + ".answer"
        guard let data = defaults.data(forKey: key),
              data.count <= ExternalAIChartExchange.maximumBytes * 2 + 1024,
              let saved = try? JSONDecoder().decode(SavedAnswer.self, from: data),
              !saved.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              saved.text.utf8.count <= ExternalAIChartExchange.maximumBytes else { return nil }
        // Re-encode only the text, including when migrating an older saved answer.
        return try? ExternalAIChartExchange.encoded(saved)
    }

    /// Store a separate copy without overwriting an answer already saved at the destination.
    @discardableResult
    static func saveCopiedAnswer(_ data: Data, sourceID: String,
                                 defaults: UserDefaults = .standard) -> Bool {
        let key = requestStorageKey(for: sourceID) + ".answer"
        guard defaults.object(forKey: key) == nil,
              data.count <= ExternalAIChartExchange.maximumBytes * 2 + 1024,
              let saved = try? JSONDecoder().decode(SavedAnswer.self, from: data),
              !saved.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              saved.text.utf8.count <= ExternalAIChartExchange.maximumBytes,
              let copy = try? ExternalAIChartExchange.encoded(saved) else { return false }
        defaults.set(copy, forKey: key)
        return true
    }

    private struct LegacyTarget: Decodable {
        let targetLevel: Int
    }

    private struct SavedAnswer: Codable {
        let text: String
    }

    private var isAdjusting = false
    private let targetStepper = UIStepper()
    private let targetLabel = UILabel()
    private let statusLabel = UILabel()
    private let scroll = UIScrollView()
    private var previousScrollSize = CGSize.zero
    private let answerView = UITextView()
    private let answerPlaceholder = UILabel()

    init(sourceID: String,
         snapshot: @escaping () -> ExternalAIChartExchange.Snapshot,
         evaluate: @escaping (Set<Int>) -> Int,
         apply: @escaping (Set<Int>, Int) -> Void) {
        self.snapshot = snapshot
        self.evaluate = evaluate
        self.apply = apply
        self.storageKey = Self.requestStorageKey(for: sourceID)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "AIでフリックノーツ選択を補助"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "閉じる", style: .done, target: self, action: #selector(close))
        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        dismissTap.cancelsTouchesInView = false
        dismissTap.delegate = self
        view.addGestureRecognizer(dismissTap)
        scroll.keyboardDismissMode = .onDrag
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32)
        ])
        stack.addArrangedSubview(instructionRow("①", text: "依頼文をコピーし、普段お使いのAIアプリなどに貼り付けて依頼してください。"))
        stack.addArrangedSubview(instructionRow("②", text: "AIの回答が完成したら、全文をコピーして下の欄へ貼り付けてください。"))
        stack.addArrangedSubview(instructionRow("③", text: "目標の難易度Lvを選び、生成したフリックノーツを確認・適用してください。"))
        targetStepper.minimumValue = 1
        targetStepper.maximumValue = 20
        targetStepper.value = 5
        targetStepper.accessibilityLabel = "目標難易度Lv"
        targetStepper.accessibilityIdentifier = "externalAI.target"
        targetStepper.addTarget(self, action: #selector(targetChanged), for: .valueChanged)
        // Migrate only the UI preference; old request snapshots are no longer needed.
        if UserDefaults.standard.object(forKey: targetStorageKey) == nil,
           let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(LegacyTarget.self, from: data),
           (1...20).contains(saved.targetLevel) {
            UserDefaults.standard.set(saved.targetLevel, forKey: targetStorageKey)
        }
        UserDefaults.standard.removeObject(forKey: storageKey)
        let savedTarget = UserDefaults.standard.integer(forKey: targetStorageKey)
        if (1...20).contains(savedTarget) {
            targetStepper.value = Double(savedTarget)
        }
        configureLabel(targetLabel)
        targetLabel.font = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(
            for: .systemFont(ofSize: 34, weight: .bold))
        targetLabel.textColor = .systemBlue
        targetStepper.tintColor = .systemBlue
        targetStepper.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
        targetStepper.layer.cornerRadius = 8
        targetStepper.setContentHuggingPriority(.required, for: .horizontal)
        targetStepper.setContentCompressionResistancePriority(.required, for: .horizontal)
        let targetRow = UIStackView(arrangedSubviews: [targetLabel, targetStepper])
        targetRow.axis = .horizontal
        targetRow.spacing = 16
        targetRow.alignment = .center

        let targetHeading = label("目標の難易度")
        targetHeading.font = .preferredFont(forTextStyle: .headline)
        let targetCard = UIStackView(arrangedSubviews: [targetHeading, targetRow])
        targetCard.axis = .vertical
        targetCard.spacing = 12
        targetCard.isLayoutMarginsRelativeArrangement = true
        targetCard.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        targetCard.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.08)
        targetCard.layer.cornerRadius = 12
        targetChanged()
        let copyButton = button("依頼文をコピー", action: #selector(copyPrompt), id: "externalAI.copy")
        copyButton.configuration?.image = UIImage(systemName: "doc.on.doc")
        copyButton.configuration?.imagePlacement = .trailing
        copyButton.configuration?.imagePadding = 8
        let shareButton = button("", action: #selector(sharePrompt(_:)), id: "externalAI.share")
        shareButton.configuration?.image = UIImage(systemName: "square.and.arrow.up")
        shareButton.accessibilityLabel = "依頼文を共有"
        shareButton.widthAnchor.constraint(equalToConstant: 48).isActive = true
        let requestRow = UIStackView(arrangedSubviews: [copyButton, shareButton])
        requestRow.spacing = 8
        requestRow.alignment = .fill
        stack.addArrangedSubview(requestRow)
        configureLabel(statusLabel)
        statusLabel.isHidden = true
        statusLabel.accessibilityIdentifier = "externalAI.status"
        statusLabel.textColor = UIColor(red: 0.75, green: 0.34, blue: 0.34, alpha: 1.0)
        stack.addArrangedSubview(statusLabel)
        let requestNote = label("依頼文には編集中の歌詞と時刻が含まれます。AIへ渡す際は、文字数制限で途中までになっていないか確認してください。\n\nAIの回答は少しずつ表示されることがあります。コピーボタンが表示されていても、回答が最後まで出たことを確認してから、全文をコピーしてください。")
        requestNote.textColor = .gray
        stack.addArrangedSubview(requestNote)
        stack.addArrangedSubview(label("AIの回答"))
        answerView.delegate = self
        if let data = UserDefaults.standard.data(forKey: answerStorageKey),
           data.count <= ExternalAIChartExchange.maximumBytes * 2 + 1024,
           let saved = try? JSONDecoder().decode(SavedAnswer.self, from: data),
           saved.text.utf8.count <= ExternalAIChartExchange.maximumBytes {
            answerView.text = saved.text
            // Decoding ignores the legacy requestID; rewrite without it.
            if let migrated = try? ExternalAIChartExchange.encoded(saved) {
                UserDefaults.standard.set(migrated, forKey: answerStorageKey)
            }
        }
        answerView.font = .preferredFont(forTextStyle: .body)
        answerView.adjustsFontForContentSizeCategory = true
        answerView.backgroundColor = .secondarySystemBackground
        answerView.layer.cornerRadius = 8
        answerView.autocorrectionType = .no
        answerView.smartQuotesType = .no
        answerView.smartDashesType = .no
        answerView.accessibilityLabel = "AIの回答"
        answerView.accessibilityIdentifier = "externalAI.answer"
        answerView.heightAnchor.constraint(equalToConstant: 180).isActive = true
        stack.addArrangedSubview(answerView)
        answerPlaceholder.text = "AIからの回答テキストを全文貼り付けてください"
        configureLabel(answerPlaceholder)
        answerPlaceholder.textColor = .placeholderText
        answerPlaceholder.isUserInteractionEnabled = false
        answerPlaceholder.isAccessibilityElement = false
        answerPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        answerView.addSubview(answerPlaceholder)
        NSLayoutConstraint.activate([
            answerPlaceholder.leadingAnchor.constraint(equalTo: answerView.frameLayoutGuide.leadingAnchor, constant: 5),
            answerPlaceholder.trailingAnchor.constraint(equalTo: answerView.frameLayoutGuide.trailingAnchor, constant: -5),
            answerPlaceholder.topAnchor.constraint(equalTo: answerView.frameLayoutGuide.topAnchor, constant: 8)
        ])
        updateAnswerPlaceholder()
        stack.addArrangedSubview(targetCard)
        stack.addArrangedSubview(button("生成・確認", action: #selector(checkAnswer), id: "externalAI.check"))
        let regenerationNote = label("同じ回答で目標難易度Lvを何度でも変えて再生成できます。適用すると現在のフリックノーツ選択を上書きします。歌詞と時刻は変わらず、Undoで戻せます。")
        regenerationNote.textColor = .gray
        stack.addArrangedSubview(regenerationNote)

        let difficultyNote = label("目標Lv7以上では、単語の途中の文字も選ぶ必要が増えるため、不自然な位置が選ばれやすくなります。高難易度ほど手直しが必要になる場合があります。")
        difficultyNote.textColor = UIColor(red: 0.75, green: 0.34, blue: 0.34, alpha: 1.0)
        stack.addArrangedSubview(difficultyNote)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // キーボードで表示領域が縮んだら、回答欄を見える位置へ移動する。
        let size = scroll.bounds.size
        guard size != previousScrollSize else { return }
        previousScrollSize = size
        if answerView.isFirstResponder {
            revealAnswerView()
        }
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        revealAnswerView()
    }

    private func revealAnswerView() {
        let rect = answerView.convert(answerView.bounds, to: scroll)
        scroll.scrollRectToVisible(rect.insetBy(dx: 0, dy: -8), animated: false)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // 回答欄内のカーソル移動・選択・貼り付け操作を妨げない。
        guard let touchedView = touch.view else { return false }
        return !touchedView.isDescendant(of: answerView)
    }

    private func instructionRow(_ number: String, text: String) -> UIView {
        let marker = label(number)
        marker.setContentHuggingPriority(.required, for: .horizontal)
        marker.setContentCompressionResistancePriority(.required, for: .horizontal)
        let textLabel = label(text)
        let row = UIStackView(arrangedSubviews: [marker, textLabel])
        row.axis = .horizontal
        row.alignment = .top
        row.spacing = 8
        return row
    }

    private func setStatus(_ text: String) {
        statusLabel.text = text
        statusLabel.isHidden = text.isEmpty
    }

    private func updateAnswerPlaceholder() {
        answerPlaceholder.isHidden = !(answerView.text ?? "").isEmpty
    }

    func textViewDidChange(_ textView: UITextView) {
        updateAnswerPlaceholder()
        saveAnswer()
    }

    private func saveAnswer() {
        let text = answerView.text ?? ""
        guard text.utf8.count <= ExternalAIChartExchange.maximumBytes,
              let data = try? ExternalAIChartExchange.encoded(
                SavedAnswer(text: text)) else {
            UserDefaults.standard.removeObject(forKey: answerStorageKey)
            return
        }
        UserDefaults.standard.set(data, forKey: answerStorageKey)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        saveAnswer()
    }

    private func configureLabel(_ label: UILabel) {
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
    }

    private func label(_ text: String) -> UILabel {
        let result = UILabel()
        configureLabel(result)
        result.text = text
        return result
    }

    private func button(_ title: String, action: ObjectiveC.Selector, id: String) -> UIButton {
        let result = UIButton(type: .system)
        var configuration = UIButton.Configuration.tinted()
        configuration.title = title
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        result.configuration = configuration
        result.accessibilityIdentifier = id
        result.addTarget(self, action: action, for: .touchUpInside)
        return result
    }

    @objc private func close() {
        guard !isAdjusting else { return }
        dismiss(animated: true)
    }

    @objc private func targetChanged() {
        targetLabel.text = "Lv \(Int(targetStepper.value))"
        targetStepper.accessibilityValue = String(Int(targetStepper.value))
        UserDefaults.standard.set(Int(targetStepper.value), forKey: targetStorageKey)
    }

    private func preparePrompt() throws -> String {
        try ExternalAIChartExchange.prompt(for: snapshot())
    }

    @objc private func copyPrompt() {
        do {
            UIPasteboard.general.string = try preparePrompt()
            setStatus("依頼文をコピーしました。お使いのAIアプリなどに貼り付けてください。")
        } catch { show(error) }
    }

    @objc private func sharePrompt(_ sender: UIButton) {
        do {
            let prompt = try preparePrompt()
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("NicoFlick-AI-" + UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("NicoFlick-AI-request.txt")
            try prompt.write(to: url, atomically: true, encoding: .utf8)
            let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            sheet.popoverPresentationController?.sourceView = sender
            sheet.popoverPresentationController?.sourceRect = sender.bounds
            sheet.completionWithItemsHandler = { _, _, _, _ in
                try? FileManager.default.removeItem(at: directory)
            }
            present(sheet, animated: true)
            setStatus("依頼文の共有画面を開きました。対応するAIアプリを選んで渡してください。")
        } catch { show(error) }
    }

    @objc private func checkAnswer() {
        guard !isAdjusting else { return }
        view.endEditing(true)
        let text = answerView.text ?? ""
        saveAnswer()
        let target = Int(targetStepper.value)
        let logID = UUID().uuidString
        #if DEBUG
        logChartCheck(logID, section: "answer", text: text)
        if let prompt = try? ExternalAIChartExchange.prompt(for: snapshot()) {
            logChartCheck(logID, section: "requestPromptCurrentRules", text: prompt)
        }
        #endif
        Task { @MainActor [self] in
            isAdjusting = true
            view.isUserInteractionEnabled = false
            isModalInPresentation = true
            defer {
                isAdjusting = false
                view.isUserInteractionEnabled = true
                isModalInPresentation = false
            }
            do {
                let current = snapshot()
                let imported = try ExternalAIChartExchange.importPhrases(from: text, current: current)
                let phrases = imported.phrases
                if !imported.supplementedIDs.isEmpty {
                    logChartCheck(logID, section: "supplementedNoteIds", text: "\(imported.supplementedIDs)")
                }
                if !imported.ignoredIDs.isEmpty {
                    logChartCheck(logID, section: "ignoredNoteIds", text: "\(imported.ignoredIDs)")
                }
                guard !phrases.isEmpty else { throw ExternalAIChartExchange.Failure.invalidSelection }
                let result = await ExternalAIChartExchange.adjust(phrases: phrases, snapshot: current, targetLevel: target, evaluate: evaluate)
                guard try ExternalAIChartExchange.revision(of: current) == ExternalAIChartExchange.revision(of: snapshot()) else {
                    throw ExternalAIChartExchange.Failure.staleSource
                }
                let selected = result.selected
                let actual = result.level
                logChartCheck(logID, section: "result",
                              text: "target=\(target), calcLv=\(actual), notes=\(selected.count), phrases=\(phrases.count), spacingMs=\(result.spacingMs)")
                logChartCheck(logID, section: "adjustedNoteIds", text: "\(selected.sorted())")
                let ignoredNotice: String
                if imported.ignoredIDs.isEmpty {
                    ignoredNotice = ""
                } else {
                    let shown = imported.ignoredIDs.prefix(20).map { String($0) }.joined(separator: ", ")
                    let suffix = imported.ignoredIDs.count > 20 ? " ほか（全\(imported.ignoredIDs.count)個）" : ""
                    ignoredNotice = "\n対象外のため除外したID: \(shown)\(suffix)\n"
                }
                let repairNotice = imported.supplementedIDs.isEmpty
                    ? ""
                    : "\nAI回答の語句内で抜けていた文字を\(imported.supplementedIDs.count)文字補完しました。\n"
                let message = """
                今回の目標: 難易度Lv \(target)
                アプリでの計算: 難易度Lv \(actual)

                語句のまとまり: \(phrases.count)個
                調整後ノーツ: \(selected.count)個
                \(repairNotice)

                【適用後に必ず確認してください】
                曲を最後までテストプレイし、不自然なノーツや打ちにくい箇所をご自身で調整してください。高難易度ほど手直しが必要になる場合があります。
                """
                let alert = UIAlertController(title: "生成結果の確認", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
                alert.addAction(UIAlertAction(title: "適用する :Lv\(actual)", style: .default) { [weak self] _ in
                    guard let self = self else { return }
                    do {
                        _ = try ExternalAIChartExchange.phrases(from: text, current: self.snapshot())
                        self.apply(selected, target)
                        self.dismiss(animated: true)
                    } catch { self.show(error) }
                })
                present(alert, animated: true)
            } catch {
                logChartCheck(logID, section: "error", text: error.localizedDescription)
                show(error)
            }
        }
    }

    /// One JSON record per line, split into small chunks for console retrieval.
    /// All records for a button press share an event ID; release builds output nothing.
    private func logChartCheck(_ eventID: String, section: String, text: String) {
        #if DEBUG
        var remaining = text[...]
        var part = 0
        repeat {
            let chunk = remaining.prefix(1000)
            remaining = remaining.dropFirst(chunk.count)
            let record: [String: String] = [
                "event": eventID, "section": section, "part": String(part),
                "last": String(remaining.isEmpty), "text": String(chunk)
            ]
            if let data = try? ExternalAIChartExchange.encoded(record) {
                print("[AIChartCheck] " + String(decoding: data, as: UTF8.self))
            }
            part += 1
        } while !remaining.isEmpty
        #endif
    }


    private func show(_ error: Error) {
        let alert = UIAlertController(title: "取り込みの確認", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
