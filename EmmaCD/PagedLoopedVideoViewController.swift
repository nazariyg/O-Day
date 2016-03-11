import AVFoundation


//--------------------------------------------------------------------------------------------------

protocol PagedLoopedVideoViewControllerDelegate : class
{
    func numberOfVideosForPagedLoopedVideoViewController(controller:PagedLoopedVideoViewController)
        -> Int
    func firstFrameAndVideoURLForVideoAtIndex (
        index:Int, forPagedLoopedVideoViewController controller:PagedLoopedVideoViewController) ->
        (firstFrame:UIImage?, videoURL:NSURL?, aspect:String?, subAlign:String?)
    func pagedLoopedVideoViewController (
        controller:PagedLoopedVideoViewController, willBeginTransitioningToIndex index:Int)
    func pagedLoopedVideoViewController (
        controller:PagedLoopedVideoViewController, didEndTransitioningToIndex index:Int)
}

//--------------------------------------------------------------------------------------------------


class PagedLoopedVideoViewController : UIViewController
{
    weak var delegate:PagedLoopedVideoViewControllerDelegate!

    private var backgroundImageView:UIImageView!
    private var firstFrameView:UIImageView!
    private var cachedVideoViews:KeyedItemsCache<LoopedVideoView>!

    private var currVideoIndex:Int!
    private var currShownView:UIView!

    private enum ViewType
    {
        case BackgroundImage
        case FirstFrame
        case Video
    }

    private var currViewType:ViewType
    {
        switch self.currShownView
        {
        case self.backgroundImageView:
            return .BackgroundImage
        case self.firstFrameView:
            return .FirstFrame
        default:
            return .Video
        }
    }

    private var videoIndexesToPausedTime = [Int: CMTime]()

    private var currTransitioningIndexes:(fromIndex:Int?, toIndex:Int)!

    private let transDFast = 0.1
    private let transDSlow = 0.2

    private var applicationWillResignActiveObserver:NSObjectProtocol!
    private var applicationDidBecomeActiveObserver:NSObjectProtocol!

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
    }

    //----------------------------------------------------------------------------------------------

    override func viewDidLoad ()
    {
        super.viewDidLoad()

        self.backgroundImageView = UIImageView(frame: self.view.bounds)
        self.firstFrameView = UIImageView(frame: self.view.bounds)
        for imageView in [self.backgroundImageView, self.firstFrameView]
        {
            imageView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
            imageView.contentMode = .ScaleAspectFill
        }

        self.backgroundImageView.image = AppConfiguration.defaultPicture
        self.view.addSubview(self.backgroundImageView)
        self.currShownView = self.backgroundImageView

        self.cachedVideoViews = KeyedItemsCache<LoopedVideoView>(capacity: 2)

        let nc = NSNotificationCenter.defaultCenter()
        self.applicationWillResignActiveObserver = nc.addObserverForName(
            UIApplicationWillResignActiveNotification, object: nil,
            queue: NSOperationQueue.mainQueue()) { [weak self] _ in
                guard let sSelf = self else
                {
                    return
                }

                sSelf.viewDidDisappear(false)
                sSelf.cachedVideoViews.clear()
            }
        self.applicationDidBecomeActiveObserver = nc.addObserverForName(
            UIApplicationDidBecomeActiveNotification, object: nil,
            queue: NSOperationQueue.mainQueue()) { [weak self] _ in
                guard let sSelf = self else
                {
                    return
                }

                sSelf.viewDidAppear(false)
            }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func didReceiveMemoryWarning ()
    {
        super.didReceiveMemoryWarning()

        //self.cachedVideoViews.clear()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func makeLoopedVideoView () -> LoopedVideoView
    {
        let videoView = LoopedVideoView(frame: self.view.bounds)
        videoView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        (videoView.layer as! AVPlayerLayer).videoGravity = AVLayerVideoGravityResizeAspectFill
        videoView.totallySeamlessLoopsPowerOfTwo = 2
        return videoView
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func didUpdateDataForVideoAtIndex (index:Int)
    {
        let videoData =
            self.delegate.firstFrameAndVideoURLForVideoAtIndex(
                index, forPagedLoopedVideoViewController: self)

        if let videoURL = videoData.videoURL, currVideoIndex = self.currVideoIndex
        {
            if abs(currVideoIndex - index) == 1
            {
                // A neighboring video has become available.
                if self.cachedVideoViews[String(index)] == nil
                {
                    // Preload the video into a view.

                    let videoView = self.makeLoopedVideoView()
                    self.cachedVideoViews.addItem(videoView, forKey: String(index))

                    videoView.readyForDisplayClosure = {
                    [unowned self, unowned videoView] in
                        if let pausedTime = self.videoIndexesToPausedTime[index]
                        {
                            videoView.seekToTime(pausedTime)
                        }
                    }
                    videoView.videoURL = videoURL
                }
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func goToVideoAtIndex (index:Int)
    {
        var beginningTransitioning = false
        if self.currTransitioningIndexes == nil
        {
            beginningTransitioning = true
        }
        else
        {
            if self.currVideoIndex == nil
            {
                if !(nil == self.currTransitioningIndexes.fromIndex &&
                     index == self.currTransitioningIndexes.toIndex)
                {
                    beginningTransitioning = true
                }
            }
            else
            {
                if !(self.currVideoIndex == self.currTransitioningIndexes.fromIndex &&
                     index == self.currTransitioningIndexes.toIndex)
                {
                    beginningTransitioning = true
                }
            }
        }
        if beginningTransitioning
        {
            self.currTransitioningIndexes = (self.currVideoIndex, index)
            self.delegate.pagedLoopedVideoViewController(self, willBeginTransitioningToIndex: index)
        }

        let videoData =
            self.delegate.firstFrameAndVideoURLForVideoAtIndex(
                index, forPagedLoopedVideoViewController: self)

        let jCurrShownView = self.currShownView
        let jCurrVideoIndex = self.currVideoIndex

        let pausePrevVideo = { [unowned self, weak jCurrShownView] in
            if let videoV = jCurrShownView as? LoopedVideoView
            {
                videoV.pause()
                if let videoI = jCurrVideoIndex
                {
                    self.videoIndexesToPausedTime[videoI] = videoV.currentTime()
                }
            }
        }

        if let firstFrame = videoData.firstFrame where videoData.videoURL == nil
        {
            // The video's first frame image is available but the video itself is still not.
            if !(self.currVideoIndex != nil && index == self.currVideoIndex) &&
               self.currViewType != .FirstFrame
            {
                // Transition to the video's first frame image.

                subAlignView(
                    self.firstFrameView, inSuperview: self.view, forAspect: videoData.aspect!,
                    withCode: videoData.subAlign!)
                self.firstFrameView.image = firstFrame
                UIView.transitionFromView(
                    self.currShownView, toView: self.firstFrameView, duration: self.transDSlow,
                    options: [.TransitionCrossDissolve], completion: { _ in
                        pausePrevVideo()
                    })

                self.currShownView = self.firstFrameView

                self.videoIndexesToPausedTime.removeValueForKey(index)
            }
        }
        else if let videoURL = videoData.videoURL
        {
            // The video is already available on the disk. Load it into a view if needed and 
            // complete the index change.

            let videoView:LoopedVideoView

            let maybePreloadNextVideo = { [unowned self] in
                let indexDiff = index - (jCurrVideoIndex ?? -1)
                if abs(indexDiff) == 1
                {
                    // Made a 1-length index change.
                    let nextIndex = index + indexDiff
                    if self.cachedVideoViews[String(nextIndex)] == nil
                    {
                        // The video is not yet loaded.
                        let numVideos =
                            self.delegate.numberOfVideosForPagedLoopedVideoViewController(self)
                        if 0 <= nextIndex && nextIndex < numVideos
                        {
                            let videoData =
                                self.delegate.firstFrameAndVideoURLForVideoAtIndex(
                                    nextIndex, forPagedLoopedVideoViewController: self)
                            if let videoURL = videoData.videoURL
                            {
                                let videoView = self.makeLoopedVideoView()
                                self.cachedVideoViews.addItem(videoView, forKey: String(nextIndex))

                                videoView.readyForDisplayClosure = {
                                [unowned self, unowned videoView] in
                                    if let pausedTime = self.videoIndexesToPausedTime[nextIndex]
                                    {
                                        videoView.seekToTime(pausedTime)
                                    }
                                }
                                videoView.videoURL = videoURL
                            }
                        }
                    }
                }
            }

            let cachedVideoView = self.cachedVideoViews[String(index)]
            if cachedVideoView == nil
            {
                // The video is not yet loaded.

                videoView = self.makeLoopedVideoView()
                self.cachedVideoViews.addItem(videoView, forKey: String(index))

                videoView.readyForDisplayClosure = { [unowned self, unowned videoView] in
                    if let pausedTime = self.videoIndexesToPausedTime[index]
                    {
                        videoView.seekToTime(pausedTime)
                    }
                    videoView.play()

                    subAlignView(
                        videoView, inSuperview: self.view, forAspect: videoData.aspect!,
                        withCode: videoData.subAlign!)
                    UIView.transitionFromView(
                        jCurrShownView, toView: videoView, duration: self.transDFast,
                        options: [.TransitionCrossDissolve], completion: { _ in
                            pausePrevVideo()

                            self.delegate.pagedLoopedVideoViewController(
                                self, didEndTransitioningToIndex: index)
                            self.currTransitioningIndexes = nil

                            maybePreloadNextVideo()
                        })
                }
                videoView.videoURL = videoURL
            }
            else
            {
                // Unpause the video.

                videoView = cachedVideoView!

                if videoView != self.currShownView
                {
                    let playVideoAndFinalize = { [unowned self, unowned videoView] in
                        videoView.play()

                        subAlignView(
                            videoView, inSuperview: self.view, forAspect: videoData.aspect!,
                            withCode: videoData.subAlign!)
                        UIView.transitionFromView(
                            jCurrShownView, toView: videoView, duration: self.transDFast,
                            options: [.TransitionCrossDissolve], completion: { _ in
                                pausePrevVideo()

                                self.delegate.pagedLoopedVideoViewController(
                                    self, didEndTransitioningToIndex: index)
                                self.currTransitioningIndexes = nil

                                maybePreloadNextVideo()
                            })
                    }

                    if videoView.readyForDisplay
                    {
                        playVideoAndFinalize()
                    }
                    else
                    {
                        // If any, join the previously assigned ready-for-display closure with
                        // a new one.
                        let jReadyForDisplayClosure = videoView.readyForDisplayClosure
                        videoView.readyForDisplayClosure = {
                            jReadyForDisplayClosure?()
                            playVideoAndFinalize()
                        }
                    }
                }
                else
                {
                    self.delegate.pagedLoopedVideoViewController(
                        self, didEndTransitioningToIndex: index)
                    self.currTransitioningIndexes = nil
                }
            }

            // After the video got rolling, the index change is complete.
            self.currVideoIndex = index
            self.currShownView = videoView
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func viewDidDisappear (animated:Bool)
    {
        if self.currViewType == .Video
        {
            (self.currShownView as! LoopedVideoView).pause()
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func viewDidAppear (animated:Bool)
    {
        if self.currViewType == .Video
        {
            (self.currShownView as! LoopedVideoView).play()
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func clear ()
    {
        self.currVideoIndex = nil
        self.cachedVideoViews.clear()
        self.videoIndexesToPausedTime.removeAll()
    }

    //----------------------------------------------------------------------------------------------
}



