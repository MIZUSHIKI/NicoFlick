import UIKit

final class NoAnimationSegue: UIStoryboardSegue {
    override func perform() {
        source.present(destination, animated: false)
    }
}
