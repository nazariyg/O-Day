import Viewmorphic


//--------------------------------------------------------------------------------------------------

private class ListedEventRecord
{
    let eventRecord:EventRecord
    let giSnapshot:GPUImagePicture
    let dateTimeLB:UILabel

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    init (eventRecord:EventRecord, giSnapshot:GPUImagePicture, dateTimeLB:UILabel)
    {
        self.eventRecord = eventRecord
        self.giSnapshot = giSnapshot
        self.dateTimeLB = dateTimeLB
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    deinit
    {
        self.giSnapshot.removeAllTargets()
        self.dateTimeLB.removeFromSuperview()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
}

//--------------------------------------------------------------------------------------------------


class EventListerViewController : UIViewController, UITableViewDataSource, UITableViewDelegate,
                                  UIScrollViewDelegate, EventEditViewControllerInputOutput,
                                  EventPresenterViewControllerDataSource,
                                  WYPopoverControllerDelegate,
                                  EventListerTagsSelectorViewControllerDelegate,
                                  SettingsViewControllerDelegate
{
    @IBOutlet private weak var eventsTableViewContainer:UIView!
    @IBOutlet private weak var eventsTableView:UITableView!
    @IBOutlet private weak var eventsViewContainer:UIView!
    @IBOutlet private weak var eventsViewSubContainer:UIView!
    @IBOutlet private weak var eventsViewBackgroundImageView:UIImageView!
    @IBOutlet private weak var eventDateLB:UILabel!
    @IBOutlet private weak var addEventBN:UIButton!
    @IBOutlet private weak var tagsBN:UIButton!
    @IBOutlet private weak var settingsBN:UIButton!
    @IBOutlet private weak var prevEventBN:UIButton!
    @IBOutlet private weak var nextEventBN:UIButton!

    private var eventsTableNumBottomRows:Int!
    private let eventRowsFadeOutLengthTop:CGFloat = 4.0
    private let eventRowsFadeOutFactorBottom:CGFloat = 0.0
    private let eventRowsSeparatorInsetFactor:CGFloat = 0.0
    private let eventsViewMaxBlurRadius:CGFloat = 10.0
    private let scrollPosSpeedFactor:CGFloat = 0.15
    private let scrollPosSnapDist:CGFloat = 0.01
    private let scrollPosMaxSpeed:CGFloat = 0.2
    private let scrollPosSpeedFactorForFastMode:CGFloat = 0.25
    private let scrollPosSnapDistForFastMode:CGFloat = 0.05
    private let scrollPosMaxSpeedForFastMode:CGFloat = 0.4
    private let eventDateTimeLBMaxAlpha:CGFloat = 0.5
    private let eventsTableViewPaddingTop:CGFloat = 10.0
    private var eventsTitleFontSize:CGFloat!
    private var eventsTitleMaxScale:CGFloat!
    private let sepaTag = 5368
    private let maybeDeleteOrRescheduleEventsTimerInterval = 3.0
    private let pastEventsTitleAlpha:CGFloat = 0.42

    private var allEvents:[ListedEventRecord]!
    private var giDefaultPictureSnapshotBefore:GPUImagePicture!
    private var giDefaultPictureSnapshotAfter:GPUImagePicture!
    private var eventsTableViewRowHeight:CGFloat!
    private var eventsTableViewInsetTop:CGFloat!
    private var focusEventRowIfNeededTimer:NSTimer!
    private var eventsTableViewPrevOffset:CGFloat!
    private var separatorImage:UIImage!
    private var nodeSystem:NodeSystem!
    private var dummyImage:UIImage!
    private var eventImageA:Image!
    private var eventImageB:Image!
    private var blurFilterA:Filter!
    private var blurFilterB:Filter!
    private var oMergeBlender:Blender!
    private var outputView:OutputView!
    private var currScrollPos:CGFloat!
    private var targetScrollPos:CGFloat!
    private var scrollPosTimer:NSTimer!
    private var currSelectedEventRowIndex:Int!
    private var cachedListedEventRecords = [String: ListedEventRecord]()
    private var noEventsLB:UILabel!
    private var selectedRowOneTimeClosure:(() -> Void)!
    private var viewDidAppearBefore = false
    private var tagsPopover:WYPopoverController!
    private var currEventsFilterTag:String!
    private var filteredEvents:[ListedEventRecord]!
    private var maybeDeleteOrRescheduleEventsTimer:NSTimer!
    private var isInPresentationMode = false
    private var presentedEvents:[ListedEventRecord]!
    private var notifDisabledAlertWasAlreadyDisplayed = false
    private var once = 0

    //----------------------------------------------------------------------------------------------

    override func viewDidLoad ()
    {
        super.viewDidLoad()

        if UIScreen.mainScreen().bounds.height < 569.0
        {
            self.eventsTableNumBottomRows = 5
            self.eventsTitleFontSize = 20.0
            self.eventsTitleMaxScale = 1.25
        }
        else
        {
            self.eventsTableNumBottomRows = 6
            self.eventsTitleFontSize = 22.0
            self.eventsTitleMaxScale = 1.33
        }

        self.view.backgroundColor = AppConfiguration.bluishColorSemiDarker

        self.eventsTableViewContainer.backgroundColor = UIColor.clearColor()
        self.eventsTableView.dataSource = self
        self.eventsTableView.delegate = self
        self.eventsTableView.backgroundColor = UIColor.clearColor()
        self.eventsTableView.separatorStyle = .None
        self.eventsTableView.decelerationRate = 0.992

        self.eventsViewContainer.backgroundColor = UIColor.clearColor()
        self.eventsViewContainer.alpha = 1.0

        let separatorHeight:CGFloat = 1.0
        let separatorMaxWidth = self.view.bounds.width
        let separatorInset = self.eventRowsSeparatorInsetFactor*separatorMaxWidth
        let separatorView =
            UIView(
                frame: CGRect(
                    x: 0.0,
                    y: 0.0,
                    width: separatorMaxWidth - separatorInset*2.0,
                    height: separatorHeight))
        separatorView.backgroundColor = UIColor(white: 1.0, alpha: 1.0)
        let separatorFadeOutColors = [
            UIColor.whiteColor().colorWithAlphaComponent(0.0).CGColor,
            UIColor.whiteColor().colorWithAlphaComponent(0.25).CGColor,
            UIColor.whiteColor().colorWithAlphaComponent(0.0).CGColor,
        ]
        let separatorFadeOutLocations = [
            0.0,
            0.5,
            1.0,
        ]
        let separatorFadeOut = CAGradientLayer()
        separatorFadeOut.frame = separatorView.bounds
        separatorFadeOut.colors = separatorFadeOutColors
        separatorFadeOut.startPoint = CGPoint(x: 0.0, y: 0.0)
        separatorFadeOut.endPoint = CGPoint(x: 1.0, y: 0.0)
        separatorFadeOut.locations = separatorFadeOutLocations
        separatorView.layer.mask = separatorFadeOut
        UIGraphicsBeginImageContextWithOptions(separatorView.bounds.size, false, 0.0)
        separatorView.drawViewHierarchyInRect(separatorView.bounds, afterScreenUpdates: true)
        self.separatorImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        self.dummyImage =
            UIImage.solidColorImageOfSize(
                CGSize(width: 8, height: 8), color: UIColor.blackColor())

        self.giDefaultPictureSnapshotBefore =
            GPUImagePicture(image: BackgroundRecord.squareDefaultPicture)
        self.giDefaultPictureSnapshotAfter =
            GPUImagePicture(image: BackgroundRecord.squareDefaultPicture)

        self.reloadEventsAndTable()

        let popoverAppearance = WYPopoverBackgroundView.appearance()
        popoverAppearance.outerShadowBlurRadius = 32
        popoverAppearance.outerShadowColor =
            AppConfiguration.bluishColor.colorWithAlphaComponent(0.33)
        popoverAppearance.fillTopColor = AppConfiguration.bluishColor
        popoverAppearance.glossShadowColor = AppConfiguration.bluishColor

        for button in [
            self.addEventBN,
            self.tagsBN,
            self.settingsBN,
            self.prevEventBN,
            self.nextEventBN]
        {
            button.layer.shouldRasterize = true
            button.layer.rasterizationScale = UIScreen.mainScreen().scale
        }

        self.maybeDeleteOrRescheduleEventsTimer =
            NSTimer.scheduledTimerWithTimeInterval(
                self.maybeDeleteOrRescheduleEventsTimerInterval, target: self,
                selector: "maybeDeleteOrRescheduleEvents", userInfo: nil, repeats: true)

        if UIScreen.mainScreenAspectRatio == .AspectRatio9x16
        {
            let eventsViewContainerAspectRatioLC =
                NSLayoutConstraint(
                    item: self.eventsViewContainer, attribute: .Height,
                    relatedBy: .Equal,
                    toItem: self.eventsViewContainer, attribute: .Width, multiplier: 0.88,
                    constant: 0.0)
            self.eventsViewContainer.addConstraint(eventsViewContainerAspectRatioLC)

            let settingsBNVerticalLC =
                NSLayoutConstraint(
                    item: self.settingsBN, attribute: .CenterY,
                    relatedBy: .Equal,
                    toItem: self.eventsViewContainer, attribute: .CenterY,
                    multiplier: 1.66, constant: 0.0)
            self.view.addConstraint(settingsBNVerticalLC)

            for button in [self.prevEventBN, self.nextEventBN]
            {
                button.alpha = 0.1//0.05
            }
        }
        else if UIScreen.mainScreenAspectRatio == .AspectRatio3x4
        {
            let eventsViewContainerAspectRatioLC =
                NSLayoutConstraint(
                    item: self.eventsViewContainer, attribute: .Height,
                    relatedBy: .Equal,
                    toItem: self.eventsViewContainer, attribute: .Width, multiplier: 0.68,
                    constant: 0.0)
            self.eventsViewContainer.addConstraint(eventsViewContainerAspectRatioLC)

            let settingsBNVerticalLC =
                NSLayoutConstraint(
                    item: self.settingsBN, attribute: .CenterY,
                    relatedBy: .Equal,
                    toItem: self.eventsViewContainer, attribute: .CenterY,
                    multiplier: 1.58, constant: 0.0)
            self.view.addConstraint(settingsBNVerticalLC)

            for button in [self.prevEventBN, self.nextEventBN]
            {
                button.alpha = 0.2
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func reloadEvents ()
    {
        self.allEvents = []
        let fm = NSFileManager()
        let eventDirURLs =
            try! fm.contentsOfDirectoryAtURL(
                AppConfiguration.eventsDirURL, includingPropertiesForKeys: nil,
                options: .SkipsHiddenFiles)
        for eventDirURL in eventDirURLs
        {
            var isDir:ObjCBool = false
            fm.fileExistsAtPath(eventDirURL.path!, isDirectory: &isDir)
            if isDir
            {
                let eventID = eventDirURL.lastPathComponent
                let cachedListedEventRecord =
                    eventID != nil ? self.cachedListedEventRecords[eventID!] : nil
                if cachedListedEventRecord == nil
                {
                    let eventRecordFileURL = eventDirURL.URLByAppendingPathComponent("E")
                    if fm.fileExistsAtPath(eventRecordFileURL.path!)
                    {
                        let eventRecord =
                            NSKeyedUnarchiver.unarchiveObjectWithFile(eventRecordFileURL.path!)
                        if let eventRecord = eventRecord as? EventRecord
                        {
                            let giSnapshot:GPUImagePicture
                            if let squareSnapshot = eventRecord.backgroundRecord?.squareSnapshot
                            {
                                giSnapshot = GPUImagePicture(image: squareSnapshot)
                            }
                            else
                            {
                                giSnapshot =
                                    GPUImagePicture(image: BackgroundRecord.squareDefaultPicture)
                            }

                            let dateTimeFormatter = NSDateFormatter()
                            dateTimeFormatter.dateStyle = .LongStyle
                            if eventRecord.useTime!
                            {
                                dateTimeFormatter.timeStyle = .ShortStyle
                            }
                            let dateTimeText =
                                dateTimeFormatter.stringFromDate(eventRecord.dateTime)
                            let dateTimeLB = UILabel()
                            dateTimeLB.textColor = UIColor.whiteColor()
                            dateTimeLB.textAlignment = .Center
                            dateTimeLB.font = UIFont.boldSystemFontOfSize(12.0)
                            dateTimeLB.adjustsFontSizeToFitWidth = true
                            dateTimeLB.minimumScaleFactor = 0.1
                            dateTimeLB.text = dateTimeText.uppercaseString

                            dateTimeLB.layer.shouldRasterize = true
                            dateTimeLB.layer.rasterizationScale = UIScreen.mainScreen().scale

                            let listedEventRecord =
                                ListedEventRecord(
                                    eventRecord: eventRecord,
                                    giSnapshot: giSnapshot,
                                    dateTimeLB: dateTimeLB)
                            self.allEvents.append(listedEventRecord)
                            self.cachedListedEventRecords[eventRecord.id] = listedEventRecord
                        }
                    }
                }
                else
                {
                    self.allEvents.append(cachedListedEventRecord!)
                }
            }
        }

        // Sort by date.
        self.allEvents.sortInPlace { listedEventRecord0, listedEventRecord1 in
            return listedEventRecord0.eventRecord.dateTime.compare(
                listedEventRecord1.eventRecord.dateTime) == .OrderedAscending
        }

        if let noEventsLB = self.noEventsLB
        {
            noEventsLB.hiddenAnimated = !self.allEvents.isEmpty
        }

        self.maybeRescheduleEventNotifications()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func reloadEventsAndTable ()
    {
        self.reloadEvents()

        if self.view.window != nil
        {
            //self.eventsTableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Fade)
            self.eventsTableView.reloadData()
        }
        else
        {
            self.eventsTableView.reloadData()
        }

        if self.viewDidAppearBefore
        {
            self.scrollViewDidScroll(self.eventsTableView)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func viewDidLayoutSubviews ()
    {
        super.viewDidLayoutSubviews()

        if UIScreen.mainScreenAspectRatio == .AspectRatio3x4
        {
            self.prevEventBN.frame.origin.x = -16.0
            self.nextEventBN.frame.origin.x = 245.0 + 16.0
        }

        dispatch_once(&self.once) {
            self.eventsTableViewContainer.layoutSubviews()
            self.eventsViewContainer.layoutSubviews()
            self.eventsViewSubContainer.layoutSubviews()

            self.nodeSystem = NodeSystem()
            self.eventImageA = self.nodeSystem.addImage(self.dummyImage)
            self.eventImageA.syncMode = true
            self.eventImageB = self.nodeSystem.addImage(self.dummyImage)
            self.eventImageB.syncMode = true
            self.blurFilterA =
                self.nodeSystem.addFilter(.GaussianBlur, settings: ["blurRadiusInPixels": 0.0])
            self.blurFilterB =
                self.nodeSystem.addFilter(.GaussianBlur, settings: ["blurRadiusInPixels": 0.0])
            self.oMergeBlender = self.nodeSystem.addBlender(.OMerge)
            self.oMergeBlender.syncMode = true
            self.outputView =
                self.nodeSystem.addOutputViewWithFrame(self.eventsViewSubContainer.bounds)
            self.eventImageA.linkTo(self.blurFilterA)
            self.eventImageB.linkTo(self.blurFilterB)
            self.blurFilterA.linkAtATo(self.oMergeBlender)
            self.blurFilterB.linkAtBTo(self.oMergeBlender)
            self.oMergeBlender.linkTo(self.outputView)
            self.eventsViewSubContainer.addSubview(self.outputView.view)
            if UIScreen.mainScreenAspectRatio == .AspectRatio3x4
            {
                let scale:CGFloat = 0.99
                self.eventsViewSubContainer.transform = CGAffineTransformMakeScale(scale, scale)
            }

            self.eventsTableViewInsetTop = self.eventsTableViewPaddingTop

            let rowsSpaceHeight = self.eventsTableView.bounds.height - self.eventsTableViewInsetTop
            self.eventsTableViewRowHeight = rowsSpaceHeight/CGFloat(self.eventsTableNumBottomRows)
            self.eventsTableView.rowHeight = self.eventsTableViewRowHeight

            self.eventsTableView.contentInset.top = self.eventsTableViewInsetTop
            self.eventsTableView.contentInset.bottom =
                self.eventsTableViewContainer.bounds.height - self.eventsTableViewInsetTop -
                self.eventsTableViewRowHeight

            self.eventsTableView.scrollIndicatorInsets.top = self.eventsTableViewInsetTop

            let logoImage = UIImage(named: "AppLogo")!
            let logoView =
                UIImageView(
                    frame: CGRect(
                        origin: CGPointZero,
                        size: CGSize(
                            width: logoImage.size.width*2.0,
                            height: logoImage.size.height*2.0)))
            logoView.image = logoImage
            logoView.tintColor = AppConfiguration.bluishColor
            logoView.alpha = 0.33
            let logoViewContainer = UIView(frame: logoView.frame)
            logoViewContainer.addSubview(logoView)
            logoViewContainer.center = CGPoint(x: self.eventsTableView.bounds.midX, y: -50.0)
            logoViewContainer.layer.shadowColor = UIColor.whiteColor().CGColor
            logoViewContainer.layer.shadowOpacity = 0.75
            logoViewContainer.layer.shadowRadius = 1.0
            logoViewContainer.layer.shadowOffset = CGSize(width: 0.0, height: 1.0)
            self.eventsTableView.addSubview(logoViewContainer)

            self.noEventsLB =
                UILabel(
                    frame: CGRect(
                        origin: CGPointZero,
                        size: CGSize(width: self.eventsTableView.bounds.width*0.66, height: 100.0)))
            self.noEventsLB.center = CGPoint(x: self.eventsTableView.bounds.midX, y: 160.0)
            self.noEventsLB.textAlignment = .Center
            self.noEventsLB.textColor = UIColor.whiteColor()
            self.noEventsLB.font = UIFont.systemFontOfSize(14.0)
            self.noEventsLB.numberOfLines = 0
            self.noEventsLB.text = "You can add a new event by tapping the plus button."
            self.eventsTableView.addSubview(self.noEventsLB)
            self.noEventsLB.shownAlpha = 0.25
            self.noEventsLB.hidden = !self.allEvents.isEmpty

            let eventsTableViewGradColors = [
                UIColor.whiteColor().colorWithAlphaComponent(0.0).CGColor,
                UIColor.whiteColor().colorWithAlphaComponent(1.0).CGColor,
            ]
            var offset:Double!
            if UIScreen.mainScreenAspectRatio == .AspectRatio9x16
            {
                offset = 0.02
            }
            else if UIScreen.mainScreenAspectRatio == .AspectRatio3x4
            {
                offset = 0.064
            }
            let span = 0.033
            let eventsTableViewGradLocations = [
                offset!,
                offset! + span,
            ]
            let eventsTableViewFadeOut = CAGradientLayer()
            eventsTableViewFadeOut.frame = self.eventsTableViewContainer.bounds
            eventsTableViewFadeOut.colors = eventsTableViewGradColors
            eventsTableViewFadeOut.locations = eventsTableViewGradLocations
            self.eventsTableViewContainer.layer.mask = eventsTableViewFadeOut

            let eventsViewGrad = EventListerEventsViewGradientMask()
            eventsViewGrad.frame = self.eventsViewSubContainer.bounds
            self.eventsViewSubContainer.layer.mask = eventsViewGrad

            let circleBorderWidth:CGFloat = 2.0
            UIGraphicsBeginImageContextWithOptions(self.eventsViewContainer.bounds.size, false, 0.0)
            let cx = UIGraphicsGetCurrentContext()
            UIColor(white: 0.9, alpha: 1.0).setStroke()
            CGContextSetLineWidth(cx, circleBorderWidth)
            let circleBorderHalfWidth = circleBorderWidth/2.0
            var circleFrame = self.eventsViewContainer.bounds
            circleFrame.insetInPlace(dx: (circleFrame.width - circleFrame.height)/2.0, dy: 0.0)
            CGContextStrokeEllipseInRect(
                cx,
                circleFrame.insetBy(
                    dx: circleBorderHalfWidth, dy: circleBorderHalfWidth))
            let circleBorderImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            let circleBorderImageView = UIImageView(frame: self.eventsViewContainer.bounds)
            circleBorderImageView.image = circleBorderImage
            self.eventsViewContainer.addSubview(circleBorderImageView)

            self.eventsViewContainer.layer.shadowColor = AppConfiguration.bluishColorLighter.CGColor
            self.eventsViewContainer.layer.shadowOpacity = 1.0
            self.eventsViewContainer.layer.shadowRadius = 64.0
            self.eventsViewContainer.layer.shadowOffset = CGSizeZero
            let shadowPath = UIBezierPath(ovalInRect: self.eventsViewContainer.bounds)
            self.eventsViewContainer.layer.shadowPath = shadowPath.CGPath

            self.eventsViewContainer.addGestureRecognizer(
                UITapGestureRecognizer(target: self, action: "eventsViewDidReceiveTap:"))
            let doubleTapGR =
                UITapGestureRecognizer(target: self, action: "eventsViewDidReceiveDoubleTap")
            doubleTapGR.numberOfTapsRequired = 2
            //self.eventsViewContainer.addGestureRecognizer(doubleTapGR)

            self.focusEventRowIfNeededTimer =
                NSTimer.scheduledTimerWithTimeInterval(
                    0.1, target: self, selector: "focusEventRowIfNeeded", userInfo: nil,
                    repeats: true)

            self.moveToTemporalyNextEvent()

            self.nodeSystem.activate()

            self.scrollPosTimer =
                NSTimer.scheduledTimerWithTimeInterval(
                    1.0/24, target: self, selector: "smoothlyChangeScrollPos", userInfo: nil,
                    repeats: true)
            NSRunLoop.mainRunLoop().addTimer(self.scrollPosTimer, forMode: NSRunLoopCommonModes)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func moveToTemporalyNextEvent ()
    {
        // Assuming the events are sorted by date.
        let currDate = NSDate()
        struct SortRecord
        {
            let dateTime:NSDate
            let rowIndex:Int!
        }
        var sortArray = [SortRecord]()
        sortArray.append(SortRecord(dateTime: currDate, rowIndex: nil))
        for (rowIndex, listedEventRecord) in self.shownEvents.enumerate()
        {
            sortArray.append(
                SortRecord(
                    dateTime: listedEventRecord.eventRecord.dateTime, rowIndex: rowIndex))
        }
        sortArray.sortInPlace() { r0, r1 in
            return r0.dateTime.compare(r1.dateTime) == .OrderedAscending
        }
        var currDateIndex:Int!
        for (i, r) in sortArray.enumerate()
        {
            if r.rowIndex == nil
            {
                currDateIndex = i
                break
            }
        }
        var eventRowIndex:Int
        if currDateIndex < sortArray.count - 1
        {
            eventRowIndex = sortArray[currDateIndex + 1].rowIndex
        }
        else
        {
            eventRowIndex = self.shownEvents.count - 1
            if eventRowIndex < 0
            {
                eventRowIndex = 0
            }
        }

        self.moveToRowAtIndex(eventRowIndex)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func viewWillAppear (animated:Bool)
    {
        super.viewWillAppear(animated)

        if let currSelectedEventRowIndex = self.currSelectedEventRowIndex
        {
            self.eventsTableView.deselectRowAtIndexPath(
                NSIndexPath(forRow: currSelectedEventRowIndex, inSection: 0), animated: false)

            self.currSelectedEventRowIndex = nil
        }

        if self.viewDidAppearBefore
        {
            //self.reloadEventsAndTable()
            self.eventsTableView.reloadData()

            let numRows = self.eventsTableView.numberOfRowsInSection(0)
            if numRows != 0
            {
                let focusedEventRowIndex = self.calcCurrFocusedEventRowIndex()
                self.moveToRowAtIndex(focusedEventRowIndex)
            }
        }

        self.eventsTableView.flashScrollIndicators()

        self.isInPresentationMode = false
        self.presentedEvents = nil
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func viewDidAppear (animated:Bool)
    {
        super.viewDidAppear(animated)

        self.maybeDeleteOrRescheduleEvents()

        self.viewDidAppearBefore = true
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func didReceiveMemoryWarning ()
    {
        super.didReceiveMemoryWarning()

        //
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func preferredStatusBarStyle () -> UIStatusBarStyle
    {
        return .LightContent
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func numberOfSectionsInTableView (tableView:UITableView) -> Int
    {
        return 1
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func tableView (tableView:UITableView, numberOfRowsInSection section:Int) -> Int
    {
        return self.shownEvents.count
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func tableView (
        tableView:UITableView, cellForRowAtIndexPath indexPath:NSIndexPath) -> UITableViewCell
    {
        let cell =
            self.eventsTableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)

        cell.contentView.backgroundColor = UIColor.clearColor()
        cell.backgroundColor = UIColor.clearColor()

        if cell.viewWithTag(self.sepaTag) == nil
        {
            let separatorView = UIImageView(image: self.separatorImage)
            separatorView.tag = self.sepaTag
            separatorView.center =
                CGPoint(
                    x: cell.bounds.midX,
                    y: cell.bounds.maxY - self.separatorImage.size.height/2.0)
            cell.addSubview(separatorView)
        }
        let numRows = self.eventsTableView.numberOfRowsInSection(0)
        if indexPath.row == numRows - 1 && numRows != 1
        {
            cell.viewWithTag(self.sepaTag)?.removeFromSuperview()
        }

        let bgColorView = UIView()
        bgColorView.backgroundColor = AppConfiguration.bluishColor.colorWithAlphaComponent(0.0)
        cell.selectedBackgroundView = bgColorView

        let eventRecord = self.shownEvents[indexPath.row].eventRecord

        let textLabel = cell.viewWithTag(18) as! UILabel

        let currDate = NSDate()
        if eventRecord.dateTime.compare(currDate) != .OrderedAscending
        {
            textLabel.textColor = UIColor.whiteColor()
        }
        else
        {
            textLabel.textColor =
                UIColor.whiteColor().colorWithAlphaComponent(self.pastEventsTitleAlpha)
        }

        textLabel.font = UIFont.systemFontOfSize(self.eventsTitleFontSize)
        textLabel.text = eventRecord.title

        return cell
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func tableView (tableView:UITableView, didSelectRowAtIndexPath indexPath:NSIndexPath)
    {
        self.selectedRowOneTimeClosure = {
            self.currSelectedEventRowIndex = indexPath.row

            self.isInPresentationMode = true
            self.presentedEvents = self.allEvents

            let sb = UIStoryboard(name: "EventPresenter", bundle: nil)
            let vc = sb.instantiateInitialViewController() as! EventPresenterViewController
            vc.dataSource = self
            vc.modalTransitionStyle = .CrossDissolve
            self.presentViewController(vc, animated: true, completion: nil)

            self.selectedRowOneTimeClosure = nil
        }

        let offsetY =
            -(self.eventsTableViewInsetTop - CGFloat(indexPath.row)*self.eventsTableViewRowHeight)
        self.eventsTableView.setContentOffset(CGPoint(x: 0.0, y: offsetY), animated: true)
        self.targetScrollPos = CGFloat(indexPath.row)
        self.eventsTableViewPrevOffset = nil

        appD().ignoringInteractionEvents.begin()

        if let cell = self.eventsTableView.cellForRowAtIndexPath(indexPath)
        {
            let textLabel = cell.viewWithTag(18) as! UILabel
            UIView.animateWithDuration(0.25) {
                textLabel.textColor = AppConfiguration.purpleColor
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func focusEventRowIfNeeded ()
    {
        if let eventsTableViewPrevOffset = self.eventsTableViewPrevOffset where
           self.eventsTableView.contentOffset.y == eventsTableViewPrevOffset
        {
            self.eventsTableViewFocus()
        }

        self.eventsTableViewPrevOffset = self.eventsTableView.contentOffset.y
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func calcCurrFocusedEventRowIndex () -> Int
    {
        let numRows = self.eventsTableView.numberOfRowsInSection(0)
        assert(numRows != 0)
        let normOffset = self.eventsTableView.contentOffset.y + self.eventsTableViewInsetTop
        var rowIndex =
            Int(round(normOffset/self.eventsTableView.contentSize.height*CGFloat(numRows)))
        if rowIndex < 0
        {
            rowIndex = 0
        }
        else if rowIndex > numRows - 1
        {
            rowIndex = numRows - 1
        }
        return rowIndex
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func eventsTableViewFocus ()
    {
        if self.eventsTableView.dragging
        {
            return
        }

        if self.isEventsTableViewBeingAnimated()
        {
            return
        }

        let numRows = self.eventsTableView.numberOfRowsInSection(0)
        if numRows == 0
        {
            return
        }

        let currFocusedEventRowIndex = self.calcCurrFocusedEventRowIndex()
        let snappedOffset = CGFloat(currFocusedEventRowIndex)*CGFloat(self.eventsTableViewRowHeight)

        let targetOffset = snappedOffset - self.eventsTableViewInsetTop
        if self.eventsTableView.contentOffset.y != targetOffset
        {
            self.eventsTableView.setContentOffset(CGPoint(x: 0.0, y: targetOffset), animated: true)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func scrollViewWillBeginDragging (scrollView:UIScrollView)
    {
        self.eventsTableView.setContentOffset(self.eventsTableView.contentOffset, animated: false)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func scrollViewDidScroll (scrollView:UIScrollView)
    {
        if self.eventsTableViewInsetTop == nil
        {
            return
        }

        let normOffset = self.eventsTableView.contentOffset.y + self.eventsTableViewInsetTop
        self.targetScrollPos = normOffset/self.eventsTableViewRowHeight
        let numRows = self.eventsTableView.numberOfRowsInSection(0)
        let minPos = CGFloat(-1.0)
        let maxPos = CGFloat(numRows)
        if self.targetScrollPos < minPos
        {
            self.targetScrollPos = minPos
        }
        else if self.targetScrollPos > maxPos
        {
            self.targetScrollPos = maxPos
        }

        for cell in self.eventsTableView.visibleCells
        {
            if let separatorView = cell.viewWithTag(self.sepaTag)
            {
                let y =
                    self.eventsTableViewContainer.convertPoint(
                        CGPointZero, fromView: separatorView).y
                let yDiff = abs(y - self.eventsTableViewInsetTop)
                let diffThreshold = self.eventsTableViewRowHeight*0.5
                separatorView.alpha = pow(yDiff > diffThreshold ? 1.0 : yDiff/diffThreshold, 2.0)
            }

            let y = self.eventsTableViewContainer.convertPoint(CGPointZero, fromView: cell).y
            let yDiff = y - self.eventsTableViewInsetTop
            let yAbsDiff = abs(yDiff)
            let diffThreshold = self.eventsTableViewRowHeight*1.0
            var standoutFactor = yAbsDiff > diffThreshold ? 0.0 : 1.0 - yAbsDiff/diffThreshold
            standoutFactor =
                CGFloat(self.dynamicType.easeInOutSine(Double(standoutFactor), 0.0, 1.0, 1.0))
            if yDiff <= 0.0
            {
                standoutFactor = 1.0
            }
            let textLabel = cell.viewWithTag(18) as! UILabel
            if standoutFactor > 0.0
            {
                //cell.contentView.layer.shadowColor = AppConfiguration.bluishColor.CGColor
                //cell.contentView.layer.shadowOpacity = Float(standoutFactor)
                //cell.contentView.layer.shadowRadius = standoutFactor*5.0
                //cell.contentView.layer.shadowOffset = CGSizeZero

                let scale = 1.0 + standoutFactor*(self.eventsTitleMaxScale - 1.0)
                textLabel.transform = CGAffineTransformMakeScale(scale, scale)
            }
            else
            {
                //cell.contentView.layer.shadowColor = nil
                //cell.contentView.layer.shadowOpacity = 0.0
                //cell.contentView.layer.shadowRadius = 0.0
                //cell.contentView.layer.shadowOffset = CGSizeZero

                textLabel.transform = CGAffineTransformIdentity
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func moveToRowAtIndex (rowIndex:Int)
    {
        if self.eventsTableViewInsetTop != nil
        {
            self.eventsTableView.contentOffset.y =
                -self.eventsTableViewInsetTop + CGFloat(rowIndex)*self.eventsTableViewRowHeight
        }
        self.targetScrollPos = CGFloat(rowIndex)
        self.currScrollPos = self.targetScrollPos
        self.scrollViewDidScroll(self.eventsTableView)

        var squareSnapshot:UIImage!
        if 0 <= rowIndex && rowIndex < self.shownEvents.count
        {
            let eventRecord = self.shownEvents[rowIndex].eventRecord
            squareSnapshot = eventRecord.backgroundRecord?.squareSnapshot
        }
        if squareSnapshot == nil
        {
            squareSnapshot = BackgroundRecord.squareDefaultPicture
        }
        self.eventsViewBackgroundImageView.image = squareSnapshot

        self.updateEventsView()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func smoothlyChangeScrollPos ()
    {
        if self.currScrollPos != self.targetScrollPos
        {
            let speedFactor:CGFloat
            let snapDist:CGFloat
            let maxSpeed:CGFloat
            if self.selectedRowOneTimeClosure == nil
            {
                speedFactor = self.scrollPosSpeedFactor
                snapDist = self.scrollPosSnapDist
                maxSpeed = self.scrollPosMaxSpeed
            }
            else
            {
                speedFactor = self.scrollPosSpeedFactorForFastMode
                snapDist = self.scrollPosSnapDistForFastMode
                maxSpeed = self.scrollPosMaxSpeedForFastMode
            }

            let absDiff = abs(self.currScrollPos - self.targetScrollPos)
            if absDiff > snapDist
            {
                var delta = (self.targetScrollPos - self.currScrollPos)*speedFactor
                if abs(delta) > maxSpeed
                {
                    delta = maxSpeed*sign(delta)
                }
                self.currScrollPos! += delta
            }
            else
            {
                self.currScrollPos = self.targetScrollPos
            }

            self.updateEventsView()
        }
        else if let selectedRowOneTimeClosure = self.selectedRowOneTimeClosure
        {
            appD().ignoringInteractionEvents.end()
            selectedRowOneTimeClosure()
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func updateEventsView ()
    {
        if self.currScrollPos == nil || self.nodeSystem == nil
        {
            return
        }

        let numRows = self.eventsTableView.numberOfRowsInSection(0)

        for listedEventRecord in self.allEvents
        {
            listedEventRecord.dateTimeLB.removeFromSuperview()
        }

        let baseRowIndex = Int(floor(self.currScrollPos))
        let nextRowIndex = baseRowIndex + 1
        let giBaseSnapshot:GPUImagePicture
        let giNextSnapshot:GPUImagePicture
        if 0 <= baseRowIndex && baseRowIndex < numRows
        {
            let listedEventRecord = self.shownEvents[baseRowIndex]

            giBaseSnapshot = listedEventRecord.giSnapshot

            self.insertAndFadeDateTimeLB(listedEventRecord.dateTimeLB, rowIndex: baseRowIndex)
        }
        else
        {
            giBaseSnapshot = self.giDefaultPictureSnapshotBefore
        }
        if 0 <= nextRowIndex && nextRowIndex < numRows
        {
            let listedEventRecord = self.shownEvents[nextRowIndex]

            giNextSnapshot = listedEventRecord.giSnapshot

            self.insertAndFadeDateTimeLB(listedEventRecord.dateTimeLB, rowIndex: nextRowIndex)
        }
        else
        {
            giNextSnapshot = self.giDefaultPictureSnapshotAfter
        }
        let ratio = self.currScrollPos - CGFloat(baseRowIndex)

        self.nodeSystem.beginUpdates()
        if self.eventImageA.giPicture !== giBaseSnapshot
        {
            giBaseSnapshot.removeAllTargets()
            self.eventImageA.giPicture = giBaseSnapshot
        }
        if self.eventImageB.giPicture !== giNextSnapshot
        {
            giNextSnapshot.removeAllTargets()
            self.eventImageB.giPicture = giNextSnapshot
        }
        if numRows != 0
        {
            self.blurFilterA["blurRadiusInPixels"] = pow(ratio, 0.75)*self.eventsViewMaxBlurRadius
            self.blurFilterB["blurRadiusInPixels"] = (1.0 - ratio)*self.eventsViewMaxBlurRadius
            self.oMergeBlender["mix"] = ratio
        }
        else
        {
            self.blurFilterA["blurRadiusInPixels"] = 0.0
            self.blurFilterB["blurRadiusInPixels"] = 0.0
            self.oMergeBlender["mix"] = 0.0
        }
        self.nodeSystem.endUpdates()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func insertAndFadeDateTimeLB (label:UILabel, rowIndex:Int)
    {
        if label.window == nil
        {
            label.frame = self.eventDateLB.frame
            self.eventDateLB.superview!.addSubview(label)
        }

        let dist = abs(self.currScrollPos - CGFloat(rowIndex))
        label.alpha = (1.0 - dist)*self.eventDateTimeLBMaxAlpha
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func provideInputDataForEventEditViewController () -> [String: AnyObject]
    {
        var data = [String: AnyObject]()

        if let currSelectedEventRowIndex = self.currSelectedEventRowIndex
        {
            let eventRecord = self.shownEvents[currSelectedEventRowIndex].eventRecord
            data["eventRecord"] = eventRecord
        }

        return data
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func eventEditViewControllerWillDeleteEventWithID (eventID:String)
    {
        // Empty.
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func acceptOutputDataFromEventEditViewController (data:[String: AnyObject])
    {
        // New event, modified event, or deleted event while not in the presentation mode.

        self.eventRecordDidChangeWithEventEditData(data)

        if let id = data["changedEventID"] as? String
        {
            if let changedEventRowIndex = self.shownEvents.indexOf({ $0.eventRecord.id == id })
            {
                self.moveToRowAtIndex(changedEventRowIndex)
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func eventEditViewControllerDidCancel ()
    {
        // Empty.
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func initialEventIndex () -> Int
    {
        let eventID = self.shownEvents[self.currSelectedEventRowIndex].eventRecord.id
        return self.presentedEvents.indexOf({ $0.eventRecord.id == eventID })!
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func eventRecordForEventIndex (eventIndex:Int) -> EventRecord?
    {
        if 0 <= eventIndex && eventIndex < self.presentedEvents.count
        {
            return self.presentedEvents[eventIndex].eventRecord
        }
        else
        {
            return nil
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func eventRecordDidChangeWithEventEditData (data:[String: AnyObject])
    {
        // New event, modified event, or deleted event whether or not in the presentation mode.

        self.disableTagFiltering()

        if let changedEventID = data["changedEventID"] as? String
        {
            self.cachedListedEventRecords.removeValueForKey(changedEventID)
        }
        else if let deletedEventID = data["deletedEventID"] as? String
        {
            self.cachedListedEventRecords.removeValueForKey(deletedEventID)
        }

        self.reloadEventsAndTable()

        // For presentation.
        if self.isInPresentationMode
        {
            if let changedEventID = data["changedEventID"] as? String
            {
                if let eventIndexSrc =
                   self.allEvents.indexOf({ $0.eventRecord.id == changedEventID })
                {
                    if let eventIndexDst =
                       self.presentedEvents.indexOf({ $0.eventRecord.id == changedEventID })
                    {
                        self.presentedEvents[eventIndexDst] = self.allEvents[eventIndexSrc]
                    }
                }
            }
            else if let deletedEventID = data["deletedEventID"] as? String
            {
                if let eventIndex =
                   self.presentedEvents.indexOf({ $0.eventRecord.id == deletedEventID })
                {
                    self.presentedEvents.removeAtIndex(eventIndex)
                }
            }
        }

        self.updateEventsView()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func eventsViewDidReceiveTap (recognizer:UITapGestureRecognizer)
    {
        let numRows = self.eventsTableView.numberOfRowsInSection(0)
        if numRows == 0
        {
            return
        }
        let focusedEventRowIndex = self.calcCurrFocusedEventRowIndex()
        self.tableView(
            self.eventsTableView,
            didSelectRowAtIndexPath: NSIndexPath(forRow: focusedEventRowIndex, inSection: 0))

    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func eventsViewDidReceiveDoubleTap ()
    {
        let numRows = self.eventsTableView.numberOfRowsInSection(0)
        if numRows == 0
        {
            return
        }
        let focusedEventRowIndex = self.calcCurrFocusedEventRowIndex()
        self.tableView(
            self.eventsTableView,
            didSelectRowAtIndexPath: NSIndexPath(forRow: focusedEventRowIndex, inSection: 0))
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func tableView (
        tableView:UITableView, editActionsForRowAtIndexPath indexPath:NSIndexPath) ->
            [UITableViewRowAction]?
    {
        let rowActionDelete = UITableViewRowAction(style: .Default, title: "Delete",
            handler: { rowAction, indexPath in
                let alert =
                    UIAlertController(
                        title: nil,
                        message: "Are you sure you want to delete this event?",
                        preferredStyle: .Alert)
                alert.addAction(UIAlertAction(title: "No", style: .Cancel, handler: { _ in
                    self.eventsTableView.reloadRowsAtIndexPaths(
                        [indexPath], withRowAnimation: .Right)
                }))
                alert.addAction(UIAlertAction(title: "Yes", style: .Default, handler: { _ in
                    let eventID = self.shownEvents[indexPath.row].eventRecord.id

                    EventRecord.deleteEventWithID(eventID)

                    var data = [String: AnyObject]()
                    data["deletedEventID"] = eventID
                    self.eventRecordDidChangeWithEventEditData(data)
                    self.scrollViewDidScroll(self.eventsTableView)
                }))
                on_main() {
                    self.presentViewController(alert, animated: true, completion: nil)
                }
            })

        let rowActionEdit = UITableViewRowAction(style: .Normal, title: "Edit",
            handler: { rowAction, indexPath in
                if let isDemo = self.shownEvents[indexPath.row].eventRecord.isDemo where isDemo
                {
                    let message =
                        "This is a demo event." +
                        " You can create your own event by tapping the plus button."
                    on_main() {
                        doOKAlertWithTitle(
                            nil,
                            message: message,
                            okHandler: {
                                self.eventsTableView.reloadRowsAtIndexPaths(
                                    [indexPath], withRowAnimation: .Right)
                            })
                    }
                    return
                }

                self.currSelectedEventRowIndex = indexPath.row

                let eventEditVC =
                    UIStoryboard(name: "EventEdit", bundle: nil).instantiateInitialViewController()!
                let eventEditTableVC =
                    eventEditVC.childViewControllers.first! as! EventEditViewController
                eventEditTableVC.inputOutputDelegate = self
                self.presentViewController(eventEditVC, animated: true, completion: nil)
            })
        rowActionEdit.backgroundColor = AppConfiguration.bluishColor

        return [rowActionDelete, rowActionEdit]
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func tableView (
        tableView:UITableView, commitEditingStyle editingStyle:UITableViewCellEditingStyle,
        forRowAtIndexPath indexPath:NSIndexPath)
    {
        // Empty.
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func contentViewAlphaForPopoverController (popoverController:WYPopoverController!) -> CGFloat
    {
        return 0.95
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func currentlySelectedTagForEventListerTagsSelectorViewController() -> String?
    {
        return self.currEventsFilterTag
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func eventListerTagsSelectorViewControllerDidSelectTag (anyTags anyTags:Bool, tag:String?)
    {
        if !anyTags
        {
            self.enableTagFilteringWithTag(tag!)
        }
        else
        {
            self.disableTagFiltering()
        }

        self.eventsTableView.setContentOffset(self.eventsTableView.contentOffset, animated: false)

        self.eventsTableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Fade)
        self.moveToRowAtIndex(0)

        appD().ignoringInteractionEvents.begin()
        self.tagsPopover.dismissPopoverAnimated(
            true, completion: {
                appD().ignoringInteractionEvents.end()
            })
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func enableTagFilteringWithTag (tag:String)
    {
        self.currEventsFilterTag = tag

        self.filteredEvents = self.allEvents.filter { listedEventRecord -> Bool in
            if let tags = listedEventRecord.eventRecord.tags
            {
                return tags.map({ $0.lowercaseString }).contains(
                    self.currEventsFilterTag.lowercaseString)
            }
            else
            {
                return false
            }
        }

        self.tagsBN.layer.shadowColor = UIColor.whiteColor().CGColor
        self.tagsBN.layer.shadowOpacity = 1.0
        self.tagsBN.layer.shadowRadius = 6.0
        self.tagsBN.layer.shadowOffset = CGSizeZero
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func disableTagFiltering ()
    {
        self.currEventsFilterTag = nil
        self.filteredEvents = nil

        self.tagsBN.layer.shadowColor = nil
        self.tagsBN.layer.shadowOpacity = 0.0
        self.tagsBN.layer.shadowRadius = 0.0
        self.tagsBN.layer.shadowOffset = CGSizeZero
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private var shownEvents:[ListedEventRecord]
    {
        return self.filteredEvents ?? self.allEvents
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func maybeDeleteOrRescheduleEvents ()
    {
        if (self.view.window == nil && self.viewDidAppearBefore) ||
           self.isInPresentationMode
        {
            return
        }

        var eventsDidChange = false
        var deletedOrChangedEventIDs = [String]()

        let currDate = NSDate()
        let ud = NSUserDefaults.standardUserDefaults()
        for listedEventRecord in self.allEvents
        {
            let eventRecord = listedEventRecord.eventRecord
            if eventRecord.dateTime.compare(currDate) == .OrderedAscending
            {
                // The event is in the past.
                if eventRecord.repeatType == .DontRepeat
                {
                    if ud.boolForKey("autoDeletePassedEvents")
                    {
                        // Delete.
                        EventRecord.deleteEventWithID(eventRecord.id)

                        eventsDidChange = true
                        deletedOrChangedEventIDs.append(eventRecord.id)
                    }
                }
                else
                {
                    // Reschedule.
                    let calendar = NSCalendar.currentCalendar()
                    let dateComps = NSDateComponents()
                    dateComps.hour = calendar.component(.Hour, fromDate: eventRecord.dateTime)
                    dateComps.minute = calendar.component(.Minute, fromDate: eventRecord.dateTime)
                    dateComps.second = calendar.component(.Second, fromDate: eventRecord.dateTime)
                    if eventRecord.repeatType == .EveryWeek
                    {
                        dateComps.weekday =
                            calendar.component(.Weekday, fromDate: eventRecord.dateTime)
                    }
                    else if eventRecord.repeatType == .EveryMonth
                    {
                        dateComps.day =
                            calendar.component(.Day, fromDate: eventRecord.dateTime)
                    }
                    else if eventRecord.repeatType == .EveryYear
                    {
                        dateComps.month =
                            calendar.component(.Month, fromDate: eventRecord.dateTime)
                        dateComps.day =
                            calendar.component(.Day, fromDate: eventRecord.dateTime)
                    }
                    let newDate =
                        calendar.nextDateAfterDate(
                            eventRecord.dateTime, matchingComponents: dateComps,
                            options: .MatchNextTimePreservingSmallerUnits)
                    if let newDate = newDate
                    {
                        eventRecord.dateTime = newDate
                        EventRecord.saveEventRecord(eventRecord)

                        eventsDidChange = true
                        deletedOrChangedEventIDs.append(eventRecord.id)
                    }
                }
            }
        }

        if eventsDidChange
        {
            if self.view.window != nil
            {
                let hud = MBProgressHUD.showHUDAddedTo(self.view, animated: true)
                hud.mode = .Text
                hud.labelText = "Updating..."
                hud.labelFont = UIFont.systemFontOfSize(14.0)
                hud.removeFromSuperViewOnHide = true
                hud.hide(true, afterDelay: 2.0)
            }

            self.disableTagFiltering()
            for eventID in deletedOrChangedEventIDs
            {
                self.cachedListedEventRecords.removeValueForKey(eventID)
            }
            self.reloadEventsAndTable()
            self.moveToRowAtIndex(0)
            self.updateEventsView()
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func provideInputDataForSettingsViewController () -> [String: AnyObject]
    {
        var data = [String: AnyObject]()
        data["events"] = self.allEvents.map { $0.eventRecord }
        return data
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func settingsViewControllerDidChangeEvents (deletedOrChangedEventIDs:[String])
    {
        self.disableTagFiltering()
        for eventID in deletedOrChangedEventIDs
        {
            self.cachedListedEventRecords.removeValueForKey(eventID)
        }
        self.reloadEventsAndTable()
        self.moveToRowAtIndex(0)
        self.updateEventsView()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func isEventsTableViewBeingAnimated () -> Bool
    {
        if let animationKeys = self.eventsTableView.layer.animationKeys() where
           !animationKeys.isEmpty
        {
            return true
        }
        else
        {
            return false
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func maybeRescheduleEventNotifications ()
    {
        let app = UIApplication.sharedApplication()

        app.cancelAllLocalNotifications()

        var eventRecordsForNotifications = [EventRecord]()
        for listedEventRecord in self.allEvents
        {
            if listedEventRecord.eventRecord.notification!
            {
                eventRecordsForNotifications.append(listedEventRecord.eventRecord)
            }
        }
        if !eventRecordsForNotifications.isEmpty
        {
            if let currNotifSettings = app.currentUserNotificationSettings()
            {
                if !currNotifSettings.types.contains(.Alert)
                {
                    if !self.notifDisabledAlertWasAlreadyDisplayed
                    {
                        let message =
                            "You have notifications enabled for some of your events." +
                            " However, notifications are not allowed for the app in" +
                            " your device's Settings."
                        on_main_with_delay(1.0) {
                            doOKAlertWithTitle(nil, message: message)
                        }

                        self.notifDisabledAlertWasAlreadyDisplayed = true
                    }

                    return
                }
            }

            for eventRecord in eventRecordsForNotifications
            {
                let notif = UILocalNotification()
                notif.category = AppConfiguration.eventDidArriveNotificationCategoryID
                notif.alertBody = eventRecord.title
                notif.fireDate = eventRecord.dateTime
                notif.soundName = UILocalNotificationDefaultSoundName
                app.scheduleLocalNotification(notif)
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func deactivate ()
    {
        self.focusEventRowIfNeededTimer?.invalidate()
        self.focusEventRowIfNeededTimer = nil
        self.scrollPosTimer?.invalidate()
        self.scrollPosTimer = nil
        self.maybeDeleteOrRescheduleEventsTimer.invalidate()
        self.maybeDeleteOrRescheduleEventsTimer = nil
    }

    //----------------------------------------------------------------------------------------------

    @IBAction private func addEventBNAction ()
    {
        self.currSelectedEventRowIndex = nil

        let eventEditVC =
            UIStoryboard(name: "EventEdit", bundle: nil).instantiateInitialViewController()!
        let eventEditTableVC = eventEditVC.childViewControllers.first! as! EventEditViewController
        eventEditTableVC.inputOutputDelegate = self
        self.presentViewController(eventEditVC, animated: true, completion: nil)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction private func tagsBNAction (sender:AnyObject)
    {
        let vc =
            UIStoryboard(
                name: "EventListerTagsSelector", bundle: nil).instantiateInitialViewController()!
        let tagsSelectorVC = vc as! EventListerTagsSelectorViewController
        tagsSelectorVC.preferredContentSize = CGSize(width: 190.0, height: 7*44.0)
        tagsSelectorVC.delegate = self

        self.tagsPopover = WYPopoverController(contentViewController: tagsSelectorVC)
        self.tagsPopover.delegate = self
        let sourceView = sender as! UIView
        appD().ignoringInteractionEvents.begin()
        let rect =
            sourceView.bounds.insetBy(
                dx: sourceView.bounds.width/4.0, dy: sourceView.bounds.height/4.0)
        self.tagsPopover.presentPopoverFromRect(
            rect, inView: sourceView, permittedArrowDirections: .Left, animated: true,
            options: .FadeWithScale, completion: {
                appD().ignoringInteractionEvents.end()
            })
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction private func prevEventBNAction ()
    {
        if self.shownEvents.isEmpty
        {
            return
        }

        self.eventsTableViewPrevOffset = nil
        var offsetY = self.eventsTableView.contentOffset.y - self.eventsTableViewRowHeight
        let minOffset:CGFloat = -self.eventsTableViewRowHeight*0.75
        if offsetY < minOffset
        {
            offsetY = minOffset
        }
        self.eventsTableView.setContentOffset(
            CGPoint(
                x: 0.0,
                y: offsetY),
            animated: true)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction private func nextEventBNAction ()
    {
        if self.shownEvents.isEmpty
        {
            return
        }
        
        self.eventsTableViewPrevOffset = nil
        self.eventsTableView.setContentOffset(
            CGPoint(
                x: 0.0,
                y: self.eventsTableView.contentOffset.y + self.eventsTableViewRowHeight),
            animated: true)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction private func settingsBNAction ()
    {
        let vc =
            UIStoryboard(
                name: "Settings", bundle: nil).instantiateInitialViewController()!
        let settingsVC = vc.childViewControllers.first! as! SettingsViewController
        settingsVC.delegate = self

        self.presentViewController(vc, animated: true, completion: nil)
    }

    //----------------------------------------------------------------------------------------------

    private class func easeInOutSine (t:Double, _ b:Double, _ c:Double, _ d:Double) -> Double
    {
        return -c/2.0*(cos(M_PI*t/d) - 1.0) + b
    }

    //----------------------------------------------------------------------------------------------
}



