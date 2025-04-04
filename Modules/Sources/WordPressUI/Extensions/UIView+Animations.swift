import UIKit

// MARK: UIView Animation Helpers
//
extension UIView {
    /// Applies a "Shrink to 80%" spring animation
    ///
    @objc public func depressSpringAnimation(_ completion: ((Bool) -> Void)? = nil) {
        scaleSpringAnimation(0.8, delay: 0.0, duration: Animations.duration)
    }

    /// Applies a "Expand to 100%" spring animation
    ///
    @objc public func normalizeSpringAnimation(_ completion: ((Bool) -> Void)? = nil) {
        scaleSpringAnimation(1.0, delay: 0.0, duration: Animations.duration)
    }

    /// Applies a Scaling with Spring Animation.
    ///
    /// - Parameters:
    ///     - scale: Target Scale
    ///     - delay: Time before the animation will be applied
    ///     - duration: Duration of the animation
    ///     - completion: Callback to be executed on completion.
    ///
    fileprivate func scaleSpringAnimation(_ scale: CGFloat, delay: TimeInterval, duration: TimeInterval, completion: ((Bool) -> Void)? = nil) {
        let damping = CGFloat(0.3)
        let velocity = CGFloat(0.1)

        let animations = {
            self.transform = CGAffineTransform(scaleX: scale, y: scale)
        }

        UIView.animate(withDuration: duration,
                                   delay: delay,
                                   usingSpringWithDamping: damping,
                                   initialSpringVelocity: velocity,
                                   options: UIView.AnimationOptions(),
                                   animations: animations,
                                   completion: completion)
    }

    /// Applies a spring animation, from size 0 to final size
    ///
    public func expandSpringAnimation(_ completion: ((Bool) -> Void)? = nil) {
        let duration = 0.5
        let delay = 0.2
        let damping = CGFloat(0.7)
        let velocity = CGFloat(0.5)
        let scaleInitial = CGFloat(0.0)
        let scaleFinal = CGFloat(1.0)

        isHidden = false
        transform = CGAffineTransform(scaleX: scaleInitial, y: scaleInitial)

        let animations = {
            self.transform = CGAffineTransform(scaleX: scaleFinal, y: scaleFinal)
        }

        UIView.animate(withDuration: duration,
            delay: delay,
            usingSpringWithDamping: damping,
            initialSpringVelocity: velocity,
            options: UIView.AnimationOptions(),
            animations: animations,
            completion: completion
        )
    }

    /// Applies a fade in animation
    ///
    public func fadeInAnimation(_ completion: ((Bool) -> Void)? = nil) {
        alpha = 0.5

        UIView.animate(withDuration: Animations.duration, animations: { [weak self] in
            self?.alpha = 1
        }, completion: { success in
            completion?(success)
        })
    }

    /// Displays the current view with a Fade In / Rotation Animation
    ///
    public func fadeInWithRotationAnimation(_ completion: ((Bool) -> Void)? = nil) {
        transform = CGAffineTransform.makeRotation(-270, scale: 3)
        alpha = 0

        UIView.animate(withDuration: Animations.duration, animations: {
            self.transform = CGAffineTransform.makeRotation(0, scale: 0.75)
            self.alpha = 1
        }, completion: { _ in
            UIView.animate(withDuration: Animations.duration, animations: {
                self.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            }, completion: { success in
                completion?(success)
            })
        })
    }

    /// Hides the current view with a Rotation / FadeOut Animation
    ///
    public func fadeOutWithRotationAnimation(_ completion: ((Bool) -> Void)? = nil) {
        UIView.animate(withDuration: Animations.duration, animations: {
            self.transform = CGAffineTransform.makeRotation(120, scale: 3)
            self.alpha = 0
        }, completion: { success in
            completion?(success)
        })
    }

    /// Applies an "Expand to 300%" animation + Fade Out
    ///
    public func explodeAnimation(_ completion: ((Bool) -> Void)? = nil) {
        UIView.animate(withDuration: Animations.duration, animations: {
            self.transform = CGAffineTransform(scaleX: 3.0, y: 3.0)
            self.alpha = 0
        }, completion: { success in
            completion?(success)
        })
    }

    /// Applies an "Expand from 300% to 100" animation
    ///
    public func implodeAnimation(_ completion: ((Bool) -> Void)? = nil) {
        transform = CGAffineTransform(scaleX: 3.0, y: 3.0)
        alpha = 0

        UIView.animate(withDuration: Animations.duration, animations: {
            self.alpha = 1
            self.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        }, completion: { success in
            completion?(success)
        })
    }

    /// Applies a Cross Dissolve transition to fade a view to or from visibile then set's the Hidden value to reflect the current alpha's state.
    ///
    public func animatableSetIsHidden(_ isHidden: Bool, animated: Bool = true, _ completion: ((Bool) -> Void)? = nil) {
        guard self.isHidden != isHidden else { return }
        guard animated else {
            self.isHidden = isHidden
            return
        }

        self.isHidden = false
        let alpha: CGFloat = isHidden ? 0 : 1
        UIView.animate(withDuration: Animations.duration, delay: 0, options: .transitionCrossDissolve, animations: {
            self.alpha = alpha
        }) { success in
            self.isHidden = isHidden
            completion?(success)
        }
    }

    /// Coordinates an animation block alongside a keyboard's notification animation event.
    /// - Parameters:
    ///     - notification: A notficiation from a keyboard change event (keyboardWillShowNotification, keyboardWillHideNotification, etc)
    ///     - animations: The animation block to be preformed. The block will provide the rects from keyboardFrameBeginUserInfoKey and keyboardFrameEndUserInfoKey to the animation block.
    ///
    public static func animate(withKeyboard notification: Notification, _ animations: @escaping (CGRect, CGRect) -> Void ) {
        guard let userInfo = notification.userInfo else { return }
        let duration: TimeInterval = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0
        let beginFrame: CGRect = (userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue ?? CGRect.zero
        let endFrame: CGRect = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? CGRect.zero
        let animationCurve: AnimationOptions = AnimationOptions(rawValue: (userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 0))

        UIView.animate(withDuration: duration, delay: 0, options: animationCurve, animations: {
            animations(beginFrame, endFrame)
        }, completion: nil)
    }

    /// Private Constants
    ///
    private struct Animations {
        static let duration = TimeInterval(0.3)
    }
}
