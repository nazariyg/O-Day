import CoreMedia


//--------------------------------------------------------------------------------------------------

protocol EventPresenterViewControllerDataSource : class
{
    func initialEventIndex () -> Int
    func eventRecordForEventIndex (eventIndex:Int) -> EventRecord?
    func eventRecordDidChangeWithEventEditData (data:[String: AnyObject])
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

class CachedEvent
{
    let eventRecord:EventRecord
    let openingImage:UIImage
    let infoView:EventPresenterInfoView

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    init (eventRecord:EventRecord, openingImage:UIImage, infoView:EventPresenterInfoView)
    {
        self.eventRecord = eventRecord
        self.openingImage = openingImage
        self.infoView = infoView
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    deinit
    {
        self.infoView.deactivate()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
}

//--------------------------------------------------------------------------------------------------


class EventPresenterViewController : UIViewController, EventPresenterEventViewDelegate,
                                     DirectionalItemCacheDataSource,
                                     EventEditViewControllerInputOutput,
                                     EventExporterViewControllerInputDelegate
{
    weak var dataSource:EventPresenterViewControllerDataSource!

    @IBOutlet private weak var eventView:UIView!
    @IBOutlet private weak var eventBGView:UIImageView!
    @IBOutlet private weak var controlsView:UIView!
    @IBOutlet private weak var shareBN:UIButton!
    @IBOutlet private weak var editBN:UIButton!
    @IBOutlet private weak var eventsBN:UIButton!

    private var currEventIndex:Int!
    private var currEventRecord:EventRecord!
    private let presentationSize = UIScreen.mainScreen().bounds.size
    private var presentationFrame:CGRect!
    private var currBackgroundView:EventPresenterBackgroundView!
    private var currEventInfoView:EventPresenterInfoView!
    private var nextEventInfoView:EventPresenterInfoView!
    private var eventIDsToInputVideoPausedTimes = [String: CMTime]()
    private var eventIDsToOverlayPausedTimes = [String: CMTime]()
    private let openingImageMaxWidth = 600
    private var cachedEvents:DirectionalItemCache<CachedEvent>!
    private var once = 0
    private var tCurr = 0.0
    private var tTarget:Double!
    private var tBase:Double!
    private var tPrev = 0.0
    private var tTimer:NSTimer!
    private let tSpeed = 0.225
    private let tSnapDist = 0.0025
    private let eventInfoFadeOutFactor = 2.5
    private let digitsViewFadeInFactor = 3.0
    private var applicationWillResignActiveObserver:NSObjectProtocol!
    private var applicationDidBecomeActiveObserver:NSObjectProtocol!
    private var countdownDidCrossZeroObserver:NSObjectProtocol!
    private var controlsViewIsShown = false
    private var swipeGR0:UISwipeGestureRecognizer!
    private var swipeGR1:UISwipeGestureRecognizer!
    private let pauseInfoViewsASAP = true
    private var currEventSharingDestination:EventSharingDestination!

    //----------------------------------------------------------------------------------------------

    deinit
    {
        UIApplication.sharedApplication().idleTimerDisabled = false
        if let applicationWillResignActiveObserver = self.applicationWillResignActiveObserver
        {
            NSNotificationCenter.defaultCenter().removeObserver(applicationWillResignActiveObserver)
        }
        if let applicationDidBecomeActiveObserver = self.applicationDidBecomeActiveObserver
        {
            NSNotificationCenter.defaultCenter().removeObserver(applicationDidBecomeActiveObserver)
        }

        if let countdownDidCrossZeroObserver = self.countdownDidCrossZeroObserver
        {
            NSNotificationCenter.defaultCenter().removeObserver(countdownDidCrossZeroObserver)
        }
    }

    //----------------------------------------------------------------------------------------------

    override func viewDidLoad ()
    {
        super.viewDidLoad()

        (self.eventView as! EventPresenterEventView).delegate = self

        self.presentationFrame = CGRect(origin: CGPointZero, size: self.presentationSize)

        self.cachedEvents = DirectionalItemCache<CachedEvent>(dataSource: self, maxItemRadius: 1)

        let nc = NSNotificationCenter.defaultCenter()

        UIApplication.sharedApplication().idleTimerDisabled = true
        self.applicationWillResignActiveObserver =
            nc.addObserverForName(
                UIApplicationWillResignActiveNotification, object: nil,
                queue: NSOperationQueue.mainQueue()) { _ in
                    UIApplication.sharedApplication().idleTimerDisabled = false
                }
        self.applicationDidBecomeActiveObserver =
            nc.addObserverForName(
                UIApplicationDidBecomeActiveNotification, object: nil,
                queue: NSOperationQueue.mainQueue()) { _ in
                    UIApplication.sharedApplication().idleTimerDisabled = true
                }

        self.countdownDidCrossZeroObserver =
            nc.addObserverForName(
                "CountdownDidCrossZero", object: nil, queue: NSOperationQueue.mainQueue())
                { [weak self] _ in
                    guard let sSelf = self else
                    {
                        return
                    }

                    sSelf.currBackgroundView?.startRippleAtCenter()
                }

        self.controlsView.shownAlpha = 0.5

        for button in [
            self.shareBN,
            self.editBN,
            self.eventsBN]
        {
            button.layer.shadowColor = UIColor.blackColor().CGColor
            button.layer.shadowOpacity = 0.75
            button.layer.shadowRadius = 3.0
            button.layer.shadowOffset = CGSizeZero

            button.layer.shouldRasterize = true
            button.layer.rasterizationScale = UIScreen.mainScreen().scale
        }

        self.view.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: "didReceiveTap"))

        self.swipeGR0 = UISwipeGestureRecognizer(target: self, action: "didReceiveSwipe")
        self.swipeGR0.direction = .Left
        self.swipeGR1 = UISwipeGestureRecognizer(target: self, action: "didReceiveSwipe")
        self.swipeGR1.direction = .Right

        self.view.backgroundColor = AppConfiguration.bluishColor
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func viewDidLayoutSubviews ()
    {
        super.viewDidLayoutSubviews()

        dispatch_once(&self.once) {
            let initEventIndex = self.dataSource.initialEventIndex()
            self.setEventWithIndex(initEventIndex)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func didReceiveMemoryWarning ()
    {
        super.didReceiveMemoryWarning()

        //
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func prefersStatusBarHidden () -> Bool
    {
        return true
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func viewDidDisappear (animated:Bool)
    {
        super.viewDidDisappear(animated)

        if self.controlsViewIsShown
        {
            self.didReceiveTap()
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func itemKeyForIndex (itemIndex:Int) -> String?
    {
        let eventRecord = self.dataSource.eventRecordForEventIndex(itemIndex)
        return eventRecord?.id
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func itemValueForIndex (itemIndex:Int) -> AnyObject?
    {
        if let eventRecord = self.dataSource.eventRecordForEventIndex(itemIndex)
        {
            var openingImage =
                eventRecord.backgroundOpeningImageForContainerSize(self.presentationSize)
            openingImage = self.resizeOpeningImageIfNeeded(openingImage)
            let infoView =
                EventPresenterInfoView(frame: self.presentationFrame, eventRecord: eventRecord)
            if self.pauseInfoViewsASAP
            {
                infoView.pause()
            }
            let cachedEvent =
                CachedEvent(
                    eventRecord: eventRecord, openingImage: openingImage, infoView: infoView)
            return cachedEvent
        }
        else
        {
            return nil
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func clearEventView ()
    {
        self.currBackgroundView?.removeFromSuperview()
        self.currBackgroundView?.deactivate()
        self.currBackgroundView = nil
        self.currEventInfoView?.removeFromSuperview()
        self.currEventInfoView = nil
        self.nextEventInfoView?.removeFromSuperview()
        self.nextEventInfoView = nil
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func setEventWithIndex (eventIndex:Int)
    {
        self.currEventIndex = eventIndex

        self.cachedEvents.changeCurrItemIndex(eventIndex)
        let currCachedEvent = self.cachedEvents.itemForIndex(eventIndex)

        self.eventBGView.image = currCachedEvent.openingImage

        if let outgoingEventID = self.currBackgroundView?.eventRecord.id
        {
            self.eventIDsToInputVideoPausedTimes[outgoingEventID] =
                self.currBackgroundView.inputVideoCurrentTime()
            self.eventIDsToOverlayPausedTimes[outgoingEventID] =
                self.currBackgroundView.overlayCurrentTime()
        }

        if self.pauseInfoViewsASAP
        {
            if let currEventInfoView = self.currEventInfoView where
               currEventInfoView !== currCachedEvent.infoView
            {
                currEventInfoView.pause()
            }
            if let nextEventInfoView = self.nextEventInfoView where
               nextEventInfoView !== currCachedEvent.infoView
            {
                nextEventInfoView.pause()
            }
        }

        self.clearEventView()

        self.currBackgroundView =
            EventPresenterBackgroundView(
                frame: self.presentationFrame, eventRecord: currCachedEvent.eventRecord)
        self.currBackgroundView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.eventView.addSubview(self.currBackgroundView)
        self.currBackgroundView.play(
            inputVideoSeekTime: nil,
            overlaySeekTime: self.eventIDsToOverlayPausedTimes[currCachedEvent.eventRecord.id])

        self.currEventInfoView = currCachedEvent.infoView
        if self.pauseInfoViewsASAP
        {
            self.currEventInfoView.play()
        }
        self.currEventInfoView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.currEventInfoView.alpha = 1.0
        self.currEventInfoView.digitsView.alpha = CGFloat(EventPresenterInfoView.digitsAlpha)
        self.eventView.addSubview(self.currEventInfoView)

        self.currEventRecord = currCachedEvent.eventRecord
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func tStartTimerIfNeeded ()
    {
        if self.tTimer == nil
        {
            self.tTimer =
                NSTimer.scheduledTimerWithTimeInterval(
                    0.05, target: self, selector: "doT", userInfo: nil, repeats: true)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func eventDraggingDidBeginWithRatio (ratio:Double)
    {
        if let eventInfoDragView = self.currEventInfoView.eventInfoDragView where
           eventInfoDragView.isDragging
        {
            return
        }

        if self.tTarget == nil
        {
            self.tTarget = ratio
        }
        else
        {
            self.tBase = self.tCurr
            self.tTarget = self.tBase + ratio
        }
        self.tTarget = self.dynamicType.tClamp(self.tTarget)

        self.tStartTimerIfNeeded()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func eventDidMoveByRatio (ratio:Double)
    {
        if let eventInfoDragView = self.currEventInfoView.eventInfoDragView where
           eventInfoDragView.isDragging
        {
            return
        }

        if self.tBase == nil
        {
            self.tTarget = ratio
        }
        else
        {
            self.tTarget = self.tBase + ratio
        }
        self.tTarget = self.dynamicType.tClamp(self.tTarget)

        self.tStartTimerIfNeeded()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func doT ()
    {
        if self.tTarget == nil
        {
            assert(false)
        }

        let tDiff = self.tTarget - self.tCurr
        let tAbsDiff = abs(tDiff)

        if tAbsDiff <= self.tSnapDist
        {
            self.tCurr = self.tTarget
            self.tCurrDidChange(true)

            return
        }

        self.tCurr += tDiff*self.tSpeed

        self.tCurrDidChange(false)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func tCurrDidChange (final:Bool)
    {
        self.tCurr = self.dynamicType.tClamp(self.tCurr)

        if !final
        {
            let tCurrSign = sign(self.tCurr)
            let tPrevSign = sign(self.tPrev)
            if tCurrSign != tPrevSign
            {
                let nextEventIndex:Int
                if tCurrSign < 0.0
                {
                    nextEventIndex = self.currEventIndex + 1
                }
                else
                {
                    nextEventIndex = self.currEventIndex - 1
                }

                let cachedEvent = self.cachedEvents.itemForIndex(nextEventIndex)
                let openingImage = cachedEvent?.openingImage ?? AppConfiguration.defaultPicture
                self.currBackgroundView.beginTransitionToEventWithOpeningImage(
                    openingImage, transitionMix: self.tCurr)

                if self.pauseInfoViewsASAP
                {
                    self.nextEventInfoView?.pause()
                }
                self.nextEventInfoView?.removeFromSuperview()
                if let cachedEvent = cachedEvent
                {
                    self.nextEventInfoView = cachedEvent.infoView
                    if self.pauseInfoViewsASAP
                    {
                        self.nextEventInfoView.play()
                    }
                    self.nextEventInfoView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
                    self.eventView.addSubview(self.nextEventInfoView)
                }
            }
            else
            {
                self.currBackgroundView.setTransitionMix(self.tCurr)
            }

            self.currEventInfoView.alpha = self.tValueToCurrInfoViewAlpha(self.tCurr)
            self.nextEventInfoView?.alpha = self.tValueToNextInfoViewAlpha(self.tCurr)
            let refAlpha = CGFloat(EventPresenterInfoView.digitsAlpha)
            self.nextEventInfoView?.digitsView.alpha =
                pow(
                    self.tValueToNextInfoViewAlpha(self.tCurr),
                    CGFloat(self.digitsViewFadeInFactor))*refAlpha
        }
        else
        {
            self.currBackgroundView.setTransitionMix(self.tCurr)

            self.currEventInfoView.alpha = self.tValueToCurrInfoViewAlpha(self.tCurr)
            self.nextEventInfoView?.alpha = self.tValueToNextInfoViewAlpha(self.tCurr)
            let refAlpha = CGFloat(EventPresenterInfoView.digitsAlpha)
            self.nextEventInfoView?.digitsView.alpha =
                pow(
                    self.tValueToNextInfoViewAlpha(self.tCurr),
                    CGFloat(self.digitsViewFadeInFactor))*refAlpha

            var tDone = false
            var eventIndexToSet:Int!

            if self.tCurr == -1.0
            {
                tDone = true
                eventIndexToSet = self.currEventIndex + 1
            }
            else if self.tCurr == 1.0
            {
                tDone = true
                eventIndexToSet = self.currEventIndex - 1
            }
            else if self.tCurr == 0.0
            {
                tDone = true

                self.currBackgroundView.resetTransition()

                if self.pauseInfoViewsASAP
                {
                    self.nextEventInfoView?.pause()
                }
                self.nextEventInfoView?.removeFromSuperview()
                self.nextEventInfoView = nil
            }

            if let eventIndexToSet = eventIndexToSet
            {
                if self.dataSource.eventRecordForEventIndex(eventIndexToSet) == nil
                {
                    return
                }
            }

            self.tTarget = nil
            self.tBase = nil
            self.tTimer?.invalidate()
            self.tTimer = nil

            if tDone
            {
                self.tCurr = 0.0
                self.tPrev = 0.0

                if let eventIndexToSet = eventIndexToSet
                {
                    self.setEventWithIndex(eventIndexToSet)
                }

                return
            }
        }

        self.tPrev = self.tCurr
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func eventDraggingDidEndWithRatio (ratio:Double)
    {
        self.tTarget = self.tTarget ?? self.tCurr

        if self.tTarget < -0.5
        {
            if self.cachedEvents.itemForIndex(self.currEventIndex + 1) != nil
            {
                self.tTarget = -1.0
            }
            else
            {
                self.tTarget = 0.0
            }
        }
        else if self.tTarget > 0.5
        {
            if self.cachedEvents.itemForIndex(self.currEventIndex - 1) != nil
            {
                self.tTarget = 1.0
            }
            else
            {
                self.tTarget = 0.0
            }
        }
        else
        {
            self.tTarget = 0.0
        }

        self.tBase = nil

        self.tStartTimerIfNeeded()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func didReceiveTap ()
    {
        if !self.controlsViewIsShown
        {
            let showControlsView = {
                self.controlsView.hiddenAnimated = false
                self.controlsViewIsShown = true

                self.view.addGestureRecognizer(self.swipeGR0)
                self.view.addGestureRecognizer(self.swipeGR1)
            }

            if !self.currEventInfoView.eventInfoDragView.isTouched
            {
                on_main_with_delay(0.075) {
                    showControlsView()
                }
            }
            else
            {
                on_main_with_delay(0.42) {
                    if !self.currEventInfoView.eventInfoDragView.isTouched &&
                       !self.currEventInfoView.eventInfoDragView.isDragging
                    {
                        showControlsView()
                    }
                }
            }
        }
        else
        {
            self.controlsView.hiddenAnimated = true
            self.controlsViewIsShown = false

            self.view.removeGestureRecognizer(self.swipeGR0)
            self.view.removeGestureRecognizer(self.swipeGR1)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func didReceiveSwipe ()
    {
        if self.controlsViewIsShown
        {
            self.didReceiveTap()
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func eventViewDidReceiveTap ()
    {
        if self.currEventInfoView.eventInfoDragView.isTouched
        {
            return
        }

        self.didReceiveTap()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func tValueToCurrInfoViewAlpha (ratio:Double) -> CGFloat
    {
        var a = 1.0 - abs(ratio)*self.eventInfoFadeOutFactor
        if a < 0.0
        {
            a = 0.0
        }
        return CGFloat(a)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func tValueToNextInfoViewAlpha (ratio:Double) -> CGFloat
    {
        let omInvFOF = 1.0 - 1.0/self.eventInfoFadeOutFactor
        if abs(ratio) < omInvFOF
        {
            return 0.0
        }
        else
        {
            var a = (abs(ratio) - omInvFOF)*self.eventInfoFadeOutFactor
            if a > 1.0
            {
                a = 1.0
            }
            return CGFloat(a)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func dismiss ()
    {
        self.tTimer?.invalidate()

        let parentDismissal = {
            self.controlsViewIsShown = false
            self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
        }

        if let currBackgroundView = self.currBackgroundView
        {
            currBackgroundView.deactivate()
        }

        parentDismissal()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func resizeOpeningImageIfNeeded (image:UIImage!) -> UIImage!
    {
        if let image = image where image.pixelWidth > self.openingImageMaxWidth
        {
            let scale = Double(self.openingImageMaxWidth)/Double(image.pixelWidth)
            return image.resizedImageWithScale(scale)
        }
        else
        {
            return image
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func provideInputDataForEventEditViewController() -> [String: AnyObject]
    {
        var data = [String: AnyObject]()
        data["eventRecord"] = self.currEventRecord
        return data
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func eventEditViewControllerWillDeleteEventWithID (eventID:String)
    {
        self.clearEventView()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func acceptOutputDataFromEventEditViewController (data: [String: AnyObject])
    {
        // This goes first.
        self.dataSource.eventRecordDidChangeWithEventEditData(data)

        if data["changedEventID"] != nil ||
           data["deletedEventID"] != nil
        {
            var currCachedEvent:CachedEvent! =
                self.itemValueForIndex(self.currEventIndex) as? CachedEvent

            self.clearEventView()

            if currCachedEvent == nil
            {
                self.currEventIndex = self.currEventIndex - 1
                currCachedEvent = self.itemValueForIndex(self.currEventIndex) as? CachedEvent

                if currCachedEvent == nil
                {
                    self.eventBGView.image = AppConfiguration.defaultPicture
                    self.dismiss()
                    return
                }
            }

            if data["changedEventID"] != nil
            {
                let id = currCachedEvent.eventRecord.id
                self.cachedEvents.updateItem(currCachedEvent, forKey: id)
                self.eventIDsToInputVideoPausedTimes[id] = nil
                self.eventIDsToOverlayPausedTimes[id] = nil
            }
            else  // data["deletedEventID"] != nil
            {
                self.cachedEvents.clear()
            }
            
            self.setEventWithIndex(self.currEventIndex)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func eventEditViewControllerDidCancel ()
    {
        self.currBackgroundView.play()
        if self.pauseInfoViewsASAP
        {
            self.currEventInfoView?.play()
        }
        else
        {
            self.cachedEvents.walk { $0.infoView.play() }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func provideInputDataForEventExporterViewController () -> [String: AnyObject]
    {
        var data = [String: AnyObject]()
        data["eventRecord"] = self.currEventRecord
        return data
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func sharingDestinationForEventExporterViewController () -> EventSharingDestination
    {
        return self.currEventSharingDestination
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func eventExporterViewControllerWillDismiss ()
    {
        self.currBackgroundView.play()
        if self.pauseInfoViewsASAP
        {
            self.currEventInfoView?.play()
        }
        else
        {
            self.cachedEvents.walk { $0.infoView.play() }
        }
    }

    //----------------------------------------------------------------------------------------------

    private class func tClamp (tValue:Double) -> Double
    {
        var value = tValue
        if value < -1.0
        {
            value = -1.0
        }
        else if value > 1.0
        {
            value = 1.0
        }
        return value
    }

    //----------------------------------------------------------------------------------------------

    @IBAction func shareBNAction ()
    {
        let exporterVCClosure = {
            self.currBackgroundView.pause()
            if self.pauseInfoViewsASAP
            {
                self.currEventInfoView?.pause()
            }
            else
            {
                self.cachedEvents.walk { $0.infoView.pause() }
            }

            let vc =
                UIStoryboard(name: "EventExporter", bundle: nil).instantiateInitialViewController()!
            let eventExporterVC = vc as! EventExporterViewController
            eventExporterVC.inputDelegate = self
            self.presentViewController(vc, animated: true, completion: nil)
        }

        let dialog = KCSelectionDialog(title: "Share To", closeButtonTitle: "Cancel")
        dialog.addItem(
            item: "Facebook", icon: UIImage(named: "Facebook")!, didTapHandler: {
                self.currEventSharingDestination = .Facebook
                exporterVCClosure()
            })
        dialog.addItem(
            item: "Instagram", icon: UIImage(named: "Instagram")!, didTapHandler: {
                self.currEventSharingDestination = .Instagram
                exporterVCClosure()
            })
        dialog.addItem(
            item: "Twitter", icon: UIImage(named: "Twitter")!, didTapHandler: {
                self.currEventSharingDestination = .Twitter
                exporterVCClosure()
            })
        dialog.addItem(
            item: "Messages", icon: UIImage(named: "Messages")!, didTapHandler: {
                self.currEventSharingDestination = .Messages
                exporterVCClosure()
            })
        dialog.addItem(
            item: "Other", icon: UIImage(named: "OtherShares")!, didTapHandler: {
                self.currEventSharingDestination = .OtherShares
                exporterVCClosure()
            })
        dialog.addItem(
            item: "Save to Photos", icon: UIImage(named: "PhotoLibrary")!, didTapHandler: {
                self.currEventSharingDestination = .PhotoLibrary
                exporterVCClosure()
            })
        AppConfiguration.makeupSelectionDialog(dialog)
        dialog.show()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction func editBNAction ()
    {
        if let isDemo = self.currEventRecord.isDemo where isDemo
        {
            doOKAlertWithTitle(nil, message: "This is a demo event.", okHandler: nil)
            return
        }

        self.currBackgroundView.pause()
        if self.pauseInfoViewsASAP
        {
            self.currEventInfoView?.pause()
        }
        else
        {
            self.cachedEvents.walk { $0.infoView.pause() }
        }

        let vc =
            UIStoryboard(name: "EventEdit", bundle: nil).instantiateInitialViewController()!
        let eventEditTableVC = vc.childViewControllers.first! as! EventEditViewController
        eventEditTableVC.inputOutputDelegate = self
        self.presentViewController(vc, animated: true, completion: nil)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction func eventsBNAction ()
    {
        self.dismiss()
    }

    //----------------------------------------------------------------------------------------------
}



