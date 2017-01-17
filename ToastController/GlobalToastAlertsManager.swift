import Foundation
import UIKit
import ReactiveSwift
import Result
import Logger

enum ToastRemoveType {
    case fromTimer, fromPanGesture, fromTapGesture
}

public class GlobalToastAlertsManager {
    
    var toastsWindow: AlertWindow?
    fileprivate var toastAlertsViewController: ToastAlertViewController?
    fileprivate var toastAlertsModels: [ToastAlert]
    
    fileprivate var removeAlertSignal: Signal<ToastRemoveType, NoError>
    fileprivate var removeAlertObserver: Observer<ToastRemoveType, NoError>
    fileprivate var removeAlertDisposable: Disposable?
    
    fileprivate let applicationRootWindow: UIWindow
    fileprivate let navigationBarHeight: CGFloat
	
	var toastDidPress:((_ toast: ToastAlert)->Void)?
	
    fileprivate var dismissing: Bool {
        didSet {
            if dismissing == false && !dismissingCache.isEmpty {
                dismissingCache.forEach(addToastAlert)
                dismissingCache.removeAll()
            }
        }
    }
    fileprivate var dismissingCache: [ToastAlert]
    
    public init(applicationRootWindow: UIWindow, navigationBarHeight: CGFloat) {
        self.applicationRootWindow = applicationRootWindow
        self.navigationBarHeight = navigationBarHeight
        toastsWindow = nil
        toastAlertsViewController = nil
        toastAlertsModels = []
        (removeAlertSignal, removeAlertObserver) = Signal.pipe()
        
        dismissingCache = []
        dismissing = false
    }
    
    fileprivate func subscribeToRemoveAlertsSignal() {
        removeAlertDisposable = removeAlertSignal.observeValues { [unowned self] removeType in
			
			// Como controlarias este caso? Si siempre se elimina la primera
			if self.toastDidPress != nil && removeType == .fromTapGesture
			{
				self.toastDidPress!(self.toastAlertsModels.first!)
			}
			
			self.toastAlertsModels.removeFirst()
            
            if self.toastAlertsModels.isEmpty {
                self.removeToastAlertWindowAndViewController()
            } else {
                switch removeType {
                case .fromTimer: self.toastAlertsViewController!.removeCurrentToastViewFromTimerAndPresentNext(self.toastAlertsModels.first!)
                case .fromPanGesture: self.toastAlertsViewController!.removeCurrentToastViewFromPanGestureAndPresentNext(self.toastAlertsModels.first!)
				case .fromTapGesture: self.toastAlertsViewController!.removeCurrentToastViewFromPanGestureAndPresentNext(self.toastAlertsModels.first!)
                }
            }
        }
    }
    
    public func addToastAlert(_ newToastAlert: ToastAlert) {
        
        if dismissing {
            dismissingCache.append(newToastAlert)
            return
        }
        
        logInfo("Adding toast alert of level \"\(newToastAlert.level)\": \(newToastAlert.message)")

        toastAlertsModels.append(newToastAlert)
        
        if toastAlertsModels.count == 1 {
            presentWindowAndViewController(newToastAlert)
        }
    }
    
    fileprivate func presentWindowAndViewController(_ toastAlertModel: ToastAlert) {
        toastsWindow = AlertWindow()
        toastsWindow?.backgroundColor = .clear
        toastsWindow!.clipsToBounds = false
        toastsWindow!.layer.cornerRadius = 3.0
        subscribeToRemoveAlertsSignal()
        
        toastAlertsViewController = ToastAlertViewController(toastsWindow: self.toastsWindow!, firstToastAlertModel: toastAlertModel, removeAlertObserver: removeAlertObserver, navigationBarHeight: navigationBarHeight)
        toastsWindow!.presentAlertViewController(toastAlertsViewController!, windowLevel: UIWindowLevelAlert + 1, animated: false)
        self.applicationRootWindow.makeKeyAndVisible()
    }
    
    fileprivate func removeToastAlertWindowAndViewController() {
        dismissing = true
        removeAlertDisposable?.dispose()
        toastAlertsViewController?.dismiss(animated: false, completion: {
            self.toastsWindow?.rootViewController = nil
            self.toastAlertsViewController = nil
            self.toastsWindow?.removeFromSuperview()
            self.toastsWindow?.isHidden = true
            self.toastsWindow = nil
            self.applicationRootWindow.makeKeyAndVisible()
            self.dismissing = false
        })
    }
}

class AlertWindow: UIWindow {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if let alertVC = rootViewController?.presentedViewController as? ToastAlertViewController, let currentToastView = alertVC.currentToastView , !currentToastView.isHidden && currentToastView.alpha > 0 && currentToastView.isUserInteractionEnabled && currentToastView.point(inside: convert(point, to: currentToastView), with: event) {
            return true
        }
        return false
    }
    
    deinit {
        print("[DEINIT] Alert Window")
    }
}

public func += (left: GlobalToastAlertsManager, right: ToastAlert) {
    left.addToastAlert(right)
}

extension UIWindow {
    func presentAlertViewController(_ viewController: UIViewController, windowLevel: UIWindowLevel, animated: Bool, completion: (()->())? = nil) {
        self.windowLevel = windowLevel
        let rootViewController = UIViewController()
        self.rootViewController = rootViewController
        makeKeyAndVisible()
        rootViewController.present(viewController, animated: animated, completion: completion)
    }
}
