//
//  GestureAnimating.swift
//  Movin
//
//  Created by xxxAIRINxxx on 2018/08/02.
//  Copyright © 2018 xxxAIRINxxx. All rights reserved.
//

import Foundation
import UIKit

public enum GestureDirectionType {
    case top
    case bottom
    case left
    case right
    case none(UIView)

    var canAutoStartAnimation: Bool {
        switch self {
        case .none: return false
        default: return true
        }
    }
}

public class GestureAnimating: NSObject {

    var updateGestureHandler: ((CGFloat) -> Void)?
    var updateGestureStateHandler: ((UIGestureRecognizer.State) -> Void)?

    public fileprivate(set) weak var view: UIView!
    public let direction: GestureDirectionType
    public let range: CGSize

    public var panCompletionThresholdRatio: CGFloat = 0.8
    public var smoothness: CGFloat = 1.0

    fileprivate(set) var currentProgress: CGFloat = 0.0
    fileprivate(set) var isCompleted: Bool = false

    fileprivate(set) var gesture: UIPanGestureRecognizer?

    private var lastTranslation: CGPoint?
    private var fastSwipe = false
    private var count = 0

    deinit {
        Movin.dp("GestureAnimating - deinit")
        self.unregisterGesture()
    }

    public init(_ view: UIView, _ direction: GestureDirectionType, _ range: CGSize) {
        self.view = view
        self.direction = direction
        self.range = range

        super.init()

        self.registerGesture(view)
    }

    fileprivate func registerGesture(_ view: UIView) {
        Movin.dp("GestureAnimating - registerGesture")
        self.gesture = UIPanGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
        self.gesture?.maximumNumberOfTouches = 1
        self.gesture?.delegate = self
        view.addGestureRecognizer(self.gesture!)
    }

    func unregisterGesture() {
        Movin.dp("GestureAnimating - unregisterGesture")
        guard let g = self.gesture else {
            return
        }
        g.view?.removeGestureRecognizer(g)
        self.gesture = nil
    }

    @objc fileprivate func handleGesture(_ recognizer: UIPanGestureRecognizer) {

        let translation = recognizer.translation(in: self.view)

        switch self.direction {
        case .top:
            let translatedCenterY = translation.y * -1.0 * self.smoothness
            self.currentProgress = translatedCenterY / self.range.height
        case .bottom:
            let translatedCenterY = translation.y * self.smoothness
            self.currentProgress = translatedCenterY / self.range.height
        case .left:
            let translatedCenterX = translation.x * -1.0 * self.smoothness
            self.currentProgress = translatedCenterX / self.range.width
        case .right:
            let translatedCenterX = translation.x * self.smoothness
            self.currentProgress = translatedCenterX / self.range.width
        case .none(let parentView):
            self.view.center = recognizer.location(in: parentView)
            let x = translation.x / self.range.width
            let y = translation.y / self.range.height
            self.currentProgress = max(x, y)
        }

        Movin.dp(self.currentProgress, key: "GestureAnimating currentProgress : ")

        self.isCompleted = self.currentProgress >= self.panCompletionThresholdRatio

        if let lastTranslation = lastTranslation {

            let yDelta = lastTranslation.y - translation.y

            // if self.count == 0, recognizer.state == .ended {
            //     self.currentProgress = self.panCompletionThresholdRatio
            // }

            switch self.direction {
            case .top where yDelta > 15:
                self.fastSwipe = true
                self.count = 1
            case .bottom where yDelta < -15:
                self.fastSwipe = true
                self.count = 1
            default:
                if self.fastSwipe {
                    if recognizer.state == .ended {
                        self.fastSwipe = false
                        self.isCompleted = true
                    } else if self.count == 3 {
                        self.fastSwipe = false
                    }
                    self.count += 1
                }
            }
        }

        self.updateGestureHandler?(self.currentProgress)
        self.updateGestureStateHandler?(recognizer.state)

        if recognizer.state == .ended {
            self.lastTranslation = nil
            self.count = 0
        } else {
            self.lastTranslation = translation
        }
    }

}

// MARK: - UIGestureRecognizerDelegate

extension GestureAnimating: UIGestureRecognizerDelegate {

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        Movin.dp("GestureAnimating - shouldRecognizeSimultaneouslyWith")
        guard let g = self.gesture else {
            return false
        }
        guard g.view is UIScrollView else {
            return false
        }
        return true
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy
    otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        Movin.dp("GestureAnimating - shouldBeRequiredToFailBy")
        return false
    }
}
