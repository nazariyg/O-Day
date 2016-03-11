class EventListerEventsViewGradientMask : CALayer
{
    private let padding:CGFloat = 0.002

    //----------------------------------------------------------------------------------------------

    override init ()
    {
        super.init()
        self.setNeedsDisplay()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    required init? (coder aDecoder:NSCoder)
    {
        super.init(coder: aDecoder)
    }

    //----------------------------------------------------------------------------------------------

    override func drawInContext (ctx:CGContext)
    {
        super.drawInContext(ctx)

        let eventsViewGradComponents:[CGFloat] = [
            1.0, 1.0,
            1.0, 1.0,
            1.0, 0.0,
        ]
        let eventsViewGradLocations:[CGFloat] = [
            0.0,
            0.5 - padding,
            0.5 - padding,
        ]
        let eventsViewGrad =
            CGGradientCreateWithColorComponents(
                CGColorSpaceCreateDeviceGray(), eventsViewGradComponents,
                eventsViewGradLocations, eventsViewGradLocations.count)
        let eventsViewGradCenter =
            CGPoint(
                x: self.bounds.midX,
                y: self.bounds.midY)
        let eventsViewGradRadius = min(self.bounds.width, self.bounds.height)
        CGContextDrawRadialGradient(
            ctx, eventsViewGrad, eventsViewGradCenter, 0.0, eventsViewGradCenter,
            eventsViewGradRadius, .DrawsAfterEndLocation)
    }

    //----------------------------------------------------------------------------------------------
}



