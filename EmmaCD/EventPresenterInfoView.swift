//--------------------------------------------------------------------------------------------------

class EventPresenterInfoViewSavingOptions
{
    var digitsStopMotionFPS:Int!
    var digitsStopMotionReferenceDate:NSDate!
    var infoOffsetYRatio:Double?
    var infoScale:Double?
}

//--------------------------------------------------------------------------------------------------


class EventPresenterInfoView : UIView, DraggableViewDelegate
{
    var eventInfoDragView:DraggableView!
    var digitsView:DigitsView!
    static let digitsAlpha = 1.0
    var infoOffsetYRatio = 0.0
    var infoScale = 1.0

    private var eventRecord:EventRecord!
    private var eventInfoContainer:UIView!
    private var eventInfoSubContainer:UIView!
    private var timeStyleRecord:TimeStyleRecord!
    private let titleFrameCenterYFactor = 0.25
    private let titleFrameHeightFactor = 0.18  //0.12
    private let draggingBoundsPaddingTop = 0.025
    private let draggingBoundsPaddingBottom = 0.05
    private let countdownResolution = 0.025
    private var countdownTimer:NSTimer!
    private var lastCountdownRefreshTimestamp:Double!
    private var lastDigitGroupValues:[Int]!
    private var prevTimeDiff:Double!
    private let titleAlpha = 0.94
    private let frameAlpha = 0.94
    private var forPreview = false
    private var forSaving = false
    private var savingOptions:EventPresenterInfoViewSavingOptions!
    private var digitsStopMotionCurrFrame:Int!
    private var isPaused = false
    private var eventInfoDragViewBaseOffsetY:CGFloat!

    //----------------------------------------------------------------------------------------------

    init (
        frame:CGRect, eventRecord:EventRecord, forPreview:Bool = false,
        savingOptions:EventPresenterInfoViewSavingOptions? = nil)
    {
        super.init(frame: frame)

        self.eventRecord = eventRecord

        self.forPreview = forPreview

        if let savingOptions = savingOptions
        {
            self.forSaving = true
            self.savingOptions = savingOptions
        }

        var infoOffsetY:CGFloat!

        let eventInfoContainerFrame:CGRect
        if !self.forSaving || self.savingOptions.infoOffsetYRatio == nil
        {
            if !self.forSaving
            {
                let eventMeta = self.eventRecord.meta
                if let infoOffsetYRatio = eventMeta["infoOffsetYRatio"].double
                {
                    self.infoOffsetYRatio = infoOffsetYRatio
                    infoOffsetY = CGFloat(self.infoOffsetYRatio)*self.bounds.height
                    eventInfoContainerFrame = self.bounds.offsetBy(dx: 0.0, dy: infoOffsetY)
                }
                else
                {
                    eventInfoContainerFrame = self.bounds
                }
            }
            else
            {
                eventInfoContainerFrame = self.bounds
            }
        }
        else
        {
            self.infoOffsetYRatio = self.savingOptions.infoOffsetYRatio!
            infoOffsetY = CGFloat(self.infoOffsetYRatio)*self.bounds.height
            eventInfoContainerFrame = self.bounds.offsetBy(dx: 0.0, dy: infoOffsetY)
        }
        self.eventInfoContainer = UIView(frame: eventInfoContainerFrame)
        self.eventInfoContainer.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.eventInfoContainer.userInteractionEnabled = false
        self.eventInfoSubContainer = UIView(frame: self.eventInfoContainer.bounds)
        self.eventInfoSubContainer.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.eventInfoContainer.addSubview(self.eventInfoSubContainer)
        self.addSubview(self.eventInfoContainer)

        if self.forSaving
        {
            if let infoScale = self.savingOptions.infoScale
            {
                self.eventInfoSubContainer.transform =
                    CGAffineTransformMakeScale(CGFloat(infoScale), CGFloat(infoScale))
            }
        }

        let refView = self.eventInfoSubContainer
        let refRect = refView.bounds

        var titleLBFrame:CGRect
        let titleLB:TitleLabel

        var frameFrame:CGRect!

        if self.eventRecord.frameStyleRecord == nil
        {
            let titleFrameCenterY = refRect.height*CGFloat(self.titleFrameCenterYFactor)

            titleLBFrame = CGRectZero
            titleLBFrame.size.width = refRect.width
            titleLBFrame.size.height = refRect.height*CGFloat(self.titleFrameHeightFactor)
            titleLBFrame.insetInPlace(
                dx: refRect.width*CGFloat(AppConfiguration.titlePaddingHFactor), dy: 0.0)
            titleLBFrame.origin.x = (refRect.width - titleLBFrame.width)/2.0
            titleLBFrame.origin.y = titleFrameCenterY - titleLBFrame.height/2.0

            titleLB = TitleLabel(frame: titleLBFrame, fontSize: AppConfiguration.titleFontSize)
            self.eventInfoSubContainer.addSubview(titleLB)
        }
        else
        {
            let frameStyleRecord = self.eventRecord.frameStyleRecord!

            let frameImageView = UIImageView()
            frameImageView.image = frameStyleRecord.frameImage
            frameImageView.alpha = CGFloat(self.frameAlpha)
            titleLBFrame =
                FrameStyleRecord.layoutFrameImageView(
                    frameImageView, inView: self.eventInfoSubContainer,
                    withTextRect: frameStyleRecord.textRect, offsetX: 0.0,
                    frameID: frameStyleRecord.frameID)
            frameFrame = frameImageView.frame

            titleLB =
                TitleLabel(frame: titleLBFrame, fontSize: AppConfiguration.titleFontSizeFramed)
            if !frameStyleRecord.hasFill!
            {
                self.eventInfoSubContainer.insertSubview(titleLB, belowSubview: frameImageView)
            }
            else
            {
                self.eventInfoSubContainer.addSubview(titleLB)
            }
        }

        titleLB.alpha = CGFloat(self.titleAlpha)

        titleLB.text = self.eventRecord.title
        if let titleStyleRecord = self.eventRecord.titleStyleRecord
        {
            titleLB.fontName = titleStyleRecord.fontName
            titleLB.textColor = titleStyleRecord.color
        }

        let currDate:NSDate
        if !self.forSaving
        {
            currDate = NSDate()
        }
        else
        {
            currDate = self.savingOptions.digitsStopMotionReferenceDate
        }

        if self.eventRecord.timeStyleRecord == nil
        {
            self.timeStyleRecord = TimeStyleRecord()

            self.timeStyleRecord.digitStyleID = 25

            let dateComps =
                NSCalendar.currentCalendar().components(
                    [.Second],
                    fromDate: currDate,
                    toDate: self.eventRecord.dateTime,
                    options: [])
            let digits = String(abs(dateComps.second)).characters.map { String($0) }
            if digits.count <= 6
            {
                self.timeStyleRecord.timeStyle = .S6p
            }
            else
            {
                self.timeStyleRecord.timeStyle = .S8p
            }
        }
        else
        {
            self.timeStyleRecord = self.eventRecord.timeStyleRecord
        }
        let digitStyleID = String(format: "%02d", self.timeStyleRecord.digitStyleID)
        let groups =
            TimeStyleRecord.digitsViewGroupsForTimeStyle(
                self.timeStyleRecord.timeStyle,
                fromDate: currDate,
                toDate: self.eventRecord.dateTime)
        var numPlacesFactor:CGFloat = 0.0
        for group in groups
        {
            numPlacesFactor += CGFloat(group.numPlaces)
        }
        numPlacesFactor += CGFloat(groups.count - 1)*0.5
        var useDigitsViewPaddingHFactor = AppConfiguration.digitsViewPaddingHFactor
        if ["02", "21", "22", "23", "24"].contains(digitStyleID)
        {
            useDigitsViewPaddingHFactor += 0.32/Double(numPlacesFactor)
        }
        var digitsViewFrame = CGRectZero
        digitsViewFrame.size.width = refRect.width
        digitsViewFrame.size.height = refRect.height*0.25
        digitsViewFrame.insetInPlace(
            dx: refRect.width*CGFloat(useDigitsViewPaddingHFactor), dy: 0.0)
        digitsViewFrame.origin.x = (refRect.width - digitsViewFrame.width)/2.0
        let tarFileName = "DigitStyle\(digitStyleID).tar"
        let tarURL = NSBundle.mainBundle().URLForResource(tarFileName, withExtension: nil)!
        self.digitsView =
            DigitsView(
                frame: digitsViewFrame, sourceTarURL: tarURL, styleID: digitStyleID,
                pushyTimers: false)
        if self.forSaving
        {
            self.digitsView.setStopMotionModeWithFPS(self.savingOptions.digitsStopMotionFPS)
        }
        TimeStyleRecord.setLabelAppearanceForDigitsView(
            self.digitsView, timeStyle: self.timeStyleRecord.timeStyle)
        self.digitsView.groups = groups
        let digitAspect = self.digitsView.digitRect.height/self.digitsView.digitRect.width
        if self.eventRecord.frameStyleRecord == nil
        {
            if titleLB.numberOfLines < 2
            {
                self.digitsView.center.y =
                    titleLBFrame.midY + 60.0 + 100.0*digitAspect/numPlacesFactor
            }
            else
            {
                self.digitsView.center.y =
                    titleLBFrame.midY + 80.0 + 100.0*digitAspect/numPlacesFactor
            }
        }
        else
        {
            self.digitsView.center.y = titleLBFrame.midY + 100.0 + 10.0*digitAspect
        }
        self.digitsView.alpha = CGFloat(self.dynamicType.digitsAlpha)
        self.eventInfoSubContainer.addSubview(self.digitsView)

        if !self.forSaving
        {
            var eventInfoDragViewFrame:CGRect
            if self.eventRecord.frameStyleRecord == nil
            {
                eventInfoDragViewFrame = titleLBFrame
            }
            else
            {
                eventInfoDragViewFrame = frameFrame
            }
            self.eventInfoDragViewBaseOffsetY = eventInfoDragViewFrame.origin.y
            if let infoOffsetY = infoOffsetY
            {
                eventInfoDragViewFrame.offsetInPlace(dx: 0.0, dy: infoOffsetY)
            }
            eventInfoDragViewFrame.size.height +=
                self.digitsView.maxYInView(self) - eventInfoDragViewFrame.maxY
            self.eventInfoDragView = DraggableView(frame: eventInfoDragViewFrame)
            self.eventInfoDragView.draggingLimitedToDirection = .Vertical
            var draggingBounds = self.bounds
            draggingBounds.size.height *=
                1.0 - CGFloat(self.draggingBoundsPaddingTop + self.draggingBoundsPaddingBottom)
            draggingBounds.origin.y =
                CGFloat(self.draggingBoundsPaddingTop)*self.bounds.height
            self.eventInfoDragView.draggingBounds = draggingBounds
            self.eventInfoDragView.sisterView = self.eventInfoContainer
            self.eventInfoDragView.tapCount = 2
            self.eventInfoDragView.delegate = self
            self.addSubview(self.eventInfoDragView)
        }

        if !self.forSaving
        {
            self.makeCountdownTimer()
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func makeCountdownTimer ()
    {
        self.countdownTimer =
            NSTimer.scheduledTimerWithTimeInterval(
                self.countdownResolution, target: self, selector: "doCountdown", userInfo: nil,
                repeats: true)
        NSRunLoop.mainRunLoop().addTimer(self.countdownTimer, forMode: NSRunLoopCommonModes)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    required init? (coder aDecoder:NSCoder)
    {
        super.init(coder: aDecoder)
    }

    //----------------------------------------------------------------------------------------------

    func draggableView (
        draggableView:DraggableView, didEndDraggingToFrame frame:CGRect, sisterViewFrame:CGRect?)
    {
        self.infoOffsetYRatio = Double(self.eventInfoContainer.frame.origin.y/self.bounds.height)

        if self.forPreview || self.forSaving
        {
            return
        }

        var eventMeta = self.eventRecord.meta
        eventMeta["infoOffsetYRatio"].doubleValue = self.infoOffsetYRatio
        self.eventRecord.meta = eventMeta
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func doCountdown ()
    {
        let timeStyle = self.timeStyleRecord.timeStyle

        if timeStyle != .Breaths &&
           timeStyle != .Heartbeats6p &&
           timeStyle != .Heartbeats8p
        {
            if let lastCountdownRefreshTimestamp = self.lastCountdownRefreshTimestamp
            {
                let currTimestamp = self.timeGetCurrent()
                if abs(currTimestamp - lastCountdownRefreshTimestamp) < 1.0
                {
                    if self.forSaving
                    {
                        self.digitsView.makeStopMotionFrame()
                    }

                    return
                }
            }

            self.digitsView.maxAnimationDuration = nil
        }
        else if timeStyle == .Breaths
        {
            if let lastCountdownRefreshTimestamp = self.lastCountdownRefreshTimestamp
            {
                let currTimestamp = self.timeGetCurrent()
                if abs(currTimestamp - lastCountdownRefreshTimestamp) <
                   AppConfiguration.breathDuration
                {
                    if self.forSaving
                    {
                        self.digitsView.makeStopMotionFrame()
                    }

                    return
                }
            }

            self.digitsView.maxAnimationDuration = AppConfiguration.breathDuration/2.0
        }
        else  // heartbeats
        {
            if let lastCountdownRefreshTimestamp = self.lastCountdownRefreshTimestamp
            {
                let currTimestamp = self.timeGetCurrent()
                if abs(currTimestamp - lastCountdownRefreshTimestamp) <
                   AppConfiguration.heartbeatDuration
                {
                    if self.forSaving
                    {
                        self.digitsView.makeStopMotionFrame()
                    }

                    return
                }
            }

            self.digitsView.maxAnimationDuration = AppConfiguration.heartbeatDuration
        }

        let currDate:NSDate
        if !self.forSaving
        {
            currDate = NSDate()
        }
        else
        {
            currDate =
                self.savingOptions.digitsStopMotionReferenceDate.dateByAddingTimeInterval(
                    self.timeGetCurrent())
        }

        let groups =
            TimeStyleRecord.digitsViewGroupsForTimeStyle(
                timeStyle,
                fromDate: currDate,
                toDate: self.eventRecord.dateTime)

        var isDiff = true
        if let lastDigitGroupValues = self.lastDigitGroupValues
        {
            var inEq = false
            for (groupIndex, group) in groups.enumerate()
            {
                if group.value != lastDigitGroupValues[groupIndex]
                {
                    inEq = true
                    break
                }
            }
            isDiff = inEq
        }
        if isDiff
        {
            self.lastCountdownRefreshTimestamp = self.timeGetCurrent()
            self.lastDigitGroupValues = groups.map { $0.value }
        }
        else
        {
            if self.forSaving
            {
                self.digitsView.makeStopMotionFrame()
            }

            return
        }

        let direction:DigitsView.GroupValueChangeDirection =
            currDate.compare(self.eventRecord.dateTime) == .OrderedAscending ? .Down : .Up
        if direction == .Up && self.digitsView.id == "10"
        {
            self.digitsView.maxAnimationDuration = 0.33
        }
        if !self.forSaving
        {
            for (groupIndex, group) in groups.enumerate()
            {
                self.digitsView.setValue(
                    group.value, forGroup: groupIndex, direction: direction, animated: true)
            }
        }
        else
        {
            for (groupIndex, group) in groups.enumerate()
            {
                self.digitsView.makeStopMotionFrameBySettingValue(
                    group.value, forGroup: groupIndex, direction: direction, animated: true)
            }
        }

        if !self.forSaving
        {
            let currTimeDiff = currDate.timeIntervalSinceDate(self.eventRecord.dateTime)
            if let prevTimeDiff = prevTimeDiff
            {
                let sign0 = prevTimeDiff < 0.0 ? -1 : 1
                let sign1 = currTimeDiff < 0.0 ? -1 : 1
                if sign0 != sign1
                {
                    if self.window != nil
                    {
                        NSNotificationCenter.defaultCenter().postNotificationName(
                            "CountdownDidCrossZero", object: nil)
                    }
                }
            }
            self.prevTimeDiff = currTimeDiff
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func pause ()
    {
        if self.isPaused
        {
            return
        }

        self.digitsView.stop()

        self.countdownTimer?.invalidate()
        self.countdownTimer = nil

        self.isPaused = true
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func play ()
    {
        if !self.isPaused
        {
            return
        }

        let groups =
            TimeStyleRecord.digitsViewGroupsForTimeStyle(
                self.timeStyleRecord.timeStyle,
                fromDate: NSDate(),
                toDate: self.eventRecord.dateTime)
        self.digitsView.activateWithGroups(groups)

        self.countdownTimer?.invalidate()
        self.makeCountdownTimer()

        self.isPaused = false
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func makeDigitsStopMotionFrame ()
    {
        if self.digitsStopMotionCurrFrame == nil
        {
            self.digitsStopMotionCurrFrame = 0
        }
        else
        {
            self.digitsStopMotionCurrFrame = self.digitsStopMotionCurrFrame + 1
        }

        self.doCountdown()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func setInfoViewOffsetYRatio (infoOffsetYRatio:Double)
    {
        assert(self.forPreview)

        self.infoOffsetYRatio = infoOffsetYRatio
        let infoOffsetY = CGFloat(self.infoOffsetYRatio)*self.bounds.height
        self.eventInfoDragView.frame.origin.y = self.eventInfoDragViewBaseOffsetY + infoOffsetY
        UIView.animateWithDuration(
            0.33, delay: 0.0, options: [.CurveEaseOut], animations: {
                self.eventInfoContainer.frame.origin.y = infoOffsetY
            },
            completion: nil)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func setInfoViewScale (scale:Double)
    {
        assert(self.forPreview)

        self.infoScale = scale
        let transform = CGAffineTransformMakeScale(CGFloat(scale), CGFloat(scale))
        self.eventInfoDragView.referenceTransform = transform
        UIView.animateWithDuration(
            0.33, delay: 0.0, options: [.CurveEaseOut], animations: {
                self.eventInfoSubContainer.transform = transform
            },
            completion: nil)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func snapInfoViewWithinBounds ()
    {
        assert(self.forPreview)

        self.eventInfoDragView.snapWithinDraggingBoundsAnimated(true)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func hitTest (point:CGPoint, withEvent event:UIEvent?) -> UIView?
    {
        if self.forPreview
        {
            return nil
        }

        let subview = super.hitTest(point, withEvent: event)
        return subview === self.eventInfoDragView ? subview : nil
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func timeGetCurrent () -> CFAbsoluteTime
    {
        if !self.forSaving
        {
            return CFAbsoluteTimeGetCurrent()
        }
        else
        {
            let currFrame = Double(self.digitsStopMotionCurrFrame)
            let fps = Double(self.savingOptions.digitsStopMotionFPS)
            return currFrame/fps
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func deactivate ()
    {
        self.countdownTimer?.invalidate()

        self.digitsView.deactivate()
    }

    //----------------------------------------------------------------------------------------------
}



