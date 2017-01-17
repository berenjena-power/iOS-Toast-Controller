import Foundation
import UIKit
import Cartography
import ReactiveSwift
import Result
import Logger
import Helpers

class ToastAlertViewController: UIViewController {
    
    let animationDuration: TimeInterval = 0.3
    
    fileprivate var toastsWindow: UIWindow
    
    fileprivate var currentToastAlertModel: ToastAlert
    fileprivate (set) var currentToastView: UIView?
    fileprivate let removeAlertObserver: Observer<ToastRemoveType, NoError>
    
    fileprivate var timer: PausableTimer?
    fileprivate var panGestureRecognizer: UIPanGestureRecognizer!
	fileprivate var tapGestureRecognizer: UITapGestureRecognizer!
    
    fileprivate let navigationBarHeight: CGFloat
    
    init(toastsWindow: UIWindow, firstToastAlertModel: ToastAlert, removeAlertObserver: Observer<ToastRemoveType, NoError>, navigationBarHeight: CGFloat) {
        self.toastsWindow = toastsWindow
        currentToastAlertModel = firstToastAlertModel
        self.removeAlertObserver = removeAlertObserver
        
        self.navigationBarHeight = navigationBarHeight
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var topConstraint: NSLayoutConstraint?
    override func viewDidLoad() {
        super.viewDidLoad()
        
        currentToastView = currentToastAlertModel.buildToastAlertView()
        
        self.placeToastViewInView(currentToastView!)
        
        topConstraint?.constant = -200
		
		self.configureTapGesture()
        self.configurePanGesture()
        self.configureTimer()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.topConstraint?.constant = 60
        UIView.animate(withDuration: animationDuration, delay: 0.0, usingSpringWithDamping: 0.7, initialSpringVelocity: 1, options: .allowUserInteraction, animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
        
    fileprivate func configureTimer() {
        if !currentToastAlertModel.persistent {
            timer = PausableTimer(timerDuration: ToastAlert.toastDuration) { [weak self] _ in
                self?.removeAlertObserver.send(value: .fromTimer)
            }.start()
        }
    }
    
    fileprivate func placeToastViewInView(_ toastView: UIView) {
        view.addSubview(toastView)
        
        let maxWidth: CGFloat = 500
        
        constrain(toastView, self.view) {
            toastView, toastContainerView in
            topConstraint = toastView.top == toastContainerView.top + 60
            (toastView.width == maxWidth) ~ 750
            toastView.leading >= toastContainerView.leading + 20
            toastView.trailing <= toastContainerView.trailing - 20
            toastView.centerX == toastContainerView.centerX
        }
    }
    
    fileprivate func configurePanGesture() {
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(ToastAlertViewController.handlePanGesture(_:)))
        self.currentToastView?.addGestureRecognizer(panGestureRecognizer)
    }
	
	fileprivate func configureTapGesture() {
		tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ToastAlertViewController.handleTapGesture(_:)))
		self.currentToastView?.addGestureRecognizer(tapGestureRecognizer)
	}
	
	
	func handleTapGesture(_ gestureRecognizer: UITapGestureRecognizer)
	{
		self.removeAlertObserver.send(value: .fromTapGesture)
	}
	
    func handlePanGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            timer?.pause()
            fallthrough
            
        case .changed:
            let translation = gestureRecognizer.translation(in: self.view)
            gestureRecognizer.view!.center = CGPoint(x: gestureRecognizer.view!.center.x + translation.x, y: gestureRecognizer.view!.center.y)
            gestureRecognizer.setTranslation(CGPoint(x: 0,y: 0), in: self.view)

        case .ended:
            let distanceFromCenter = gestureRecognizer.view!.center.x - (toastsWindow.bounds.width / 2.0)
            let distanceSign = distanceFromCenter / abs(distanceFromCenter)
            if abs(distanceFromCenter) > 50 {
                let animationDistance = self.view.bounds.width * distanceSign
                let initialSpringVelocity: CGFloat = abs(gestureRecognizer.velocity(in: self.view).x / animationDistance)
                UIView.animate(withDuration: animationDuration, delay: 0.0, usingSpringWithDamping: 1, initialSpringVelocity: initialSpringVelocity, options: .allowUserInteraction, animations: {
                    gestureRecognizer.view?.transform = CGAffineTransform(translationX: animationDistance, y: 0.0)
                }, completion: { [unowned self] completed in
                    self.toastXCoordinate = self.currentToastView?.frame.origin.x ?? 0.0
                    self.removeAlertObserver.send(value: .fromPanGesture)
                })
            } else {
                let animationDistance = abs(distanceFromCenter) * -distanceSign
                UIView.animate(withDuration: 0.2, delay: 0.0, options: .allowUserInteraction, animations: {
                    gestureRecognizer.view?.transform = CGAffineTransform(translationX: animationDistance, y: 0.0)
                }, completion: { [unowned self] _ in
                    self.timer?.resume()
                })
            }
            break
            
        case .cancelled, .failed: self.timer?.resume()
        default: break
        }
    }
    
    fileprivate var toastXCoordinate: CGFloat = 0.0
    override func dismiss(animated flag: Bool, completion: (() -> Void)?) {
        if let currentToastView = currentToastView {
            currentToastView.removeGestureRecognizer(panGestureRecognizer)
            UIView.animate(withDuration: animationDuration, delay: 0.0, options: .allowUserInteraction, animations: {
                currentToastView.transform = CGAffineTransform(translationX: currentToastView.frame.origin.x, y: 3.0 * -currentToastView.bounds.height)
            }, completion: { _ in
                super.dismiss(animated: flag, completion: completion)
            })
        } else {
            super.dismiss(animated: flag, completion: completion)
        }
    }
    
    
    // MARK: - Toast views remove and present next methods
    
    func removeCurrentToastViewFromTimerAndPresentNext(_ nextToastAlertModel: ToastAlert) {
        
        guard let currentToastView = currentToastView else {
            logError("There's no current toast view to remove.")
            return
        }
        
        timer?.stop()
        
        let nextToastView = nextToastAlertModel.buildToastAlertView()
        placeToastViewInView(nextToastView)
        nextToastView.alpha = 0.0
        
        UIView.animate(withDuration: animationDuration, delay: 0.0, options: .allowUserInteraction, animations: {
            currentToastView.transform = CGAffineTransform(translationX: 0, y: 3.0 * -currentToastView.bounds.height)
            
        }, completion: { [unowned self] completed in
            
            UIView.animate(withDuration: self.animationDuration, animations: {
                nextToastView.alpha = 1.0
            }, completion: { [unowned self] _ in
                currentToastView.removeFromSuperview()
                
                self.currentToastAlertModel = nextToastAlertModel
                self.currentToastView = nextToastView
                self.currentToastView?.addGestureRecognizer(self.panGestureRecognizer)
                
                self.configureTimer()
            })
        })
    }
    
    func removeCurrentToastViewFromPanGestureAndPresentNext(_ nextToastAlertModel: ToastAlert) {
        guard let _ = currentToastView else {
            logError("There's no current toast view to remove.")
            return
        }
        
        timer?.stop()
        
        self.currentToastView!.alpha = 0.0
        
        let nextToastView = nextToastAlertModel.buildToastAlertView()
        self.currentToastView!.removeFromSuperview()
        self.placeToastViewInView(nextToastView)
        self.currentToastAlertModel = nextToastAlertModel
        self.currentToastView = nextToastView
        
        self.currentToastView!.alpha = 0.0
        self.currentToastView?.removeGestureRecognizer(panGestureRecognizer)
        UIView.animate(withDuration: self.animationDuration, delay: 0.0, options: .allowUserInteraction, animations: { [unowned self] _ in
            self.currentToastView!.alpha = 1.0
        }, completion: { [unowned self] _ in
            self.currentToastView?.addGestureRecognizer(self.panGestureRecognizer)
            self.configureTimer()
        })
    }
    
    deinit {
        print("[DEINIT] ToastAlertsViewController")
        timer?.stop()
    }
}
