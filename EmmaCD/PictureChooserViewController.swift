import UIKit
import Alamofire


//--------------------------------------------------------------------------------------------------

protocol PictureChooserViewControllerOutput : class
{
    func acceptOutputDataFromPictureChooserViewController (data:[String: AnyObject])
}

//--------------------------------------------------------------------------------------------------

private class CachedPicture
{
    var tempCachedImage:UIImage!
    let imageURL:NSURL
    let resolution:String

    static let picturesTempDirURL = {
        return AppConfiguration.tempDirURL.URLByAppendingPathComponent("p", isDirectory: true)
    }()

    static let asyncQueue = {
        return dispatch_queue_create("CachedPicture.asyncQueue", DISPATCH_QUEUE_SERIAL)
    }()

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    init (image:UIImage, resolution:String)
    {
        self.tempCachedImage = image
        self.imageURL = makeTempFileURL(self.dynamicType.picturesTempDirURL)
        self.resolution = resolution

        dispatch_async(self.dynamicType.asyncQueue) {
            let pngImage = UIImagePNGRepresentation(image)
            if let pngImage = pngImage
            {
                let saved = pngImage.writeToURL(self.imageURL, atomically: true)
                if saved
                {
                    on_main() {
                        self.tempCachedImage = nil
                    }
                }
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    deinit
    {
        _ = try? NSFileManager().removeItemAtURL(self.imageURL)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    var image:UIImage
    {
        if let tempCachedImage = self.tempCachedImage
        {
            return tempCachedImage
        }
        else
        {
            return UIImage(contentsOfFile: self.imageURL.path!)!
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
}

//--------------------------------------------------------------------------------------------------


class PictureChooserViewController : UIViewController, UISearchBarDelegate
{
    weak var outputDelegate:PictureChooserViewControllerOutput!

    @IBOutlet private weak var previewView:UIView!
    @IBOutlet private weak var searchBar:UISearchBar!
    @IBOutlet private weak var goBackBN:UIButton!
    @IBOutlet private weak var goForwardBN:UIButton!
    @IBOutlet private weak var cancelBN:UIButton!
    @IBOutlet private weak var selectBN:UIButton!
    @IBOutlet private weak var progressAI:UIActivityIndicatorView!

    private let picturesURL = AppConfiguration.serverURLForAPI + "pictures/"

    private var containerView:UIView!
    private var imageView:UIImageView!

    private var currItemIndex:Int!
    private var lastSearchResults:[JSON]!
    private let cachedPictures =
        KeyedItemsCache<CachedPicture>(
            capacity: 32, purgeByAddedDateInsteadOfLastAccessedDate: true)
    private var visitedItemIDs = Set<String>()
    private let pictureTransDSlow = 0.25
    private let pictureTransDFast = 0.1

    private var pictureIsBeingDownloaded = false
    private var pictureDownloadRequest:Request!

    private enum PicturePredownloadDirection
    {
        case Right
        case Left
    }

    private var currPicturePredownloadSessionID = 0
    private var pictureIDsToCurrPredownloadPictureRequests = [String: Request]()
    private var prevPicturePredownloadDirection:PicturePredownloadDirection!

    private var activityIndicatorVC:NestableActivityIndicatorViewController!
    private let minTimeBeforeProgressAI = 1.0

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

        if self.pictureIsBeingDownloaded
        {
            self.pictureDownloadRequest?.cancel()
        }
        for request in self.pictureIDsToCurrPredownloadPictureRequests.values
        {
            request.cancel()
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
            self.searchBar.transform = CGAffineTransformMakeScale(1.5, 1.5)
            self.progressAI.transform = CGAffineTransformMakeScale(2.0, 2.0)
        }

        self.previewView.backgroundColor = UIColor.clearColor()

        let previewCornerRadius = 12.0

        self.previewView.layer.cornerRadius = CGFloat(previewCornerRadius)
        self.previewView.layer.shadowOpacity = 0.33
        self.previewView.layer.shadowColor = AppConfiguration.bluishColor.CGColor
        self.previewView.layer.shadowRadius = 12.0
        self.previewView.layer.shadowOffset = CGSizeZero

        self.containerView = UIView(frame: self.previewView.bounds)
        self.containerView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.containerView.layer.cornerRadius =
            CGFloat(previewCornerRadius - previewCornerRadius*0.1)
        self.containerView.layer.masksToBounds = true
        self.previewView.insertSubview(self.containerView, belowSubview: self.searchBar)

        self.imageView = UIImageView(frame: self.previewView.bounds)
        self.imageView.contentMode = .ScaleAspectFill
        self.imageView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.containerView.addSubview(self.imageView)

        self.imageView.image = AppConfiguration.defaultPicture

        self.searchBar.keyboardAppearance = .Dark
        self.searchBar.autocapitalizationType = .None
        self.searchBar.autocorrectionType = .Yes
        let sbTF = self.searchBar.valueForKey("_searchField") as! UITextField
        sbTF.layer.cornerRadius = 5.0
        sbTF.layer.masksToBounds = false
        sbTF.layer.shouldRasterize = true
        sbTF.layer.backgroundColor = UIColor.whiteColor().colorWithAlphaComponent(0.25).CGColor
        self.searchBar.delegate = self

        for button in [self.goBackBN, self.goForwardBN, self.cancelBN, self.selectBN]
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

        let grGoBack = UISwipeGestureRecognizer(target: self, action: "goBackBNAction")
        grGoBack.direction = .Right
        let grGoForward = UISwipeGestureRecognizer(target: self, action: "goForwardBNAction")
        grGoForward.direction = .Left
        self.view.addGestureRecognizer(grGoBack)
        self.view.addGestureRecognizer(grGoForward)

        self.activityIndicatorVC =
            NestableActivityIndicatorViewController(activityIndicator: self.progressAI)

        let nc = NSNotificationCenter.defaultCenter()
        self.applicationWillResignActiveObserver = nc.addObserverForName(
            UIApplicationWillResignActiveNotification, object: nil,
            queue: NSOperationQueue.mainQueue()) { [weak self] _ in
                guard let sSelf = self else
                {
                    return
                }

                if sSelf.pictureIsBeingDownloaded
                {
                    sSelf.pictureDownloadRequest?.suspend()
                }
                for request in sSelf.pictureIDsToCurrPredownloadPictureRequests.values
                {
                    request.suspend()
                }
            }
        self.applicationDidBecomeActiveObserver = nc.addObserverForName(
            UIApplicationDidBecomeActiveNotification, object: nil,
            queue: NSOperationQueue.mainQueue()) { [weak self] _ in
                guard let sSelf = self else
                {
                    return
                }

                if sSelf.pictureIsBeingDownloaded
                {
                    sSelf.pictureDownloadRequest?.resume()
                }
                for request in sSelf.pictureIDsToCurrPredownloadPictureRequests.values
                {
                    request.resume()
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

        let searchActivityID = self.activityWillBegin()
        let queryParams = [
            "app": AppConfiguration.appIDForServer,
            "q": query,
        ]
        let request =
            Alamofire.request(
                .GET, self.picturesURL, parameters: queryParams,
                headers: AppConfiguration.serverHeaders)
        request.response { [weak self] _, response, data, _ in
            guard let sSelf = self else
            {
                return
            }

            sSelf.activityDidEnd(searchActivityID)

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

    private func activityWillBegin () -> Int
    {
        if !self.activityIndicatorVC.hasAnyActivity()
        {
            for subview in self.view.subviews
            {
                subview.userInteractionEnabled = false
            }
            self.cancelBN.userInteractionEnabled = true
        }

        return self.activityIndicatorVC.activityIDForStartedActivityWithGraceTime(
            self.minTimeBeforeProgressAI)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func activityDidEnd (activityID:Int)
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

                self.cachedPictures.clear()
                self.visitedItemIDs.removeAll()

                self.currPicturePredownloadSessionID = self.currPicturePredownloadSessionID &+ 1
                for request in self.pictureIDsToCurrPredownloadPictureRequests.values
                {
                    request.cancel()
                }
                self.pictureIDsToCurrPredownloadPictureRequests.removeAll()
                self.prevPicturePredownloadDirection = nil

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
        let hud = MBProgressHUD.showHUDAddedTo(self.imageView, animated: true)
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
        let cachedPicture = self.cachedPictures[itemID]

        if cachedPicture == nil
        {
            var previewPictureURL:String?

            var resolution = AppConfiguration.pictureResolutionForPreview
            let resolutionIndex = AppConfiguration.resolutions.indexOf(resolution)!
            for (var i = resolutionIndex; i >= 0; i--)
            {
                resolution = AppConfiguration.resolutions[i]
                previewPictureURL = item["p_" + resolution].string
                if previewPictureURL != nil
                {
                    break
                }
            }

            if let previewPictureURL = previewPictureURL
            {
                self.pictureIsBeingDownloaded = true

                let downloadActivityID = self.activityWillBegin()

                let cachedPictureAddedDate = NSDate()

                self.pictureDownloadRequest =
                    Alamofire.request(
                        .GET, previewPictureURL, headers: AppConfiguration.serverHeaders)
                self.pictureDownloadRequest.response { [weak self] _, response, data, _ in
                    guard let sSelf = self else
                    {
                        return
                    }

                    sSelf.pictureIsBeingDownloaded = false

                    sSelf.activityDidEnd(downloadActivityID)

                    if let response = response, data = data where response.statusCode == 200
                    {
                        let image = UIImage(data: data)
                        if let image = image
                        {
                            let prevItemIndex = sSelf.currItemIndex ?? -1

                            sSelf.currItemIndex = index
                            sSelf.updateControlButtons()
                            sSelf.setPreviewImage(image, forItem: item)

                            if sSelf.cachedPictures[itemID] == nil
                            {
                                let cachedPicture =
                                    CachedPicture(image: image, resolution: resolution)
                                sSelf.cachedPictures.addItem(
                                    cachedPicture, forKey: itemID,
                                    usingAddedDate: cachedPictureAddedDate)
                            }

                            let direction:PicturePredownloadDirection =
                                sSelf.currItemIndex - prevItemIndex >= 0 ? .Right : .Left
                            sSelf.maybePredownloadPicturesInDirection(direction)
                        }
                    }
                    else
                    {
                        sSelf.couldNotConnect()
                    }
                }
            }
        }
        else
        {
            let prevItemIndex = self.currItemIndex ?? -1

            self.currItemIndex = index
            self.updateControlButtons()
            self.setPreviewImage(
                cachedPicture!.image, forItem: item,
                faster: self.visitedItemIDs.contains(itemID))

            let direction:PicturePredownloadDirection =
                self.currItemIndex - prevItemIndex >= 0 ? .Right : .Left
            self.maybePredownloadPicturesInDirection(direction)
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

    private func maybePredownloadPicturesInDirection (direction:PicturePredownloadDirection)
    {
        if let prevPicturePredownloadDirection = self.prevPicturePredownloadDirection where
           direction != prevPicturePredownloadDirection
        {
            self.currPicturePredownloadSessionID = self.currPicturePredownloadSessionID &+ 1
            for request in self.pictureIDsToCurrPredownloadPictureRequests.values
            {
                request.cancel()
            }
            self.pictureIDsToCurrPredownloadPictureRequests.removeAll()

            self.cachedPictures.reversePurgeSorting()
        }

        self.prevPicturePredownloadDirection = direction

        let maybePredownloadPictureForItemAtIndex = { (index:Int) in
            let item = self.lastSearchResults[index]
            let itemID = item["item_id"].stringValue

            if self.cachedPictures[itemID] != nil ||
               self.pictureIDsToCurrPredownloadPictureRequests[itemID] != nil
            {
                return
            }

            var previewPictureURL:String?

            var resolution = AppConfiguration.pictureResolutionForPreview
            let resolutionIndex = AppConfiguration.resolutions.indexOf(resolution)!
            for (var i = resolutionIndex; i >= 0; i--)
            {
                resolution = AppConfiguration.resolutions[i]
                previewPictureURL = item["p_" + resolution].string
                if previewPictureURL != nil
                {
                    break
                }
            }

            if let previewPictureURL = previewPictureURL
            {
                let cachedPictureAddedDate = NSDate()

                let request =
                    Alamofire.request(
                        .GET, previewPictureURL, headers: AppConfiguration.serverHeaders)

                self.pictureIDsToCurrPredownloadPictureRequests[itemID] = request

                let boundPicturePredownloadSessionID = self.currPicturePredownloadSessionID

                request.response { [weak self] _, response, data, _ in
                    guard let sSelf = self else
                    {
                        return
                    }

                    if boundPicturePredownloadSessionID != sSelf.currPicturePredownloadSessionID
                    {
                        return
                    }

                    sSelf.pictureIDsToCurrPredownloadPictureRequests.removeValueForKey(itemID)

                    if let response = response, data = data where response.statusCode == 200
                    {
                        let image = UIImage(data: data)
                        if let image = image
                        {
                            if sSelf.cachedPictures[itemID] == nil
                            {
                                let cachedPicture =
                                    CachedPicture(image: image, resolution: resolution)
                                sSelf.cachedPictures.addItem(
                                    cachedPicture, forKey: itemID,
                                    usingAddedDate: cachedPictureAddedDate)
                            }
                        }
                    }
                }
            }
        }

        let numPredownloadedImagesOnEachSide = self.cachedPictures.capacity/2
        var lowIndex = self.currItemIndex - numPredownloadedImagesOnEachSide
        var highIndex = self.currItemIndex + numPredownloadedImagesOnEachSide + 1
        if direction == .Right
        {
            lowIndex++
        }
        else  // .Left
        {
            highIndex--
        }
        if lowIndex < 0
        {
            lowIndex = 0
        }
        if highIndex > self.lastSearchResults.count
        {
            highIndex = self.lastSearchResults.count
        }
        if direction == .Right
        {
            for (var index = lowIndex; index < highIndex; index++)
            {
                maybePredownloadPictureForItemAtIndex(index)
            }
        }
        else  // .Left
        {
            for (var index = highIndex - 1; index >= lowIndex; index--)
            {
                maybePredownloadPictureForItemAtIndex(index)
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func setPreviewImage (image:UIImage, forItem item:JSON, faster:Bool = false)
    {
        appD().ignoringInteractionEvents.begin()

        let itemID = item["item_id"].stringValue
        self.visitedItemIDs.insert(itemID)

        let aspect = item["aspect"].stringValue
        let subAlign = item["sub_align"].string ?? "c"
        subAlignView(
            self.imageView, inSuperview: self.containerView, forAspect: aspect, withCode: subAlign)

        let duration = !faster ? self.pictureTransDSlow : self.pictureTransDFast
        UIView.transitionWithView(
            self.imageView, duration: duration, options: .TransitionCrossDissolve, animations: {
                self.imageView.image = image
            },
            completion: { _ in
                appD().ignoringInteractionEvents.end()
            })
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func outputPicture (picture:UIImage, forItem item:JSON)
    {
        if let animationKeys = self.selectBN.layer.animationKeys() where !animationKeys.isEmpty
        {
            on_main_with_delay(0.05) {
                self.outputPicture(picture, forItem: item)
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

                let iuURL = self.picturesURL + itemID + "/"
                let queryParams = ["iu": "1"]
                let request =
                Alamofire.request(
                    .GET, iuURL, parameters: queryParams, headers: AppConfiguration.serverHeaders)
                request.resume()

                let backgroundPictureRecord = BackgroundPictureRecord()
                backgroundPictureRecord.itemID = Int(itemID)!
                backgroundPictureRecord.picture = picture
                backgroundPictureRecord.subAlign = item["sub_align"].string ?? "c"
                backgroundPictureRecord.snapshot = picture

                var outputData = [String: AnyObject]()
                outputData["backgroundPictureRecord"] = backgroundPictureRecord
                self.outputDelegate.acceptOutputDataFromPictureChooserViewController(outputData)

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

    private func dismiss ()
    {
        self.view.endEditing(true)

        (self.parentViewController as! BackgroundChooserViewController).dismiss()
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

        let useResolution = AppConfiguration.pictureResolutionForUse

        let item = self.lastSearchResults[self.currItemIndex]
        let itemID = item["item_id"].stringValue

        if let cachedPicture = self.cachedPictures[itemID] where
           cachedPicture.resolution == useResolution
        {
            // The cached version is just fine.
            appD().ignoringInteractionEvents.begin()

            // The backend image file may disappear soon.
            let pictureCopy = cachedPicture.image.copiedImage()

            self.outputPicture(pictureCopy, forItem: item)
        }
        else
        {
            // Download the picture in the presentational resolution.

            for request in self.pictureIDsToCurrPredownloadPictureRequests.values
            {
                request.cancel()
            }

            var usePictureURL:String?

            let resolutionIndex = AppConfiguration.resolutions.indexOf(useResolution)!
            for (var i = resolutionIndex; i >= 0; i--)
            {
                usePictureURL = item["p_" + AppConfiguration.resolutions[i]].string
                if usePictureURL != nil
                {
                    break
                }
            }

            if let usePictureURL = usePictureURL
            {
                let downloadActivityID = self.activityWillBegin()

                let request =
                    Alamofire.request(
                        .GET, usePictureURL, headers: AppConfiguration.serverHeaders)
                request.response { [weak self] _, response, data, _ in
                    guard let sSelf = self else
                    {
                        return
                    }

                    sSelf.activityDidEnd(downloadActivityID)

                    if let response = response, data = data where response.statusCode == 200
                    {
                        let image = UIImage(data: data)
                        if let image = image
                        {
                            appD().ignoringInteractionEvents.begin()
                            sSelf.outputPicture(image, forItem: item)
                        }
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

    //----------------------------------------------------------------------------------------------
}



