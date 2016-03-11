import Viewmorphic


//--------------------------------------------------------------------------------------------------

protocol FrameStyleChooserViewControllerInputOutput : class
{
    func provideInputDataForFrameStyleChooserViewController () -> [String: AnyObject]
    func acceptOutputDataFromFrameStyleChooserViewController (data:[String: AnyObject])
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

class SlotRecord
{
    let isNoFrameSlot:Bool
    private var id:Int!
    private var frameImageData:NSData!
    var frameThumb:UIImage!
    private var textRect:CGRect!
    private var hasColor:Bool!
    private var hasFill:Bool!

    private var frameImageView:UIImageView!
    private var titleLB:TitleLabel!

    private var origImage:UIImage!
    private var invert = false
    private var colorize = false
    private var colorizeHue = 0.0

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    init ()
    {
        self.isNoFrameSlot = true
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    init (
        id:Int, frameImageData:NSData, frameThumb:UIImage, textRect:CGRect, hasColor:Bool,
        hasFill:Bool)
    {
        self.id = id
        self.isNoFrameSlot = false
        self.frameImageData = frameImageData
        self.frameThumb = frameThumb
        self.textRect = textRect
        self.hasColor = hasColor
        self.hasFill = hasFill
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
}

//--------------------------------------------------------------------------------------------------


class FrameStyleChooserViewController : UIViewController, UIScrollViewDelegate,
                                        FrameChooserGridViewControllerInputOutput
{
    weak var inputOutputDelegate:FrameStyleChooserViewControllerInputOutput!
    private var inputData:[String: AnyObject]!

    @IBOutlet private weak var backgroundImageViewContainer:UIView!
    @IBOutlet private weak var backgroundImageView:UIImageView!
    @IBOutlet private weak var framesSVContainer:UIView!
    @IBOutlet private weak var framesSV:UIScrollView!
    @IBOutlet private weak var cancelBN:UIButton!
    @IBOutlet private weak var doneBN:UIButton!
    @IBOutlet private weak var gridViewBN:UIButton!
    @IBOutlet private weak var recolorSliderContainer:UIView!
    @IBOutlet private weak var invertLB:UILabel!
    @IBOutlet private weak var colorizeLB:UILabel!
    @IBOutlet private weak var initPromptLB:UILabel!

    private let cornerRadius = 12.0
    private var slots = [SlotRecord]()
    private var currSlotIndex = 0
    private var prevSlotIndex = -1
    private var slotWidth:CGFloat!
    private var slotHeight:CGFloat!
    private var recolorSlider:TGPDiscreteSlider!
    private var colorizeHueSlider:TGPDiscreteSlider!
    private var asyncQueue:dispatch_queue_t!
    private var once = 0

    private let excludedFrameIDs = [
        37,
        38,
        41,
        42,
        43,
        47,
        64,
        70,
        80,
        87,
        88,
        99,
        100,
        101,
    ]

    //----------------------------------------------------------------------------------------------

    override func viewDidLoad ()
    {
        super.viewDidLoad()

        self.inputData =
            self.inputOutputDelegate.provideInputDataForFrameStyleChooserViewController()

        let queueLabel = "FrameStyleChooserViewController.asyncQueue"
        self.asyncQueue = dispatch_queue_create(queueLabel, DISPATCH_QUEUE_SERIAL)

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

        let tarURL = NSBundle.mainBundle().URLForResource("Frames.tar", withExtension: nil)!
        let tarData = NSData(contentsOfFile: tarURL.path!)
        let fm = NSFileManager()
        let itemsDict = try! fm.readFilesWithTarData(tarData, progress: nil) as NSDictionary
        let keyPrefix = "Frames/"
        var frameID = 1
        while true
        {
            if self.excludedFrameIDs.contains(frameID)
            {
                frameID++
                continue
            }

            let frameIDString = String(format: "%03d", frameID)
            let frameKey = keyPrefix + frameIDString
            let frameImageKey = "\(frameKey)/F.png"
            let frameThumbKey = "\(frameKey)/T.png"
            let frameMetaKey = "\(frameKey)/Meta.json"
            let frameImageData = itemsDict.objectForKey(frameImageKey) as? NSData
            let frameThumbData = itemsDict.objectForKey(frameThumbKey) as? NSData
            let frameMetaData = itemsDict.objectForKey(frameMetaKey) as? NSData
            if frameImageData != nil
            {
                let frameThumb = UIImage(data: frameThumbData!)!
                let frameMeta = JSON(data: frameMetaData!).dictionaryObject!
                let textRectDict = frameMeta["textRect"] as! [String: AnyObject]
                let textRect =
                    CGRect(
                        x: textRectDict["x"] as! Double,
                        y: textRectDict["y"] as! Double,
                        width: textRectDict["w"] as! Double,
                        height: textRectDict["h"] as! Double)
                let hasColor = (frameMeta["hasColor"] as? Bool) ?? false
                let hasFill = (frameMeta["hasFill"] as? Bool) ?? false
                let slotRecord =
                    SlotRecord(
                        id: frameID, frameImageData: frameImageData!, frameThumb: frameThumb,
                        textRect: textRect, hasColor: hasColor, hasFill: hasFill)

                self.slots.append(slotRecord)
            }
            else
            {
                break
            }

            frameID++
        }
        self.slots.append(SlotRecord())

        self.gridViewBN.layer.shadowColor = UIColor.blackColor().CGColor
        self.gridViewBN.layer.shadowOpacity = 0.75
        self.gridViewBN.layer.shadowRadius = 5.0
        self.gridViewBN.layer.shadowOffset = CGSizeZero
        self.gridViewBN.layer.shouldRasterize = true
        self.gridViewBN.layer.rasterizationScale = UIScreen.mainScreen().scale
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func viewDidLayoutSubviews ()
    {
        super.viewDidLayoutSubviews()

        if UIScreen.mainScreenAspectRatio == .AspectRatio3x4
        {
            self.initPromptLB.frame.origin.y = 310.0
        }

        dispatch_once(&self.once) {
            self.framesSVContainer.layoutSubviews()

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

            self.slotWidth = self.framesSV.bounds.width
            self.slotHeight = self.framesSV.bounds.height

            let contentWidth = CGFloat(self.slots.count)*self.slotWidth
            self.framesSV.contentSize = CGSize(width: contentWidth, height: self.slotHeight)
            self.framesSV.delegate = self

            let colors = [
                UIColor.whiteColor().colorWithAlphaComponent(0.0).CGColor,
                UIColor.whiteColor().colorWithAlphaComponent(1.0).CGColor,
                UIColor.whiteColor().colorWithAlphaComponent(1.0).CGColor,
                UIColor.whiteColor().colorWithAlphaComponent(0.0).CGColor,
            ]
            let padding = 0.12
            let locations = [
                0.0,
                padding,
                1.0 - padding,
                1.0,
            ]
            let framesSVFadeOut = CAGradientLayer()
            framesSVFadeOut.frame = self.framesSVContainer.bounds
            framesSVFadeOut.colors = colors
            framesSVFadeOut.startPoint = CGPoint(x: 0.0, y: 0.0)
            framesSVFadeOut.endPoint = CGPoint(x: 1.0, y: 0.0)
            framesSVFadeOut.locations = locations
            self.framesSVContainer.layer.mask = framesSVFadeOut

            self.recolorSlider = TGPDiscreteSlider(frame: self.recolorSliderContainer.bounds)
            self.recolorSlider.value = 1
            self.recolorSlider.tickCount = 3
            self.recolorSlider.incrementValue = 1
            self.recolorSlider.tickStyle = 2
            self.makeupDiscreteSlider(self.recolorSlider)
            self.recolorSlider.addTarget(
                self, action: "recolorSliderValueChanged", forControlEvents: .ValueChanged)
            self.recolorSlider.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
            self.recolorSliderContainer.addSubview(self.recolorSlider)

            for label in [self.invertLB, self.colorizeLB, self.initPromptLB]
            {
                label.shownAlpha = 0.66
                label.layer.shadowColor = UIColor.blackColor().CGColor
                label.layer.shadowOpacity = 0.5
                label.layer.shadowOffset = CGSizeZero
                label.layer.shadowRadius = 3.0
            }

            let colorizeHueSliderPaddingX:CGFloat = 42.0
            var colorizeHueSliderFrame = CGRectZero
            colorizeHueSliderFrame.origin.x = 0.0
            colorizeHueSliderFrame.size.width = self.view.bounds.width
            colorizeHueSliderFrame.origin.y = self.recolorSliderContainer.frame.midY - 90.0
            colorizeHueSliderFrame.size.height = 50.0
            colorizeHueSliderFrame.insetInPlace(dx: colorizeHueSliderPaddingX, dy: 0.0)
            self.colorizeHueSlider = TGPDiscreteSlider(frame: colorizeHueSliderFrame)
            self.colorizeHueSlider.tickCount = 512
            self.colorizeHueSlider.incrementValue = 1
            self.colorizeHueSlider.tickStyle = 3
            self.makeupDiscreteSlider(self.colorizeHueSlider)
            self.colorizeHueSlider.trackStyle = 4
            self.colorizeHueSlider.trackImage = "Spectrum"
            self.colorizeHueSlider.addTarget(
                self, action: "colorizeHueSliderValueChanged", forControlEvents: .ValueChanged)
            self.colorizeHueSlider.alpha = 0.0
            self.view.addSubview(self.colorizeHueSlider)

            let noFrameLabelOffset = CGFloat(self.slots.count - 1)*self.slotWidth
            let noFrameLabel =
                UILabel(
                    frame: CGRect(
                        x: noFrameLabelOffset,
                        y: 0.0,
                        width: self.slotWidth,
                        height: self.slotHeight))
            noFrameLabel.text = "Frameless"
            noFrameLabel.textAlignment = .Center
            noFrameLabel.textColor = UIColor.whiteColor()
            noFrameLabel.font = UIFont.systemFontOfSize(20.0)
            noFrameLabel.alpha = 0.8
            noFrameLabel.layer.shadowColor = UIColor.blackColor().CGColor
            noFrameLabel.layer.shadowOffset = CGSizeZero
            noFrameLabel.layer.shadowRadius = 3.0
            noFrameLabel.layer.shadowOpacity = 0.75
            self.framesSV.addSubview(noFrameLabel)

            self.moveToSlotAtIndex(self.currSlotIndex)
            self.currentSlotDidChange()
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func makeupDiscreteSlider (slider:TGPDiscreteSlider)
    {
        slider.opaque = false
        slider.minimumValue = 0.0
        slider.trackStyle = 2
        slider.trackThickness = 0.5
        slider.tickSize = CGSize(width: 10.0, height: 10.0)
        slider.tintColor = AppConfiguration.bluishColor
        slider.thumbStyle = 2
        slider.thumbColor = UIColor.whiteColor()
        slider.thumbSize = CGSize(width: 30.0, height: 30.0)
        slider.thumbSRadius = 2.0
        slider.thumbSOffset = CGSizeZero
        slider.shownAlpha = 0.66

        slider.layer.shouldRasterize = true
        slider.layer.rasterizationScale = UIScreen.mainScreen().scale
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

    func scrollingDidChange ()
    {
        var slotIndex = Int(round(self.framesSV.contentOffset.x/self.slotWidth))
        if slotIndex < 0
        {
            slotIndex = 0
        }
        else if slotIndex > self.slots.count - 1
        {
            slotIndex = self.slots.count - 1
        }

        if slotIndex != self.prevSlotIndex
        {
            self.prevSlotIndex = self.currSlotIndex
            self.currSlotIndex = slotIndex

            self.currentSlotDidChange()
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func scrollViewDidEndDecelerating (scrollView:UIScrollView)
    {
        self.scrollingDidChange()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func currentSlotDidChange ()
    {
        let slotIndexesForLoading = [
            self.currSlotIndex - 1,
            self.currSlotIndex,
            self.currSlotIndex + 1,
        ]

        for slotIndex in 0..<self.slots.count
        {
            if !slotIndexesForLoading.contains(slotIndex)
            {
                let slotRecord = self.slots[slotIndex]

                if !slotRecord.isNoFrameSlot && slotRecord.frameImageView != nil &&
                   !(slotRecord.invert || slotRecord.colorize)
                {
                    slotRecord.frameImageView.removeFromSuperview()
                    slotRecord.frameImageView = nil
                }
            }
        }

        for slotIndex in slotIndexesForLoading
        {
            if 0 <= slotIndex && slotIndex < self.slots.count
            {
                let slotRecord = self.slots[slotIndex]

                if slotRecord.isNoFrameSlot
                {
                    continue
                }

                if slotRecord.frameImageView == nil
                {
                    //dispatch_async(self.asyncQueue) {
                    on_main_sync() {
                        let frameImage = UIImage(data: slotRecord.frameImageData)!

                        //on_main() {
                        on_main_sync() {
                            slotRecord.frameImageView = UIImageView(image: frameImage)
                            slotRecord.frameImageView.contentMode = .ScaleToFill
                            if slotIndex == 0
                            {
                                slotRecord.frameImageView.hidden = true
                            }

                            let offsetX = CGFloat(slotIndex)*self.slotWidth
                            let outerTextRect =
                                FrameStyleRecord.layoutFrameImageView(
                                    slotRecord.frameImageView, inView: self.framesSV,
                                    withTextRect: slotRecord.textRect, offsetX: offsetX,
                                    frameID: slotRecord.id)
                            if slotIndex == 0
                            {
                                slotRecord.frameImageView.hiddenAnimated = false
                            }

                            if slotRecord.titleLB == nil
                            {
                                slotRecord.titleLB =
                                    TitleLabel(
                                        frame: outerTextRect,
                                        fontSize: AppConfiguration.titleFontSizeFramed)
                                if slotIndex == 0
                                {
                                    slotRecord.titleLB.hidden = true
                                }
                                if let title = self.inputData["title"] as? String
                                {
                                    slotRecord.titleLB.text = title
                                }
                                if let titleStyleRecord =
                                   self.inputData["titleStyleRecord"] as? TitleStyleRecord
                                {
                                    slotRecord.titleLB.fontName = titleStyleRecord.fontName
                                    slotRecord.titleLB.textColor = titleStyleRecord.color
                                }

                                if !slotRecord.hasFill!
                                {
                                    self.framesSV.insertSubview(
                                        slotRecord.titleLB, belowSubview: slotRecord.frameImageView)
                                }
                                else
                                {
                                    self.framesSV.addSubview(slotRecord.titleLB)
                                }
                                if slotIndex == 0
                                {
                                    slotRecord.titleLB.hiddenAnimated = false
                                }
                            }
                            else
                            {
                                if slotRecord.hasFill!
                                {
                                    self.framesSV.insertSubview(
                                        slotRecord.titleLB, aboveSubview: slotRecord.frameImageView)
                                }
                            }
                        }
                    }
                }
            }
        }

        let currSlotRecord = self.slots[self.currSlotIndex]

        if !currSlotRecord.isNoFrameSlot
        {
            self.recolorSliderContainer.hiddenAnimated = false
            self.invertLB.hiddenAnimated = false
            self.colorizeLB.hiddenAnimated = false

            if currSlotRecord.invert
            {
                self.recolorSlider.value = 0
            }
            else if currSlotRecord.colorize
            {
                self.recolorSlider.value = 2
            }
            else
            {
                self.recolorSlider.value = 1
            }
            self.colorizeHueSlider.hiddenAnimated = !currSlotRecord.colorize
            self.colorizeHueSlider.value =
                CGFloat(currSlotRecord.colorizeHue*Double(self.colorizeHueSlider.tickCount - 1))
        }
        else
        {
            self.recolorSliderContainer.hiddenAnimated = true
            self.invertLB.hiddenAnimated = true
            self.colorizeLB.hiddenAnimated = true
            self.colorizeHueSlider.hiddenAnimated = true
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func scrollViewDidScroll (scrollView:UIScrollView)
    {
        self.scrollingDidChange()

        self.initPromptLB.hiddenAnimated = true
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func recolorSliderValueChanged ()
    {
        self.recoloringInputDidChange()

        let sliderValueInt = Int(round(self.recolorSlider.value))
        self.colorizeHueSlider.hiddenAnimated = sliderValueInt != 2
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func recoloringInputDidChange (byColorizeHueSlider:Bool = false)
    {
        let sliderValueInt = Int(round(self.recolorSlider.value))

        let currSlotRecord = self.slots[self.currSlotIndex]

        if currSlotRecord.frameImageView == nil
        {
            return
        }

        let origImage:UIImage
        if currSlotRecord.origImage == nil
        {
            origImage = UIImage(data: currSlotRecord.frameImageData)!
            currSlotRecord.origImage = origImage
        }
        else
        {
            origImage = currSlotRecord.origImage
        }

        if sliderValueInt == 0
        {
            let recoloredImage:UIImage
            if !currSlotRecord.hasColor
            {
                let luminance:CGFloat = 0.1
                let tintColor =
                    UIColor(red: luminance, green: luminance, blue: luminance, alpha: 1.0)
                recoloredImage =
                    NodeSystem.filteredImageFromImage(
                        origImage, filterType: .ColorTint, settings: ["tintColor": tintColor])
            }
            else
            {
                recoloredImage =
                    NodeSystem.filteredImageFromImage(origImage, filterType: .ColorInvert)
            }
            UIView.transitionWithView(
                currSlotRecord.frameImageView, duration: 0.2, options: .TransitionCrossDissolve,
                animations: {
                    currSlotRecord.frameImageView.image = recoloredImage
                },
                completion: nil)

            currSlotRecord.invert = true
            currSlotRecord.colorize = false
        }
        else if sliderValueInt == 2
        {
            let tintColor =
                UIColor(
                    hue: CGFloat(currSlotRecord.colorizeHue), saturation: 0.8, brightness: 0.95,
                    alpha: 1.0)
            let recoloredImage =
                NodeSystem.filteredImageFromImage(
                    origImage, filterType: .ColorTint, settings: ["tintColor": tintColor])
            if !byColorizeHueSlider
            {
                UIView.transitionWithView(
                    currSlotRecord.frameImageView, duration: 0.2,
                    options: .TransitionCrossDissolve, animations: {
                        currSlotRecord.frameImageView.image = recoloredImage
                    },
                    completion: nil)
            }
            else
            {
                currSlotRecord.frameImageView.image = recoloredImage
            }

            currSlotRecord.invert = false
            currSlotRecord.colorize = true
        }
        else
        {
            UIView.transitionWithView(
                currSlotRecord.frameImageView, duration: 0.2, options: .TransitionCrossDissolve,
                animations: {
                    currSlotRecord.frameImageView.image = origImage
                },
                completion: nil)

            currSlotRecord.invert = false
            currSlotRecord.colorize = false
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func colorizeHueSliderValueChanged ()
    {
        let sliderValue =
            Double(self.colorizeHueSlider.value)/Double(self.colorizeHueSlider.tickCount - 1)

        let currSlotRecord = self.slots[self.currSlotIndex]
        currSlotRecord.colorizeHue = sliderValue
        self.recoloringInputDidChange(true)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func dismiss ()
    {
        self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func outputFrameStyle ()
    {
        self.scrollingDidChange()

        let currSlotRecord = self.slots[self.currSlotIndex]

        if !currSlotRecord.isNoFrameSlot && currSlotRecord.frameImageView?.image == nil
        {
            return
        }

        var frameStyleRecord:FrameStyleRecord!

        if !currSlotRecord.isNoFrameSlot
        {
            frameStyleRecord = FrameStyleRecord()
            frameStyleRecord.frameImage = currSlotRecord.frameImageView.image!
            frameStyleRecord.frameID = currSlotRecord.id
            frameStyleRecord.textRect = currSlotRecord.textRect
            frameStyleRecord.hasFill = currSlotRecord.hasFill

            let snapshotPaddingH:CGFloat = 12.0
            let snapshotPaddingV:CGFloat = 18.0
            let snapshotImageViewContainer = UIView(frame: currSlotRecord.frameImageView.bounds)
            let snapshotFrame =
                snapshotImageViewContainer.bounds.insetBy(
                    dx: snapshotPaddingH,
                    dy: snapshotPaddingV)
            let snapshotImageView = UIImageView(frame: snapshotFrame)
            snapshotImageView.contentMode = .ScaleAspectFit
            snapshotImageView.image = currSlotRecord.frameImageView.image
            snapshotImageViewContainer.addSubview(snapshotImageView)
            UIGraphicsBeginImageContextWithOptions(
                snapshotImageViewContainer.bounds.size, false, 0.0)
            snapshotImageViewContainer.drawViewHierarchyInRect(
                snapshotImageViewContainer.bounds, afterScreenUpdates: true)
            let snapshot = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            frameStyleRecord.snapshot = snapshot
        }

        var outputData = [String: AnyObject]()
        if frameStyleRecord != nil
        {
            outputData["frameStyleRecord"] = frameStyleRecord
        }
        self.inputOutputDelegate.acceptOutputDataFromFrameStyleChooserViewController(outputData)

        self.dismiss()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func provideInputDataForFrameChooserGridViewController () -> [String: AnyObject]
    {
        var data = [String: AnyObject]()
        data["slots"] = self.slots
        return data
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func acceptOutputDataFromFrameChooserGridViewController (data:[String: AnyObject])
    {
        let slotIndex = data["slotIndex"] as! Int
        self.moveToSlotAtIndex(slotIndex)

        self.initPromptLB.hiddenAnimated = true
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func moveToSlotAtIndex (slotIndex:Int)
    {
        self.framesSV.contentOffset.x = CGFloat(slotIndex)*self.slotWidth
        self.scrollingDidChange()
    }

    //----------------------------------------------------------------------------------------------

    @IBAction private func cancelBNAction ()
    {
        self.dismiss()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction private func doneBNAction ()
    {
        self.outputFrameStyle()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction func gridViewBNAction ()
    {
        let sb = UIStoryboard(name: "FrameChooserGridView", bundle: nil)
        let gridViewVC = sb.instantiateInitialViewController()! as! FrameChooserGridViewController
        gridViewVC.inputOutputDelegate = self

        let gridViewContainerVC = UIViewController()
        gridViewContainerVC.view.frame = gridViewVC.view.frame

        let be = UIBlurEffect(style: .Dark)

        let blView = UIVisualEffectView(effect: be)
        blView.frame = gridViewContainerVC.view.bounds
        blView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        gridViewContainerVC.view.addSubview(blView)

        let viView = UIVisualEffectView(effect: UIVibrancyEffect(forBlurEffect: be))
        viView.frame = blView.bounds
        viView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        blView.contentView.addSubview(viView)

        gridViewContainerVC.addChildViewController(gridViewVC)
        gridViewVC.view.frame = viView.bounds
        viView.contentView.addSubview(gridViewVC.view)
        gridViewVC.didMoveToParentViewController(gridViewContainerVC)

        viView.backgroundColor = AppConfiguration.bluishColor.colorWithAlphaComponent(0.4)

        gridViewContainerVC.modalTransitionStyle = .CrossDissolve
        gridViewContainerVC.modalPresentationStyle = .OverFullScreen
        self.presentViewController(gridViewContainerVC, animated: true, completion: nil)
    }

    //----------------------------------------------------------------------------------------------
}



