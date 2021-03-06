//
//  Transition.swift
//  Movin
//
//  Created by xxxAIRINxxx on 2018/08/02.
//  Copyright © 2018 xxxAIRINxxx. All rights reserved.
//

import Foundation
import UIKit

public enum TransitionType {
    case push
    case pop
    case present
    case dismiss

    public var reversedType: TransitionType {
        switch self {
        case .push: return .pop
        case .pop: return .push
        case .present: return .dismiss
        case .dismiss: return .present
        }
    }

    public var isPresenting: Bool {
        self == .push || self == .present
    }

    public var isDismissing: Bool {
        self == .pop || self == .dismiss
    }
}

open class Transition: NSObject {

    public fileprivate(set) weak var movin: Movin!
    public let fromVC: UIViewController
    public let toVC: UIViewController
    public let gestureTransitioning: GestureTransitioning?

    public var customContainerViewSetupHandler: ((TransitionType, UIView) -> Void)?
    public var customContainerViewCompletionHandler: ((TransitionType, Bool, UIView) -> Void)?

    public fileprivate(set) var isInteractiveTransition: Bool = false
    public fileprivate(set) var animatedTransitioning: AnimatedTransitioning?
    public fileprivate(set) var interactiveTransitioning: InteractiveTransitioning?
    public fileprivate(set) var completion: ((TransitionType, Bool) -> Void)?

    deinit {
        Movin.dp("Transition - deinit")
    }

    public init(_ movin: Movin, _ fromVC: UIViewController, _ toVC: UIViewController, _ gestureTransitioning: GestureTransitioning?) {
        Movin.dp("Transition - init")
        self.movin = movin
        self.fromVC = fromVC
        self.toVC = toVC
        self.gestureTransitioning = gestureTransitioning

        super.init()

        self.handleInteractiveGestureIfNeeded()
    }

    @discardableResult public func configureCompletion(_ completion: ((TransitionType, Bool) -> Void)?) -> Transition {
        Movin.dp("Transition - configureCompletion")
        self.completion = completion
        return self
    }

    open func prepareTransition(_ type: TransitionType, _ transitionContext: UIViewControllerContextTransitioning) {
        Movin.dp("Transition - prepareTransition type: \(type)")
        let containerView = transitionContext.containerView

        if let handler = self.customContainerViewSetupHandler {
            handler(type, containerView)
        } else {
            if !self.toVC.isOverContext {
                containerView.addSubview(self.fromVC.view)
            }
            containerView.addSubview(self.toVC.view)
        }

        let animationDirection = AnimationDirection(self.movin.duration, type.isPresenting)

        self.movin.beforeAnimation(animationDirection)
        self.movin.configureAnimations(animationDirection)
    }

    open func currentTransitionType() -> TransitionType? {
        Movin.dp("Transition - currentTransitionType")
        if let type = self.gestureTransitioning?.currentType() {
            return type
        }
        if let type = self.animatedTransitioning?.type {
            return type
        }
        return nil
    }

    open func configureInteractiveTransitioningIfNeeded() -> InteractiveTransitioning? {
        Movin.dp("Transition - configureInteractiveTransitioningIfNeeded")
        if !self.isInteractiveTransition {
            return nil
        }
        self.setInteractiveTransitioningIfNeeded()
        self.handleInteractiveGestureIfNeeded()
        return self.interactiveTransitioning
    }

    open func setInteractiveTransitioningIfNeeded() {
        Movin.dp("Transition - setInteractiveTransitioningIfNeeded")
        self.interactiveTransitioning = nil
        guard let type = self.gestureTransitioning?.currentType(), self.gestureTransitioning?.hasGesture(type) == true else {
            return
        }
        self.interactiveTransitioning = InteractiveTransitioning(self, type)
    }

    open func handleInteractiveGestureIfNeeded() {
        Movin.dp("Transition - handleInteractiveGestureIfNeeded")
        guard let type = self.currentTransitionType(), let gesture = self.gestureTransitioning?.gesture(type) else {
            return
        }

        gesture.updateGestureHandler = { [weak self] completed in
            let isForward = self?.currentTransitionType()?.isPresenting ?? true
            if #available(iOS 11.0, *) {
                self?.movin.interactiveAnimate(isForward, completed)
                self?.interactiveTransitioning?.update(completed)
            } else {
                if self?.currentTransitionType()?.isPresenting == true {
                    self?.movin.interactiveAnimate(isForward, completed)
                    self?.interactiveTransitioning?.update(completed)
                } else {
                    let c = 1.0 - completed
                    self?.movin.interactiveAnimate(isForward, c)
                    self?.interactiveTransitioning?.update(c)
                }
            }
        }
        gesture.updateGestureStateHandler = { [weak self] state in
            switch state {
            case .began:
                self?.startInteractiveTransition()
            case .changed:
                break
            case .ended:
                if self?.gestureTransitioning?.gesture(type)?.isCompleted == true {
                    self?.interactiveTransitioning?.finish()
                } else {
                    self?.interactiveTransitioning?.cancel()
                }
            case .cancelled, .failed:
                self?.interactiveTransitioning?.cancel()
            default:
                break
            }
        }
    }

    open func startInteractiveTransition() {
        Movin.dp("Transition - startInteractiveTransition")
        guard let type = self.currentTransitionType() else {
            return
        }
        self.isInteractiveTransition = true

        switch type {
        case .push:
            self.fromVC.navigationController?.pushViewController(self.toVC, animated: true)
        case .present:
            self.fromVC.present(self.toVC, animated: true, completion: nil)
        case .pop:
            _ = self.fromVC.navigationController?.popViewController(animated: true)
        case .dismiss:
            self.fromVC.dismiss(animated: true, completion: nil)
        }
    }

    func finishTransition(_ type: TransitionType, _ didComplete: Bool, _ containerView: UIView) {
        Movin.dp("Transition - startInteractiveTransition type: \(type)")
        self.gestureTransitioning?.finishTransition(type, didComplete)

        self.animatedTransitioning = nil
        self.isInteractiveTransition = false

        if let c = self.customContainerViewCompletionHandler {
            c(type, didComplete, containerView)
        } else {
            self.completion?(type, didComplete)
        }

        self.handleInteractiveGestureIfNeeded()
    }
}

extension Transition: UIViewControllerTransitioningDelegate {

    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        Movin.dp("Transition - animationController forPresented")
        self.animatedTransitioning = AnimatedTransitioning(self, .present)
        return self.animatedTransitioning
    }

    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        // Movin.dp("Transition - animationController forDismissed")
        self.animatedTransitioning = AnimatedTransitioning(self, .dismiss)
        return self.animatedTransitioning
    }

    public func interactionControllerForPresentation(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        Movin.dp("Transition - interactionControllerForPresentation")
        return self.configureInteractiveTransitioningIfNeeded()
    }

    public func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        Movin.dp("Transition - interactionControllerForDismissal")
        return self.configureInteractiveTransitioningIfNeeded()
    }
}

extension Transition: UINavigationControllerDelegate {

    public func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        Movin.dp("Transition - navigationController animationControllerFor")
        switch operation {
        case .push:
            self.animatedTransitioning = AnimatedTransitioning(self, .push)
        case .pop:
            self.animatedTransitioning = AnimatedTransitioning(self, .pop)
        case .none:
            self.animatedTransitioning = nil
        default:
            self.animatedTransitioning = nil
        }

        return self.animatedTransitioning
    }

    public func navigationController(_ navigationController: UINavigationController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        Movin.dp("Transition - navigationController interactionControllerFor")
        return self.configureInteractiveTransitioningIfNeeded()
    }
}