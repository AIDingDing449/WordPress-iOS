import UIKit

class QuickStartSpotlightView: UIView {

    // MARK: - Initialization

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 40, height: 40))

        setupLayout()
        self.setupLayers()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        setupLayout()
        self.setupLayers()
    }

    private func setupLayout() {
        self.isUserInteractionEnabled = false
        addConstraints([
            widthAnchor.constraint(equalToConstant: 40.0),
            heightAnchor.constraint(equalToConstant: 40.0)
            ])
    }

    // MARK: - Setup Layers

    /// This will draw the view and animation
    /// - Note: This was generated by Kite Compositor for Mac 1.9.4
    private func setupLayers() {
        // Colors
        //
        let backgroundColor = UIColor(red: 0.096, green: 0.44875, blue: 0.64, alpha: 1)
        let borderColor = UIColor(red: 0.126, green: 0.588984, blue: 0.84, alpha: 1)
        let backgroundColor1 = UIColor(red: 0.096, green: 0.44875, blue: 0.64, alpha: 1)

        // Big Circle
        //
        let bigCircleLayer = CALayer()
        bigCircleLayer.name = "Big Circle"
        bigCircleLayer.bounds = CGRect(x: 0, y: 0, width: 40, height: 40)
        bigCircleLayer.position = CGPoint(x: 20, y: 20)
        bigCircleLayer.contentsGravity = CALayerContentsGravity.center
        bigCircleLayer.opacity = 0.5
        bigCircleLayer.backgroundColor = backgroundColor.cgColor
        bigCircleLayer.cornerRadius = 20
        bigCircleLayer.borderColor = borderColor.cgColor
        bigCircleLayer.shadowOffset = CGSize(width: 0, height: 1)
        bigCircleLayer.allowsEdgeAntialiasing = true
        bigCircleLayer.allowsGroupOpacity = true
        bigCircleLayer.fillMode = CAMediaTimingFillMode.forwards
        bigCircleLayer.transform = CATransform3D( m11: 0, m12: 0, m13: 0, m14: 0,
                                                  m21: 0, m22: 0, m23: 0, m24: 0,
                                                  m31: 0, m32: 0, m33: 1, m34: 0,
                                                  m41: 0, m42: 0, m43: 0, m44: 1 )
        bigCircleLayer.sublayerTransform = CATransform3D( m11: -5, m12: -0, m13: -0, m14: -0,
                                                          m21: -0, m22: 5, m23: -0, m24: -0,
                                                          m31: -0, m32: -0, m33: 1, m34: -0,
                                                          m41: 0, m42: 0, m43: 0, m44: 1 )

        // Big Circle Animations
        //

        // pop big
        //
        let popBigAnimation = CASpringAnimation()
        popBigAnimation.beginTime = self.layer.convertTime(CACurrentMediaTime(), from: nil) + 0.05
        popBigAnimation.duration = 0.99321
        popBigAnimation.fillMode = CAMediaTimingFillMode.forwards
        popBigAnimation.isRemovedOnCompletion = false
        popBigAnimation.keyPath = "transform.scale.xy"
        popBigAnimation.toValue = 1
        popBigAnimation.stiffness = 200
        popBigAnimation.damping = 10
        popBigAnimation.mass = 0.7
        popBigAnimation.initialVelocity = 4

        bigCircleLayer.add(popBigAnimation, forKey: "popBigAnimation")

        // Group Animation
        //
        let groupAnimationAnimation = CAAnimationGroup()
        groupAnimationAnimation.beginTime = self.layer.convertTime(CACurrentMediaTime(), from: nil) + 1.04321
        groupAnimationAnimation.duration = 2
        groupAnimationAnimation.repeatCount = 9999
        groupAnimationAnimation.fillMode = CAMediaTimingFillMode.forwards
        groupAnimationAnimation.isRemovedOnCompletion = false
        groupAnimationAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)

        // Group Animation Animations
        //
        // get small
        //
        let getSmallAnimation = CABasicAnimation()
        getSmallAnimation.beginTime = 0.002777
        getSmallAnimation.duration = 0.253381
        getSmallAnimation.fillMode = CAMediaTimingFillMode.forwards
        getSmallAnimation.isRemovedOnCompletion = false
        getSmallAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.default)
        getSmallAnimation.keyPath = "transform.scale.xy"
        getSmallAnimation.toValue = 0.5
        // pop big
        //
        let popBigAnimation1 = CASpringAnimation()
        popBigAnimation1.beginTime = 0.333027
        popBigAnimation1.duration = 0.99321
        popBigAnimation1.fillMode = CAMediaTimingFillMode.forwards
        popBigAnimation1.isRemovedOnCompletion = false
        popBigAnimation1.keyPath = "transform.scale.xy"
        popBigAnimation1.toValue = 1
        popBigAnimation1.stiffness = 200
        popBigAnimation1.damping = 10
        popBigAnimation1.mass = 0.7
        popBigAnimation1.initialVelocity = 4
        groupAnimationAnimation.animations = [ getSmallAnimation, popBigAnimation1 ]

        bigCircleLayer.add(groupAnimationAnimation, forKey: "groupAnimationAnimation")

        self.layer.addSublayer(bigCircleLayer)

        // Small Circle
        //
        let smallCircleLayer = CALayer()
        smallCircleLayer.name = "Small Circle"
        smallCircleLayer.bounds = CGRect(x: 0, y: 0, width: 16, height: 16)
        smallCircleLayer.position = CGPoint(x: 20, y: 20)
        smallCircleLayer.contentsGravity = CALayerContentsGravity.center
        smallCircleLayer.backgroundColor = backgroundColor1.cgColor
        smallCircleLayer.cornerRadius = 8
        smallCircleLayer.borderColor = borderColor.cgColor
        smallCircleLayer.shadowOffset = CGSize(width: 0, height: 1)
        smallCircleLayer.allowsEdgeAntialiasing = true
        smallCircleLayer.allowsGroupOpacity = true
        smallCircleLayer.fillMode = CAMediaTimingFillMode.forwards
        smallCircleLayer.transform = CATransform3D( m11: 0, m12: 0, m13: 0, m14: 0,
                                                    m21: 0, m22: 0, m23: 0, m24: 0,
                                                    m31: 0, m32: 0, m33: 1, m34: 0,
                                                    m41: 0, m42: 0, m43: 0, m44: 1 )
        smallCircleLayer.sublayerTransform = CATransform3D( m11: -5, m12: -0, m13: -0, m14: -0,
                                                            m21: -0, m22: 5, m23: -0, m24: -0,
                                                            m31: -0, m32: -0, m33: 1, m34: -0,
                                                            m41: 0, m42: 0, m43: 0, m44: 1 )

        // Small Circle Animations
        //

        // breathOUT
        //
        let breathOUTAnimation = CASpringAnimation()
        breathOUTAnimation.beginTime = self.layer.convertTime(CACurrentMediaTime(), from: nil) + 0.000001
        breathOUTAnimation.duration = 1
        breathOUTAnimation.repeatDuration = 1
        breathOUTAnimation.fillMode = CAMediaTimingFillMode.forwards
        breathOUTAnimation.isRemovedOnCompletion = false
        breathOUTAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        breathOUTAnimation.keyPath = "transform.scale.xy"
        breathOUTAnimation.toValue = 1
        breathOUTAnimation.stiffness = 200
        breathOUTAnimation.damping = 10
        breathOUTAnimation.mass = 0.7
        breathOUTAnimation.initialVelocity = 4

        smallCircleLayer.add(breathOUTAnimation, forKey: "breathOUTAnimation")

        // Group Animation
        //
        let groupAnimationAnimation1 = CAAnimationGroup()
        groupAnimationAnimation1.beginTime = self.layer.convertTime(CACurrentMediaTime(), from: nil) + 1
        groupAnimationAnimation1.duration = 2
        groupAnimationAnimation1.repeatCount = 99999
        groupAnimationAnimation1.fillMode = CAMediaTimingFillMode.forwards
        groupAnimationAnimation1.isRemovedOnCompletion = false
        groupAnimationAnimation1.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)

        // Group Animation Animations
        //
        // breathIN
        //
        let breathINAnimation = CABasicAnimation()
        breathINAnimation.beginTime = 0.000001
        breathINAnimation.duration = 0.25
        breathINAnimation.fillMode = CAMediaTimingFillMode.forwards
        breathINAnimation.isRemovedOnCompletion = false
        breathINAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.default)
        breathINAnimation.keyPath = "transform.scale.xy"
        breathINAnimation.toValue = 0.5
        breathINAnimation.fromValue = 1
        // breathOUT
        //
        let breathOUTAnimation1 = CASpringAnimation()
        breathOUTAnimation1.beginTime = 0.307227
        breathOUTAnimation1.duration = 1
        breathOUTAnimation1.repeatDuration = 1
        breathOUTAnimation1.fillMode = CAMediaTimingFillMode.forwards
        breathOUTAnimation1.isRemovedOnCompletion = false
        breathOUTAnimation1.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        breathOUTAnimation1.keyPath = "transform.scale.xy"
        breathOUTAnimation1.toValue = 1
        breathOUTAnimation1.stiffness = 200
        breathOUTAnimation1.damping = 10
        breathOUTAnimation1.mass = 0.7
        breathOUTAnimation1.initialVelocity = 4
        groupAnimationAnimation1.animations = [ breathINAnimation, breathOUTAnimation1 ]

        smallCircleLayer.add(groupAnimationAnimation1, forKey: "groupAnimationAnimation1")

        self.layer.addSublayer(smallCircleLayer)

    }
}
