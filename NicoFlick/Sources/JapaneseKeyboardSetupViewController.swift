import UIKit

final class FlickOnlyReminderViewController: UIViewController {
    var onDismiss: (() -> Void)?
    private let guideImage: UIImage

    init(guideImage: UIImage) {
        self.guideImage = guideImage
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        let message = UILabel()
        message.text = "同じ文字の連打でSAFEが多いようです。\n設定 ＞ 一般 ＞ キーボード で\n「フリックのみ」がオンか確認してみてください。\n設定済みなら、そのままで大丈夫です。"
        message.textColor = .white
        message.font = .preferredFont(forTextStyle: .body)
        message.adjustsFontForContentSizeCategory = true
        message.numberOfLines = 0

        let imageView = UIImageView(image: guideImage)
        imageView.contentMode = .scaleAspectFit
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        imageView.isAccessibilityElement = true
        imageView.accessibilityLabel = "設定アプリの「一般」→「キーボード」で「フリックのみ」をオンにします。"

        let closeButton = UIButton(type: .system)
        closeButton.setTitle("閉じる", for: .normal)
        closeButton.setTitleColor(UIColor(red: 0.65, green: 0.77, blue: 1.0, alpha: 1.0), for: .normal)
        closeButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        closeButton.titleLabel?.adjustsFontForContentSizeCategory = true
        closeButton.addTarget(self, action: #selector(closeGuide), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [message, imageView, closeButton])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            closeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    @objc private func closeGuide() {
        dismiss(animated: true) { [weak self] in
            self?.onDismiss?()
        }
    }
}


final class JapaneseKeyboardSetupViewController: UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
    var onDismiss: (() -> Void)?
    private var didNotifyDismiss = false
    private let pages: [JapaneseKeyboardGuidePageViewController] = [
        JapaneseKeyboardGuidePageViewController(
            image: UIImage(named: "JapaneseFlickGuide"),
            symbolName: nil,
            titleText: "1. Add the Japanese Kana Keyboard",
            bodyText: "Open Settings and go to:\n\nGeneral → Keyboard → Keyboards\n→ Add New Keyboard\n→ Japanese → Kana",
            noteText: "Look for 日本語 and かな if the Settings app is displayed in another language."
        ),
        JapaneseKeyboardGuidePageViewController(
            image: nil,
            symbolName: "gearshape.fill",
            titleText: "2. Turn On “Flick Only”",
            bodyText: "Go back to:\n\nSettings → General → Keyboard\n\nThen turn on Flick Only.",
            noteText: "Strongly recommended: this disables multi-tap character cycling and makes rhythm-game input more consistent."
        ),
        JapaneseKeyboardGuidePageViewController(
            image: nil,
            symbolName: "globe",
            titleText: "3. Switch Keyboards In-Game",
            bodyText: "When the keyboard appears, touch and hold the 🌐 Globe key, then choose:\n\n日本語かな",
            noteText: "You’re ready to play NicoFlick!\n\nThis concludes the English setup guide. The rest of NicoFlick is available primarily in Japanese."
        )
    ]

    private lazy var pageViewController = UIPageViewController(
        transitionStyle: .scroll,
        navigationOrientation: .horizontal
    )
    private let pageControl = UIPageControl()
    private let closeButton = UIButton(type: .system)
    private let headingLabel = UILabel()
    private var currentPage = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureHeader()
        configureFooter()
        configurePages()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentationController?.delegate = self
    }

    private func configureHeader() {
        headingLabel.translatesAutoresizingMaskIntoConstraints = false
        headingLabel.text = "Japanese Flick Keyboard Setup"
        headingLabel.font = .preferredFont(forTextStyle: .headline)
        headingLabel.adjustsFontForContentSizeCategory = true
        headingLabel.textAlignment = .center

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("Done", for: .normal)
        closeButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        closeButton.addTarget(self, action: #selector(closeGuide), for: .touchUpInside)
        closeButton.accessibilityHint = "Closes the keyboard setup guide"

        view.addSubview(headingLabel)
        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            headingLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            headingLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 56),
            headingLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -56),
            closeButton.centerYAnchor.constraint(equalTo: headingLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func configurePages() {
        addChildViewController(pageViewController)
        pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageViewController.view)
        pageViewController.didMove(toParentViewController: self)
        pageViewController.dataSource = self
        pageViewController.delegate = self
        pageViewController.setViewControllers([pages[0]], direction: .forward, animated: false)

        NSLayoutConstraint.activate([
            pageViewController.view.topAnchor.constraint(equalTo: headingLabel.bottomAnchor, constant: 8),
            pageViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageViewController.view.bottomAnchor.constraint(equalTo: pageControl.topAnchor, constant: -8)
        ])
    }

    private func configureFooter() {
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.numberOfPages = pages.count
        pageControl.currentPage = 0
        pageControl.pageIndicatorTintColor = .systemGray3
        pageControl.currentPageIndicatorTintColor = .systemBlue
        pageControl.addTarget(self, action: #selector(pageControlChanged), for: .valueChanged)
        view.addSubview(pageControl)

        NSLayoutConstraint.activate([
            pageControl.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    @objc private func closeGuide() {
        dismiss(animated: true) { [weak self] in
            self?.notifyDismissIfNeeded()
        }
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        notifyDismissIfNeeded()
    }

    private func notifyDismissIfNeeded() {
        guard !didNotifyDismiss else { return }
        didNotifyDismiss = true
        onDismiss?()
    }

    @objc private func pageControlChanged() {
        let nextPage = pageControl.currentPage
        let direction: UIPageViewController.NavigationDirection = nextPage >= currentPage ? .forward : .reverse
        currentPage = nextPage
        pageViewController.setViewControllers([pages[nextPage]], direction: direction, animated: true)
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard let page = viewController as? JapaneseKeyboardGuidePageViewController,
              let index = pages.firstIndex(where: { $0 === page }),
              index > 0 else {
            return nil
        }
        return pages[index - 1]
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard let page = viewController as? JapaneseKeyboardGuidePageViewController,
              let index = pages.firstIndex(where: { $0 === page }),
              index + 1 < pages.count else {
            return nil
        }
        return pages[index + 1]
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard completed,
              let visiblePage = pageViewController.viewControllers?.first as? JapaneseKeyboardGuidePageViewController,
              let index = pages.firstIndex(where: { $0 === visiblePage }) else {
            return
        }
        currentPage = index
        pageControl.currentPage = index
    }
}

private final class JapaneseKeyboardGuidePageViewController: UIViewController {
    private let image: UIImage?
    private let symbolName: String?
    private let titleText: String
    private let bodyText: String
    private let noteText: String

    init(image: UIImage?, symbolName: String?, titleText: String, bodyText: String, noteText: String) {
        self.image = image
        self.symbolName = symbolName
        self.titleText = titleText
        self.bodyText = bodyText
        self.noteText = noteText
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 16
        if let image = image {
            imageView.image = image
        } else if let symbolName = symbolName {
            let configuration = UIImage.SymbolConfiguration(pointSize: 96, weight: .regular)
            imageView.image = UIImage(systemName: symbolName, withConfiguration: configuration)
        }
        imageView.tintColor = .systemBlue
        imageView.isAccessibilityElement = false

        let titleLabel = makeLabel(text: titleText, style: .title2, weight: .bold)
        let bodyLabel = makeLabel(text: bodyText, style: .body, weight: .regular)
        let noteLabel = makeLabel(text: noteText, style: .footnote, weight: .regular)
        noteLabel.textColor = .secondaryLabel

        let textStack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel, noteLabel])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 16
        textStack.alignment = .fill

        view.addSubview(imageView)
        view.addSubview(textStack)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.76),
            imageView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.42),
            textStack.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
            textStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            textStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -8)
        ])
    }

    private func makeLabel(text: String, style: UIFont.TextStyle, weight: UIFont.Weight) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: style).pointSize, weight: weight)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }
}
