import Viewmorphic


//--------------------------------------------------------------------------------------------------

protocol EventPresenterBackgroundViewOutputDelegate : class
{
    func outputPictureIsReady (picture:UIImage)
    func outputVideoDidCompleteFrameWithProgress (progress:Double)
    func outputVideoIsReadyWithSuccess (success:Bool, videoTempRelPath:String?)
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

class EventPresenterBackgroundViewSavingOptions
{
    var exportType:EventExportType!
    var pictureExportOverlaySeekToTime:CMTime?
    var pictureExportInputVideoSeekToTime:CMTime?
    var outputVideoWidth:Int!
    var outputVideoHeight:Int!
    var outputVideoAVSettings:[String: AnyObject]!
    var topView:UIView?
    var topImage:UIImage?
    var logo:UIImage?
    var duration:Double?
    var customTimeAlign:String?
}

//--------------------------------------------------------------------------------------------------


class EventPresenterBackgroundView : UIView
{
    weak var outputDelegate:EventPresenterBackgroundViewOutputDelegate!

    var eventRecord:EventRecord!
    private let minInputImageWidthForPresentation = 720
    private let minInputImageWidthForPreview = 600
    private let minInputImageWidthForSaving = 1280
    private let maxInputImageWidthForNotPreview = 1440
    private let maxInputImageWidthForPreview = 800
    private let loopJointTimeFactor = 0.12
    private let maxLoopJointTime = 1.5
    private var dummyImage:UIImage!
    private var nodeSystem:NodeSystem!
    private var inputVideo:Video!
    private var overlay:Video!
    private var overlayLowPassFilter:Filter!
    private var rippleFilter:Filter!
    private var outputLowPassFilter:Filter!
    private var outputView:OutputView!
    private var setOverlayLowPassFilterToZeroTimer:NSTimer!
    private var setOutputLowPassFilterToZeroTimer:NSTimer!
    private let rippleDuration = 24.0
    private let rippleTimeRange = (0.33, 0.9)
    private var rippleStartTime:Double!
    private var rippleTimer:NSTimer!
    private let rippleTapPadding = 0.0  // 42.0
    private var hMergeBlender:Blender!
    private var transitionImage:Image!
    private var forPreview = false
    private var forSaving = false
    private var savingOptions:EventPresenterBackgroundViewSavingOptions!
    private var outputVideoURL:NSURL!
    private var outputVideo:OutputVideo!
    private var dummyVideo:Video!
    private var topView:View!
    private var isSavingVideo = false

    //----------------------------------------------------------------------------------------------

    init (
        frame:CGRect, eventRecord:EventRecord, forPreview:Bool = false,
        savingOptions:EventPresenterBackgroundViewSavingOptions? = nil)
    {
        super.init(frame: frame)

        self.eventRecord = eventRecord

        self.forPreview = forPreview

        if savingOptions != nil
        {
            self.forSaving = true
            self.savingOptions = savingOptions
        }

        self.dummyImage =
            UIImage.solidColorImageOfSize(
                CGSize(width: 8, height: 8), color: UIColor.blackColor())

        self.nodeSystem = NodeSystem()
        self.nodeSystem.videosTotallySeamlessLoopsPowerOfTwo = !self.forSaving ? 4 : 0
        self.nodeSystem.cropInputEarliest = true

        var preOutputNode:Node!

        if let customPictureRecord = eventRecord.backgroundRecord as? BackgroundCustomPictureRecord
        {
            var useImage = customPictureRecord.picture
            let imageMinWidth = self.minInputImageWidth
            if useImage.pixelWidth < imageMinWidth
            {
                useImage =
                    useImage.resizedImageWithScale(
                        Double(imageMinWidth)/Double(useImage.pixelWidth))
            }
            else if useImage.pixelWidth > self.maxInputImageWidth
            {
                useImage =
                    useImage.resizedImageWithScale(
                        Double(self.maxInputImageWidth)/Double(useImage.pixelWidth))
            }
            let image = self.nodeSystem.addImage(useImage)

            preOutputNode = image
        }
        else if let overlayRecord = eventRecord.backgroundRecord as? BackgroundOverlayRecord
        {
            var useImage = overlayRecord.inputImage
            let imageMinWidth = self.minInputImageWidth
            if useImage.pixelWidth < imageMinWidth
            {
                useImage =
                    useImage.resizedImageWithScale(
                        Double(imageMinWidth)/Double(useImage.pixelWidth))
            }
            else if useImage.pixelWidth > self.maxInputImageWidth
            {
                useImage =
                    useImage.resizedImageWithScale(
                        Double(self.maxInputImageWidth)/Double(useImage.pixelWidth))
            }
            let inputImage = self.nodeSystem.addImage(useImage)

            let inputImageBrightnessFilter:Filter
            if let brightness = overlayRecord.inputImageBrightness
            {
                inputImageBrightnessFilter =
                    self.nodeSystem.addFilter(.Brightness, settings: ["brightness": brightness])
            }
            else
            {
                inputImageBrightnessFilter = self.nodeSystem.addFilter(.Empty)
            }

            self.overlay = self.nodeSystem.addVideo(overlayRecord.videoURL)
            self.overlay.startsPlayingAutomatically = false
            self.overlay.alignment =
                self.dynamicType.inputAlignmentFromSubAlignCode(overlayRecord.subAlign)
            if self.forSaving && self.savingOptions.exportType! == .Picture
            {
                if let seekToTime = self.savingOptions.pictureExportOverlaySeekToTime
                {
                    self.overlay.seekToTime(seekToTime)
                }
            }

            let overlayCropFilter:Filter
            if let cropRegion = overlayRecord.cropRegion
            {
                overlayCropFilter =
                    self.nodeSystem.addFilter(
                        .Crop, settings: ["cropRegion": NSValue(CGRect: cropRegion)])
            }
            else
            {
                overlayCropFilter = self.nodeSystem.addFilter(.Empty)
            }

            let overlayTransformFilter:Filter
            if let transform = overlayRecord.transform
            {
                overlayTransformFilter =
                    self.nodeSystem.addFilter(
                        .Transform,
                        settings: ["affineTransform": NSValue(CGAffineTransform: transform)])
            }
            else
            {
                overlayTransformFilter = self.nodeSystem.addFilter(.Empty)
            }

            let overlayHueFilter:Filter
            if let hue = overlayRecord.hue
            {
                overlayHueFilter = self.nodeSystem.addFilter(.FastHue, settings: ["hue": hue])
            }
            else
            {
                overlayHueFilter = self.nodeSystem.addFilter(.Empty)
            }

            let overlayZoomBlurFilter:Filter
            if let zoomBlur = overlayRecord.zoomBlur
            {
                overlayZoomBlurFilter =
                    self.nodeSystem.addFilter(.ZoomBlur, settings: ["blurSize": zoomBlur])
            }
            else
            {
                overlayZoomBlurFilter = self.nodeSystem.addFilter(.Empty)
            }

            if !self.forSaving
            {
                self.overlayLowPassFilter =
                    self.nodeSystem.addFilter(.LowPass, settings: ["filterStrength": 0.95])
            }
            else
            {
                self.overlayLowPassFilter = self.nodeSystem.addFilter(.Empty)
            }

            let blender = self.nodeSystem.addBlender(overlayRecord.blenderType)

            inputImage.linkTo(inputImageBrightnessFilter)
            inputImageBrightnessFilter.linkAtATo(blender)
            self.overlay.linkTo(overlayCropFilter)
            overlayCropFilter.linkTo(overlayTransformFilter)
            overlayTransformFilter.linkTo(overlayHueFilter)
            overlayHueFilter.linkTo(overlayZoomBlurFilter)
            overlayZoomBlurFilter.linkTo(self.overlayLowPassFilter)
            self.overlayLowPassFilter.linkAtBTo(blender)

            preOutputNode = blender
        }
        else if let pictureRecord = eventRecord.backgroundRecord as? BackgroundPictureRecord
        {
            var useImage = pictureRecord.picture
            let imageMinWidth = self.minInputImageWidth
            if useImage.pixelWidth < imageMinWidth
            {
                useImage =
                    useImage.resizedImageWithScale(
                        Double(imageMinWidth)/Double(useImage.pixelWidth))
            }
            else if useImage.pixelWidth > self.maxInputImageWidth
            {
                useImage =
                    useImage.resizedImageWithScale(
                        Double(self.maxInputImageWidth)/Double(useImage.pixelWidth))
            }
            let image = self.nodeSystem.addImage(useImage)
            image.alignment =
                self.dynamicType.inputAlignmentFromSubAlignCode(pictureRecord.subAlign)

            preOutputNode = image
        }
        else if let videoRecord = eventRecord.backgroundRecord as? BackgroundVideoRecord
        {
            self.inputVideo = self.nodeSystem.addVideo(videoRecord.videoURL)
            self.inputVideo.startsPlayingAutomatically = false
            self.inputVideo.alignment =
                self.dynamicType.inputAlignmentFromSubAlignCode(videoRecord.subAlign)
            if self.forSaving && self.savingOptions.exportType! == .Picture
            {
                if let seekToTime = self.savingOptions.pictureExportInputVideoSeekToTime
                {
                    self.inputVideo.seekToTime(seekToTime)
                }
            }

            preOutputNode = self.inputVideo
        }
        else
        {
            let image = self.nodeSystem.addImage(AppConfiguration.defaultPicture)

            preOutputNode = image
        }

        if !self.forSaving
        {
            self.rippleFilter = self.nodeSystem.addFilter(.Empty)
            preOutputNode.linkTo(self.rippleFilter)

            self.outputLowPassFilter = self.nodeSystem.addFilter(.Empty)
            self.rippleFilter.linkTo(self.outputLowPassFilter)

            self.hMergeBlender = self.nodeSystem.addBlender(.OnlyA)
            self.hMergeBlender.syncMode = true
            self.outputLowPassFilter.linkAtATo(self.hMergeBlender)
            self.transitionImage = self.nodeSystem.addImage(self.dummyImage)
            self.transitionImage.syncMode = true
            self.transitionImage.linkAtBTo(self.hMergeBlender)

            preOutputNode = self.hMergeBlender
        }
        else
        {
            assert(!(self.savingOptions.topView != nil && self.savingOptions.topImage != nil))

            if let topView = self.savingOptions.topView
            {
                self.topView = self.nodeSystem.addView(topView)
                let blender = self.nodeSystem.addBlender(.PremultAlpha)
                preOutputNode.linkAtATo(blender)
                self.topView.linkAtBTo(blender)

                preOutputNode = blender
            }
            else if let topImage = self.savingOptions.topImage
            {
                let topImage = self.nodeSystem.addImage(topImage)
                let blender = self.nodeSystem.addBlender(.PremultAlpha)
                preOutputNode.linkAtATo(blender)
                topImage.linkAtBTo(blender)

                preOutputNode = blender
            }

            if let logoImage = self.savingOptions.logo
            {
                let logo = self.nodeSystem.addImage(logoImage)
                let blender = self.nodeSystem.addBlender(.PremultAlpha)
                preOutputNode.linkAtATo(blender)
                logo.linkAtBTo(blender)

                preOutputNode = blender
            }
        }

        if !self.forSaving || self.savingOptions.exportType! == .Picture
        {
            self.outputView = self.nodeSystem.addOutputViewWithFrame(self.bounds)
            preOutputNode.linkTo(self.outputView)
            self.outputView.view.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
            self.addSubview(self.outputView.view)

            if self.forSaving
            {
                self.outputView.frameDoneClosure = { [weak self] in
                    guard let sSelf = self else
                    {
                        return
                    }

                    let picture = sSelf.outputView.imageFromCurrentFramebuffer()

                    on_main() {
                        sSelf.outputDelegate.outputPictureIsReady(picture)
                    }
                }
            }
        }
        else  // saving .Video
        {
            self.outputVideoURL = makeTempFileURL(AppConfiguration.tempDirURL, ext: "mp4")

            let size =
                CGSize(
                    width: self.savingOptions.outputVideoWidth,
                    height: self.savingOptions.outputVideoHeight)
            self.outputVideo =
                self.nodeSystem.addOutputVideo(
                    self.outputVideoURL, size: size, fileType: AVFileTypeQuickTimeMovie,
                    outputSettings: self.savingOptions.outputVideoAVSettings)

            if self.eventRecord.hasAnyVideos()
            {
                preOutputNode.linkTo(self.outputVideo)
            }
            else
            {
                let dummyVideoURL =
                    NSBundle.mainBundle().URLForResource("DummyVideo.mp4", withExtension: nil)!
                self.dummyVideo = self.nodeSystem.addVideo(dummyVideoURL)
                self.dummyVideo.startsPlayingAutomatically = false
                let dummyBlender = self.nodeSystem.addBlender(.OnlyA)
                preOutputNode.linkAtATo(dummyBlender)
                self.dummyVideo.linkAtBTo(dummyBlender)

                dummyBlender.linkTo(self.outputVideo)
            }

            var progressVideo:Video!
            if eventRecord.backgroundRecord is BackgroundCustomPictureRecord ||
               eventRecord.backgroundRecord is BackgroundPictureRecord
            {
                progressVideo = self.dummyVideo
            }
            else if eventRecord.backgroundRecord is BackgroundOverlayRecord
            {
                progressVideo = self.overlay
            }
            else if eventRecord.backgroundRecord is BackgroundVideoRecord
            {
                progressVideo = self.inputVideo
            }
            else
            {
                progressVideo = self.dummyVideo
            }

            self.outputVideo.frameDoneClosure = { [weak self] in
                on_main() {
                    guard let sSelf = self else
                    {
                        return
                    }

                    sSelf.outputDelegate.outputVideoDidCompleteFrameWithProgress(
                        progressVideo.progress)
                }
            }

            self.outputVideo.completionClosure = { [weak self] success in
                on_main() {
                    guard let sSelf = self else
                    {
                        return
                    }

                    sSelf.isSavingVideo = false

                    sSelf.nullifyNodeSystemClosures()

                    var videoTempRelPath:String!
                    if success
                    {
                        videoTempRelPath =
                            AppConfiguration.dropTempDirURLFromURL(sSelf.outputVideoURL)
                    }
                    sSelf.outputDelegate.outputVideoIsReadyWithSuccess(
                        success, videoTempRelPath: videoTempRelPath)
                }
            }

            if var duration = self.savingOptions.duration
            {
                var useDuration:Double!
                var useVideo:Video!
                var startTime:Double!
                var timeAlign:String!
                var jointTimeMark:Double!

                if eventRecord.backgroundRecord is BackgroundCustomPictureRecord ||
                   eventRecord.backgroundRecord is BackgroundPictureRecord ||
                   eventRecord.backgroundRecord == nil
                {
                    useDuration = duration
                    useVideo = self.dummyVideo
                    startTime = 0.0
                    timeAlign = "s"
                    jointTimeMark = CMTimeGetSeconds(useVideo.duration)
                }
                else
                {
                    var nativeLoop:Bool!
                    var jointTime:Double!

                    if let overlayRecord = eventRecord.backgroundRecord as? BackgroundOverlayRecord
                    {
                        useVideo = self.overlay
                        timeAlign = overlayRecord.timeAlign
                        nativeLoop = overlayRecord.nativeLoop
                        jointTime = overlayRecord.jointTime
                    }
                    else if let videoRecord = eventRecord.backgroundRecord as? BackgroundVideoRecord
                    {
                        useVideo = self.inputVideo
                        timeAlign = videoRecord.timeAlign
                        nativeLoop = videoRecord.nativeLoop
                        jointTime = videoRecord.jointTime
                    }

                    if let customTimeAlign = self.savingOptions.customTimeAlign
                    {
                        timeAlign = customTimeAlign
                    }

                    var forceLooping = false
                    let baseDuration = CMTimeGetSeconds(useVideo.duration)
                    if duration > baseDuration && self.savingOptions.topView != nil
                    {
                        duration = baseDuration
                        forceLooping = true
                    }

                    if duration < baseDuration || forceLooping
                    {
                        let usedJointTime = !nativeLoop ? jointTime : 0.0
                        jointTimeMark = baseDuration - usedJointTime
                        var sTime, eTime : Double
                        if timeAlign == "s"
                        {
                            sTime = 0.0
                            eTime = min(duration, jointTimeMark)
                        }
                        else if timeAlign == "e"
                        {
                            sTime = max(jointTimeMark - duration, 0.0)
                            eTime = jointTimeMark
                        }
                        else  // "m"
                        {
                            let baseMidTime = baseDuration/2.0
                            let halfDuration = duration/2.0
                            sTime = baseMidTime - halfDuration
                            eTime = baseMidTime + halfDuration
                            if eTime > jointTimeMark
                            {
                                sTime -= eTime - jointTimeMark
                                eTime = jointTimeMark
                            }
                            sTime = max(sTime, 0.0)
                        }
                        if eTime > sTime
                        {
                            useDuration = eTime - sTime
                            startTime = sTime
                        }
                    }
                    else
                    {
                        assert(self.eventRecord.hasAnyVideos())
                    }
                }

                if useDuration != nil
                {
                    assert(self.loopJointTimeFactor < 0.5)

                    let loopJointTime =
                        min(useDuration*self.loopJointTimeFactor, self.maxLoopJointTime)

                    if timeAlign == "s"
                    {
                        useDuration = min(useDuration + loopJointTime, jointTimeMark)
                    }
                    else if timeAlign == "e"
                    {
                        var sTime = startTime
                        let eTime = startTime + useDuration
                        sTime = max(sTime - loopJointTime, 0.0)
                        useDuration = eTime - sTime
                        startTime = sTime
                    }
                    else  // "m"
                    {
                        var sTime = startTime
                        var eTime = startTime + useDuration
                        let halfLoopJointTime = loopJointTime/2.0
                        sTime = max(sTime - halfLoopJointTime, 0.0)
                        eTime = min(eTime + halfLoopJointTime, jointTimeMark)
                        useDuration = eTime - sTime
                        startTime = sTime
                    }

                    let frameRate = useVideo.frameRate
                    let timescale = useVideo.duration.timescale
                    let secondsToCMTime = { (seconds:Double) -> CMTime in
                        return CMTimeMakeWithSeconds(round(seconds*frameRate)/frameRate, timescale)
                    }

                    useVideo.timeRange =
                        CMTimeRange(
                            start: secondsToCMTime(startTime),
                            duration: secondsToCMTime(useDuration))
                    self.outputVideo.setLoopJointTime(
                        secondsToCMTime(loopJointTime), forDuration: secondsToCMTime(useDuration))
                }
            }
        }

        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: "didReceiveTap:"))
        let longPressGR = UILongPressGestureRecognizer(target: self, action: "didReceiveLongPress:")
        longPressGR.minimumPressDuration = 3.0
        self.addGestureRecognizer(longPressGR)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    required init? (coder aDecoder:NSCoder)
    {
        super.init(coder: aDecoder)
    }

    //----------------------------------------------------------------------------------------------

    private var minInputImageWidth:Int
    {
        if !self.forSaving
        {
            if !self.forPreview
            {
                return self.minInputImageWidthForPresentation
            }
            else
            {
                return self.minInputImageWidthForPreview
            }
        }
        else
        {
            return self.minInputImageWidthForSaving
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private var maxInputImageWidth:Int
    {
        if !self.forPreview
        {
            return self.maxInputImageWidthForNotPreview
        }
        else
        {
            return self.maxInputImageWidthForPreview
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func play (inputVideoSeekTime inputVideoSeekTime:CMTime? = nil, overlaySeekTime:CMTime? = nil)
    {
        assert(!self.forSaving)

        if let overlay = self.overlay
        {
            if let overlaySeekTime = overlaySeekTime
            {
                overlay.seekToTime(overlaySeekTime)
            }
        }

        if let inputVideo = self.inputVideo
        {
            if let inputVideoSeekTime = inputVideoSeekTime
            {
                inputVideo.seekToTime(inputVideoSeekTime)
            }
        }

        let wasActive = self.nodeSystem.isActive
        if !self.nodeSystem.isActive
        {
            self.nodeSystem.activate()
        }

        if let overlay = self.overlay
        {
            overlay.play()

            if !wasActive
            {
                self.setOverlayLowPassFilterToZeroTimer?.invalidate()
                self.setOverlayLowPassFilterToZeroTimer =
                    NSTimer.scheduledTimerWithTimeInterval(0.01, target: self,
                        selector: "setOverlayLowPassFilterToZero", userInfo: nil, repeats: true)
            }
        }

        if let inputVideo = self.inputVideo
        {
            inputVideo.play()
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func pause ()
    {
        assert(!self.forSaving)

        self.overlay?.pause()
        self.inputVideo?.pause()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func save ()
    {
        assert(self.forSaving)

        if self.savingOptions.exportType! == .Video
        {
            self.isSavingVideo = true
        }

        self.nodeSystem.activate()
        self.overlay?.play()
        self.inputVideo?.play()
        self.dummyVideo?.play()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    var topViewRenderingSemaphore:dispatch_semaphore_t
    {
        return self.topView.viewRenderingSemaphore
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func cancelSaving ()
    {
        assert(self.forSaving)

        self.nullifyNodeSystemClosures()

        if self.isSavingVideo
        {
            self.outputVideo?.cancel()
            self.isSavingVideo = false
        }

        self.deactivate()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func overlayCurrentTime () -> CMTime?
    {
        return self.overlay?.currentTime()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func inputVideoCurrentTime () -> CMTime?
    {
        return self.inputVideo?.currentTime()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func overlayDuration () -> CMTime?
    {
        return self.overlay?.duration
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func inputVideoDuration () -> CMTime?
    {
        return self.inputVideo?.duration
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func setOverlayLowPassFilterToZero ()
    {
        if self.overlayLowPassFilter.filterType == .Empty
        {
            return
        }

        var newValue = (self.overlayLowPassFilter["filterStrength"] as! Double) - 0.005
        if newValue < 0.0
        {
            newValue = 0.0
        }
        self.overlayLowPassFilter["filterStrength"] = newValue
        if newValue == 0.0
        {
            self.setOverlayLowPassFilterToZeroTimer.invalidate()
            self.setOverlayLowPassFilterToZeroTimer = nil

            self.overlayLowPassFilter.filterType = .Empty
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func didReceiveTap (recognizer:UITapGestureRecognizer)
    {
        if let touchView = recognizer.view where recognizer.state == .Recognized
        {
            let point = recognizer.locationInView(touchView)

            let nonRippleRect =
                touchView.bounds.insetBy(
                    dx: CGFloat(self.rippleTapPadding),
                    dy: CGFloat(self.rippleTapPadding))
            if !nonRippleRect.contains(point)
            {
                self.startRippleAtPoint(point, touchView: touchView)
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func didReceiveLongPress (recognizer:UITapGestureRecognizer)
    {
        if let touchView = recognizer.view where recognizer.state == .Recognized
        {
            let point = recognizer.locationInView(touchView)
            self.startRippleAtPoint(point, touchView: touchView)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func startRippleAtPoint (point:CGPoint, touchView:UIView)
    {
        if self.hMergeBlender.blenderType != .OnlyA
        {
            return
        }

        let normCenter =
            CGPoint(
                x: point.x/touchView.bounds.width,
                y: point.y/touchView.bounds.height)

        let startRipple = {
            self.rippleFilter.setFilterType(
                .Ripple,
                withSettings: ["center": NSValue(CGPoint: normCenter), "time": 0.0],
                completion: {
                    self.rippleTimer?.invalidate()
                    self.rippleStartTime = CFAbsoluteTimeGetCurrent()
                    self.rippleTimer =
                        NSTimer.scheduledTimerWithTimeInterval(
                            0.05, target: self, selector: "doRipple", userInfo: nil,
                            repeats: true)
                })
        }

        if self.rippleTimer == nil
        {
            startRipple()
        }
        else
        {
            self.smoothlyMakeEffectChange() {
                startRipple()
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func startRippleAtCenter ()
    {
        self.startRippleAtPoint(CGPoint(x: self.bounds.midX, y: self.bounds.midY), touchView: self)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func doRipple ()
    {
        if self.rippleFilter.filterType == .Empty
        {
            return
        }

        var rippleTime = (CFAbsoluteTimeGetCurrent() - self.rippleStartTime)/self.rippleDuration
        rippleTime += self.rippleTimeRange.0
        if rippleTime > self.rippleTimeRange.1
        {
            rippleTime = self.rippleTimeRange.1
        }

        self.rippleFilter["time"] = rippleTime

        if rippleTime == self.rippleTimeRange.1
        {
            self.rippleTimer.invalidate()
            self.rippleTimer = nil

            self.rippleFilter.filterType = .Empty
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func smoothlyMakeEffectChange (change:(() -> Void))
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

                        sSelf.outputLowPassFilter["filterStrength"] = 0.95
                        sSelf.setOutputLowPassFilterToZeroTimer =
                            NSTimer.scheduledTimerWithTimeInterval(
                                0.01, target: sSelf,
                                selector: "setOutputLowPassFilterToZero:", userInfo: nil,
                                repeats: true)

                        change()
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

        var newValue = (self.outputLowPassFilter["filterStrength"] as! Double) - 0.01
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

    private func mixForUse (mix:Double) -> Double
    {
        return self.dynamicType.easeInSine(abs(mix), b: 0.0, c: 1.0, d: 1.0)*sign(mix)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func beginTransitionToEventWithOpeningImage (openingImage:UIImage, transitionMix mix:Double)
    {
        self.transitionImage.image = openingImage
        self.hMergeBlender.setBlenderType(.HMerge, withSettings: ["mix": self.mixForUse(mix)])
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func setTransitionMix (mix:Double)
    {
        if self.hMergeBlender.blenderType != .HMerge
        {
            return
        }

        self.hMergeBlender["mix"] = self.mixForUse(mix)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func resetTransition ()
    {
        self.hMergeBlender.blenderType = .OnlyA
        self.transitionImage.image = self.dummyImage
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func deactivate ()
    {
        self.setOverlayLowPassFilterToZeroTimer?.invalidate()
        self.setOutputLowPassFilterToZeroTimer?.invalidate()
        self.rippleTimer?.invalidate()

        self.nullifyNodeSystemClosures()

        if self.isSavingVideo
        {
            self.outputVideo?.cancel()
            self.isSavingVideo = false
        }

        if self.nodeSystem.isActive
        {
            self.nodeSystem.deactivate()
        }

        if let outputVideoURL = self.outputVideoURL
        {
            let fm = NSFileManager()
            _ = try? fm.removeItemAtURL(outputVideoURL)
            self.outputVideoURL = nil
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func nullifyNodeSystemClosures ()
    {
        self.outputView?.frameDoneClosure = nil
        self.outputVideo?.frameDoneClosure = nil
        self.outputVideo?.completionClosure = nil
    }

    //----------------------------------------------------------------------------------------------

    private class func inputAlignmentFromSubAlignCode (subAlign:String) -> Input.Alignment
    {
        let alignment:Input.Alignment
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
        return alignment
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private class func easeInSine (t:Double, b:Double, c:Double, d:Double) -> Double
    {
        return -c*cos(t/d*M_PI_2) + c + b
    }

    //----------------------------------------------------------------------------------------------
}



