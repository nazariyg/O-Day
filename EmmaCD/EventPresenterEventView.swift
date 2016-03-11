//--------------------------------------------------------------------------------------------------

protocol EventPresenterEventViewDelegate : class
{
    func eventDraggingDidBeginWithRatio (ratio:Double)
    func eventDidMoveByRatio (ratio:Double)
    func eventDraggingDidEndWithRatio (ratio:Double)
    func eventViewDidReceiveTap ()
}

//--------------------------------------------------------------------------------------------------


class EventPresenterEventView : UIView
{
    weak var delegate:EventPresenterEventViewDelegate!

    private let dragRatioFactor:CGFloat = 2.0

    private var draggingStartX:CGFloat!
    private var draggingIsAboutToBegin = false
    private var prevTouches:Set<UITouch>!
    private var hadAnyMovement = false

    //----------------------------------------------------------------------------------------------

    override func touchesBegan (touches:Set<UITouch>, withEvent event:UIEvent?)
    {
        self.draggingStartX = touches.first!.locationInView(self).x
        self.draggingIsAboutToBegin = true

        self.prevTouches = touches
        self.hadAnyMovement = false
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func touchesMoved (touches:Set<UITouch>, withEvent event:UIEvent?)
    {
        if let draggingStartX = self.draggingStartX
        {
            let draggingCurrX = touches.first!.locationInView(self).x
            var dragRatio = (draggingCurrX - draggingStartX)/self.bounds.width*self.dragRatioFactor
            dragRatio = clamp(dragRatio, -1.0, 1.0)

            if self.draggingIsAboutToBegin
            {
                self.delegate.eventDraggingDidBeginWithRatio(Double(dragRatio))
                self.draggingIsAboutToBegin = false
            }

            self.delegate.eventDidMoveByRatio(Double(dragRatio))
        }

        self.prevTouches = touches
        self.hadAnyMovement = true
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func touchesEnded (touches:Set<UITouch>, withEvent event:UIEvent?)
    {
        self.touchesCompleted(touches)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func touchesCancelled (touches:Set<UITouch>?, withEvent event:UIEvent?)
    {
        if let touches = touches
        {
            self.touchesCompleted(touches)
        }
        else if let prevTouches = self.prevTouches
        {
            self.touchesCompleted(prevTouches)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func touchesCompleted (touches:Set<UITouch>)
    {
        if self.hadAnyMovement
        {
            if let draggingStartX = self.draggingStartX
            {
                let draggingCurrX = touches.first!.locationInView(self).x
                var dragRatio =
                    (draggingCurrX - draggingStartX)/self.bounds.width*self.dragRatioFactor
                dragRatio = clamp(dragRatio, -1.0, 1.0)

                self.delegate.eventDraggingDidEndWithRatio(Double(dragRatio))
            }
        }
        else
        {
            self.delegate.eventViewDidReceiveTap()
        }

        self.draggingStartX = nil
        self.draggingIsAboutToBegin = false
        self.hadAnyMovement = false
    }

    //----------------------------------------------------------------------------------------------
}



