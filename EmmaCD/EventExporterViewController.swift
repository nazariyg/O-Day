import AVFoundation


//--------------------------------------------------------------------------------------------------

protocol EventExporterViewControllerInputDelegate : class
{
    func provideInputDataForEventExporterViewController () -> [String: AnyObject]
    func sharingDestinationForEventExporterViewController () -> EventSharingDestination
    func eventExporterViewControllerWillDismiss ()
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

enum EventSharingDestination
{
    case Instagram
    case Facebook
    case Twitter
    case Messages
    case OtherShares
    case PhotoLibrary
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

enum EventExportType
{
    case Picture
    case Video
}

//--------------------------------------------------------------------------------------------------


class EventExporterViewController : UIViewController,
                                    EventPresenterBackgroundViewOutputDelegate,
                                    EventSharerViewControllerInputDelegate
{
    weak var inputDelegate:EventExporterViewControllerInputDelegate!

    @IBOutlet private weak var cancelBN:UIButton!
    @IBOutlet private weak var previewViewContainer:UIView!
    @IBOutlet private weak var exportTypeSLContainer:UIView!
    @IBOutlet private weak var exportTypePictureLB:UILabel!
    @IBOutlet private weak var exportTypeVideoLB:UILabel!
    @IBOutlet private weak var videoDurationLB:UILabel!
    @IBOutlet private weak var videoDurationSLContainer:UIView!
    @IBOutlet private weak var videoCaptureRegionLB:UILabel!
    @IBOutlet private weak var videoCaptureRegionSLContainer:UIView!

    private var inputData:[String: AnyObject]!
    private var eventRecord:EventRecord!
    private var sharingDestination:EventSharingDestination!
    private var aspectRatio:Double!
    private var outputVideoMaxDuration:Int!
    private var outputVideoBitRateMbps:Double!
    private let ptReferenceOutputWidth = UIScreen.mainScreen().bounds.width
    private var outputScale = 2.0
    private var outputVideoDefaultBitRateMbps = 12.0
    private let defaultAspectRatio = 3.0/4.0
    private let previewSlidersHeight:CGFloat = 50.0
    private let previewSlidersPadding:CGFloat = 0.0
    private let infoOffsetSLLengthFactor:CGFloat = 0.62
    private let infoScaleSLLengthFactor:CGFloat = 0.62
    private let referenceCamelLabelsSliderHeight:CGFloat = 30.0
    private let videoDurationDefaultOptions = [3, 6, 10, 15, 20, 25]
    private let videoDurationDefaultOptionsSnapDist = 2
    private let videoDurationDefaultOptionsMaxDurationForInit = 15
    private let infoOffsetYRatioShift = -0.33
    private let infoScaleRangeMinValue = 0.66
    private let outputVideoSizeMultipleOf = 16
    private let outputVideoProfileLevel = AVVideoProfileLevelH264High41
    private let outputVideoMaxKeyFrameIntervalKey = 72
    private let outputInfoViewDigitsStopMotionFPS = 24
    private let videoTimeAlignments = ["s", "m", "e"]
    private var previewView:UIView!
    private var infoOffsetSL:TGPDiscreteSlider!
    private var infoScaleSL:TGPDiscreteSlider!
    private var exportTypeSL:TGPDiscreteSlider!
    private var videoDurationSL:TGPDiscreteSlider!
    private var videoDurationSLLabels:TGPCamelLabels!
    private var videoCaptureRegionSL:TGPDiscreteSlider!
    private var videoCaptureRegionSLLabels:TGPCamelLabels!
    private var previewBackgroundView:EventPresenterBackgroundView!
    private var previewInfoView:EventPresenterInfoView!
    private var savingBackgroundView:EventPresenterBackgroundView!
    private var savingInfoView:EventPresenterInfoView!
    private var currExportType:EventExportType!
    private var currVideoDuration:Double!
    private var currVideoCaptureRegionTimeAlign:String!
    private var infoOffsetSLDidStopReceivingTouchesObserver:NSObjectProtocol!
    private var infoScaleSLDidStopReceivingTouchesObserver:NSObjectProtocol!
    private var snapshotForSharerVC:UIView!
    private var savingIsComplete = false
    private var savedPicture:UIImage!
    private var videoSavingProgress = 0.0
    private var savedVideoURL:NSURL!
    private var once = 0

    //----------------------------------------------------------------------------------------------

    deinit
    {
        if let infoOffsetSLDidStopReceivingTouchesObserver =
           self.infoOffsetSLDidStopReceivingTouchesObserver
        {
            NSNotificationCenter.defaultCenter().removeObserver(
                infoOffsetSLDidStopReceivingTouchesObserver)
        }
        if let infoScaleSLDidStopReceivingTouchesObserver =
           self.infoScaleSLDidStopReceivingTouchesObserver
        {
            NSNotificationCenter.defaultCenter().removeObserver(
                infoScaleSLDidStopReceivingTouchesObserver)
        }
    }

    //----------------------------------------------------------------------------------------------

    override func viewDidLoad ()
    {
        super.viewDidLoad()

        self.inputData = self.inputDelegate.provideInputDataForEventExporterViewController()

        self.eventRecord = self.inputData["eventRecord"] as! EventRecord

        self.sharingDestination =
            self.inputDelegate.sharingDestinationForEventExporterViewController()

        self.aspectRatio = self.defaultAspectRatio
        if self.sharingDestination! == .Instagram
        {
            self.aspectRatio = EventSharerViewController.instagramAspectRatio
        }
        else if self.sharingDestination! == .Facebook
        {
            self.aspectRatio = EventSharerViewController.facebookAspectRatio
        }
        else if self.sharingDestination! == .Twitter
        {
            self.aspectRatio = EventSharerViewController.twitterAspectRatio
        }

        if self.sharingDestination! == .Instagram
        {
            self.outputVideoMaxDuration = Int(EventSharerViewController.instagramMaxVideoDuration)
        }
        else if self.sharingDestination! == .Twitter
        {
            self.outputVideoMaxDuration = Int(EventSharerViewController.twitterMaxVideoDuration)
        }

        self.outputVideoBitRateMbps = self.outputVideoDefaultBitRateMbps
        if self.sharingDestination! == .Twitter
        {
            self.outputVideoBitRateMbps = EventSharerViewController.twitterVideoBitRateMbps
        }

        self.view.tintColor = AppConfiguration.tintColor
        self.view.backgroundColor = AppConfiguration.bluishColorDarkerP

        //self.previewViewContainer.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.25)
        self.previewViewContainer.backgroundColor = UIColor.clearColor()

        self.exportTypePictureLB.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: "exportTypePictureLBDidReceiveTap"))
        self.exportTypeVideoLB.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: "exportTypeVideoLBDidReceiveTap"))

        self.view.userInteractionEnabled = false
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func viewDidLayoutSubviews ()
    {
        super.viewDidLayoutSubviews()

        dispatch_once(&self.once) {
            let outputSize = self.calcOutputSizeAndVideoDim().outputSize

            let useAspectRatio = outputSize.width/outputSize.height
            self.previewView = UIView()
            self.previewViewContainer.addSubview(self.previewView)
            self.previewView.translatesAutoresizingMaskIntoConstraints = false
            self.previewViewContainer.addConstraint(
                NSLayoutConstraint(
                    item: self.previewView, attribute: .CenterX,
                    relatedBy: .Equal,
                    toItem: self.previewViewContainer, attribute: .CenterX,
                    multiplier: 1.0, constant: 0.0))
            self.previewViewContainer.addConstraint(
                NSLayoutConstraint(
                    item: self.previewView, attribute: .CenterY,
                    relatedBy: .Equal,
                    toItem: self.previewViewContainer, attribute: .CenterY,
                    multiplier: 1.0, constant: 0.0))
            let containerAspectRatio =
                self.previewViewContainer.bounds.width/self.previewViewContainer.bounds.height
            if useAspectRatio <= containerAspectRatio
            {
                self.previewViewContainer.addConstraint(
                    NSLayoutConstraint(
                        item: self.previewView, attribute: .Height,
                        relatedBy: .Equal,
                        toItem: self.previewViewContainer, attribute: .Height,
                        multiplier: 1.0, constant: 0.0))
                self.previewViewContainer.addConstraint(
                    NSLayoutConstraint(
                        item: self.previewView, attribute: .Width,
                        relatedBy: .Equal,
                        toItem: self.previewView, attribute: .Height,
                        multiplier: useAspectRatio, constant: 0.0))
            }
            else
            {
                self.previewViewContainer.addConstraint(
                    NSLayoutConstraint(
                        item: self.previewView, attribute: .Width,
                        relatedBy: .Equal,
                        toItem: self.previewViewContainer, attribute: .Width,
                        multiplier: 1.0, constant: 0.0))
                self.previewViewContainer.addConstraint(
                    NSLayoutConstraint(
                        item: self.previewView, attribute: .Height,
                        relatedBy: .Equal,
                        toItem: self.previewView, attribute: .Width,
                        multiplier: 1.0/useAspectRatio, constant: 0.0))
            }

            self.previewViewContainer.layoutSubviews()

            let openingImageViewFrame = self.previewView.bounds.insetBy(dx: 0.0, dy: 1.0)
            let openingImageView = UIImageView(frame: openingImageViewFrame)
            openingImageView.contentMode = .ScaleAspectFill
            openingImageView.clipsToBounds = true
            openingImageView.image =
                self.eventRecord.backgroundOpeningImageForContainerSize(
                    self.previewView.bounds.size)
            self.previewView.addSubview(openingImageView)

            let eventViewFrame = CGRect(origin: CGPointZero, size: outputSize)
            let eventView = UIView(frame: eventViewFrame)
            eventView.center =
                CGPoint(x: self.previewView.bounds.midX, y: self.previewView.bounds.midY)
            self.previewView.addSubview(eventView)
            let scale = self.previewView.bounds.width/outputSize.width
            eventView.transform = CGAffineTransformMakeScale(scale, scale)
            eventView.userInteractionEnabled = false

            self.previewBackgroundView =
                EventPresenterBackgroundView(
                    frame: eventView.bounds, eventRecord: self.eventRecord, forPreview: true)
            eventView.addSubview(self.previewBackgroundView)
            self.previewBackgroundView.play()

            self.previewInfoView =
                EventPresenterInfoView(
                    frame: eventView.bounds, eventRecord: self.eventRecord, forPreview: true)
            self.previewInfoView.clipsToBounds = true
            eventView.addSubview(self.previewInfoView)

            let refFrame = self.previewView.frame

            let infoOffsetSLFrame =
                CGRect(
                    origin: CGPointZero,
                    size: CGSize(
                        width: refFrame.height*self.infoOffsetSLLengthFactor,
                        height: self.previewSlidersHeight))
            let infoOffsetSLContainer = UIView(frame: infoOffsetSLFrame)
            infoOffsetSLContainer.center =
                CGPoint(
                    x: refFrame.maxX - self.previewSlidersPadding - self.previewSlidersHeight/2.0,
                    y: refFrame.midY)
            infoOffsetSLContainer.transform = CGAffineTransformMakeRotation(CGFloat(M_PI_2))
            self.infoOffsetSL = TGPDiscreteSlider(frame: infoOffsetSLContainer.bounds)
            self.makeupPreviewSlider(self.infoOffsetSL)
            self.infoOffsetSL.addTarget(
                self, action: "infoOffsetSLValueChanged", forControlEvents: .ValueChanged)
            infoOffsetSLContainer.addSubview(self.infoOffsetSL)
            self.previewViewContainer.addSubview(infoOffsetSLContainer)
            self.setContinuousSliderValue(
                self.infoOffsetSL,
                value: self.previewInfoView.infoOffsetYRatio - self.infoOffsetYRatioShift)

            let infoScaleSLFrame =
                CGRect(
                    origin: CGPointZero,
                    size: CGSize(
                        width: refFrame.width*self.infoScaleSLLengthFactor,
                        height: self.previewSlidersHeight))
            let infoScaleSLContainer = UIView(frame: infoScaleSLFrame)
            infoScaleSLContainer.center =
                CGPoint(
                    x: refFrame.midX,
                    y: refFrame.maxY - self.previewSlidersPadding - self.previewSlidersHeight/2.0)
            self.infoScaleSL = TGPDiscreteSlider(frame: infoScaleSLContainer.bounds)
            self.makeupPreviewSlider(self.infoScaleSL)
            self.infoScaleSL.addTarget(
                self, action: "infoScaleSLValueChanged", forControlEvents: .ValueChanged)
            infoScaleSLContainer.addSubview(self.infoScaleSL)
            self.previewViewContainer.addSubview(infoScaleSLContainer)
            self.setContinuousSliderValue(self.infoScaleSL, value: 1.0)

            let nc = NSNotificationCenter.defaultCenter()
            self.infoOffsetSLDidStopReceivingTouchesObserver =
                nc.addObserverForName(
                    "TGPDiscreteSliderDidStopReceivingTouches", object: self.infoOffsetSL,
                    queue: NSOperationQueue.mainQueue()) { [weak self] _ in
                        guard let sSelf = self else
                        {
                            return
                        }

                        sSelf.previewInfoView?.snapInfoViewWithinBounds()
                    }
            self.infoScaleSLDidStopReceivingTouchesObserver =
                nc.addObserverForName(
                    "TGPDiscreteSliderDidStopReceivingTouches", object: self.infoScaleSL,
                    queue: NSOperationQueue.mainQueue()) { [weak self] _ in
                        guard let sSelf = self else
                        {
                            return
                        }

                        sSelf.previewInfoView?.snapInfoViewWithinBounds()
                    }

            self.exportTypeSLContainer.backgroundColor = UIColor.clearColor()
            self.exportTypeSL = TGPDiscreteSlider(frame: self.exportTypeSLContainer.bounds)
            self.exportTypeSL.alpha = 0.9
            self.exportTypeSL.tickCount = 2
            self.exportTypeSL.incrementValue = 1
            self.exportTypeSL.tickStyle = 2
            self.exportTypeSL.minimumValue = 0.0
            self.exportTypeSL.trackStyle = 2
            self.exportTypeSL.trackThickness = 0.5
            self.exportTypeSL.tickSize = CGSize(width: 10.0, height: 10.0)
            self.exportTypeSL.tintColor = UIColor(red: 0.99, green: 0.99, blue: 0.99, alpha: 1.0)
            self.exportTypeSL.thumbStyle = 2
            self.exportTypeSL.thumbColor = UIColor.whiteColor()
            self.exportTypeSL.thumbSize = CGSize(width: 30.0, height: 30.0)
            self.exportTypeSL.thumbSRadius = 2.0
            self.exportTypeSL.thumbSOffset = CGSizeZero
            self.exportTypeSL.opaque = false
            self.exportTypeSL.addTarget(
                self, action: "exportTypeSLValueChanged", forControlEvents: .ValueChanged)
            self.exportTypeSLContainer.addSubview(self.exportTypeSL)

            let pictureOnly = (self.inputData["pictureOnly"] as? Bool) ?? false
            let videoOnly = (self.inputData["videoOnly"] as? Bool) ?? false

            var videoDurationSLLabelNames = [String]()
            var videoDurationSLInitValue = -1
            for durationOption in self.videoDurationDefaultOptions
            {
                var duration = durationOption

                if let maxDuration = self.outputVideoMaxDuration
                {
                    if abs(duration - maxDuration) <= self.videoDurationDefaultOptionsSnapDist
                    {
                        duration = maxDuration
                    }

                    if duration > maxDuration
                    {
                        continue
                    }
                }

                let labelName = String(duration)
                if !videoDurationSLLabelNames.contains(labelName)
                {
                    videoDurationSLLabelNames.append(labelName)
                    if duration <= self.videoDurationDefaultOptionsMaxDurationForInit
                    {
                        videoDurationSLInitValue++
                    }
                }
            }
            self.videoDurationSLContainer.backgroundColor = UIColor.clearColor()
            self.videoDurationSL = TGPDiscreteSlider(frame: self.videoDurationSLContainer.bounds)
            self.videoDurationSL.tickCount = Int32(videoDurationSLLabelNames.count)
            self.videoDurationSLLabels = TGPCamelLabels()
            self.videoDurationSLLabels.names = videoDurationSLLabelNames
            self.makeupDiscreteSlider(
                self.videoDurationSL, withCamelLabels: self.videoDurationSLLabels)
            self.videoDurationSL.addTarget(
                self, action: "videoDurationSLValueChanged", forControlEvents: .ValueChanged)
            self.videoDurationSLContainer.addSubview(self.videoDurationSLLabels)
            self.videoDurationSLContainer.addSubview(self.videoDurationSL)
            self.changeValueForSlider(self.videoDurationSL, value: videoDurationSLInitValue)
            self.videoDurationSLValueChanged()

            self.videoCaptureRegionSLContainer.backgroundColor = UIColor.clearColor()
            self.videoCaptureRegionSL =
                TGPDiscreteSlider(frame: self.videoCaptureRegionSLContainer.bounds)
            self.videoCaptureRegionSL.tickCount = 4
            self.videoCaptureRegionSLLabels = TGPCamelLabels()
            self.videoCaptureRegionSLLabels.names = ["OPTIMAL", "BEGINNING", "MIDDLE", "ENDING"]
            self.makeupDiscreteSlider(
                self.videoCaptureRegionSL, withCamelLabels: self.videoCaptureRegionSLLabels)
            self.videoCaptureRegionSL.addTarget(
                self, action: "videoCaptureRegionSLValueChanged", forControlEvents: .ValueChanged)
            self.videoCaptureRegionSLLabels.downFontSize = 10.0
            self.videoCaptureRegionSLLabels.upFontSize = 11.0
            self.videoCaptureRegionSLContainer.addSubview(self.videoCaptureRegionSLLabels)
            self.videoCaptureRegionSLContainer.addSubview(self.videoCaptureRegionSL)
            self.videoCaptureRegionSL.value = 0
            self.videoCaptureRegionSLValueChanged()

            on_main() {
                if pictureOnly
                {
                    self.exportTypeSLContainer.hidden = true
                    self.exportTypeVideoLB.hidden = true

                    self.exportTypePictureLB.textAlignment = .Center
                    self.exportTypePictureLB.center = self.exportTypeSLContainer.center
                    self.exportTypePictureLB.userInteractionEnabled = false
                }
                else if videoOnly
                {
                    self.exportTypeSLContainer.hidden = true
                    self.exportTypePictureLB.hidden = true

                    self.exportTypeVideoLB.textAlignment = .Center
                    self.exportTypeVideoLB.center = self.exportTypeSLContainer.center
                    self.exportTypeVideoLB.userInteractionEnabled = false
                }
            }
            let exportTypeSLValue:CGFloat
            if pictureOnly
            {
                exportTypeSLValue = 0
            }
            else
            {
                exportTypeSLValue = 1
            }
            self.exportTypeSL.value = exportTypeSLValue
            self.exportTypeSLValueChangedInternal(true)

            eventView.alpha = 0.0
            UIView.animateWithDuration(
                0.5, delay: 0.5, options: [.CurveEaseOut], animations: {
                    eventView.alpha = 1.0
                },
                completion: { _ in
                    self.view.userInteractionEnabled = true
                })
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func makeupPreviewSlider (slider:TGPDiscreteSlider)
    {
        slider.alpha = 0.5

        slider.opaque = false
        slider.tickCount = 512
        slider.incrementValue = 1
        slider.tickStyle = 3
        slider.minimumValue = 0.0
        slider.trackStyle = 4
        slider.trackImage = "WhiteLine2px"
        slider.trackThickness = 0.5
        slider.tickSize = CGSize(width: 10.0, height: 10.0)
        slider.tintColor = AppConfiguration.tintColor
        slider.thumbStyle = 2
        slider.thumbColor = UIColor.whiteColor()
        slider.thumbSize = CGSize(width: 30.0, height: 30.0)
        slider.thumbSRadius = 2.0
        slider.thumbSOffset = CGSizeZero

        slider.layer.shouldRasterize = true
        slider.layer.rasterizationScale = UIScreen.mainScreen().scale
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func makeupDiscreteSlider (
        slider:TGPDiscreteSlider, withCamelLabels camelLabels:TGPCamelLabels)
    {
        slider.alpha = 0.9

        slider.incrementValue = 1
        slider.tickStyle = 2
        slider.minimumValue = 0.0
        slider.trackStyle = 2
        slider.trackThickness = 0.5
        slider.tickSize = CGSize(width: 10.0, height: 10.0)
        slider.tintColor = UIColor(red: 0.99, green: 0.99, blue: 0.99, alpha: 1.0)
        slider.thumbStyle = 2
        slider.thumbColor = UIColor.whiteColor()
        slider.thumbSize =
            CGSize(
                width: self.referenceCamelLabelsSliderHeight,
                height: self.referenceCamelLabelsSliderHeight)
        slider.thumbSRadius = 2.0
        slider.thumbSOffset = CGSizeZero
        slider.opaque = false

        camelLabels.frame =
            CGRect(
                x: slider.frame.origin.x,
                y: slider.frame.origin.y - slider.frame.height + 14.0,
                width: slider.frame.width,
                height: slider.frame.height - 8.0)
        camelLabels.upFontColor = UIColor.whiteColor()
        camelLabels.upFontSize = 17.0
        camelLabels.downFontColor = UIColor.whiteColor().colorWithAlphaComponent(0.5)
        camelLabels.downFontSize = 14.0
        camelLabels.animationDuration = 0.25
        slider.ticksListener = camelLabels
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

    private func changeEnabledStateForSlider (slider:TGPDiscreteSlider, enabled:Bool, animated:Bool)
    {
        let disabledAlpha:CGFloat = 0.25
        let animationDuration = 0.25

        if !enabled
        {
            slider.enabled = false
            if !animated
            {
                slider.alpha = disabledAlpha
            }
            else
            {
                UIView.animateWithDuration(animationDuration) {
                    slider.alpha = disabledAlpha
                }
            }
            if let ticksListener = slider.ticksListener as? TGPCamelLabels
            {
                ticksListener.enabled = false
                if !animated
                {
                    ticksListener.alpha = disabledAlpha
                }
                else
                {
                    UIView.animateWithDuration(animationDuration) {
                        ticksListener.alpha = disabledAlpha
                    }
                }
            }
        }
        else
        {
            slider.enabled = true
            if !animated
            {
                slider.alpha = 1.0
            }
            else
            {
                UIView.animateWithDuration(animationDuration) {
                    slider.alpha = 1.0
                }
            }
            if let ticksListener = slider.ticksListener as? TGPCamelLabels
            {
                ticksListener.enabled = true
                if !animated
                {
                    ticksListener.alpha = 1.0
                }
                else
                {
                    UIView.animateWithDuration(animationDuration) {
                        ticksListener.alpha = 1.0
                    }
                }
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func changeValueForSlider (slider:TGPDiscreteSlider, value:Int)
    {
        slider.value = CGFloat(value)
        if let ticksListener = slider.ticksListener as? TGPCamelLabels
        {
            ticksListener.value = UInt(value)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func setContinuousSliderValue (slider:TGPDiscreteSlider, value:Double)
    {
        slider.value = CGFloat(round(value*Double(slider.tickCount - 1)))
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func getContinuousSliderValue (slider:TGPDiscreteSlider) -> Double
    {
        return Double(slider.value)/Double(slider.tickCount - 1)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func infoOffsetSLValueChanged ()
    {
        if self.previewInfoView == nil
        {
            return
        }

        let sliderValue = self.getContinuousSliderValue(self.infoOffsetSL)

        self.previewInfoView.setInfoViewOffsetYRatio(sliderValue + self.infoOffsetYRatioShift)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func infoScaleSLValueChanged ()
    {
        if self.previewInfoView == nil
        {
            return
        }
        
        let sliderValue = self.getContinuousSliderValue(self.infoScaleSL)

        let scale = self.infoScaleRangeMinValue + sliderValue*(1.0 - self.infoScaleRangeMinValue)
        self.previewInfoView.setInfoViewScale(scale)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func exportTypeSLValueChangedInternal (isInternal:Bool)
    {
        let sliderValueInt = Int(round(self.exportTypeSL.value))

        let disabledAlpha:CGFloat = 0.25
        let animationDuration = 0.25
        let lbOffAlpha:CGFloat = 1.0
        let lbShadowOpacity:Float = 0.9
        let lbShadowRadius:CGFloat = 5.0

        if sliderValueInt == 0
        {
            self.currExportType = .Picture

            self.videoDurationSL.enabled = false

            self.videoCaptureRegionSL.enabled = false

            let changeClosure = {
                self.videoDurationLB.alpha = disabledAlpha
                self.videoDurationSLContainer.alpha = disabledAlpha

                self.videoCaptureRegionLB.alpha = disabledAlpha
                self.videoCaptureRegionSLContainer.alpha = disabledAlpha

                self.exportTypeVideoLB.textColor = UIColor.whiteColor()
                self.exportTypeVideoLB.alpha = lbOffAlpha
                self.exportTypeVideoLB.layer.shadowColor = nil
                self.exportTypeVideoLB.layer.shadowOpacity = 0.0
                self.exportTypeVideoLB.layer.shadowRadius = 0.0
                self.exportTypePictureLB.textColor = UIColor.whiteColor()
                self.exportTypePictureLB.alpha = 1.0
                self.exportTypePictureLB.layer.shadowColor = UIColor.whiteColor().CGColor
                self.exportTypePictureLB.layer.shadowOpacity = lbShadowOpacity
                self.exportTypePictureLB.layer.shadowRadius = lbShadowRadius
                self.exportTypePictureLB.layer.shadowOffset = CGSizeZero
            }
            if isInternal
            {
                changeClosure()
            }
            else
            {
                UIView.animateWithDuration(animationDuration) {
                    changeClosure()
                }
            }
        }
        else  // 1
        {
            self.currExportType = .Video

            self.videoDurationSL.enabled = true

            self.videoCaptureRegionSL.enabled = true

            let changeClosure = {
                self.videoDurationLB.alpha = 1.0
                self.videoDurationSLContainer.alpha = 1.0

                self.videoCaptureRegionLB.alpha = 1.0
                self.videoCaptureRegionSLContainer.alpha = 1.0

                self.exportTypePictureLB.textColor = UIColor.whiteColor()
                self.exportTypePictureLB.alpha = lbOffAlpha
                self.exportTypePictureLB.layer.shadowColor = nil
                self.exportTypePictureLB.layer.shadowOpacity = 0.0
                self.exportTypePictureLB.layer.shadowRadius = 0.0
                self.exportTypeVideoLB.textColor = UIColor.whiteColor()
                self.exportTypeVideoLB.alpha = 1.0
                self.exportTypeVideoLB.layer.shadowColor = UIColor.whiteColor().CGColor
                self.exportTypeVideoLB.layer.shadowOpacity = lbShadowOpacity
                self.exportTypeVideoLB.layer.shadowRadius = lbShadowRadius
                self.exportTypeVideoLB.layer.shadowOffset = CGSizeZero
            }
            if isInternal
            {
                changeClosure()
            }
            else
            {
                UIView.animateWithDuration(animationDuration) {
                    changeClosure()
                }
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func exportTypeSLValueChanged ()
    {
        self.exportTypeSLValueChangedInternal(false)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func exportTypePictureLBDidReceiveTap ()
    {
        let sliderValueInt = Int(round(self.exportTypeSL.value))
        if sliderValueInt == 0
        {
            return
        }

        self.exportTypeSL.value = CGFloat(0)
        self.exportTypeSLValueChanged()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func exportTypeVideoLBDidReceiveTap ()
    {
        let sliderValueInt = Int(round(self.exportTypeSL.value))
        if sliderValueInt == 1
        {
            return
        }

        self.exportTypeSL.value = CGFloat(1)
        self.exportTypeSLValueChanged()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func videoDurationSLValueChanged ()
    {
        let sliderValueInt = Int(round(self.videoDurationSL.value))
        let camelLabels = self.videoDurationSL.ticksListener as! TGPCamelLabels
        let duration = Double(camelLabels.names[sliderValueInt] as! String)!

        self.currVideoDuration = duration
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func videoCaptureRegionSLValueChanged ()
    {
        let sliderValueInt = Int(round(self.videoCaptureRegionSL.value))

        if sliderValueInt > 0
        {
            self.currVideoCaptureRegionTimeAlign = self.videoTimeAlignments[sliderValueInt - 1]
        }
        else
        {
            self.currVideoCaptureRegionTimeAlign = nil
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func calcOutputSizeAndVideoDim () ->
        (outputSize:CGSize, outputVideoWidth:Int!, outputVideoHeight:Int!)
    {
        var outputSize =
            CGSize(
                width: self.ptReferenceOutputWidth,
                height: self.ptReferenceOutputWidth/CGFloat(self.aspectRatio))

        var outputVideoWidth:Int!
        var outputVideoHeight:Int!

        let pictureOnly = (self.inputData["pictureOnly"] as? Bool) ?? false
        if !pictureOnly
        {
            var videoPixelSizeFactor = 1.0
            if self.sharingDestination! == .Instagram
            {
                videoPixelSizeFactor = EventSharerViewController.instagramVideoPixelSizeFactor
            }
            else if self.sharingDestination! == .Facebook
            {
                // For the HD option.
                videoPixelSizeFactor = EventSharerViewController.facebookVideoPixelSizeFactor
            }
            else if self.sharingDestination! == .Twitter
            {
                videoPixelSizeFactor = EventSharerViewController.twitterVideoPixelSizeFactor
            }

            let useScale = CGFloat(self.outputScale*videoPixelSizeFactor)

            outputVideoWidth = Int(round(outputSize.width*useScale))
            outputVideoHeight = Int(round(outputSize.height*useScale))

            var recalcOutputSize = false

            let m = self.outputVideoSizeMultipleOf
            if outputVideoWidth % m != 0
            {
                outputVideoWidth = Int(ceil(Double(outputVideoWidth)/Double(m)))*m
                recalcOutputSize = true
            }
            if outputVideoHeight % m != 0
            {
                outputVideoHeight = Int(ceil(Double(outputVideoHeight)/Double(m)))*m
                recalcOutputSize = true
            }

            if recalcOutputSize
            {
                outputSize.width = CGFloat(outputVideoWidth)/useScale
                outputSize.height = CGFloat(outputVideoHeight)/useScale
            }
        }

        return (
            outputSize: outputSize,
            outputVideoWidth: outputVideoWidth,
            outputVideoHeight: outputVideoHeight)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func doCapture ()
    {
        let outputSizeAndVideoDim = self.calcOutputSizeAndVideoDim()

        let outputSize = outputSizeAndVideoDim.outputSize

        let outputVideoWidth = outputSizeAndVideoDim.outputVideoWidth
        let outputVideoHeight = outputSizeAndVideoDim.outputVideoHeight

        let savingOptions = EventPresenterBackgroundViewSavingOptions()

        savingOptions.exportType = self.currExportType

        if self.currExportType == .Picture
        {
            if self.eventRecord.backgroundRecord is BackgroundOverlayRecord
            {
                let currTime = CMTimeGetSeconds(self.previewBackgroundView.overlayCurrentTime()!)
                let duration = CMTimeGetSeconds(self.previewBackgroundView.overlayDuration()!)
                let seekToTime = currTime % duration
                savingOptions.pictureExportOverlaySeekToTime =
                    CMTimeMakeWithSeconds(
                        seekToTime, self.previewBackgroundView.overlayDuration()!.timescale)
            }
            else if self.eventRecord.backgroundRecord is BackgroundVideoRecord
            {
                let currTime = CMTimeGetSeconds(self.previewBackgroundView.inputVideoCurrentTime()!)
                let duration = CMTimeGetSeconds(self.previewBackgroundView.inputVideoDuration()!)
                let seekToTime = currTime % duration
                savingOptions.pictureExportInputVideoSeekToTime =
                    CMTimeMakeWithSeconds(
                        seekToTime, self.previewBackgroundView.inputVideoDuration()!.timescale)
            }
        }
        else  // .Video
        {
            savingOptions.outputVideoWidth = outputVideoWidth
            savingOptions.outputVideoHeight = outputVideoHeight

            savingOptions.outputVideoAVSettings = [
                AVVideoWidthKey: outputVideoWidth,
                AVVideoHeightKey: outputVideoHeight,
                AVVideoCodecKey: AVVideoCodecH264,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: Int(self.outputVideoBitRateMbps*1e06),
                    AVVideoProfileLevelKey: self.outputVideoProfileLevel,
                    AVVideoMaxKeyFrameIntervalKey: self.outputVideoMaxKeyFrameIntervalKey,
                ],
            ]

            savingOptions.duration = self.currVideoDuration

            // For Instagram, make video duration slightly shorter than the accepted maximum.
            if self.sharingDestination! == .Instagram &&
               savingOptions.duration > EventSharerViewController.instagramAdjustedMaxVideoDuration
            {
                savingOptions.duration = EventSharerViewController.instagramAdjustedMaxVideoDuration
            }

            if let currVideoCaptureRegionTimeAlign = self.currVideoCaptureRegionTimeAlign
            {
                savingOptions.customTimeAlign = currVideoCaptureRegionTimeAlign
            }
        }

        let outputFrame = CGRect(origin: CGPointZero, size: outputSize)

        let referenceDate = NSDate().dateByAddingTimeInterval(-1.0)
        let infoViewSavingOptions = EventPresenterInfoViewSavingOptions()
        infoViewSavingOptions.digitsStopMotionFPS = self.outputInfoViewDigitsStopMotionFPS
        infoViewSavingOptions.digitsStopMotionReferenceDate = referenceDate
        infoViewSavingOptions.infoOffsetYRatio = self.previewInfoView.infoOffsetYRatio
        infoViewSavingOptions.infoScale = self.previewInfoView.infoScale
        self.savingInfoView =
            EventPresenterInfoView(
                frame: outputFrame, eventRecord: self.eventRecord,
                savingOptions: infoViewSavingOptions)
        self.savingInfoView.layer.contentsScale = CGFloat(self.outputScale)
        let savingInfoViewContainer = UIView(frame: self.savingInfoView.bounds)
        savingInfoViewContainer.hidden = true
        savingInfoViewContainer.addSubview(self.savingInfoView)
        self.view.addSubview(savingInfoViewContainer)
        savingOptions.topView = self.savingInfoView

        // Logo.
        if AppConfiguration.exportEventsWithAppLogo
        {
            let logo = UIImage(named: "AppLogoAlt")!
            let logoAspectRatio = logo.size.width/logo.size.height
            let refInfoViewOffset =
                self.previewInfoView.infoOffsetYRatio - self.infoOffsetYRatioShift
            let logoView = UIView(frame: outputFrame)
            var logoImageViewFrame = CGRectZero
            logoImageViewFrame.size.width =
                logoView.bounds.width*CGFloat(AppConfiguration.appLogoWidthFactor)
            logoImageViewFrame.size.height = logoImageViewFrame.width/logoAspectRatio
            logoImageViewFrame.origin.x = outputFrame.width - logoImageViewFrame.width
            if refInfoViewOffset < 0.5
            {
                // At the bottom.
                logoImageViewFrame.origin.y = outputFrame.height - logoImageViewFrame.height
                logoImageViewFrame.offsetInPlace(
                    dx: -AppConfiguration.appLogoOffset.x, dy: -AppConfiguration.appLogoOffset.y)
            }
            else
            {
                // At the top.
                logoImageViewFrame.origin.y = 0.0
                logoImageViewFrame.offsetInPlace(
                    dx: -AppConfiguration.appLogoOffset.x, dy: AppConfiguration.appLogoOffset.y)
            }
            let logoImageView = UIImageView(frame: logoImageViewFrame)
            logoImageView.contentMode = .ScaleAspectFit
            logoImageView.image = logo
            logoImageView.alpha = CGFloat(AppConfiguration.appLogoAlpha)
            logoView.addSubview(logoImageView)
            logoView.tintColor = UIColor.whiteColor()
            UIGraphicsBeginImageContextWithOptions(
                logoView.bounds.size, false, CGFloat(self.outputScale))
            logoView.drawViewHierarchyInRect(logoView.bounds, afterScreenUpdates: true)
            savingOptions.logo = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
        }

        self.savingBackgroundView =
            EventPresenterBackgroundView(
                frame: outputFrame, eventRecord: self.eventRecord,
                savingOptions: savingOptions)
        self.savingBackgroundView.outputDelegate = self

        let snapshot = self.view.snapshotViewAfterScreenUpdates(false)
        self.snapshotForSharerVC = self.view.snapshotViewAfterScreenUpdates(false)

        self.view.insertSubview(snapshot, belowSubview: self.cancelBN)

        self.previewBackgroundView.removeFromSuperview()
        self.previewBackgroundView.deactivate()
        self.previewBackgroundView = nil
        self.previewInfoView.removeFromSuperview()
        self.previewInfoView.deactivate()
        self.previewInfoView = nil

        self.view.userInteractionEnabled = false

        self.savingInfoView.makeDigitsStopMotionFrame()

        let doSaving = {
            let vc =
                UIStoryboard(name: "EventSharer", bundle: nil).instantiateInitialViewController()!
            let sharerVC = vc as! EventSharerViewController
            sharerVC.inputDelegate = self
            sharerVC.modalPresentationStyle = .OverFullScreen
            self.presentViewController(sharerVC, animated: false, completion: {
                on_main_with_delay(0.25) {
                    self.savingBackgroundView.save()
                }
            })
        }

        authorizePhotoLibraryUsageIfNeededWithSuccessClosure({
            doSaving()
        },
        failureClosure: {
            self.dismiss()
        })
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func outputPictureIsReady (picture:UIImage)
    {
        self.savedPicture = picture

        self.savingDidComplete()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func outputVideoDidCompleteFrameWithProgress (progress:Double)
    {
        self.videoSavingProgress = progress

        dispatch_semaphore_wait(
            self.savingBackgroundView.topViewRenderingSemaphore, DISPATCH_TIME_FOREVER)

        self.savingInfoView.makeDigitsStopMotionFrame()

        dispatch_semaphore_signal(self.savingBackgroundView.topViewRenderingSemaphore)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func outputVideoIsReadyWithSuccess (success:Bool, videoTempRelPath:String?)
    {
        if success
        {
            let videoTempURL =
                AppConfiguration.tempDirURL.URLByAppendingPathComponent(videoTempRelPath!)
            self.savedVideoURL = makeTempFileURL(AppConfiguration.tempDirURL, ext: "mp4")
            let fm = NSFileManager()
            try! fm.moveItemAtURL(videoTempURL, toURL: self.savedVideoURL)

            self.savingDidComplete()
        }
        else
        {
            self.dismiss()
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func savingDidComplete ()
    {
        self.savingBackgroundView.removeFromSuperview()
        self.savingBackgroundView.deactivate()
        self.savingBackgroundView = nil
        self.savingInfoView.removeFromSuperview()
        self.savingInfoView.deactivate()
        self.savingInfoView = nil

        self.savingIsComplete = true
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func provideInputDataForEventSharerViewController () -> [String: AnyObject]
    {
        var data = [String: AnyObject]()

        data["snapshot"] = self.snapshotForSharerVC

        data["eventRecord"] = self.eventRecord

        return data
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func exportTypeForEventSharerViewController () -> EventExportType
    {
        return self.currExportType
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func isSavingCompleteForEventSharerViewController () -> Bool
    {
        return self.savingIsComplete
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func savedPictureForEventSharerViewController () -> UIImage
    {
        return self.savedPicture
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func videoSavingProgressForEventSharerViewController () -> Double
    {
        return self.videoSavingProgress
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func savedVideoURLForEventSharerViewController () -> NSURL
    {
        return self.savedVideoURL
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func sharingDestinationForEventSharerViewController () -> EventSharingDestination
    {
        return self.sharingDestination
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func eventSharerViewControllerWillDismiss ()
    {
        self.dismiss()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction func captureBNAction ()
    {
        // IAP
        let ud = NSUserDefaults.standardUserDefaults()
        if AppConfiguration.sharingRequiresFullVersion && !ud.boolForKey("appIsFullVersion")
        {
            let message = "This feature is only available in the Full Version."
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .Alert)
            let iapTitle = "Upgrade to the Full Version"
            alert.addAction(UIAlertAction(title: iapTitle, style: .Default, handler: { _ in
                appD().upgradeAppToFullVersion()
            }))
            alert.addAction(UIAlertAction(title: "Close", style: .Cancel, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)

            return
        }

        self.doCapture()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction private func dismiss ()
    {
        self.previewBackgroundView?.deactivate()
        self.previewInfoView?.deactivate()

        self.savingBackgroundView?.cancelSaving()
        self.savingBackgroundView?.deactivate()
        self.savingInfoView?.deactivate()

        //AppConfiguration.clearTempDir()

        self.inputDelegate?.eventExporterViewControllerWillDismiss()
        self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }

    //----------------------------------------------------------------------------------------------
}



