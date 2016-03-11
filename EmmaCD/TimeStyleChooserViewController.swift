import Viewmorphic


//--------------------------------------------------------------------------------------------------

protocol TimeStyleChooserViewControllerInputOutput : class
{
    func provideInputDataForTimeStyleChooserViewController () -> [String: AnyObject]
    func acceptOutputDataFromTimeStyleChooserViewController (data:[String: AnyObject])
}

//--------------------------------------------------------------------------------------------------


class TimeStyleChooserViewController : UIViewController, UITableViewDataSource, UITableViewDelegate
{
    weak var inputOutputDelegate:TimeStyleChooserViewControllerInputOutput!
    private var inputData:[String: AnyObject]!

    @IBOutlet private weak var stylesTableViewContainer:UIView!
    @IBOutlet private weak var stylesTableView:UITableView!
    @IBOutlet private weak var backgroundImageViewContainer:UIView!
    @IBOutlet private weak var backgroundImageView:UIImageView!
    @IBOutlet private weak var cancelBN:UIButton!
    @IBOutlet private weak var doneBN:UIButton!

    private let digitStyleIDs = [
        "25",
        "10",
        "01",
        "19",
        "04",
        "15",
        "07",
        "06",
        "16",
        "02",
        "22",
        "21",
        "23",
        "24",
        "08",
        "11",
        "09",
        "18",
    ]

    private var hiddenTimeStyles:[TimeStyleRecord.TimeStyle] = [
        .D4p_H_Mi_S,
        .D4p_S,
        .S8p,
        .Heartbeats8p,
    ]

    private let refRowHeight = 140.0
    private let stylesFocusOffset = 140.0
    private let digitsViewPaddingH = 20.0
    private let digitsViewPaddingHMore = 44.0
    private let digitsViewPaddingV = 26.0
    private var numFirstSyncLoadedDigitsViews:Int! = 3
    private let initTimeStyle = TimeStyleRecord.TimeStyle.S6p
    private var useTimeStyles:[TimeStyleRecord.TimeStyle] = []
    private var currTimeStyle:TimeStyleRecord.TimeStyle
    private var currFocusedStyleRowIndex:Int
    private var timeStylesToCountdownValues = [Int: [Int: Double]]()
    private var initialTimeStylesToCountdownValues:[Int: [Int: Double]]
    private let cornerRadius = 12.0
    private var asyncQueue:dispatch_queue_t
    private var digitsViews = [DigitsView!]()
    private var stylesTableViewPrevOffset:CGFloat!
    private var timeStyleSlider:TGPDiscreteSlider!
    private var focusStyleIfNeededTimer:NSTimer!
    private var countdownSecondTimer:NSTimer!
    private var countdownBreathTimer:NSTimer!
    private var countdownHeartbeatTimer:NSTimer!
    private var once = 0

    //----------------------------------------------------------------------------------------------

    required init? (coder aDecoder:NSCoder)
    {
        var rawValue = 0
        while true
        {
            let timeStyle = TimeStyleRecord.TimeStyle(rawValue: rawValue)
            if let timeStyle = timeStyle where !self.hiddenTimeStyles.contains(timeStyle)
            {
                self.useTimeStyles.append(timeStyle)
            }
            else if timeStyle == nil
            {
                break
            }
            rawValue++
        }

        let ud = NSUserDefaults.standardUserDefaults()
        let udInitTimeStyle = ud.objectForKey("initTimeStyle") as? Int
        if udInitTimeStyle == nil
        {
            self.currTimeStyle = self.initTimeStyle
        }
        else
        {
            self.currTimeStyle = TimeStyleRecord.TimeStyle(rawValue: udInitTimeStyle!)!
        }

        self.currFocusedStyleRowIndex = 0

        for timeStyle in self.useTimeStyles
        {
            var countdownValue:Double!

            switch timeStyle
            {
            case .Y_Mo_D_H_Mi_S:
                let dateComps = NSDateComponents()
                dateComps.calendar = NSCalendar.currentCalendar()
                dateComps.year = 1970 + 1
                dateComps.month = 7
                dateComps.day = 16
                dateComps.hour = 15
                dateComps.minute = 30
                dateComps.second = 59
                countdownValue = dateComps.date!.timeIntervalSince1970
            case .Mo_D_H_Mi_S:
                let dateComps = NSDateComponents()
                dateComps.calendar = NSCalendar.currentCalendar()
                dateComps.year = 1970 + 1
                dateComps.month = 7
                dateComps.day = 16
                dateComps.hour = 15
                dateComps.minute = 30
                dateComps.second = 59
                countdownValue = dateComps.date!.timeIntervalSince1970
            case .D3p_H_Mi_S:
                let dateComps = NSDateComponents()
                dateComps.calendar = NSCalendar.currentCalendar()
                dateComps.year = 1970 + 0
                dateComps.month = 1
                dateComps.day = 13
                dateComps.hour = 15
                dateComps.minute = 30
                dateComps.second = 59
                countdownValue = dateComps.date!.timeIntervalSince1970
            case .D3p_S:
                countdownValue = 12*86400 + 1234
            case .D:
                countdownValue = 122*86400
            case .S6p:
                countdownValue = 12345
            case .Breaths:
                countdownValue = 12345*AppConfiguration.breathDuration
            case .Heartbeats6p:
                countdownValue = 12345*AppConfiguration.heartbeatDuration
            default:
                assert(false)
            }

            var digitStylesToCountdownValues = [Int: Double]()
            for rowIndex in 0..<self.digitStyleIDs.count
            {
                digitStylesToCountdownValues[rowIndex] = countdownValue
            }
            self.timeStylesToCountdownValues[timeStyle.rawValue] = digitStylesToCountdownValues
        }
        self.initialTimeStylesToCountdownValues = self.timeStylesToCountdownValues

        let queueLabel = "TimeStyleChooserViewController.asyncQueue"
        self.asyncQueue = dispatch_queue_create(queueLabel, DISPATCH_QUEUE_SERIAL)

        if self.numFirstSyncLoadedDigitsViews == nil
        {
            self.numFirstSyncLoadedDigitsViews = self.digitStyleIDs.count
        }

        for _ in 0..<self.digitStyleIDs.count
        {
            self.digitsViews.append(nil)
        }

        super.init(coder: aDecoder)
    }

    //----------------------------------------------------------------------------------------------

    override func viewDidLoad ()
    {
        super.viewDidLoad()

        self.inputData =
            self.inputOutputDelegate.provideInputDataForTimeStyleChooserViewController()

        self.view.backgroundColor = AppConfiguration.backgroundChooserBackgroundColor

        self.cancelBN.setTitleColor(AppConfiguration.bluishColor, forState: .Normal)
        self.doneBN.setTitleColor(AppConfiguration.bluishColor, forState: .Normal)

        self.backgroundImageViewContainer.layer.cornerRadius = CGFloat(self.cornerRadius)
        var backgroundImage:UIImage! = self.inputData["backgroundImage"] as? UIImage
        if backgroundImage == nil
        {
            backgroundImage = AppConfiguration.defaultPicture
        }
        backgroundImage =
            NodeSystem.filteredImageFromImage(
                backgroundImage, filterType: .GaussianBlur, settings: ["blurRadiusInPixels": 26.0])
        backgroundImage =
            NodeSystem.filteredImageFromImage(
                backgroundImage, filterType: .Gamma, settings: ["gamma": 1.5])
        self.backgroundImageView.image = backgroundImage
        self.backgroundImageView.layer.cornerRadius = CGFloat(self.cornerRadius)
        self.backgroundImageView.layer.masksToBounds = true

        self.stylesTableView.dataSource = self
        self.stylesTableView.delegate = self
        self.stylesTableView.separatorStyle = .None
        self.stylesTableView.backgroundColor = UIColor.clearColor()
        self.stylesTableView.rowHeight = CGFloat(self.refRowHeight)
        self.stylesTableView.showsVerticalScrollIndicator = false
        self.stylesTableView.decelerationRate = 0.95
        self.stylesTableView.contentInset.top = CGFloat(self.stylesFocusOffset)
        self.stylesTableView.contentInset.bottom =
            self.view.bounds.height - CGFloat(self.stylesFocusOffset + self.refRowHeight)

        self.focusStyleIfNeededTimer = NSTimer.scheduledTimerWithTimeInterval(
            0.1, target: self, selector: "focusStyleIfNeeded", userInfo: nil, repeats: true)

        self.countdownSecondTimer =
            NSTimer.scheduledTimerWithTimeInterval(
                1.0, target: self, selector: "countdownSecond", userInfo: nil, repeats: true)
        self.countdownBreathTimer =
            NSTimer.scheduledTimerWithTimeInterval(
                AppConfiguration.breathDuration, target: self, selector: "countdownBreath",
                userInfo: nil, repeats: true)
        self.countdownHeartbeatTimer =
            NSTimer.scheduledTimerWithTimeInterval(
                AppConfiguration.heartbeatDuration, target: self, selector: "countdownHeartbeat",
                userInfo: nil, repeats: true)

        let swipeLeftGR = UISwipeGestureRecognizer(target: self, action: "didSwipeLeft")
        swipeLeftGR.direction = .Left
        self.stylesTableView.addGestureRecognizer(swipeLeftGR)
        let swipeRightGR = UISwipeGestureRecognizer(target: self, action: "didSwipeRight")
        swipeRightGR.direction = .Right
        self.stylesTableView.addGestureRecognizer(swipeRightGR)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func viewDidLayoutSubviews ()
    {
        super.viewDidLayoutSubviews()

        dispatch_once(&self.once) {
            self.stylesTableViewContainer.layoutSubviews()

            self.backgroundImageViewContainer.layer.shadowOpacity = 0.33
            self.backgroundImageViewContainer.layer.shadowColor =
                AppConfiguration.bluishColor.CGColor
            self.backgroundImageViewContainer.layer.shadowRadius = 12.0
            self.backgroundImageViewContainer.layer.shadowOffset = CGSizeZero
            let shadowPath =
                UIBezierPath(
                    roundedRect: self.backgroundImageViewContainer.bounds,
                    cornerRadius: CGFloat(self.cornerRadius))
            self.backgroundImageViewContainer.layer.shadowPath = shadowPath.CGPath

            let timeStyleSliderPaddingX:CGFloat = 22.0
            let timeStyleSliderPaddingY:CGFloat = 32.0
            var frame = self.view.frame
            frame.size.height = 50.0
            frame.origin.y += self.view.frame.height - frame.size.height - timeStyleSliderPaddingY
            frame.insetInPlace(
                dx: (frame.width - (frame.width - timeStyleSliderPaddingX*2.0))/2.0, dy: 0.0)
            frame.origin.x = timeStyleSliderPaddingX
            self.timeStyleSlider = TGPDiscreteSlider(frame: frame)
            self.timeStyleSlider.tickCount = Int32(self.useTimeStyles.count)
            self.timeStyleSlider.incrementValue = 1
            self.timeStyleSlider.tickStyle = 2
            self.timeStyleSlider.opaque = false
            self.timeStyleSlider.minimumValue = 0.0
            self.timeStyleSlider.trackStyle = 2
            self.timeStyleSlider.trackThickness = 0.5
            self.timeStyleSlider.tickSize = CGSize(width: 10.0, height: 10.0)
            self.timeStyleSlider.tintColor = AppConfiguration.bluishColor
            self.timeStyleSlider.thumbStyle = 2
            self.timeStyleSlider.thumbColor = UIColor.whiteColor()
            self.timeStyleSlider.thumbSize = CGSize(width: 30.0, height: 30.0)
            self.timeStyleSlider.thumbSRadius = 2.0
            self.timeStyleSlider.thumbSOffset = CGSizeZero
            self.timeStyleSlider.alpha = 0.5
            self.timeStyleSlider.layer.shouldRasterize = true
            self.timeStyleSlider.layer.rasterizationScale = UIScreen.mainScreen().scale
            self.timeStyleSlider.addTarget(
                self, action: "timeStyleSliderValueChanged", forControlEvents: .ValueChanged)
            self.timeStyleSlider.autoresizingMask = [.FlexibleRightMargin]
            self.view.addSubview(self.timeStyleSlider)

            self.timeStyleSlider.value = CGFloat(self.useTimeStyles.indexOf(self.currTimeStyle)!)

            let focusTop =
                CGFloat(self.stylesFocusOffset)/self.stylesTableViewContainer.bounds.height
            let bottomY = CGFloat(self.refRowHeight*DigitsView.maxDisplayHeightScale())
            let focusBottom = focusTop + (bottomY/self.stylesTableViewContainer.bounds.height)*0.9
            let colors = [
                UIColor.whiteColor().colorWithAlphaComponent(0.0).CGColor,
                UIColor.whiteColor().colorWithAlphaComponent(0.2).CGColor,
                UIColor.whiteColor().colorWithAlphaComponent(1.0).CGColor,
                UIColor.whiteColor().colorWithAlphaComponent(1.0).CGColor,
                UIColor.whiteColor().colorWithAlphaComponent(0.2).CGColor,
                UIColor.whiteColor().colorWithAlphaComponent(0.0).CGColor,
            ]
            let locations = [
                focusTop*0.15,
                focusTop - 0.033 + 0.016,
                focusTop + 0.033 + 0.016,
                focusBottom - 0.066,
                focusBottom,
                focusBottom + (1.0 - focusBottom)*0.7,
            ]
            let stylesTableViewFadeOut = CAGradientLayer()
            stylesTableViewFadeOut.frame = self.stylesTableViewContainer.bounds
            stylesTableViewFadeOut.colors = colors
            stylesTableViewFadeOut.locations = locations
            self.stylesTableViewContainer.layer.mask = stylesTableViewFadeOut

            for (styleIndex, digitStyleID) in self.digitStyleIDs.enumerate()
            {
                let tarFileName = "DigitStyle\(digitStyleID).tar"
                let tarURL = NSBundle.mainBundle().URLForResource(tarFileName, withExtension: nil)!
                let frame = CGRect(origin: CGPointZero, size: CGSize(width: 16.0, height: 16.0))

                let assignDigitsView = { [weak self] (digitsView:DigitsView, async:Bool) in
                    guard let sSelf = self else
                    {
                        return
                    }

                    digitsView.loopAnimationEnabled = false
                    sSelf.digitsViews[styleIndex] = digitsView
                    if async
                    {
                        sSelf.scrollViewDidScroll(sSelf.stylesTableView)
                        sSelf.stylesTableView.reloadData()
                    }
                }

                if styleIndex < self.numFirstSyncLoadedDigitsViews
                {
                    let digitsView =
                        DigitsView(
                            frame: frame, sourceTarURL: tarURL, styleID: digitStyleID,
                            pushyTimers: true)
                    
                    assignDigitsView(digitsView, false)
                }
                else
                {
                    dispatch_async(self.asyncQueue) {
                        let digitsView =
                            DigitsView(
                                frame: frame, sourceTarURL: tarURL, styleID: digitStyleID,
                                pushyTimers: true)
                        
                        on_main() {
                            assignDigitsView(digitsView, true)
                        }
                    }
                }
            }
            self.scrollViewDidScroll(self.stylesTableView)
            self.stylesTableView.reloadData()
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func viewWillAppear (animated:Bool)
    {
        super.viewWillAppear(animated)

        self.scrollViewDidScroll(self.stylesTableView)
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

    func numberOfSectionsInTableView (tableView:UITableView) -> Int
    {
        return 1
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func tableView (tableView:UITableView, numberOfRowsInSection section:Int) -> Int
    {
        return self.digitStyleIDs.count
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func tableView (tableView:UITableView, heightForRowAtIndexPath indexPath:NSIndexPath) -> CGFloat
    {
        let digitStyleID = self.digitStyleIDs[indexPath.row]
        let height =
            CGFloat(self.refRowHeight*DigitsView.displayHeightScaleForStyleID(digitStyleID))
        return height
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func tableView (
        tableView:UITableView, cellForRowAtIndexPath indexPath:NSIndexPath) ->
            UITableViewCell
    {
        let cell =
            self.stylesTableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)

        for subview in cell.contentView.subviews
        {
            subview.removeFromSuperview()
        }

        let digitsView = self.digitsViews[indexPath.row]
        if digitsView == nil
        {
            let activityIndicator = UIActivityIndicatorView(frame: cell.contentView.bounds)
            activityIndicator.activityIndicatorViewStyle = .WhiteLarge
            activityIndicator.startAnimating()
            activityIndicator.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
            activityIndicator.alpha = 0.5
            cell.contentView.addSubview(activityIndicator)

            return cell
        }

        var usePaddingH = self.digitsViewPaddingH
        if ["02", "21", "22", "23", "24"].contains(digitsView.id)
        {
            if self.currTimeStyle.rawValue <= 3
            {
                usePaddingH = self.digitsViewPaddingHMore*0.66
            }
            else
            {
                usePaddingH = self.digitsViewPaddingHMore
            }
        }
        var digitsViewFrame =
            cell.contentView.bounds.insetBy(
                dx: CGFloat(usePaddingH),
                dy: CGFloat(self.digitsViewPaddingV))
        let hRatio = digitsView.digitRect.height/digitsView.size.height
        let targetHeight = digitsViewFrame.height*hRatio
        digitsViewFrame.insetInPlace(dx: 0.0, dy: (digitsViewFrame.height - targetHeight)/2.0)
        if digitsView.frame != digitsViewFrame
        {
            digitsView.frame = digitsViewFrame
        }

        TimeStyleRecord.setLabelAppearanceForDigitsView(digitsView, timeStyle: self.currTimeStyle)
        let countdownValue =
            self.timeStylesToCountdownValues[self.currTimeStyle.rawValue]![indexPath.row]!
        digitsView.groups =
            TimeStyleRecord.digitsViewGroupsForTimeStyle(
                self.currTimeStyle,
                fromDate: NSDate(timeIntervalSince1970: 0.0),
                toDate: NSDate(timeIntervalSince1970: countdownValue))

        cell.contentView.addSubview(digitsView)
        cell.contentView.clipsToBounds = false
        cell.clipsToBounds = false

        return cell
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func stylesTableViewFocus ()
    {
        if self.stylesTableView.dragging
        {
            return
        }

        let normOffset = self.stylesTableView.contentOffset.y + CGFloat(self.stylesFocusOffset)

        var snappedOffset:CGFloat!
        var rowHeights = [CGFloat]()
        var rowHeightSum:CGFloat = 0.0
        for styleID in self.digitStyleIDs
        {
            let rowHeight =
                CGFloat(self.refRowHeight*DigitsView.displayHeightScaleForStyleID(styleID))
            rowHeights.append(rowHeight)
            rowHeightSum += rowHeight
        }
        let lastRowOffset = rowHeightSum - rowHeights.last!
        if normOffset < 0.0
        {
            snappedOffset = 0.0
            self.currFocusedStyleRowIndex = 0
        }
        else if normOffset > lastRowOffset
        {
            snappedOffset = lastRowOffset
            self.currFocusedStyleRowIndex = self.digitStyleIDs.count - 1
        }
        else
        {
            var rowOffset:CGFloat = 0.0
            for (rowIndex, rowHeight) in rowHeights.enumerate()
            {
                let nextRowOffset = rowOffset + rowHeight

                if rowOffset <= normOffset && normOffset < nextRowOffset
                {
                    if normOffset < (rowOffset + nextRowOffset)/2.0
                    {
                        snappedOffset = rowOffset
                        self.currFocusedStyleRowIndex = rowIndex
                    }
                    else
                    {
                        snappedOffset = nextRowOffset

                        self.currFocusedStyleRowIndex = rowIndex + 1
                        if self.currFocusedStyleRowIndex == self.digitStyleIDs.count
                        {
                            self.currFocusedStyleRowIndex = self.digitStyleIDs.count - 1
                        }
                    }
                    break
                }

                rowOffset = nextRowOffset
            }
            if snappedOffset == nil
            {
                snappedOffset = lastRowOffset
                self.currFocusedStyleRowIndex = self.digitStyleIDs.count - 1
            }
        }

        let targetOffset = snappedOffset - CGFloat(self.stylesFocusOffset)
        if self.stylesTableView.contentOffset.y != targetOffset
        {
            self.stylesTableView.setContentOffset(CGPoint(x: 0.0, y: targetOffset), animated: true)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func focusStyleIfNeeded ()
    {
        if let stylesTableViewPrevOffset = self.stylesTableViewPrevOffset where
           self.stylesTableView.contentOffset.y == stylesTableViewPrevOffset
        {
            self.stylesTableViewFocus()
        }

        self.stylesTableViewPrevOffset = self.stylesTableView.contentOffset.y
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func scrollViewWillBeginDragging (scrollView:UIScrollView)
    {
        self.stylesTableView.setContentOffset(self.stylesTableView.contentOffset, animated: false)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func timeStyleSliderValueChanged ()
    {
        let sliderValue = Int(round(self.timeStyleSlider.value))
        let timeStyle = self.useTimeStyles[sliderValue]
        self.setTimeStyle(timeStyle)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func setTimeStyle (timeStyle:TimeStyleRecord.TimeStyle)
    {
        self.currTimeStyle = timeStyle

        self.scrollViewDidScroll(self.stylesTableView)
        self.stylesTableView.reloadData()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func countdownSecond ()
    {
        if self.currTimeStyle == .Breaths ||
           self.currTimeStyle == .Heartbeats6p
        {
            return
        }

        let timeStyleRawValue = self.currTimeStyle.rawValue
        var countdownValue =
            self.timeStylesToCountdownValues[timeStyleRawValue]![self.currFocusedStyleRowIndex]!
        if self.currTimeStyle != .D
        {
            countdownValue -= 1.0
        }
        else
        {
            countdownValue -= 86400.0/3.0
        }
        self.timeStylesToCountdownValues[timeStyleRawValue]![self.currFocusedStyleRowIndex] =
            countdownValue

        let digitsView = self.digitsViews[self.currFocusedStyleRowIndex]
        if digitsView == nil
        {
            return
        }
        digitsView.maxAnimationDuration = nil
        let groups =
            TimeStyleRecord.digitsViewGroupsForTimeStyle(
                self.currTimeStyle,
                fromDate: NSDate(timeIntervalSince1970: 0.0),
                toDate: NSDate(timeIntervalSince1970: countdownValue))
        if digitsView.numGroups != groups.count
        {
            return
        }
        let direction:DigitsView.GroupValueChangeDirection = countdownValue >= 0.0 ? .Down : .Up
        for (groupIndex, group) in groups.enumerate()
        {
            digitsView.setValue(
                group.value, forGroup: groupIndex, direction: direction, animated: true)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func countdownBreath ()
    {
        if self.currTimeStyle != .Breaths
        {
            return
        }

        let timeStyleRawValue = self.currTimeStyle.rawValue
        var countdownValue =
            self.timeStylesToCountdownValues[timeStyleRawValue]![self.currFocusedStyleRowIndex]!
        countdownValue -= AppConfiguration.breathDuration
        self.timeStylesToCountdownValues[timeStyleRawValue]![self.currFocusedStyleRowIndex] =
            countdownValue
        countdownValue += 1e-4*sign(countdownValue)

        let digitsView = self.digitsViews[self.currFocusedStyleRowIndex]
        if digitsView == nil
        {
            return
        }
        digitsView.maxAnimationDuration = AppConfiguration.breathDuration/2.0
        let groups =
            TimeStyleRecord.digitsViewGroupsForTimeStyle(
                self.currTimeStyle,
                fromDate: NSDate(timeIntervalSince1970: 0.0),
                toDate: NSDate(timeIntervalSince1970: countdownValue))
        if digitsView.numGroups != groups.count
        {
            return
        }
        let direction:DigitsView.GroupValueChangeDirection = countdownValue >= 0.0 ? .Down : .Up
        for (groupIndex, group) in groups.enumerate()
        {
            digitsView.setValue(
                group.value, forGroup: groupIndex, direction: direction, animated: true)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func countdownHeartbeat ()
    {
        if self.currTimeStyle != .Heartbeats6p
        {
            return
        }

        let timeStyleRawValue = self.currTimeStyle.rawValue
        var countdownValue =
            self.timeStylesToCountdownValues[timeStyleRawValue]![self.currFocusedStyleRowIndex]!
        countdownValue -= AppConfiguration.heartbeatDuration
        self.timeStylesToCountdownValues[timeStyleRawValue]![self.currFocusedStyleRowIndex] =
            countdownValue
        countdownValue += 1e-4*sign(countdownValue)

        let digitsView = self.digitsViews[self.currFocusedStyleRowIndex]
        if digitsView == nil
        {
            return
        }
        digitsView.maxAnimationDuration = AppConfiguration.heartbeatDuration
        let groups =
            TimeStyleRecord.digitsViewGroupsForTimeStyle(
                self.currTimeStyle,
                fromDate: NSDate(timeIntervalSince1970: 0.0),
                toDate: NSDate(timeIntervalSince1970: countdownValue))
        if digitsView.numGroups != groups.count
        {
            return
        }
        let direction:DigitsView.GroupValueChangeDirection = countdownValue >= 0.0 ? .Down : .Up
        for (groupIndex, group) in groups.enumerate()
        {
            digitsView.setValue(
                group.value, forGroup: groupIndex, direction: direction, animated: true)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func didSwipeLeft ()
    {
        var timeStyleIndex = self.useTimeStyles.indexOf(self.currTimeStyle)!
        let prevTimeStyleIndex = timeStyleIndex
        timeStyleIndex++
        if timeStyleIndex > self.useTimeStyles.count - 1
        {
            timeStyleIndex = self.useTimeStyles.count - 1
        }
        if timeStyleIndex != prevTimeStyleIndex
        {
            self.timeStyleSlider.value = CGFloat(timeStyleIndex)

            let timeStyle = self.useTimeStyles[timeStyleIndex]
            self.setTimeStyle(timeStyle)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func didSwipeRight ()
    {
        var timeStyleIndex = self.useTimeStyles.indexOf(self.currTimeStyle)!
        let prevTimeStyleIndex = timeStyleIndex
        timeStyleIndex--
        if timeStyleIndex < 0
        {
            timeStyleIndex = 0
        }
        if timeStyleIndex != prevTimeStyleIndex
        {
            self.timeStyleSlider.value = CGFloat(timeStyleIndex)

            let timeStyle = self.useTimeStyles[timeStyleIndex]
            self.setTimeStyle(timeStyle)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func scrollViewDidScroll (scrollView:UIScrollView)
    {
        for cell in self.stylesTableView.visibleCells
        {
            let y =
                self.stylesTableViewContainer.convertPoint(
                    CGPointZero, fromView: cell.contentView).y
            let diffY =
                (CGFloat(self.stylesFocusOffset) - y)/self.stylesTableViewContainer.bounds.height
            let absDiffY = abs(diffY)
            var r = -pow(absDiffY*1.0, 0.66)
            if diffY < 0.0
            {
                r = -r
            }
            var t = CATransform3DMakeRotation(r, 1.0, 0.0, 0.0)
            let s = 1.0 + pow(absDiffY*1.25, 2.0)
            t = CATransform3DScale(t, s, s, 1.0)
            cell.contentView.layer.transform = t
            var transform = CATransform3DIdentity
            var d = 1000.0*(1.0 - absDiffY)*1.33
            if d < 500.0
            {
                d = 500.0
            }
            transform.m34 = -1.0/d
            cell.layer.sublayerTransform = transform
            //cell.contentView.layer.opacity = Float(1.0 - pow(absDiffY, 0.42))
        }

        for digitsView in self.digitsViews
        {
            digitsView?.loopAnimationEnabled = false
        }
        self.digitsViews[self.currFocusedStyleRowIndex]?.loopAnimationEnabled = true
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func dismiss ()
    {
        self.focusStyleIfNeededTimer?.invalidate()
        self.countdownSecondTimer?.invalidate()
        self.countdownBreathTimer?.invalidate()
        self.countdownHeartbeatTimer?.invalidate()

        for digitsView in self.digitsViews
        {
            digitsView?.deactivate()
        }

        self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func outputDigitStyle ()
    {
        self.stylesTableViewFocus()

        let timeStyle = self.currTimeStyle
        let digitStyleID = Int(self.digitStyleIDs[self.currFocusedStyleRowIndex])!

        let digitsView = self.digitsViews[self.currFocusedStyleRowIndex]
        if digitsView == nil
        {
            return
        }

        let cover = self.view.snapshotViewAfterScreenUpdates(false)
        self.view.addSubview(cover)

        let snapshotContainer = UIView()
        let snapshotSize = (self.inputData["snapshotSize"] as! NSValue).CGSizeValue()
        snapshotContainer.frame = CGRect(origin: CGPointZero, size: snapshotSize)
        let paddingH = 16.0
        let paddingV = 24.0
        let digitsViewFrame =
            snapshotContainer.bounds.insetBy(dx: CGFloat(paddingH), dy: CGFloat(paddingV))
        digitsView.frame = digitsViewFrame
        snapshotContainer.addSubview(digitsView)

        TimeStyleRecord.setLabelAppearanceForDigitsView(digitsView, timeStyle: timeStyle)
        let rowIndex = self.currFocusedStyleRowIndex
        let countdownValue =
            self.initialTimeStylesToCountdownValues[timeStyle.rawValue]![rowIndex]!
        digitsView.groups =
            TimeStyleRecord.digitsViewGroupsForTimeStyle(
                timeStyle,
                fromDate: NSDate(timeIntervalSince1970: 0.0),
                toDate: NSDate(timeIntervalSince1970: countdownValue))

        UIGraphicsBeginImageContextWithOptions(snapshotContainer.bounds.size, false, 0)
        snapshotContainer.drawViewHierarchyInRect(
            snapshotContainer.bounds, afterScreenUpdates: true)
        let snapshot = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        let timeStyleRecord = TimeStyleRecord()
        timeStyleRecord.timeStyle = timeStyle
        timeStyleRecord.digitStyleID = digitStyleID
        timeStyleRecord.snapshot = snapshot

        var outputData = [String: AnyObject]()
        outputData["timeStyleRecord"] = timeStyleRecord
        self.inputOutputDelegate.acceptOutputDataFromTimeStyleChooserViewController(outputData)

        let ud = NSUserDefaults.standardUserDefaults()
        ud.setInteger(timeStyle.rawValue, forKey: "initTimeStyle")

        self.dismiss()
    }

    //----------------------------------------------------------------------------------------------

    @IBAction private func cancelBNAction ()
    {
        self.dismiss()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction private func doneBNAction ()
    {
        self.outputDigitStyle()
    }

    //----------------------------------------------------------------------------------------------
}



