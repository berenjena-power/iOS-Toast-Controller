import Foundation
import UIKit

class ToastAlertPresentationController: UIPresentationController {    
    override func presentationTransitionWillBegin() {
        containerView?.addSubview(presentedView!)
    }
}
