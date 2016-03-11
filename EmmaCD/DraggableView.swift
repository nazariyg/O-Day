//--------------------------------------------------------------------------------------------------

protocol DraggableViewDelegate : class
{
    func draggableView (
        draggableView:DraggableView, didEndDraggingToFrame frame:CGRect, sisterViewFrame:CGRect?)
}

//--------------------------------------------------------------------------------------------------


class DraggableView : UIView
{
    weak var delegate:DraggableViewDelegate?

    enum DragDirection
    {
        case Horizontal
        case Vertical
    }

    var draggingLimitedToDirection:DragDirection?
    var draggingBounds:CGRect?
    var sisterView:UIView?
    var draggingStartTouchDownMinTime = 0.0
    var tapCount = 1
    var isDragging = false
    var isTouched = false
    var referenceTransform:CGAffineTransform?
    private let draggingAnimationDuration = 0.33
    private let bouncingAnimationDuration = 0.5
    private var lastTouchBeginTimestamp:Double!

    //----------------------------------------------------------------------------------------------

    override func touchesBegan (touches:Set<UITouch>, withEvent event:UIEvent?)
    {
        self.isTouched = true

        super.touchesBegan(touches, withEvent: event)

        if touches.first!.tapCount != self.tapCount
        {
            return
        }

        self.lastTouchBeginTimestamp = CFAbsoluteTimeGetCurrent()
        self.isDragging = true
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func touchesMoved (touches:Set<UITouch>, withEvent event:UIEvent?)
    {
        super.touchesMoved(touches, withEvent: event)

        if touches.first!.tapCount != self.tapCount
        {
            return
        }

        if let lastTouchBeginTimestamp = self.lastTouchBeginTimestamp
        {
            let currTimestamp = CFAbsoluteTimeGetCurrent()
            if currTimestamp - lastTouchBeginTimestamp < self.draggingStartTouchDownMinTime
            {
                self.lastTouchBeginTimestamp = CFAbsoluteTimeGetCurrent()
                return
            }
        }

        let touch = touches.first!
        let location = touch.locationInView(self)
        let prevLocation = touch.previousLocationInView(self)
        let dx = self.draggingLimitedToDirection != .Vertical ? location.x - prevLocation.x : 0.0
        let dy = self.draggingLimitedToDirection != .Horizontal ? location.y - prevLocation.y : 0.0

        UIView.animateWithDuration(
            self.draggingAnimationDuration, delay: 0.0,
            options: [.CurveEaseOut, .AllowUserInteraction], animations: {
                self.frame.offsetInPlace(dx: dx, dy: dy)
            },
            completion: { _ in
                if self.isBeingAnimated()
                {
                    return
                }

                if self.sisterView == nil
                {
                    self.delegate?.draggableView(
                        self, didEndDraggingToFrame: self.frame, sisterViewFrame: nil)
                }
            })

        if let sisterView = self.sisterView
        {
            UIView.animateWithDuration(
                self.draggingAnimationDuration, delay: 0.0,
                options: [.CurveEaseOut, .AllowUserInteraction], animations: {
                    sisterView.frame.offsetInPlace(dx: dx, dy: dy)
                },
                completion: { _ in
                    if self.isBeingAnimated()
                    {
                        return
                    }

                    self.delegate?.draggableView(
                        self, didEndDraggingToFrame: self.frame, sisterViewFrame: sisterView.frame)
                })
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func isBeingAnimated () -> Bool
    {
        if let animationKeys = self.layer.animationKeys() where !animationKeys.isEmpty
        {
            return true
        }
        else
        {
            return false
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func touchesEnded (touches:Set<UITouch>, withEvent event:UIEvent?)
    {
        super.touchesEnded(touches, withEvent: event)

        self.draggingEnded()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func touchesCancelled (touches:Set<UITouch>?, withEvent event:UIEvent?)
    {
        super.touchesCancelled(touches, withEvent: event)

        self.draggingEnded()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func snapWithinDraggingBoundsAnimated (animated:Bool)
    {
        let draggingBounds = self.draggingBounds!

        var referenceFrame:CGRect
        if self.referenceTransform == nil
        {
            referenceFrame = self.frame
        }
        else
        {
            referenceFrame = CGRectApplyAffineTransform(self.bounds, self.referenceTransform!)
            referenceFrame.origin =
                CGPoint(
                    x: self.frame.midX - referenceFrame.width/2.0,
                    y: self.frame.midY - referenceFrame.height/2.0)
        }

        var originTargetX:CGFloat!
        var originTargetY:CGFloat!
        if referenceFrame.minX < draggingBounds.minX
        {
            originTargetX = draggingBounds.minX
        }
        else if referenceFrame.maxX > draggingBounds.maxX
        {
            originTargetX = referenceFrame.origin.x - (referenceFrame.maxX - draggingBounds.maxX)
        }
        if referenceFrame.minY < draggingBounds.minY
        {
            originTargetY = draggingBounds.minY
        }
        else if referenceFrame.maxY > draggingBounds.maxY
        {
            originTargetY = referenceFrame.origin.y - (referenceFrame.maxY - draggingBounds.maxY)
        }
        if originTargetX != nil || originTargetY != nil
        {
            if originTargetX == nil
            {
                originTargetX = referenceFrame.origin.x
            }
            if originTargetY == nil
            {
                originTargetY = referenceFrame.origin.y
            }
            let dx = originTargetX - referenceFrame.origin.x
            let dy = originTargetY - referenceFrame.origin.y

            if animated
            {
                UIView.animateWithDuration(
                    self.bouncingAnimationDuration, delay: 0.0,
                    options: [.CurveEaseOut, .AllowUserInteraction], animations: {
                        self.frame.offsetInPlace(dx: dx, dy: dy)
                    },
                    completion: { _ in
                        if self.isBeingAnimated()
                        {
                            return
                        }

                        if self.sisterView == nil
                        {
                            self.delegate?.draggableView(
                                self, didEndDraggingToFrame: self.frame, sisterViewFrame: nil)
                        }
                    })

                if let sisterView = self.sisterView
                {
                    UIView.animateWithDuration(
                        self.bouncingAnimationDuration, delay: 0.0,
                        options: [.CurveEaseOut, .AllowUserInteraction], animations: {
                            sisterView.frame.offsetInPlace(dx: dx, dy: dy)
                        },
                        completion: { _ in
                            if self.isBeingAnimated()
                            {
                                return
                            }

                            self.delegate?.draggableView(
                                self, didEndDraggingToFrame: self.frame,
                                sisterViewFrame: sisterView.frame)
                        })
                }
            }
            else
            {
                self.frame.offsetInPlace(dx: dx, dy: dy)

                if let sisterView = self.sisterView
                {
                    sisterView.frame.offsetInPlace(dx: dx, dy: dy)

                    self.delegate?.draggableView(
                        self, didEndDraggingToFrame: self.frame, sisterViewFrame: sisterView.frame)
                }
                else
                {
                    self.delegate?.draggableView(
                        self, didEndDraggingToFrame: self.frame, sisterViewFrame: nil)
                }
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func draggingEnded ()
    {
        self.isTouched = false

        if self.draggingBounds != nil
        {
            self.snapWithinDraggingBoundsAnimated(true)
        }

        self.isDragging = false
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func layoutSubviews ()
    {
        super.layoutSubviews()

        if self.draggingBounds != nil
        {
            self.snapWithinDraggingBoundsAnimated(false)
        }
    }

    //----------------------------------------------------------------------------------------------
}



