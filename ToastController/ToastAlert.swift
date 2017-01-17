import Foundation
import UIKit
import Cartography
import Helpers

enum ToastAlertLevel {
    case success, info, warning, error
}

protocol ToastAlertPresentable {
    func presentToastAlert(_ level: ToastAlertLevel, message: String, persistant: Bool)
}

class ToastAlertView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
        layer.shadowOpacity = 0.5
        layer.cornerRadius = 3.0
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct ToastAlert {
    
    static let toastDuration: Double = 5
    static let topMargin: CGFloat = 16
    static let lateralMargin: CGFloat = 20
    
    
    let level: ToastAlertLevel
    let title: String?
    let message: String
    let persistent: Bool
    var toastHeight: CGFloat {
        return title != nil ? 150 : 60
    }
    
    init(level: ToastAlertLevel, message: String, persistent: Bool = false) {
        self.level = level
        self.title = nil
        self.message = message
        self.persistent = persistent
    }
    
    init(level: ToastAlertLevel, title: String, message: String, persistent: Bool = false) {
        self.level = level
        self.title = title
        self.message = message
        self.persistent = persistent
    }
    
    var alertColor: UIColor {
        switch level {
        case .success: return UIColor.fromHex("#419B44")
        case .info: return UIColor.fromHex("#006FBB")
        case .warning: return UIColor.fromHex("#FF9F11")
        case .error: return UIColor.fromHex("#db4437")
        }
    }
    
    func buildToastAlertView() -> UIView {
        var titleLabel: UILabel?
        if let title = title {
            let label = UILabel(frame: CGRect.zero)
            label.font = UIFont.boldSystemFont(ofSize: UIFont.systemFontSize + 2)
            label.text = title
            label.numberOfLines = 1
            label.textColor = .white
            
            titleLabel = label
        }
        
        let textLabel = UILabel(frame: CGRect.zero)
        textLabel.text = message
        textLabel.numberOfLines = 2
        textLabel.textColor = .white
        
        let stackView = UIStackView(arrangedSubviews: [titleLabel, textLabel].flatMap{$0})
        stackView.axis = .vertical
        
        
        let alertContainer = ToastAlertView(frame: CGRect.zero)
        
        alertContainer.backgroundColor = alertColor
        alertContainer.addSubview(stackView)
        let minStackViewHeight: CGFloat = 41
        constrain(stackView, alertContainer) { stack, container in
            stack.top == container.top + 8
            stack.bottom  == container.bottom - 8
            stack.trailing == container.trailing - ToastAlert.lateralMargin
            stack.leading == container.leading + ToastAlert.lateralMargin
            stack.height >= minStackViewHeight
        }
        alertContainer.setNeedsDisplay()
        
        return alertContainer
    }
}
