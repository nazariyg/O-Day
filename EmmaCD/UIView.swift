import ObjectiveC


extension UIView
{
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    var showHideAnimationDuration:Double
    {
        return 0.25
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private static var shownAlphaAOKey:UInt8 = 0
    var shownAlpha:CGFloat
    {
        get {
            return objc_getAssociatedObject(
                self, &self.dynamicType.shownAlphaAOKey) as? CGFloat ?? 1.0
        }

        set {
            objc_setAssociatedObject(
                self, &self.dynamicType.shownAlphaAOKey, newValue,
                objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)

            self.alpha = newValue
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private static var hiddenAnimatedAOKey:UInt8 = 0
    var hiddenAnimated:Bool
    {
        get {
            return objc_getAssociatedObject(
                self, &self.dynamicType.hiddenAnimatedAOKey) as? Bool ?? self.hidden
        }

        set {
            objc_setAssociatedObject(
                self, &self.dynamicType.hiddenAnimatedAOKey, newValue,
                objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)

            if newValue
            {
                if !self.hidden
                {
                    // Hide.
                    UIView.animateWithDuration(
                        self.showHideAnimationDuration, delay: 0.0, options: [],
                        animations: {
                            self.alpha = 0.0
                        },
                        completion: { _ in
                            self.hidden = true
                        })
                }
            }
            else
            {
                let targetAlpha = self.shownAlpha
                if self.hidden || self.alpha < targetAlpha
                {
                    // Show.
                    if self.hidden
                    {
                        self.alpha = 0.0
                    }
                    self.hidden = false
                    UIView.animateWithDuration(
                        self.showHideAnimationDuration, delay: 0.0, options: [],
                        animations: {
                            self.alpha = CGFloat(targetAlpha)
                        },
                        completion: nil)
                }
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
}



