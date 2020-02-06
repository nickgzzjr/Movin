//
//  Movin.swift
//  Movin
//
//  Created by xxxAIRINxxx on 2018/08/01.
//  Copyright © 2018 xxxAIRINxxx. All rights reserved.
//

import Foundation
import UIKit

public enum MovinMode {
    case auto
    case interactive(GestureAnimating)
}

public final class Movin {
    
    public let duration: TimeInterval
    
    let timingParameters: UITimingCurveProvider
    public var animator: UIViewPropertyAnimator
    private var animations: [AnimationCompatible] = []
    
    private var transition: Transition?
    
    deinit {
        Movin.dp("Movin - deinit")
    }

    public init(_ duration: TimeInterval, _ timingCurve: UITimingCurveProvider? = nil) {
        Movin.dp("Movin - init")
        self.duration = duration
        self.timingParameters = timingCurve ?? UICubicTimingParameters(animationCurve: .easeInOut)
        self.animator = UIViewPropertyAnimator(duration: duration, timingParameters: self.timingParameters)
    }
    
    @discardableResult public func addAnimation(_ a: AnimationCompatible) -> Movin {
        self.animations.append(a)
        return self
    }
    
    @discardableResult public func addAnimations(_ a: [AnimationCompatible]) -> Movin {
        self.animations += a
        return self
    }
    
    @discardableResult public func addCompletion(_ c: @escaping (UIViewAnimatingPosition) -> Swift.Void) -> Movin {
        self.animator.addCompletion(c)
        return self
    }

    public func startAnimation(_ mode: MovinMode = .auto) {
        Movin.dp("Movin - startAnimation")
        if self.animator.state != .inactive {
            self.animator.stopAnimation(true)
            self.animator.fractionComplete = 0
            self.animator.finishAnimation(at: .start)
        }

        let animationDirection = AnimationDirection(self.duration, !self.animator.isReversed)

        self.beforeAnimation(animationDirection)
        self.configureAnimations(animationDirection)
        
        switch mode {
        case .auto:
            self.animator.startAnimation()
        case .interactive(let g):
            let canAutoStartAnimation = g.direction.canAutoStartAnimation
            g.updateGestureHandler = { [weak self] completed in
                if canAutoStartAnimation {
                    self?.animator.fractionComplete = completed
                }
            }
            g.updateGestureStateHandler = { [weak self] state in
                switch state {
                case .ended:
                    if !canAutoStartAnimation {
                        self?.animator.startAnimation()
                    }
                    
                    if g.isCompleted {
                        self?.end(true)
                    } else {
                        self?.cancel(true)
                    }
                    g.unregisterGesture()
                case .cancelled, .failed:
                    self?.cancel(true)
                    g.unregisterGesture()
                default:
                    break
                }
            }
            if canAutoStartAnimation {
                self.animator.startAnimation()
                self.animator.pauseAnimation()
            }
        }
    }
    
    public func configureTransition(_ from: UIViewController, _ to: UIViewController, _ gesture: GestureTransitioning? = nil) -> Transition {
        Movin.dp("Movin - configureTransition")
        let t = Transition(self, from, to, gesture)
        self.transition = t
        
        return t
    }
    
    public func configureCustomTransition(_ transition: Transition) -> Transition {
        Movin.dp("Movin - configureCustomTransition")
        self.transition = transition
        
        return transition
    }
    
    func end(_ isForward: Bool) {
        Movin.dp("Movin - end")
        self.finish(isForward, true)
    }
    
    func cancel(_ isForward: Bool) {
        Movin.dp("Movin - cancel")
        self.animator.isReversed = isForward
        self.finish(isForward, false)
    }
    
    private func finish(_ isForward: Bool, _ didComplete: Bool) {
        Movin.dp("Movin - finish")
        self.animator.addCompletion { [weak self] _ in self?.animations.forEach { $0.finishAnimation(isForward, didComplete) } }
        
        if self.animator.state == .active { self.animator.startAnimation() }
    }
    
    func beforeAnimation(_ animationDirection: AnimationDirection) {
        Movin.dp("Movin - beforeAnimation")
        self.animations.forEach { $0.beforeAnimation(animationDirection) }
    }
    
    func configureAnimations(_ animationDirection: AnimationDirection) {
        Movin.dp("Movin - configureAnimations")
        self.animations.forEach { a in
            self.animator.addAnimations({ a.animate(animationDirection) }, delayFactor: a.delayFactor)
        }
    }
    
    func interactiveAnimate(_ isForward: Bool, _ fractionComplete: CGFloat) {
        Movin.dp("Movin - interactiveAnimate")
        self.animations.forEach { $0.interactiveAnimate(isForward, fractionComplete) }
    }
    
    func finishInteractiveAnimation(_ interactiveTransitioning: InteractiveTransitioning) {
        Movin.dp("Movin - finishInteractiveAnimation")
        self.animations.forEach { $0.finishInteractiveAnimation(interactiveTransitioning) }
    }
}

public extension Movin {
    
    static var isDebugPrintEnabled: Bool = false
    
    static func dp(_ value: Any?, key: String? = nil) {
        if !self.isDebugPrintEnabled { return }
        print("[Movin] \(key ?? "") \(value ?? "nil")")
    }
}
