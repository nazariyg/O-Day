import UIKit
import Alamofire
import Viewmorphic
import Photos
import MobileCoreServices


//--------------------------------------------------------------------------------------------------

protocol OverlayChooserViewControllerOutput : class
{
    func provideInputDataForOverlayChooserViewController () -> [String: AnyObject]
    func acceptOutputDataFromOverlayChooserViewController (data:[String: AnyObject])
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

private class CachedVideo
{
    var videoURL:NSURL?
    {
        get {
            // Making a check if the video file hasn't been removed from the temporary directory by
            // the system.
            if let path = self._videoURL?.path where NSFileManager().fileExistsAtPath(path)
            {
                return self._videoURL
            }
            else
            {
                self._videoURL = nil
                return nil
            }
        }

        set {
            self._videoURL = newValue
        }
    }

    var _videoURL:NSURL?
    var resolution:String
    var isOwner:Bool

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    init (videoURL:NSURL?, resolution:String, isOwner:Bool = true)
    {
        self._videoURL = videoURL
        self.resolution = resolution
        self.isOwner = isOwner
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    deinit
    {
        if self.isOwner
        {
            if let videoURL = self._videoURL
            {
                // Remove the video file.
                _ = try? NSFileManager().removeItemAtURL(videoURL)
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
}

//--------------------------------------------------------------------------------------------------

class OverlaySettings : NSObject, NSCoding
{
    let defaultBlenderType:Blender.BlenderType
    var cropRegion:CGRect
    let addedTransform:CGAffineTransform
    let defaultInputImageBrightness:Double
    var blenderType:Blender.BlenderType
    var isFlippedH = false
    var isFlippedV = false
    var hue = 0.0
    var inputImageBrightness:Double
    var zoomBlur = 0.0
    var pausedTime:CMTime!

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    init (
        blenderType:Blender.BlenderType, cropRegion:CGRect, addedTransform:CGAffineTransform,
        inputImageBrightness:Double)
    {
        self.defaultBlenderType = blenderType
        self.cropRegion = cropRegion
        self.addedTransform = addedTransform
        self.defaultInputImageBrightness = inputImageBrightness
        self.blenderType = blenderType
        self.inputImageBrightness = inputImageBrightness
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func encodeWithCoder (aCoder:NSCoder)
    {
        aCoder.encodeObject(
            BackgroundOverlayRecord.stringFromBlenderType(self.defaultBlenderType),
            forKey: "defaultBlenderType")
        aCoder.encodeObject(
            NSValue(CGRect: self.cropRegion), forKey: "cropRegion")
        aCoder.encodeObject(
            NSValue(CGAffineTransform: self.addedTransform), forKey: "addedTransform")
        aCoder.encodeObject(
            self.defaultInputImageBrightness, forKey: "defaultInputImageBrightness")
        aCoder.encodeObject(
            BackgroundOverlayRecord.stringFromBlenderType(self.blenderType),
            forKey: "blenderType")
        aCoder.encodeObject(
            self.isFlippedH, forKey: "isFlippedH")
        aCoder.encodeObject(
            self.isFlippedV, forKey: "isFlippedV")
        aCoder.encodeObject(
            self.hue, forKey: "hue")
        aCoder.encodeObject(
            self.inputImageBrightness, forKey: "inputImageBrightness")
        aCoder.encodeObject(
            self.zoomBlur, forKey: "zoomBlur")
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    required init? (coder aDecoder:NSCoder)
    {
        self.defaultBlenderType =
            BackgroundOverlayRecord.blenderTypeFromString(
                aDecoder.decodeObjectForKey("defaultBlenderType") as! String)
        self.cropRegion =
            (aDecoder.decodeObjectForKey("cropRegion") as! NSValue).CGRectValue()
        self.addedTransform =
            (aDecoder.decodeObjectForKey("addedTransform") as! NSValue).CGAffineTransformValue()
        self.defaultInputImageBrightness =
            aDecoder.decodeObjectForKey("defaultInputImageBrightness") as! Double
        self.blenderType =
            BackgroundOverlayRecord.blenderTypeFromString(
                aDecoder.decodeObjectForKey("blenderType") as! String)
        self.isFlippedH =
            aDecoder.decodeObjectForKey("isFlippedH") as! Bool
        self.isFlippedV =
            aDecoder.decodeObjectForKey("isFlippedV") as! Bool
        self.hue =
            aDecoder.decodeObjectForKey("hue") as! Double
        self.inputImageBrightness =
            aDecoder.decodeObjectForKey("inputImageBrightness") as! Double
        self.zoomBlur =
            aDecoder.decodeObjectForKey("zoomBlur") as! Double

        super.init()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
}

//--------------------------------------------------------------------------------------------------


class OverlayChooserViewController : UIViewController, OverlayChooserOptionsViewControllerOutput,
                                     OverlayChooserOptionsViewControllerAltOutput,
                                     UIImagePickerControllerDelegate, UINavigationControllerDelegate
{
    weak var inputOutputDelegate:OverlayChooserViewControllerOutput!
    var backgroundOverlayRecord:BackgroundOverlayRecord!
    var backgroundCustomPictureRecord:BackgroundCustomPictureRecord!

    @IBOutlet private weak var previewView:UIView!
    @IBOutlet weak var swipeReceiver:UIView!
    @IBOutlet private weak var goBackBN:UIButton!
    @IBOutlet private weak var goForwardBN:UIButton!
    @IBOutlet private weak var cancelBN:UIButton!
    @IBOutlet private weak var selectBN:UIButton!
    @IBOutlet private weak var progressAI:UIActivityIndicatorView!
    @IBOutlet private weak var optionsBN:UIButton!
    @IBOutlet private weak var pickInputImageBN:UIButton!
    @IBOutlet private weak var overlaySettingsBN0:UIButton!
    @IBOutlet private weak var overlaySettingsBN1:UIButton!
    @IBOutlet private weak var overlaySettingsBN2:UIButton!
    @IBOutlet private weak var overlaySettingsBN3:UIButton!
    @IBOutlet private weak var overlaySettingsBN4:UIButton!
    @IBOutlet private weak var prompt:UILabel!

    private var overlaySettingsBNs:[UIButton]!

    private let videosURL = AppConfiguration.serverURLForAPI + "videos/"

    private var currItemIndex:Int!
    private var lastSearchResults:[JSON]!
    private var cachedVideos:KeyedItemsCache<CachedVideo>!
    private var lastSearchQuery:String!

    private enum ActivityType
    {
        case Search
        case DownloadVideoData
        case DownloadOutputVideo
    }

    private var activityIndicatorVC:NestableActivityIndicatorViewController!

    private let videosTempDirURL = {
        return AppConfiguration.tempDirURL.URLByAppendingPathComponent("v", isDirectory: true)
    }()

    private var hudView:UIView!

    private var videoDataIsBeingDownloaded = false
    private var currDownloadedVideoDataID:String!
    private var videoDownloadRequest:Request?

    private var videoIsBeingPredownloaded = false
    private var currPredownloadedVideoID:String!
    private var didPredownloadVideoClosureAlways:(() -> Void)!
    private var didPredownloadVideoClosureSuccess:(() -> Void)!
    private var predownloadedVideoWasPickedUp = false
    private var videoPredownloadRequest:Request?
    private let maxNumPredownloadedVideos = 2

    private var applicationWillResignActiveObserver:NSObjectProtocol!
    private var applicationDidBecomeActiveObserver:NSObjectProtocol!

    private var backgroundImageView:UIImageView!

    private var lastSetInputImage:UIImage!

    private var nodeSystem:NodeSystem!
    private var inputImage:Image!
    private var inputImageBrightnessFilter:Filter!
    private var overlay:Video!
    private var overlayCropFilter:Filter!
    private var overlayTransformFilter:Filter!
    private var overlayHueFilter:Filter!
    private var overlayZoomBlurFilter:Filter!
    private var overlayLowPassFilter:Filter!
    private var blender:Blender!
    private var outputLowPassFilter:Filter!
    private var outputView:OutputView!

    private let maxInputImagePixelDim = 1440
    private let minInputImagePixelWidth = 720
    private let outputLowPassFilterStrength = 0.95
    private let outputLowPassFilterSetToZeroFrequency = 0.01
    private let outputLowPassFilterSetToZeroSpeed = 0.005
    private var setOverlayLowPassFilterToZeroTimer:NSTimer!
    private var setOutputLowPassFilterToZeroTimer:NSTimer!
    private var setOverlayTimeoutTimer:NSTimer!

    private var itemIDsToOverlaySettings = [String: OverlaySettings]()
    private var currOverlaySettings:OverlaySettings!

    private let overlaySettingsBNsAlpha = 0.15
    private let overlaySettingsBNsAlphaSelected = 0.35
    private let overlaySettingsPanelAlpha = 0.5
    private var overlaySettingsSelectedBNIDs = Set<Int>()

    private var blenderSlider:TGPDiscreteSlider!
    private var transformSlider:TGPDiscreteSlider!
    private var hueSlider:TGPDiscreteSlider!
    private var brightnessSlider:TGPDiscreteSlider!
    private var zoomBlurSlider:TGPDiscreteSlider!
    private let hueSliderEmptyFilterSnapDist = 0.025
    private let brightnessSliderEmptyFilterSnapDist = 0.025
    private let zoomBlurSliderEmptyFilterSnapDist = 0.025
    private let brightnessRange = (-0.2, 0.2)
    private let zoomBlurRange = (0.0, 5.0)

    private let previewCornerRadius = 12.0

    private var once = 0

    //----------------------------------------------------------------------------------------------

    deinit
    {
        if let applicationWillResignActiveObserver = self.applicationWillResignActiveObserver
        {
            NSNotificationCenter.defaultCenter().removeObserver(applicationWillResignActiveObserver)
        }
        if let applicationDidBecomeActiveObserver = self.applicationDidBecomeActiveObserver
        {
            NSNotificationCenter.defaultCenter().removeObserver(applicationDidBecomeActiveObserver)
        }

        if self.videoDataIsBeingDownloaded
        {
            self.videoDownloadRequest?.cancel()
        }
        if self.videoIsBeingPredownloaded
        {
            self.videoPredownloadRequest?.cancel()
        }
    }

    //----------------------------------------------------------------------------------------------

    override func viewDidLoad ()
    {
        super.viewDidLoad()

        let inputData = self.inputOutputDelegate.provideInputDataForOverlayChooserViewController()
        self.backgroundOverlayRecord =
            inputData["backgroundOverlayRecord"] as? BackgroundOverlayRecord
        self.backgroundCustomPictureRecord =
            inputData["backgroundCustomPictureRecord"] as? BackgroundCustomPictureRecord

        self.view.backgroundColor = AppConfiguration.backgroundChooserBackgroundColor

        let screenSize = UIScreen.mainScreen().bounds
        let screenAspect = screenSize.height/screenSize.width

        var useAspect = screenAspect
        if UIDevice.currentDevice().userInterfaceIdiom == .Phone
        {
            if UIScreen.mainScreenAspectRatio == .AspectRatio9x16
            {
                useAspect *= 0.975
            }
            else if UIScreen.mainScreenAspectRatio == .AspectRatio3x4
            {
                useAspect *= 0.955
            }
        }
        else  // .Pad
        {
            //
        }

        self.view.addConstraint(
            NSLayoutConstraint(
                item: self.previewView, attribute: .Height,
                relatedBy: .Equal,
                toItem: self.previewView, attribute: .Width,
                multiplier: useAspect, constant: 0.0))

        if UIDevice.currentDevice().userInterfaceIdiom == .Pad
        {
            self.progressAI.transform = CGAffineTransformMakeScale(2.0, 2.0)
        }

        self.previewView.backgroundColor = UIColor.clearColor()

        self.previewView.layer.cornerRadius = CGFloat(self.previewCornerRadius)

        self.cachedVideos = KeyedItemsCache<CachedVideo>(capacity: 15)

        for button in [
            self.goBackBN,
            self.goForwardBN,
            self.cancelBN,
            self.selectBN,
            self.optionsBN,
            self.pickInputImageBN]
        {
            button.hidden = true
            button.shownAlpha = 0.2

            button.layer.shadowColor = UIColor.blackColor().CGColor
            button.layer.shadowOpacity = 0.75
            button.layer.shadowRadius = 5.0
            button.layer.shadowOffset = CGSizeZero
            button.layer.shouldRasterize = true
            button.layer.rasterizationScale = UIScreen.mainScreen().scale
        }
        self.cancelBN.hidden = false
        self.optionsBN.hidden = false
        self.pickInputImageBN.hidden = false

        self.overlaySettingsBNs = [
            self.overlaySettingsBN0,
            self.overlaySettingsBN1,
            self.overlaySettingsBN2,
            self.overlaySettingsBN3,
            self.overlaySettingsBN4,
        ]

        for button in self.overlaySettingsBNs
        {
            button.hidden = true
            button.shownAlpha = CGFloat(self.overlaySettingsBNsAlpha)

            button.layer.shadowColor = UIColor.blackColor().CGColor
            button.layer.shadowOpacity = 0.75
            button.layer.shadowRadius = 5.0
            button.layer.shadowOffset = CGSizeZero
            button.layer.shouldRasterize = true
            button.layer.rasterizationScale = UIScreen.mainScreen().scale
        }

        self.activityIndicatorVC =
            NestableActivityIndicatorViewController(activityIndicator: self.progressAI)

        let nc = NSNotificationCenter.defaultCenter()
        self.applicationWillResignActiveObserver =
            nc.addObserverForName(
                UIApplicationWillResignActiveNotification, object: nil,
                queue: NSOperationQueue.mainQueue()) { [weak self] _ in
                    guard let sSelf = self else
                    {
                        return
                    }

                    if sSelf.videoDataIsBeingDownloaded
                    {
                        sSelf.videoDownloadRequest?.suspend()
                    }
                    if sSelf.videoIsBeingPredownloaded
                    {
                        sSelf.videoPredownloadRequest?.suspend()
                    }
                }
        self.applicationDidBecomeActiveObserver =
            nc.addObserverForName(
                UIApplicationDidBecomeActiveNotification, object: nil,
                queue: NSOperationQueue.mainQueue()) { [weak self] _ in
                    guard let sSelf = self else
                    {
                        return
                    }

                    if sSelf.videoDataIsBeingDownloaded
                    {
                        sSelf.videoDownloadRequest?.resume()
                    }
                    if sSelf.videoIsBeingPredownloaded
                    {
                        sSelf.videoPredownloadRequest?.resume()
                    }
                }

        let defaultPicture = AppConfiguration.defaultPicture

        self.backgroundImageView = UIImageView(frame: self.previewView.bounds)
        self.backgroundImageView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.backgroundImageView.layer.cornerRadius =
            CGFloat(self.previewCornerRadius - self.previewCornerRadius*0.1)
        self.backgroundImageView.layer.masksToBounds = true
        self.backgroundImageView.contentMode = .ScaleAspectFill
        if self.backgroundOverlayRecord == nil && self.backgroundCustomPictureRecord == nil
        {
            self.backgroundImageView.image = defaultPicture
        }
        else if self.backgroundOverlayRecord != nil
        {
            let eventRecord = EventRecord()
            eventRecord.backgroundRecord = self.backgroundOverlayRecord
            self.backgroundImageView.image = eventRecord.backgroundOpeningImageForContainerSize()
        }
        else
        {
            self.backgroundImageView.image = self.backgroundCustomPictureRecord.picture
        }
        self.previewView.addSubview(self.backgroundImageView)

        self.nodeSystem = NodeSystem()
        self.nodeSystem.videosTotallySeamlessLoopsPowerOfTwo = 2
        self.nodeSystem.stopVideosBeforeReplacing = true
        if self.backgroundOverlayRecord == nil
        {
            if self.backgroundCustomPictureRecord == nil
            {
                self.inputImage = self.nodeSystem.addImage(defaultPicture)
            }
            else
            {
                self.inputImage =
                    self.nodeSystem.addImage(self.backgroundCustomPictureRecord.picture)
            }
            self.inputImageBrightnessFilter = self.nodeSystem.addFilter(.Empty)
            if self.backgroundCustomPictureRecord == nil
            {
                self.overlay =
                    self.nodeSystem.addVideo(
                        NSBundle.mainBundle().URLForResource(
                            "DefaultOverlay.mp4", withExtension: nil)!)
                let cropDeltaY = 0.2
                let cropRegion = CGRect(x: 0.0, y: cropDeltaY, width: 1.0, height: 1.0 - cropDeltaY)
                self.overlayCropFilter =
                    self.nodeSystem.addFilter(
                        .Crop, settings: ["cropRegion": NSValue(CGRect: cropRegion)])
            }
            else
            {
                self.overlay =
                    self.nodeSystem.addVideo(
                        NSBundle.mainBundle().URLForResource("DummyVideo.mp4", withExtension: nil)!)
                self.overlayCropFilter = self.nodeSystem.addFilter(.Empty)
            }
            self.overlayTransformFilter = self.nodeSystem.addFilter(.Empty)
            self.overlayHueFilter = self.nodeSystem.addFilter(.Empty)
            self.overlayZoomBlurFilter = self.nodeSystem.addFilter(.Empty)
            self.overlayLowPassFilter =
                self.nodeSystem.addFilter(
                    .LowPass, settings: ["filterStrength": self.outputLowPassFilterStrength])
            self.blender = self.nodeSystem.addBlender(.Screen)
        }
        else
        {
            self.inputImage = self.nodeSystem.addImage(self.backgroundOverlayRecord.inputImage)
            self.inputImageBrightnessFilter = self.nodeSystem.addFilter(.Empty)
            self.overlay = self.nodeSystem.addVideo(self.backgroundOverlayRecord.videoURL)
            self.overlayCropFilter = self.nodeSystem.addFilter(.Empty)
            self.overlayTransformFilter = self.nodeSystem.addFilter(.Empty)
            self.overlayHueFilter = self.nodeSystem.addFilter(.Empty)
            self.overlayZoomBlurFilter = self.nodeSystem.addFilter(.Empty)
            self.overlayLowPassFilter =
                self.nodeSystem.addFilter(
                    .LowPass, settings: ["filterStrength": self.outputLowPassFilterStrength])
            self.blender = self.nodeSystem.addBlender(.OnlyA)
        }
        self.outputLowPassFilter = self.nodeSystem.addFilter(.Empty)

        let iconDimSize = 64
        let iconOffsetY = 6.0
        let iconAttachment0 = NSTextAttachment()
        iconAttachment0.image =
            UIImage(named: "PickImage")!.resizedImageToNewPixelWidth(
                iconDimSize, newPixelHeight: iconDimSize)
        iconAttachment0.bounds =
            CGRect(x: 0.0, y: CGFloat(-iconOffsetY),
                width: iconAttachment0.image!.size.width,
                height: iconAttachment0.image!.size.height)
        let iconAttachment1 = NSTextAttachment()
        iconAttachment1.image =
            UIImage(named: "Options")!.resizedImageToNewPixelWidth(
                iconDimSize, newPixelHeight: iconDimSize)
        iconAttachment1.bounds =
            CGRect(x: 0.0, y: CGFloat(-iconOffsetY),
                width: iconAttachment1.image!.size.width,
                height: iconAttachment1.image!.size.height)
        let attrText = NSMutableAttributedString()
        attrText.appendAttributedString(NSAttributedString(string: "Tap "))
        attrText.appendAttributedString(NSAttributedString(attachment: iconAttachment0))
        attrText.appendAttributedString(NSAttributedString(string: " to place your image."))
        attrText.appendAttributedString(NSAttributedString(string: "\n"))
        attrText.appendAttributedString(NSAttributedString(string: "Tap "))
        attrText.appendAttributedString(NSAttributedString(attachment: iconAttachment1))
        attrText.appendAttributedString(NSAttributedString(string: " to select overlays."))
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .Center
        paragraphStyle.lineSpacing = 5.0
        let attributes = [
            NSFontAttributeName: UIFont.systemFontOfSize(14.0),
            NSParagraphStyleAttributeName: paragraphStyle,
        ]
        attrText.addAttributes(attributes, range: NSMakeRange(0, attrText.length))
        self.prompt.attributedText = attrText
        self.prompt.alpha = 0.5
        self.prompt.layer.shadowColor = UIColor.blackColor().CGColor
        self.prompt.layer.shadowOpacity = 0.5
        self.prompt.layer.shadowOffset = CGSizeZero
        self.prompt.layer.shadowRadius = 3.0
        self.prompt.layer.shouldRasterize = true
        self.prompt.layer.rasterizationScale = UIScreen.mainScreen().scale

        let grGoBack = UISwipeGestureRecognizer(target: self, action: "goBackBNAction")
        grGoBack.direction = .Right
        let grGoForward = UISwipeGestureRecognizer(target: self, action: "goForwardBNAction")
        grGoForward.direction = .Left
        self.swipeReceiver.addGestureRecognizer(grGoBack)
        self.swipeReceiver.addGestureRecognizer(grGoForward)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func viewDidLayoutSubviews ()
    {
        super.viewDidLayoutSubviews()

        dispatch_once(&self.once) {
            self.previewView.layer.shadowOpacity = 0.33
            self.previewView.layer.shadowColor = AppConfiguration.bluishColor.CGColor
            self.previewView.layer.shadowRadius = 12.0
            self.previewView.layer.shadowOffset = CGSizeZero
            let previewViewShadowPath =
                UIBezierPath(
                    roundedRect: self.previewView.bounds,
                    cornerRadius: CGFloat(self.previewCornerRadius))
            self.previewView.layer.shadowPath = previewViewShadowPath.CGPath

            self.outputView = self.nodeSystem.addOutputViewWithFrame(self.previewView.bounds)

            self.inputImage.linkTo(self.inputImageBrightnessFilter)
            self.inputImageBrightnessFilter.linkAtATo(self.blender)
            self.overlay.linkTo(self.overlayCropFilter)
            self.overlayCropFilter.linkTo(self.overlayTransformFilter)
            self.overlayTransformFilter.linkTo(self.overlayHueFilter)
            self.overlayHueFilter.linkTo(self.overlayZoomBlurFilter)
            self.overlayZoomBlurFilter.linkTo(self.overlayLowPassFilter)
            self.overlayLowPassFilter.linkAtBTo(self.blender)
            self.blender.linkTo(self.outputLowPassFilter)
            self.outputLowPassFilter.linkTo(self.outputView)

            self.outputView.view.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
            self.outputView.view.layer.cornerRadius =
                CGFloat(self.previewCornerRadius - self.previewCornerRadius*0.1)
            self.outputView.view.layer.masksToBounds = true
            self.outputView.view.layer.opaque = false
            self.previewView.addSubview(self.outputView.view)

            self.nodeSystem.activate()

            self.setOverlayLowPassFilterToZeroTimer =
                NSTimer.scheduledTimerWithTimeInterval(
                    self.outputLowPassFilterSetToZeroFrequency, target: self,
                    selector: "setOverlayLowPassFilterToZero:", userInfo: nil,
                    repeats: true)

            let bn0Frame = self.overlaySettingsBN0.frame
            let offsetX = bn0Frame.midX - 36.0
            var overlaySettingsPanelFrame =
                CGRect(
                    x: offsetX,
                    y: bn0Frame.origin.y - 50.0,
                    width: self.previewView.frame.size.width - offsetX*2.0,
                    height: 30.0)
            overlaySettingsPanelFrame.insetInPlace(dx: 3.0, dy: 0.0)

            self.blenderSlider = TGPDiscreteSlider(frame: overlaySettingsPanelFrame)
            self.blenderSlider.tickCount = 5
            self.blenderSlider.incrementValue = 1
            self.blenderSlider.tickStyle = 2
            self.makeupDiscreteSlider(self.blenderSlider)
            self.blenderSlider.addTarget(
                self, action: "blenderSliderValueChanged", forControlEvents: .ValueChanged)
            self.previewView.addSubview(self.blenderSlider)

            self.transformSlider = TGPDiscreteSlider(frame: overlaySettingsPanelFrame)
            self.transformSlider.tickCount = 4
            self.transformSlider.incrementValue = 1
            self.transformSlider.tickStyle = 2
            self.makeupDiscreteSlider(self.transformSlider)
            self.transformSlider.addTarget(
                self, action: "transformSliderValueChanged", forControlEvents: .ValueChanged)
            self.previewView.addSubview(self.transformSlider)

            self.hueSlider = TGPDiscreteSlider(frame: overlaySettingsPanelFrame)
            self.hueSlider.tickCount = 512
            self.hueSlider.incrementValue = 1
            self.hueSlider.tickStyle = 3
            self.makeupDiscreteSlider(self.hueSlider)
            self.hueSlider.trackStyle = 4
            self.hueSlider.trackImage = "Spectrum"
            self.hueSlider.addTarget(
                self, action: "hueSliderValueChanged", forControlEvents: .ValueChanged)
            self.previewView.addSubview(self.hueSlider)

            var brightnessSliderFrame = overlaySettingsPanelFrame
            brightnessSliderFrame.origin.y -= overlaySettingsPanelFrame.height + 10.0
            self.brightnessSlider = TGPDiscreteSlider(frame: brightnessSliderFrame)
            self.brightnessSlider.tickCount = 512
            self.brightnessSlider.incrementValue = 1
            self.brightnessSlider.tickStyle = 3
            self.makeupDiscreteSlider(self.brightnessSlider)
            self.brightnessSlider.trackStyle = 4
            self.brightnessSlider.trackImage = "Brightness"
            self.brightnessSlider.addTarget(
                self, action: "brightnessSliderValueChanged", forControlEvents: .ValueChanged)
            //self.previewView.addSubview(self.brightnessSlider)

            self.zoomBlurSlider = TGPDiscreteSlider(frame: overlaySettingsPanelFrame)
            self.zoomBlurSlider.tickCount = 512
            self.zoomBlurSlider.incrementValue = 1
            self.zoomBlurSlider.tickStyle = 3
            self.makeupDiscreteSlider(self.zoomBlurSlider)
            self.zoomBlurSlider.addTarget(
                self, action: "zoomBlurSliderValueChanged", forControlEvents: .ValueChanged)
            self.previewView.addSubview(self.zoomBlurSlider)

            self.hudView = UIView(frame: self.previewView.bounds)
            self.hudView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
            self.hudView.userInteractionEnabled = false
            self.previewView.addSubview(self.hudView)

            if let backgroundOverlayRecord = self.backgroundOverlayRecord
            {
                self.prompt.hidden = true

                self.lastSetInputImage = backgroundOverlayRecord.inputImage

                let cachedVideo =
                    CachedVideo(
                        videoURL: backgroundOverlayRecord.videoURL,
                        resolution: backgroundOverlayRecord.resolution, isOwner: false)
                self.cachedVideos.addItem(
                    cachedVideo, forKey: String(backgroundOverlayRecord.itemID))

                let overlaySettings =
                    NSKeyedUnarchiver.unarchiveObjectWithData(
                        backgroundOverlayRecord.overlaySettings)
                            as! OverlaySettings
                self.itemIDsToOverlaySettings[String(backgroundOverlayRecord.itemID)] =
                    overlaySettings
                self.currOverlaySettings = overlaySettings

                self.setInputImageBrightness(overlaySettings.inputImageBrightness)
                self.setOverlayBlenderType(overlaySettings.blenderType)
                self.setOverlayCropRegion(overlaySettings.cropRegion)
                self.setOverlayTransform(
                    isFlippedH: overlaySettings.isFlippedH,
                    isFlippedV: overlaySettings.isFlippedV)
                self.setOverlayHue(overlaySettings.hue)
                self.setOverlayZoomBlur(overlaySettings.zoomBlur)

                let item = JSON(data: backgroundOverlayRecord.item)
                self.lastSearchResults = [item]
                self.currItemIndex = 0
                self.updateControlButtons()
            }
            else if let backgroundCustomPictureRecord = self.backgroundCustomPictureRecord
            {
                self.setInputImage(backgroundCustomPictureRecord.picture)
            }
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
        slider.alpha = 0.0

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

    private func searchWithQuery (query:String)
    {
        if self.videoDataIsBeingDownloaded
        {
            self.videoDownloadRequest?.cancel()
        }
        if self.videoIsBeingPredownloaded
        {
            self.videoPredownloadRequest?.cancel()
        }

        let searchActivityID = self.activityWillBegin(.Search)

        let queryParams = [
            "app": AppConfiguration.appIDForServer,
            "a": AppConfiguration.aspectForServer,
            "o": "1",
            "q": query,
        ]
        let request =
            Alamofire.request(
                .GET, self.videosURL, parameters: queryParams,
                headers: AppConfiguration.serverHeaders)
        request.response { [weak self] _, response, data, _ in
            guard let sSelf = self else
            {
                return
            }

            sSelf.activityDidEnd(searchActivityID, activityType: .Search)

            if let response = response, data = data where response.statusCode == 200
            {
                sSelf.lastSearchQuery = query
                sSelf.didReceiveSearchResults(data)
            }
            else
            {
                sSelf.couldNotConnect()
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func activityWillBegin (activityType:ActivityType) -> Int
    {
        if !self.activityIndicatorVC.hasAnyActivity()
        {
            for subview in self.view.subviews
            {
                subview.userInteractionEnabled = false
            }
            self.cancelBN.userInteractionEnabled = true
        }

        let graceTime:Double
        switch activityType
        {
        case .Search:
            graceTime = 1.0
        case .DownloadVideoData:
            graceTime = 0.0
        case .DownloadOutputVideo:
            graceTime = 2.2
        }
        return self.activityIndicatorVC.activityIDForStartedActivityWithGraceTime(graceTime)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func activityDidEnd (activityID:Int, activityType:ActivityType)
    {
        self.activityIndicatorVC.stopIndicatingActivityWithID(activityID)

        if !self.activityIndicatorVC.hasAnyActivity()
        {
            for subview in self.view.subviews
            {
                subview.userInteractionEnabled = true
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func didReceiveSearchResults (data:NSData)
    {
        let resultsJSON = JSON(data: data)
        if let results = resultsJSON.array
        {
            //
            //print("Num results: \(results.count)")
            //

            if !results.isEmpty
            {
                self.lastSearchResults = results

                self.cachedVideos.clear()
                self.itemIDsToOverlaySettings.removeAll()

                self.currItemIndex = nil
                self.goToItemAtIndex(0)

                self.backgroundImageView.removeFromSuperview()
            }
            else
            {
                self.doMessage("No results")
            }
        }
        else
        {
            self.couldNotConnect()
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func couldNotConnect ()
    {
        self.doMessage("Could not connect")
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func doMessage (message:String)
    {
        let hud = MBProgressHUD.showHUDAddedTo(self.hudView, animated: true)
        hud.mode = .Text
        hud.labelText = message
        hud.labelFont = UIFont.systemFontOfSize(14.0)
        hud.hide(true, afterDelay: 2.0)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func goToItemAtIndex (index:Int)
    {
        let item = self.lastSearchResults[index]
        let itemID = item["item_id"].stringValue

        let cachedVideo = self.cachedVideos[itemID]
        if cachedVideo == nil
        {
            // The video is not yet in the cache.

            if self.videoIsBeingPredownloaded && itemID == self.currPredownloadedVideoID &&
               self.predownloadedVideoWasPickedUp
            {
                return
            }

            let pvURLAndRes = self.previewVideoURLAndResolutionForItem(item)
            if let previewVideoURL = pvURLAndRes.previewVideoURL
            {
                let resolution = pvURLAndRes.resolution

                self.videoDataIsBeingDownloaded = true
                self.currDownloadedVideoDataID = itemID
                self.videoDownloadRequest = nil

                let downloadVDActivityID = self.activityWillBegin(.DownloadVideoData)

                if self.videoIsBeingPredownloaded && itemID == self.currPredownloadedVideoID
                {
                    // The video is already being downloaded by the predownload functionality.
                    // "Pick up" the video by telling the predownload functionality what should be
                    // done thereafter.

                    self.didPredownloadVideoClosureAlways = {
                        self.activityDidEnd(downloadVDActivityID, activityType: .DownloadVideoData)
                    }
                    let prevItemIndex = self.currItemIndex
                    self.didPredownloadVideoClosureSuccess = {
                        if !self.videoDataIsBeingDownloaded ||
                           itemID != self.currDownloadedVideoDataID
                        {
                            return
                        }

                        self.videoDataIsBeingDownloaded = false

                        self.currItemIndex = index
                        self.updateControlButtons()

                        self.maybePredownloadVideoAfterIndex(index, prevItemIndex: prevItemIndex)
                    }

                    self.predownloadedVideoWasPickedUp = true

                    // The video predownload functionality is now able to handle it.
                    return
                }

                let cachedVideoAddedDate = NSDate()

                // Video.
                let tempFileURL = makeTempFileURL(self.videosTempDirURL, ext: "mp4")
                self.videoDownloadRequest = Alamofire.download(.GET, previewVideoURL) { _, _ in
                    return tempFileURL
                }
                .response { [weak self] _, response, _, error in
                    guard let sSelf = self else
                    {
                        return
                    }

                    sSelf.activityDidEnd(downloadVDActivityID, activityType: .DownloadVideoData)

                    if !sSelf.videoDataIsBeingDownloaded ||
                       itemID != sSelf.currDownloadedVideoDataID
                    {
                        return
                    }

                    sSelf.videoDataIsBeingDownloaded = false

                    if response?.statusCode == 200 && error == nil
                    {
                        let prevItemIndex = sSelf.currItemIndex

                        sSelf.currItemIndex = index
                        sSelf.updateControlButtons()

                        let cachedVideo = sSelf.cachedVideos[itemID]
                        if cachedVideo == nil
                        {
                            let cachedVideo =
                                CachedVideo(videoURL: tempFileURL, resolution: resolution)
                            sSelf.cachedVideos.addItem(
                                cachedVideo, forKey: itemID, usingAddedDate: cachedVideoAddedDate)

                            sSelf.setOverlay(tempFileURL, forItem: item)
                        }
                        else if cachedVideo!.videoURL == nil
                        {
                            cachedVideo!.videoURL = tempFileURL
                            cachedVideo!.resolution = resolution

                            sSelf.setOverlay(tempFileURL, forItem: item)
                        }

                        sSelf.maybePredownloadVideoAfterIndex(index, prevItemIndex: prevItemIndex)
                    }
                    else
                    {
                        sSelf.couldNotConnect()
                    }
                }
            }
        }
        else if cachedVideo!.videoURL != nil
        {
            // The video is available in the cache.

            let prevItemIndex = self.currItemIndex

            self.currItemIndex = index
            self.updateControlButtons()

            self.setOverlay(cachedVideo!.videoURL!, forItem: item)

            self.maybePredownloadVideoAfterIndex(index, prevItemIndex: prevItemIndex)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func updateControlButtons ()
    {
        self.goBackBN.hiddenAnimated =
            !(self.currItemIndex != nil && self.currItemIndex > 0)
        self.goForwardBN.hiddenAnimated =
            !(self.currItemIndex != nil && self.currItemIndex < self.lastSearchResults.count - 1)
        self.selectBN.hiddenAnimated =
            !(self.lastSetInputImage != nil)
        if self.currItemIndex != nil
        {
            for button in self.overlaySettingsBNs
            {
                button.hiddenAnimated = false
            }
        }
        if self.currItemIndex != nil && self.lastSetInputImage != nil && !self.prompt.hidden
        {
            self.hidePrompt()
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func maybePredownloadVideoAfterIndex (
        index:Int, prevItemIndex:Int?, numAlreadyPredownloadedVideos:Int? = nil)
    {
        let usePrevItemIndex = prevItemIndex ?? -1
        let indexDiff = index - usePrevItemIndex
        if indexDiff == 0 || indexDiff == 1
        {
            let nextIndex = index + 1
            if nextIndex < self.lastSearchResults.count
            {
                let nextItem = self.lastSearchResults[nextIndex]
                if self.cachedVideos[nextItem["item_id"].stringValue]?.videoURL == nil
                {
                    // Predownload the video to the right.
                    self.predownloadVideo(nextItem, atIndex: nextIndex, prevItemIndex: index,
                        numAlreadyPredownloadedVideos: numAlreadyPredownloadedVideos)
                }
            }
        }
        else if indexDiff == -1
        {
            let prevIndex = index - 1
            if prevIndex >= 0
            {
                let prevItem = self.lastSearchResults[prevIndex]
                if self.cachedVideos[prevItem["item_id"].stringValue]?.videoURL == nil
                {
                    // Predownload the video to the left.
                    self.predownloadVideo(prevItem, atIndex: prevIndex, prevItemIndex: index,
                        numAlreadyPredownloadedVideos: numAlreadyPredownloadedVideos)
                }
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func predownloadVideo (
        item:JSON, atIndex index:Int, prevItemIndex:Int?, numAlreadyPredownloadedVideos:Int?)
    {
        if self.videoIsBeingPredownloaded
        {
            return
        }

        let pvURLAndRes = self.previewVideoURLAndResolutionForItem(item)
        if let previewVideoURL = pvURLAndRes.previewVideoURL
        {
            let resolution = pvURLAndRes.resolution

            let itemID = item["item_id"].stringValue

            self.videoIsBeingPredownloaded = true
            self.currPredownloadedVideoID = itemID
            self.didPredownloadVideoClosureAlways = nil
            self.didPredownloadVideoClosureSuccess = nil
            self.predownloadedVideoWasPickedUp = false

            let cachedVideoAddedDate = NSDate()

            let tempFileURL = makeTempFileURL(self.videosTempDirURL, ext: "mp4")
            self.videoPredownloadRequest = Alamofire.download(.GET, previewVideoURL) { _, _ in
                return tempFileURL
            }
            .response { [weak self] _, response, _, error in
                guard let sSelf = self else
                {
                    return
                }

                if !sSelf.videoIsBeingPredownloaded || itemID != sSelf.currPredownloadedVideoID
                {
                    return
                }

                sSelf.videoIsBeingPredownloaded = false

                if sSelf.predownloadedVideoWasPickedUp
                {
                    sSelf.didPredownloadVideoClosureAlways()
                }

                if response?.statusCode == 200 && error == nil
                {
                    let cachedVideo = sSelf.cachedVideos[itemID]
                    if cachedVideo == nil
                    {
                        let cachedVideo =
                            CachedVideo(videoURL: tempFileURL, resolution: resolution)
                        sSelf.cachedVideos.addItem(
                            cachedVideo, forKey: itemID, usingAddedDate: cachedVideoAddedDate)
                    }
                    else if cachedVideo!.videoURL == nil
                    {
                        cachedVideo!.videoURL = tempFileURL
                        cachedVideo!.resolution = resolution
                    }

                    if sSelf.predownloadedVideoWasPickedUp
                    {
                        sSelf.didPredownloadVideoClosureSuccess()

                        sSelf.setOverlay(tempFileURL, forItem: item)
                    }
                    else
                    {
                        let newNumAlreadyPredownloadedVideos =
                            (numAlreadyPredownloadedVideos ?? 0) + 1

                        if newNumAlreadyPredownloadedVideos < sSelf.maxNumPredownloadedVideos
                        {
                            sSelf.maybePredownloadVideoAfterIndex(
                                index, prevItemIndex: prevItemIndex,
                                numAlreadyPredownloadedVideos: newNumAlreadyPredownloadedVideos)
                        }
                    }
                }
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func smoothlyMakeChange (change:(() -> Void), speedFactor:Double = 1.0)
    {
        self.setOutputLowPassFilterToZeroTimer?.invalidate()
        let filterStrength =
            self.outputLowPassFilter.filterType == .Empty ?
                0.0 : self.outputLowPassFilter["filterStrength"]
        self.outputLowPassFilter.setFilterType(
            .LowPass, withSettings: ["filterStrength": filterStrength], completion: {
                self.outputLowPassFilter.frameDoneClosure = { [weak self] in
                    on_main() {
                        guard let sSelf = self else
                        {
                            return
                        }

                        sSelf.outputLowPassFilter.frameDoneClosure = nil

                        sSelf.outputLowPassFilter["filterStrength"] =
                            sSelf.outputLowPassFilterStrength
                        sSelf.setOutputLowPassFilterToZeroTimer =
                            NSTimer.scheduledTimerWithTimeInterval(
                                sSelf.outputLowPassFilterSetToZeroFrequency/speedFactor,
                                target: sSelf, selector: "setOutputLowPassFilterToZero:",
                                userInfo: nil, repeats: true)

                        change()
                    }
                }
            })
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func pickInputImage ()
    {
        let dialog = KCSelectionDialog(title: "Image Source", closeButtonTitle: "Cancel")
        dialog.addItem(
            item: "Photo Library", icon: UIImage(named: "PhotoLibrary")!, didTapHandler: {
                self.pickInputImageFromPhotoLibrary()
            })
        dialog.addItem(
            item: "Take a Photo", icon: UIImage(named: "Camera")!, didTapHandler: {
                self.takeInputImageFromCamera()
            })
        AppConfiguration.makeupSelectionDialog(dialog)
        dialog.show()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func pickInputImageFromPhotoLibrary ()
    {
        authorizePhotoLibraryUsageIfNeededWithSuccessClosure({
            let sourceType = UIImagePickerControllerSourceType.PhotoLibrary

            if !UIImagePickerController.isSourceTypeAvailable(sourceType)
            {
                return
            }
            let availableMediaTypes =
                UIImagePickerController.availableMediaTypesForSourceType(sourceType)
            if availableMediaTypes == nil || !availableMediaTypes!.contains(String(kUTTypeImage))
            {
                doOKAlertWithTitle(
                    nil,
                    message: "Don't you have any pictures in your Photo Library?")
                return
            }

            let picker = UIImagePickerController()
            picker.sourceType = sourceType
            picker.mediaTypes = [String(kUTTypeImage)]
            picker.delegate = self
            self.presentViewController(picker, animated: true, completion: nil)

            self.overlay?.pause()
        })
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func takeInputImageFromCamera ()
    {
        authorizeCameraUsageIfNeededWithSuccessClosure({
            let sourceType = UIImagePickerControllerSourceType.Camera

            if !UIImagePickerController.isSourceTypeAvailable(sourceType)
            {
                return
            }
            let availableMediaTypes =
                UIImagePickerController.availableMediaTypesForSourceType(sourceType)
            if availableMediaTypes == nil || !availableMediaTypes!.contains(String(kUTTypeImage))
            {
                return
            }

            let picker = UIImagePickerController()
            picker.sourceType = sourceType
            picker.mediaTypes = [String(kUTTypeImage)]
            picker.delegate = self
            self.presentViewController(picker, animated: true, completion: nil)

            self.overlay?.pause()
        })
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func imagePickerController (
        picker:UIImagePickerController, didFinishPickingMediaWithInfo info:[String: AnyObject])
    {
        self.overlay?.play()

        if let mediaType = info[UIImagePickerControllerMediaType] as? String
        {
            if mediaType != String(kUTTypeImage)
            {
                self.dismissViewControllerAnimated(true, completion: {
                    doOKAlertWithTitle(
                        "Unexpected Media Kind",
                        message: "Please try again to select an image.")
                })
                return
            }
        }
        else
        {
            return
        }

        let originalImage = info[UIImagePickerControllerOriginalImage] as? UIImage
        let editedImage = info[UIImagePickerControllerEditedImage] as? UIImage
        let image = editedImage ?? originalImage

        self.dismissViewControllerAnimated(true, completion: {
            if let image = image
            {
                self.setInputImage(image.normalizedImage())
            }
        })
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func imagePickerControllerDidCancel (picker:UIImagePickerController)
    {
        self.overlay?.play()

        self.dismissViewControllerAnimated(true, completion: nil)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func setInputImage (image:UIImage)
    {
        var useImage = image

        let width = Double(useImage.pixelWidth)
        let height = Double(useImage.pixelHeight)
        let maxDim = max(width, height)
        if maxDim > Double(self.maxInputImagePixelDim)
        {
            let scale =
                width == maxDim ?
                    Double(self.maxInputImagePixelDim)/width :
                    Double(self.maxInputImagePixelDim)/height
            useImage =
                useImage.scaledDownImageToNewPixelWidth(
                    Int(round(width*scale)),
                    newPixelHeight: Int(round(height*scale)))
        }
        else if useImage.pixelWidth < self.minInputImagePixelWidth
        {
            let scale = Double(self.minInputImagePixelWidth)/Double(useImage.pixelWidth)
            useImage = useImage.resizedImageWithScale(scale)
        }

        self.lastSetInputImage = useImage

        self.smoothlyMakeChange({
            self.inputImage.image = useImage

            if self.currItemIndex == nil
            {
                self.lastSearchQuery = ""
                self.setOverlay(
                    NSBundle.mainBundle().URLForResource("DummyVideo.mp4", withExtension: nil)!,
                    forItem: nil)
            }

            self.updateControlButtons()
        })
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func setOverlayLowPassFilterToZero (timer:NSTimer)
    {
        if self.overlayLowPassFilter.filterType == .Empty
        {
            return
        }

        var newValue =
            (self.overlayLowPassFilter["filterStrength"] as! Double) -
            self.outputLowPassFilterSetToZeroSpeed
        if newValue < 0.0
        {
            newValue = 0.0
        }
        self.overlayLowPassFilter["filterStrength"] = newValue
        if newValue == 0.0
        {
            timer.invalidate()
            self.overlayLowPassFilter.filterType = .Empty
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func setOverlay (videoURL:NSURL, forItem item:JSON?)
    {
        var useItem:JSON! = item

        if item == nil
        {
            // Setting a dummy overlay for the case when only the input image is provided.
            let jsonString = "{\"item_id\": -1}"
            let data =
                jsonString.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
            useItem = JSON(data: data)
        }

        appD().ignoringInteractionEvents.begin()

        self.setOverlayTimeoutTimer?.invalidate()
        let userInfo:[String: AnyObject] = [
            "videoURL": videoURL,
            "item": useItem.rawString()!,
        ]
        self.setOverlayTimeoutTimer =
            NSTimer.scheduledTimerWithTimeInterval(
                1.5, target: self, selector: "retrySettingOverlay:", userInfo: userInfo,
                repeats: false)

        self.setOutputLowPassFilterToZeroTimer?.invalidate()
        let filterStrength =
            self.outputLowPassFilter.filterType == .Empty ?
                0.0 : self.outputLowPassFilter["filterStrength"]
        self.outputLowPassFilter.setFilterType(
            .LowPass, withSettings: ["filterStrength": filterStrength], completion: {
                self.outputLowPassFilter.frameDoneClosure = { [weak self] in
                    on_main() {
                        guard let sSelf = self else
                        {
                            appD().ignoringInteractionEvents.end()
                            return
                        }

                        sSelf.outputLowPassFilter.frameDoneClosure = nil

                        sSelf.outputLowPassFilter["filterStrength"] =
                            sSelf.outputLowPassFilterStrength

                        sSelf.overlay?.pause()
                        if let currOverlaySettings = sSelf.currOverlaySettings
                        {
                            currOverlaySettings.pausedTime = sSelf.overlay?.currentTime()
                        }

                        let alignment:Input.Alignment

                        let subAlign = useItem["sub_align"].string ?? "c"
                        switch subAlign
                        {
                        case "c":
                            alignment = .Center
                        case "l":
                            alignment = .Left
                        case "r":
                            alignment = .Right
                        case "t":
                            alignment = .Top
                        case "b":
                            alignment = .Bottom
                        default:
                            alignment = .Center
                        }

                        let itemID = useItem["item_id"].stringValue
                        let storedOverlaySettings = sSelf.itemIDsToOverlaySettings[itemID]

                        let seekToTime = storedOverlaySettings?.pausedTime ?? kCMTimeZero

                        sSelf.overlay.setVideoURL(
                            videoURL, seekingToTime: seekToTime, withAlignment: alignment,
                            completion: {
                                appD().ignoringInteractionEvents.end()

                                sSelf.setOverlayTimeoutTimer.invalidate()

                                sSelf.setOutputLowPassFilterToZeroTimer =
                                    NSTimer.scheduledTimerWithTimeInterval(
                                        sSelf.outputLowPassFilterSetToZeroFrequency, target: sSelf,
                                        selector: "setOutputLowPassFilterToZero:", userInfo: nil,
                                        repeats: true)

                                let overlaySettings:OverlaySettings

                                if storedOverlaySettings == nil
                                {
                                    var inputImageBrightness = 0.0
                                    if sSelf.lastSearchQuery.containsString("=ic_rainy_window")
                                    {
                                        inputImageBrightness = sSelf.brightnessRange.0
                                    }

                                    var blenderType:Blender.BlenderType

                                    let overlayMode = useItem["overlay_mode"].string ?? "sc"
                                    switch overlayMode
                                    {
                                    case "sc":
                                        blenderType = .Screen
                                    case "ov":
                                        blenderType = .Multiply
                                    case "ld":
                                        blenderType = .Add
                                    case "mu":
                                        blenderType = .HardLight
                                    case "lb":
                                        blenderType = .HardLight
                                    default:
                                        blenderType = .Screen
                                    }

                                    // Override suggested blender types for some overlays.
                                    if sSelf.lastSearchQuery.containsString("=ic_light_leaks") ||
                                       sSelf.lastSearchQuery.containsString("=ic_dust") ||
                                       sSelf.lastSearchQuery.containsString("=ic_fire")
                                    {
                                        blenderType = .Screen
                                    }
                                    if sSelf.lastSearchQuery.containsString("=ic_rays")
                                    {
                                        blenderType = .Multiply
                                    }
                                    if sSelf.lastSearchQuery.containsString("=ic_embers") ||
                                       sSelf.lastSearchQuery.containsString("=ic_sparks")
                                    {
                                        blenderType = .Add
                                    }

                                    var cropRegion =
                                        CGRect(
                                            origin: CGPointZero,
                                            size: CGSize(width: 1.0, height: 1.0))
                                    if Int(itemID) == 1380
                                    {
                                        let cropDeltaY = 0.08
                                        cropRegion =
                                            CGRect(
                                                x: 0.0, y: cropDeltaY,
                                                width: 1.0, height: 1.0 - cropDeltaY)
                                    }
                                    else if Int(itemID) == 928
                                    {
                                        let cropDeltaY = 0.2
                                        cropRegion =
                                            CGRect(
                                                x: 0.0, y: cropDeltaY,
                                                width: 1.0, height: 1.0 - cropDeltaY)
                                    }

                                    var addedTransform = CGAffineTransformIdentity
                                    if sSelf.lastSearchQuery.containsString("=ic_light_bokeh")
                                    {
                                        let isFlippedH = arc4random() % 2 == 0
                                        let isFlippedV = arc4random() % 2 == 0
                                        let sX = !isFlippedH ? 1.0 : -1.0
                                        let sY = !isFlippedV ? 1.0 : -1.0
                                        addedTransform =
                                            CGAffineTransformMakeScale(CGFloat(sX), CGFloat(sY))
                                    }

                                    overlaySettings =
                                        OverlaySettings(
                                            blenderType: blenderType,
                                            cropRegion: cropRegion,
                                            addedTransform: addedTransform,
                                            inputImageBrightness: inputImageBrightness)

                                    sSelf.itemIDsToOverlaySettings[itemID] = overlaySettings
                                }
                                else
                                {
                                    overlaySettings = storedOverlaySettings!
                                }
                                sSelf.currOverlaySettings = overlaySettings

                                sSelf.nodeSystem.beginUpdates()

                                sSelf.setInputImageBrightness(overlaySettings.inputImageBrightness)
                                sSelf.setOverlayBlenderType(overlaySettings.blenderType)
                                sSelf.setOverlayCropRegion(overlaySettings.cropRegion)
                                sSelf.setOverlayTransform(
                                    isFlippedH: overlaySettings.isFlippedH,
                                    isFlippedV: overlaySettings.isFlippedV)
                                sSelf.setOverlayHue(overlaySettings.hue)
                                sSelf.setOverlayZoomBlur(overlaySettings.zoomBlur)

                                sSelf.nodeSystem.endUpdates()
                            })
                    }
                }
            })
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func setOutputLowPassFilterToZero (timer:NSTimer)
    {
        if self.outputLowPassFilter.filterType == .Empty
        {
            return
        }

        var newValue =
            (self.outputLowPassFilter["filterStrength"] as! Double) -
            self.outputLowPassFilterSetToZeroSpeed
        if newValue < 0.0
        {
            newValue = 0.0
        }
        self.outputLowPassFilter["filterStrength"] = newValue
        if newValue == 0.0
        {
            timer.invalidate()
            self.outputLowPassFilter.filterType = .Empty
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func retrySettingOverlay (timer:NSTimer)
    {
        appD().ignoringInteractionEvents.end()

        if self.view.window == nil
        {
            return
        }

        print("Retrying setting an overlay...")

        let userInfoDict = timer.userInfo as! [String: AnyObject]
        let videoURL = userInfoDict["videoURL"] as! NSURL
        let itemJSONString = userInfoDict["item"] as! String
        let itemJSONData =
            itemJSONString.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
        let item = JSON(data: itemJSONData)
        self.setOverlay(videoURL, forItem: item)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func blenderSliderValueChanged ()
    {
        let blenderType:Blender.BlenderType

        switch Int(round(self.blenderSlider.value))
        {
        case 0:
            blenderType = .Multiply
        case 1:
            blenderType = .HardLight
        case 2:
            blenderType = .Screen
        case 3:
            blenderType = .Add
        case 4:
            blenderType = .DesaturatedScreen
        default:
            blenderType = .Screen
        }

        self.smoothlyMakeChange({
            self.setOverlayBlenderType(blenderType, setSlider: false)
        },
        speedFactor: 2.0)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func setOverlayBlenderType (blenderType:Blender.BlenderType, setSlider:Bool = true)
    {
        self.blender.blenderType = blenderType

        if setSlider
        {
            let sliderBlenderTypeRaw:Int
            switch blenderType
            {
            case .Multiply:
                sliderBlenderTypeRaw = 0
            case .HardLight:
                sliderBlenderTypeRaw = 1
            case .Screen:
                sliderBlenderTypeRaw = 2
            case .Add:
                sliderBlenderTypeRaw = 3
            case .DesaturatedScreen:
                sliderBlenderTypeRaw = 4
            default:
                sliderBlenderTypeRaw = 2
            }
            self.blenderSlider.value = CGFloat(sliderBlenderTypeRaw)
        }

        self.currOverlaySettings?.blenderType = blenderType
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func setOverlayCropRegion (cropRegion:CGRect)
    {
        if !(cropRegion.origin == CGPointZero &&
             cropRegion.size == CGSize(width: 1.0, height: 1.0))
        {
            self.overlayCropFilter.setFilterType(
                .Crop, withSettings: ["cropRegion": NSValue(CGRect: cropRegion)])
        }
        else
        {
            self.overlayCropFilter.filterType = .Empty
        }

        self.currOverlaySettings?.cropRegion = cropRegion
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func transformSliderValueChanged ()
    {
        let isFlippedH:Bool
        let isFlippedV:Bool

        switch Int(round(self.transformSlider.value))
        {
        case 0:
            isFlippedH = false
            isFlippedV = false
        case 1:
            isFlippedH = true
            isFlippedV = false
        case 2:
            isFlippedH = false
            isFlippedV = true
        case 3:
            isFlippedH = true
            isFlippedV = true
        default:
            isFlippedH = false
            isFlippedV = false
        }

        self.smoothlyMakeChange({
            self.setOverlayTransform(
                isFlippedH: isFlippedH,
                isFlippedV: isFlippedV,
                setSlider: false)
        },
        speedFactor: 2.0)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func setOverlayTransform (
        isFlippedH isFlippedH:Bool, isFlippedV:Bool, setSlider:Bool = true)
    {
        var addedTransform = CGAffineTransformIdentity
        if let currOverlaySettings = self.currOverlaySettings
        {
            addedTransform = currOverlaySettings.addedTransform
        }
        if !(isFlippedH == false &&
             isFlippedV == false &&
             CGAffineTransformEqualToTransform(addedTransform, CGAffineTransformIdentity))
        {
            let sX = !isFlippedH ? 1.0 : -1.0
            let sY = !isFlippedV ? 1.0 : -1.0
            var transform = CGAffineTransformMakeScale(CGFloat(sX), CGFloat(sY))
            transform = CGAffineTransformConcat(transform, addedTransform)
            self.overlayTransformFilter.setFilterType(
                .Transform,
                withSettings: ["affineTransform": NSValue(CGAffineTransform: transform)])
        }
        else
        {
            self.overlayTransformFilter.filterType = .Empty
        }

        if setSlider
        {
            let transformCase:Int
            if !isFlippedH
            {
                if !isFlippedV
                {
                    transformCase = 0
                }
                else
                {
                    transformCase = 2
                }
            }
            else
            {
                if !isFlippedV
                {
                    transformCase = 1
                }
                else
                {
                    transformCase = 3
                }
            }
            self.transformSlider.value = CGFloat(transformCase)
        }

        if let currOverlaySettings = self.currOverlaySettings
        {
            currOverlaySettings.isFlippedH = isFlippedH
            currOverlaySettings.isFlippedV = isFlippedV
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func hueSliderValueChanged ()
    {
        let sliderValue = Double(self.hueSlider.value)/Double(self.hueSlider.tickCount - 1)

        let hue = sliderValue*360.0
        self.setOverlayHue(hue, setSlider: false)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func setOverlayHue (hue:Double, setSlider:Bool = true)
    {
        let emptyFilterSnapDist = self.hueSliderEmptyFilterSnapDist*360.0
        if abs(hue - 0.0) > emptyFilterSnapDist &&
           abs(hue - 360.0) > emptyFilterSnapDist
        {
            self.overlayHueFilter.setFilterType(.FastHue, withSettings: ["hue": hue])
        }
        else
        {
            self.overlayHueFilter.filterType = .Empty
        }

        if setSlider
        {
            self.hueSlider.value = CGFloat(hue/360.0*Double(self.hueSlider.tickCount - 1))
        }

        self.currOverlaySettings?.hue = hue
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func brightnessSliderValueChanged ()
    {
        let sliderValue =
            Double(self.brightnessSlider.value)/Double(self.brightnessSlider.tickCount - 1)

        let brightness =
            self.brightnessRange.0 + sliderValue*(self.brightnessRange.1 - self.brightnessRange.0)
        self.setInputImageBrightness(brightness, setSlider: false)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func setInputImageBrightness (brightness:Double, setSlider:Bool = true)
    {
        let brightnessRangeLength = self.brightnessRange.1 - self.brightnessRange.0

        let emptyFilterSnapDist = self.brightnessSliderEmptyFilterSnapDist*brightnessRangeLength
        if abs(brightness - 0.0) > emptyFilterSnapDist
        {
            self.inputImageBrightnessFilter.setFilterType(
                .Brightness, withSettings: ["brightness": brightness])
        }
        else
        {
            self.inputImageBrightnessFilter.filterType = .Empty
        }

        if setSlider
        {
            let sliderValue = (brightness - self.brightnessRange.0)/brightnessRangeLength
            self.brightnessSlider.value =
                CGFloat(sliderValue*Double(self.brightnessSlider.tickCount - 1))
        }

        self.currOverlaySettings?.inputImageBrightness = brightness
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func zoomBlurSliderValueChanged ()
    {
        let sliderValue =
            Double(self.zoomBlurSlider.value)/Double(self.zoomBlurSlider.tickCount - 1)

        let zoomBlur =
            self.zoomBlurRange.0 + sliderValue*(self.zoomBlurRange.1 - self.zoomBlurRange.0)
        self.setOverlayZoomBlur(zoomBlur, setSlider: false)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func setOverlayZoomBlur (zoomBlur:Double, setSlider:Bool = true)
    {
        let zoomBlurRangeLength = self.zoomBlurRange.1 - self.zoomBlurRange.0

        let emptyFilterSnapDist = self.zoomBlurSliderEmptyFilterSnapDist*zoomBlurRangeLength
        if abs(zoomBlur - 0.0) > emptyFilterSnapDist
        {
            self.overlayZoomBlurFilter.setFilterType(
                .ZoomBlur, withSettings: ["blurSize": zoomBlur])
        }
        else
        {
            self.overlayZoomBlurFilter.filterType = .Empty
        }

        if setSlider
        {
            let sliderValue = (zoomBlur - self.zoomBlurRange.0)/zoomBlurRangeLength
            self.zoomBlurSlider.value =
                CGFloat(sliderValue*Double(self.zoomBlurSlider.tickCount - 1))
        }

        self.currOverlaySettings?.zoomBlur = zoomBlur
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func resetOverlaySettings ()
    {
        if self.currOverlaySettings.blenderType == self.currOverlaySettings.defaultBlenderType &&
           self.currOverlaySettings.isFlippedH == false &&
           self.currOverlaySettings.isFlippedV == false &&
           self.currOverlaySettings.hue == 0.0 &&
           self.currOverlaySettings.inputImageBrightness ==
               self.currOverlaySettings.defaultInputImageBrightness &&
           self.currOverlaySettings.zoomBlur == 0.0
        {
            return
        }

        self.smoothlyMakeChange({
            self.nodeSystem.beginUpdates()

            self.setOverlayBlenderType(self.currOverlaySettings.defaultBlenderType)
            self.setOverlayTransform(
                isFlippedH: false,
                isFlippedV: false)
            self.setOverlayHue(0.0)
            self.setInputImageBrightness(self.currOverlaySettings.defaultInputImageBrightness)
            self.setOverlayZoomBlur(0.0)

            self.nodeSystem.endUpdates()
        },
        speedFactor: 2.0)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func viewDidDisappear (animated:Bool)
    {
        super.viewDidDisappear(animated)

        self.overlay?.pause()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func viewDidAppear (animated:Bool)
    {
        super.viewDidAppear(animated)

        self.overlay?.play()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func dismiss ()
    {
        self.setOverlayLowPassFilterToZeroTimer?.invalidate()
        self.setOutputLowPassFilterToZeroTimer?.invalidate()
        self.setOverlayTimeoutTimer?.invalidate()

        self.view.endEditing(true)

        let parentDismissal = {
            (self.inputOutputDelegate as! BackgroundChooserViewController).dismiss(true)
        }

        if self.nodeSystem.isActive
        {
            self.nodeSystem.deactivate()
        }

        parentDismissal()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func previewVideoURLAndResolutionForItem (
        item:JSON) ->
            (previewVideoURL:String?, resolution:String)
    {
        var previewVideoURL:String?
        var resolution =
            AppConfiguration.videoResolutionForPreview(
                item["hd_bitrate"].doubleValue, hdByteSize: item["hd_byte_size"].doubleValue,
                sdIsMin: item["is_sd_minimum"].boolValue)
        let resolutionIndex = AppConfiguration.resolutions.indexOf(resolution)!
        for (var i = resolutionIndex; i >= 0; i--)
        {
            resolution = AppConfiguration.resolutions[i]
            previewVideoURL = item["v_" + resolution].string
            if previewVideoURL != nil
            {
                break
            }
        }
        return (previewVideoURL, resolution)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func outputOverlay (videoURL:NSURL, forItem item:JSON, resolution:String)
    {
        if let animationKeys = self.selectBN.layer.animationKeys() where !animationKeys.isEmpty
        {
            on_main_with_delay(0.05) {
                self.outputOverlay(videoURL, forItem: item, resolution: resolution)
            }
            return
        }

        let coverSnapshot =
            self.outputView.view.resizableSnapshotViewFromRect(
                self.outputView.view.bounds, afterScreenUpdates: false,
                withCapInsets: UIEdgeInsetsZero)
        self.previewView.addSubview(coverSnapshot)
        self.overlay.pause()
        self.overlay.seekToTime(kCMTimeZero)
        self.nodeSystem.beginUpdates()
        if self.overlayLowPassFilter.filterType != .Empty
        {
            self.overlayLowPassFilter["filterStrength"] = 0.0
        }
        if self.outputLowPassFilter.filterType != .Empty
        {
            self.outputLowPassFilter["filterStrength"] = 0.0
        }
        self.nodeSystem.endUpdates()

        let delay = 0.5

        let t1 = CGAffineTransformMakeScale(1.25, 1.25)
        let t2 = CGAffineTransformMakeTranslation(
            -self.selectBN.frame.width*0.1, -self.selectBN.frame.height*0.1)
        let t = CGAffineTransformConcat(t1, t2)
        UIView.animateWithDuration(delay, delay: 0.0, usingSpringWithDamping: 0.5,
            initialSpringVelocity: 0.5, options: [], animations: {
                self.selectBN.transform = t
            },
            completion: { _ in
                appD().ignoringInteractionEvents.end()

                let itemID = item["item_id"].stringValue

                let iuURL = self.videosURL + itemID + "/"
                let queryParams = ["iu": "1"]
                let request =
                    Alamofire.request(
                        .GET, iuURL, parameters: queryParams,
                        headers: AppConfiguration.serverHeaders)
                request.resume()

                let backgroundOverlayRecord = BackgroundOverlayRecord()

                backgroundOverlayRecord.inputImage = self.lastSetInputImage

                if self.currOverlaySettings.inputImageBrightness != 0.0
                {
                    backgroundOverlayRecord.inputImageBrightness =
                        self.currOverlaySettings.inputImageBrightness
                }

                backgroundOverlayRecord.itemID = Int(itemID)!
                if AppConfiguration.urlIsTemp(videoURL)
                {
                    backgroundOverlayRecord.videoRelPath =
                        AppConfiguration.dropTempDirURLFromURL(videoURL)
                    backgroundOverlayRecord.videoRelPathIsTemp = true
                }
                else
                {
                    backgroundOverlayRecord.videoRelPath =
                        AppConfiguration.dropEventsDirURLFromURL(videoURL)
                    backgroundOverlayRecord.videoRelPathIsTemp = false
                }
                backgroundOverlayRecord.subAlign = item["sub_align"].string ?? "c"
                backgroundOverlayRecord.timeAlign = item["time_align"].string ?? "s"
                backgroundOverlayRecord.nativeLoop = item["native_loop"].bool ?? false
                backgroundOverlayRecord.jointTime = item["joint_time"].double ?? 3.0
                backgroundOverlayRecord.hdBitrate = item["bitrate"].double ?? 8.0

                backgroundOverlayRecord.blenderType = self.currOverlaySettings.blenderType

                if !(self.currOverlaySettings.cropRegion.origin == CGPointZero &&
                     self.currOverlaySettings.cropRegion.size == CGSize(width: 1.0, height: 1.0))
                {
                    backgroundOverlayRecord.cropRegion = self.currOverlaySettings.cropRegion
                }

                if !(self.currOverlaySettings.isFlippedH == false &&
                     self.currOverlaySettings.isFlippedV == false &&
                     CGAffineTransformEqualToTransform(
                        self.currOverlaySettings.addedTransform, CGAffineTransformIdentity))
                {
                    let sX = !self.currOverlaySettings.isFlippedH ? 1.0 : -1.0
                    let sY = !self.currOverlaySettings.isFlippedV ? 1.0 : -1.0
                    var transform = CGAffineTransformMakeScale(CGFloat(sX), CGFloat(sY))
                    transform =
                        CGAffineTransformConcat(transform, self.currOverlaySettings.addedTransform)
                    backgroundOverlayRecord.transform = transform
                }

                if self.currOverlaySettings.hue != 0.0
                {
                    backgroundOverlayRecord.hue = self.currOverlaySettings.hue
                }

                if self.currOverlaySettings.zoomBlur != 0.0
                {
                    backgroundOverlayRecord.zoomBlur = self.currOverlaySettings.zoomBlur
                }

                backgroundOverlayRecord.overlaySettings =
                    NSKeyedArchiver.archivedDataWithRootObject(self.currOverlaySettings)

                backgroundOverlayRecord.item = try! item.rawData()

                backgroundOverlayRecord.resolution = resolution

                self.outputView.view.layer.cornerRadius = 0.0
                self.outputView.view.layer.masksToBounds = false
                UIGraphicsBeginImageContextWithOptions(self.outputView.view.bounds.size, true, 0)
                self.outputView.view.drawViewHierarchyInRect(
                    self.outputView.view.bounds, afterScreenUpdates: true)
                let snapshot = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                backgroundOverlayRecord.snapshot = snapshot

                var outputData = [String: AnyObject]()
                outputData["backgroundOverlayRecord"] = backgroundOverlayRecord
                self.inputOutputDelegate.acceptOutputDataFromOverlayChooserViewController(
                    outputData)

                self.dismiss()
            })
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func outputCustomPicture (picture:UIImage)
    {
        if let animationKeys = self.selectBN.layer.animationKeys() where !animationKeys.isEmpty
        {
            on_main_with_delay(0.05) {
                self.outputCustomPicture(picture)
            }
            return
        }

        let t1 = CGAffineTransformMakeScale(1.25, 1.25)
        let t2 = CGAffineTransformMakeTranslation(
            -self.selectBN.frame.width*0.1, -self.selectBN.frame.height*0.1)
        let t = CGAffineTransformConcat(t1, t2)
        UIView.animateWithDuration(0.5, delay: 0.0, usingSpringWithDamping: 0.5,
            initialSpringVelocity: 0.5, options: [], animations: {
                self.selectBN.transform = t
            },
            completion: { _ in
                appD().ignoringInteractionEvents.end()

                let backgroundCustomPictureRecord = BackgroundCustomPictureRecord()
                backgroundCustomPictureRecord.picture = picture
                backgroundCustomPictureRecord.snapshot = picture

                var outputData = [String: AnyObject]()
                outputData["backgroundCustomPictureRecord"] = backgroundCustomPictureRecord
                self.inputOutputDelegate.acceptOutputDataFromOverlayChooserViewController(
                    outputData)
                
                self.dismiss()
            })
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func putSelectBNBack ()
    {
        UIView.animateWithDuration(0.25, delay: 0.0,
            options: [.CurveEaseIn, .BeginFromCurrentState], animations: {
                self.selectBN.transform = CGAffineTransformMakeScale(1.0, 1.0)
                self.selectBN.layer.shadowColor = UIColor.blackColor().CGColor
            },
            completion: nil)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func acceptOutputDataFromOverlayChooserOptionsViewController (data:[String: AnyObject])
    {
        self.searchWithQuery(data["query"] as! String)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func acceptOutputDataFromOverlayChooserOptionsViewControllerAlt (data:[String: AnyObject])
    {
        self.searchWithQuery(data["query"] as! String)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func callOverlaySettingsBNActionWithID (id:Int)
    {
        switch id
        {
        case 0:
            self.overlaySettingsBN0Action()
        case 1:
            self.overlaySettingsBN1Action()
        case 2:
            self.overlaySettingsBN2Action()
        case 3:
            self.overlaySettingsBN3Action()
        default:
            break
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func hidePrompt ()
    {
        self.prompt.hiddenAnimated = true
    }

    //----------------------------------------------------------------------------------------------

    @IBAction private func goBackBNAction ()
    {
        if self.goBackBN.hidden || self.goBackBN.hiddenAnimated ||
           !self.goBackBN.userInteractionEnabled
        {
            return
        }

        if let currItemIndex = self.currItemIndex
        {
            let index = currItemIndex - 1
            if index >= 0
            {
                self.goToItemAtIndex(index)
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction private func goForwardBNAction ()
    {
        if self.goForwardBN.hidden || self.goForwardBN.hiddenAnimated ||
           !self.goForwardBN.userInteractionEnabled
        {
            return
        }

        if let currItemIndex = self.currItemIndex
        {
            let index = currItemIndex + 1
            if index < self.lastSearchResults.count
            {
                self.goToItemAtIndex(index)
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction private func pickInputImageBNAction ()
    {
        self.pickInputImage()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction func overlaySettingsBN0Action ()
    {
        if !self.overlaySettingsSelectedBNIDs.contains(0)
        {
            // Show.

            for id in self.overlaySettingsSelectedBNIDs
            {
                self.callOverlaySettingsBNActionWithID(id)
            }

            self.overlaySettingsSelectedBNIDs.insert(0)

            UIView.animateWithDuration(
                0.25, delay: 0.0, options: [.BeginFromCurrentState], animations: {
                    self.blenderSlider.alpha = CGFloat(self.overlaySettingsPanelAlpha)
                    self.overlaySettingsBN0.alpha = CGFloat(self.overlaySettingsBNsAlphaSelected)
                },
                completion: nil)
        }
        else
        {
            // Hide.

            self.overlaySettingsSelectedBNIDs.remove(0)

            UIView.animateWithDuration(
                0.25, delay: 0.0, options: [.BeginFromCurrentState], animations: {
                    self.blenderSlider.alpha = 0.0
                    self.overlaySettingsBN0.alpha = CGFloat(self.overlaySettingsBNsAlpha)
                },
                completion: nil)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction func overlaySettingsBN1Action ()
    {
        if !self.overlaySettingsSelectedBNIDs.contains(1)
        {
            // Show.

            for id in self.overlaySettingsSelectedBNIDs
            {
                self.callOverlaySettingsBNActionWithID(id)
            }

            self.overlaySettingsSelectedBNIDs.insert(1)

            UIView.animateWithDuration(
                0.25, delay: 0.0, options: [.BeginFromCurrentState], animations: {
                    self.transformSlider.alpha = CGFloat(self.overlaySettingsPanelAlpha)
                    self.overlaySettingsBN1.alpha = CGFloat(self.overlaySettingsBNsAlphaSelected)
                },
                completion: nil)
        }
        else
        {
            // Hide.

            self.overlaySettingsSelectedBNIDs.remove(1)

            UIView.animateWithDuration(
                0.25, delay: 0.0, options: [.BeginFromCurrentState], animations: {
                    self.transformSlider.alpha = 0.0
                    self.overlaySettingsBN1.alpha = CGFloat(self.overlaySettingsBNsAlpha)
                },
                completion: nil)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction func overlaySettingsBN2Action ()
    {
        if !self.overlaySettingsSelectedBNIDs.contains(2)
        {
            // Show.

            for id in self.overlaySettingsSelectedBNIDs
            {
                self.callOverlaySettingsBNActionWithID(id)
            }

            self.overlaySettingsSelectedBNIDs.insert(2)

            UIView.animateWithDuration(
                0.25, delay: 0.0, options: [.BeginFromCurrentState], animations: {
                    self.hueSlider.alpha = CGFloat(self.overlaySettingsPanelAlpha)
                    self.brightnessSlider.alpha = CGFloat(self.overlaySettingsPanelAlpha)
                    self.overlaySettingsBN2.alpha = CGFloat(self.overlaySettingsBNsAlphaSelected)
                },
                completion: nil)
        }
        else
        {
            // Hide.

            self.overlaySettingsSelectedBNIDs.remove(2)

            UIView.animateWithDuration(
                0.25, delay: 0.0, options: [.BeginFromCurrentState], animations: {
                    self.hueSlider.alpha = 0.0
                    self.brightnessSlider.alpha = 0.0
                    self.overlaySettingsBN2.alpha = CGFloat(self.overlaySettingsBNsAlpha)
                },
                completion: nil)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction func overlaySettingsBN3Action ()
    {
        if !self.overlaySettingsSelectedBNIDs.contains(3)
        {
            // Show.

            for id in self.overlaySettingsSelectedBNIDs
            {
                self.callOverlaySettingsBNActionWithID(id)
            }

            self.overlaySettingsSelectedBNIDs.insert(3)

            UIView.animateWithDuration(
                0.25, delay: 0.0, options: [.BeginFromCurrentState], animations: {
                    self.zoomBlurSlider.alpha = CGFloat(self.overlaySettingsPanelAlpha)
                    self.overlaySettingsBN3.alpha = CGFloat(self.overlaySettingsBNsAlphaSelected)
                },
                completion: nil)
        }
        else
        {
            // Hide.

            self.overlaySettingsSelectedBNIDs.remove(3)

            UIView.animateWithDuration(
                0.25, delay: 0.0, options: [.BeginFromCurrentState], animations: {
                    self.zoomBlurSlider.alpha = 0.0
                    self.overlaySettingsBN3.alpha = CGFloat(self.overlaySettingsBNsAlpha)
                },
                completion: nil)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction func overlaySettingsBN4Action ()
    {
        self.resetOverlaySettings()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction private func cancelBNAction ()
    {
        self.dismiss()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction private func selectBNAction ()
    {
        if self.lastSetInputImage == nil
        {
            return
        }

        UIView.animateWithDuration(0.5, delay: 0.0, usingSpringWithDamping: 0.5,
            initialSpringVelocity: 0.5, options: [], animations: {
                self.selectBN.transform = CGAffineTransformMakeScale(0.85, 0.85)
                self.selectBN.alpha = 0.75
                self.selectBN.layer.shadowColor = UIColor.whiteColor().CGColor
            },
            completion: nil)

        if self.currItemIndex != nil
        {
            let item = self.lastSearchResults[self.currItemIndex]
            let itemID = item["item_id"].stringValue

            let useResolution = AppConfiguration.videoResolutionForUse(
                item["hd_bitrate"].doubleValue, hdByteSize: item["hd_byte_size"].doubleValue)

            if let cachedVideo = self.cachedVideos[itemID] where
               cachedVideo.resolution == useResolution && cachedVideo.videoURL != nil
            {
                // The cached version is just fine.
                appD().ignoringInteractionEvents.begin()
                cachedVideo.isOwner = false
                self.outputOverlay(cachedVideo.videoURL!, forItem: item, resolution: useResolution)
            }
            else
            {
                // Download the video in the presentational resolution.

                if self.videoIsBeingPredownloaded
                {
                    self.videoPredownloadRequest?.cancel()
                }

                var useVideoURL:String?

                let resolutionIndex = AppConfiguration.resolutions.indexOf(useResolution)!
                for (var i = resolutionIndex; i >= 0; i--)
                {
                    useVideoURL = item["v_" + AppConfiguration.resolutions[i]].string
                    if useVideoURL != nil
                    {
                        break
                    }
                }

                if let useVideoURL = useVideoURL
                {
                    let downloadActivityID = self.activityWillBegin(.DownloadOutputVideo)

                    self.doMessage("Optimizing quality...")

                    let tempFileURL = makeTempFileURL(self.videosTempDirURL, ext: "mp4")
                    Alamofire.download(.GET, useVideoURL) { _, _ in
                        return tempFileURL
                    }
                    .response { [weak self] _, response, _, error in
                        guard let sSelf = self else
                        {
                            return
                        }

                        sSelf.activityDidEnd(downloadActivityID, activityType: .DownloadOutputVideo)

                        if response?.statusCode == 200 && error == nil
                        {
                            appD().ignoringInteractionEvents.begin()
                            sSelf.outputOverlay(
                                tempFileURL, forItem: item, resolution: useResolution)
                        }
                        else
                        {
                            sSelf.couldNotConnect()
                            sSelf.putSelectBNBack()
                        }
                    }
                }
                else
                {
                    self.putSelectBNBack()
                }
            }
        }
        else
        {
            appD().ignoringInteractionEvents.begin()
            self.outputCustomPicture(self.lastSetInputImage)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction private func optionsBNAction ()
    {
        let optionsSB = UIStoryboard(name: "OverlayChooserOptionsAlt", bundle: nil)
        let optionsVC = optionsSB.instantiateInitialViewController()!

        let optionsContainerVC = UIViewController()
        optionsContainerVC.view.frame = optionsVC.view.frame

        let be = UIBlurEffect(style: .Dark)

        let blView = UIVisualEffectView(effect: be)
        blView.frame = optionsContainerVC.view.bounds
        blView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        optionsContainerVC.view.addSubview(blView)

        let viView = UIVisualEffectView(effect: UIVibrancyEffect(forBlurEffect: be))
        viView.frame = blView.bounds
        viView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        blView.contentView.addSubview(viView)

        optionsContainerVC.addChildViewController(optionsVC)
        optionsVC.view.frame = viView.bounds
        viView.contentView.addSubview(optionsVC.view)
        optionsVC.didMoveToParentViewController(optionsContainerVC)

        viView.backgroundColor = AppConfiguration.bluishColor.colorWithAlphaComponent(0.4)

        optionsContainerVC.modalTransitionStyle = .CrossDissolve
        optionsContainerVC.modalPresentationStyle = .OverFullScreen
        (optionsVC as! OverlayChooserOptionsViewControllerAlt).delegate = self
        self.presentViewController(optionsContainerVC, animated: true, completion: nil)
    }

    //----------------------------------------------------------------------------------------------
}



