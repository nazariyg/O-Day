import UIKit
import Alamofire
import AVFoundation


//--------------------------------------------------------------------------------------------------

protocol VideoChooserViewControllerOutput : class
{
    func acceptOutputDataFromVideoChooserViewController (data:[String: AnyObject])
}

//--------------------------------------------------------------------------------------------------

private class CachedVideo
{
    var firstFrame:UIImage?
    
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
    var isOwner = true

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    init (firstFrame:UIImage?, videoURL:NSURL?, resolution:String)
    {
        self.firstFrame = firstFrame
        self._videoURL = videoURL
        self.resolution = resolution
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


class VideoChooserViewController : UIViewController, UISearchBarDelegate,
                                   PagedLoopedVideoViewControllerDelegate,
                                   VideoChooserOptionsViewControllerOutput
{
    weak var outputDelegate:VideoChooserViewControllerOutput!

    @IBOutlet private weak var previewView:UIView!
    @IBOutlet private weak var searchBar:UISearchBar!
    @IBOutlet private weak var goBackBN:UIButton!
    @IBOutlet private weak var goForwardBN:UIButton!
    @IBOutlet private weak var cancelBN:UIButton!
    @IBOutlet private weak var selectBN:UIButton!
    @IBOutlet private weak var progressAI:UIActivityIndicatorView!
    @IBOutlet private weak var optionsBN:UIButton!

    private let videosURL = AppConfiguration.serverURLForAPI + "videos/"

    private var pagedVideoViewController:PagedLoopedVideoViewController!

    private var currItemIndex:Int!
    private var lastSearchResults:[JSON]!
    private var cachedVideos:KeyedItemsCache<CachedVideo>!

    private enum ActivityType
    {
        case Search
        case DownloadVideoData
        case VideoTransitioning
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

    private var currVideoTransitioningActivityID:Int!

    private var videoIsBeingPredownloaded = false
    private var currPredownloadedVideoID:String!
    private var didPredownloadVideoClosureAlways:(() -> Void)!
    private var didPredownloadVideoClosureSuccess:(() -> Void)!
    private var predownloadedVideoWasPickedUp = false
    private var videoPredownloadRequest:Request?

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

        self.view.backgroundColor = AppConfiguration.backgroundChooserBackgroundColor

        let screenSize = UIScreen.mainScreen().bounds
        let screenAspect = screenSize.height/screenSize.width

        var useAspect = screenAspect
        if UIDevice.currentDevice().userInterfaceIdiom == .Phone
        {
            useAspect *= 0.975
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
            self.searchBar.transform = CGAffineTransformMakeScale(1.5, 1.5)
            self.progressAI.transform = CGAffineTransformMakeScale(2.0, 2.0)
        }

        let previewCornerRadius = 12.0

        self.previewView.layer.cornerRadius = CGFloat(previewCornerRadius)
        self.previewView.layer.shadowOpacity = 0.33
        self.previewView.layer.shadowColor = AppConfiguration.bluishColor.CGColor
        self.previewView.layer.shadowRadius = 12.0
        self.previewView.layer.shadowOffset = CGSizeZero

        self.pagedVideoViewController = PagedLoopedVideoViewController()
        self.addChildViewController(self.pagedVideoViewController)
        self.pagedVideoViewController.view.frame = self.previewView.bounds
        self.pagedVideoViewController.view.layer.cornerRadius =
            CGFloat(previewCornerRadius - previewCornerRadius*0.1)
        self.pagedVideoViewController.view.layer.masksToBounds = true
        self.previewView.insertSubview(
            self.pagedVideoViewController.view, belowSubview: self.searchBar)
        self.pagedVideoViewController.didMoveToParentViewController(self)
        self.pagedVideoViewController.delegate = self

        self.cachedVideos = KeyedItemsCache<CachedVideo>(capacity: 15)

        self.searchBar.keyboardAppearance = .Dark
        self.searchBar.autocapitalizationType = .None
        self.searchBar.autocorrectionType = .Yes
        let sbTF = self.searchBar.valueForKey("_searchField") as! UITextField
        sbTF.layer.cornerRadius = 5.0
        sbTF.layer.masksToBounds = false
        sbTF.layer.shouldRasterize = true
        sbTF.layer.backgroundColor = UIColor.whiteColor().colorWithAlphaComponent(0.25).CGColor
        self.searchBar.delegate = self

        for button in [
            self.goBackBN,
            self.goForwardBN,
            self.cancelBN,
            self.selectBN,
            self.optionsBN]
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

        let grGoBack = UISwipeGestureRecognizer(target: self, action: "goBackBNAction")
        grGoBack.direction = .Right
        let grGoForward = UISwipeGestureRecognizer(target: self, action: "goForwardBNAction")
        grGoForward.direction = .Left
        self.view.addGestureRecognizer(grGoBack)
        self.view.addGestureRecognizer(grGoForward)

        self.activityIndicatorVC =
            NestableActivityIndicatorViewController(activityIndicator: self.progressAI)

        self.hudView = UIView(frame: self.previewView.bounds)
        self.hudView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.previewView.insertSubview(self.hudView, belowSubview: self.searchBar)

        let nc = NSNotificationCenter.defaultCenter()
        self.applicationWillResignActiveObserver = nc.addObserverForName(
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
        self.applicationDidBecomeActiveObserver = nc.addObserverForName(
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
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func didReceiveMemoryWarning ()
    {
        super.didReceiveMemoryWarning()

        //
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func searchBarSearchButtonClicked (searchBar:UISearchBar)
    {
        self.searchBar.resignFirstResponder()

        let query = self.searchBar.text!
        self.searchWithQuery(query)
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
            "o": "0",
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
        case .VideoTransitioning:
            graceTime = 999.0
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
            if !results.isEmpty
            {
                self.lastSearchResults = results
                self.pagedVideoViewController.clear()
                self.currItemIndex = nil
                self.goToItemAtIndex(0)
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
        let maybePredownloadVideo = { (prevItemIndex:Int?) in
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
                        self.predownloadVideo(nextItem, atIndex: nextIndex)
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
                        self.predownloadVideo(prevItem, atIndex: prevIndex)
                    }
                }
            }
        }

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

                // Send out both requests for the first frame and for the video itself
                // simultaneously.

                let cachedVideoAddedDate = NSDate()

                // First frame.
                let previewFFURL = item["t_" + resolution].stringValue
                let requestFF =
                    Alamofire.request(
                        .GET, previewFFURL, headers: AppConfiguration.serverHeaders)
                requestFF.response { [weak self] _, response, data, _ in
                    guard let sSelf = self else
                    {
                        return
                    }

                    if !sSelf.videoDataIsBeingDownloaded ||
                       itemID != sSelf.currDownloadedVideoDataID
                    {
                        return
                    }

                    if let response = response, data = data where response.statusCode == 200
                    {
                        let firstFrame = UIImage(data: data)
                        if let firstFrame = firstFrame
                        {
                            let cachedVideo = sSelf.cachedVideos[itemID]
                            if cachedVideo == nil
                            {
                                let cachedVideo =
                                    CachedVideo(
                                        firstFrame: firstFrame, videoURL: nil,
                                        resolution: resolution)
                                sSelf.cachedVideos.addItem(
                                    cachedVideo, forKey: itemID,
                                    usingAddedDate: cachedVideoAddedDate)

                                sSelf.pagedVideoViewController.didUpdateDataForVideoAtIndex(index)
                                sSelf.pagedVideoViewController.goToVideoAtIndex(index)
                            }
                            else if cachedVideo!.firstFrame == nil
                            {
                                cachedVideo!.firstFrame = firstFrame
                                cachedVideo!.resolution = resolution

                                sSelf.pagedVideoViewController.didUpdateDataForVideoAtIndex(index)
                            }
                        }
                    }
                }

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

                        self.pagedVideoViewController.goToVideoAtIndex(index)

                        maybePredownloadVideo(prevItemIndex)
                    }

                    self.predownloadedVideoWasPickedUp = true

                    // The video predownload functionality is now able to handle it.
                    return
                }

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
                                CachedVideo(
                                    firstFrame: nil, videoURL: tempFileURL, resolution: resolution)
                            sSelf.cachedVideos.addItem(
                                cachedVideo, forKey: itemID, usingAddedDate: cachedVideoAddedDate)

                            sSelf.pagedVideoViewController.didUpdateDataForVideoAtIndex(index)
                            sSelf.pagedVideoViewController.goToVideoAtIndex(index)
                        }
                        else if cachedVideo!.videoURL == nil
                        {
                            cachedVideo!.videoURL = tempFileURL
                            cachedVideo!.resolution = resolution

                            sSelf.pagedVideoViewController.didUpdateDataForVideoAtIndex(index)
                            sSelf.pagedVideoViewController.goToVideoAtIndex(index)
                        }

                        maybePredownloadVideo(prevItemIndex)
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

            self.pagedVideoViewController.goToVideoAtIndex(index)

            maybePredownloadVideo(prevItemIndex)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func numberOfVideosForPagedLoopedVideoViewController (
        controller:PagedLoopedVideoViewController) ->
            Int
    {
        return self.lastSearchResults.count
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func firstFrameAndVideoURLForVideoAtIndex (
        index:Int, forPagedLoopedVideoViewController controller:PagedLoopedVideoViewController) ->
            (firstFrame:UIImage?, videoURL:NSURL?, aspect:String?, subAlign:String?)
    {
        let item = self.lastSearchResults[index]
        let itemID = item["item_id"].stringValue

        if let cachedVideo = self.cachedVideos[itemID]
        {
            let aspect = item["aspect"].stringValue
            let subAlign = item["sub_align"].string ?? "c"
            return (
                firstFrame: cachedVideo.firstFrame,
                videoURL: cachedVideo.videoURL,
                aspect: aspect,
                subAlign: subAlign
            )
        }
        else
        {
            return (firstFrame: nil, videoURL: nil, aspect: nil, subAlign: nil)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func pagedLoopedVideoViewController (
        controller:PagedLoopedVideoViewController, willBeginTransitioningToIndex index:Int)
    {
        self.currVideoTransitioningActivityID = self.activityWillBegin(.VideoTransitioning)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func pagedLoopedVideoViewController (
        controller:PagedLoopedVideoViewController, didEndTransitioningToIndex index:Int)
    {
        if let currVideoTransitioningActivityID = self.currVideoTransitioningActivityID
        {
            self.activityDidEnd(currVideoTransitioningActivityID, activityType: .VideoTransitioning)
            self.currVideoTransitioningActivityID = nil
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func updateControlButtons ()
    {
        self.goBackBN.hiddenAnimated = self.currItemIndex <= 0
        self.goForwardBN.hiddenAnimated = self.currItemIndex >= self.lastSearchResults.count - 1
        self.selectBN.hiddenAnimated = false
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func predownloadVideo (item:JSON, atIndex index:Int)
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
                            CachedVideo(
                                firstFrame: nil, videoURL: tempFileURL, resolution: resolution)
                        sSelf.cachedVideos.addItem(
                            cachedVideo, forKey: itemID, usingAddedDate: cachedVideoAddedDate)

                        sSelf.pagedVideoViewController.didUpdateDataForVideoAtIndex(index)
                    }
                    else if cachedVideo!.videoURL == nil
                    {
                        cachedVideo!.videoURL = tempFileURL
                        cachedVideo!.resolution = resolution

                        sSelf.pagedVideoViewController.didUpdateDataForVideoAtIndex(index)
                    }

                    if sSelf.predownloadedVideoWasPickedUp
                    {
                        sSelf.didPredownloadVideoClosureSuccess()
                    }
                }
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func dismiss ()
    {
        self.view.endEditing(true)
        
        (self.parentViewController as! BackgroundChooserViewController).dismiss()
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

    private func outputVideo (videoURL:NSURL, forItem item:JSON)
    {
        if let animationKeys = self.selectBN.layer.animationKeys() where !animationKeys.isEmpty
        {
            on_main_with_delay(0.05) {
                self.outputVideo(videoURL, forItem: item)
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

                let itemID = item["item_id"].stringValue

                let iuURL = self.videosURL + itemID + "/"
                let queryParams = ["iu": "1"]
                let request =
                    Alamofire.request(
                        .GET, iuURL, parameters: queryParams,
                        headers: AppConfiguration.serverHeaders)
                request.resume()

                let backgroundVideoRecord = BackgroundVideoRecord()
                backgroundVideoRecord.itemID = Int(itemID)!
                if AppConfiguration.urlIsTemp(videoURL)
                {
                    backgroundVideoRecord.videoRelPath =
                        AppConfiguration.dropTempDirURLFromURL(videoURL)
                    backgroundVideoRecord.videoRelPathIsTemp = true
                }
                else
                {
                    backgroundVideoRecord.videoRelPath =
                        AppConfiguration.dropEventsDirURLFromURL(videoURL)
                    backgroundVideoRecord.videoRelPathIsTemp = false
                }
                backgroundVideoRecord.subAlign = item["sub_align"].string ?? "c"
                backgroundVideoRecord.timeAlign = item["time_align"].string ?? "s"
                backgroundVideoRecord.nativeLoop = item["native_loop"].bool ?? false
                backgroundVideoRecord.jointTime = item["joint_time"].double ?? 3.0

                let asset = AVURLAsset(URL: videoURL, options: nil)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                let cgSnapshot = try! generator.copyCGImageAtTime(kCMTimeZero, actualTime: nil)
                let snapshot = UIImage(CGImage: cgSnapshot)
                backgroundVideoRecord.snapshot = snapshot

                var outputData = [String: AnyObject]()
                outputData["backgroundVideoRecord"] = backgroundVideoRecord
                self.outputDelegate.acceptOutputDataFromVideoChooserViewController(outputData)

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

    func acceptOutputDataFromVideoChooserOptionsViewController (data:[String: AnyObject])
    {
        self.searchWithQuery(data["query"] as! String)
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

    @IBAction private func cancelBNAction ()
    {
        self.dismiss()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction private func selectBNAction ()
    {
        if self.currItemIndex == nil
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
            self.outputVideo(cachedVideo.videoURL!, forItem: item)
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
                        sSelf.outputVideo(tempFileURL, forItem: item)
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

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction private func optionsBNAction ()
    {
        let optionsSB = UIStoryboard(name: "VideoChooserOptions", bundle: nil)
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
        (optionsVC as! VideoChooserOptionsViewController).delegate = self
        self.presentViewController(optionsContainerVC, animated: true, completion: nil)
    }

    //----------------------------------------------------------------------------------------------
}



