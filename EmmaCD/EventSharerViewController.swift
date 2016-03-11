import AVFoundation
import Photos
import FBSDKShareKit
import TwitterKit
import MessageUI
import MobileCoreServices


//--------------------------------------------------------------------------------------------------

protocol EventSharerViewControllerInputDelegate : class
{
    func provideInputDataForEventSharerViewController () -> [String: AnyObject]
    func exportTypeForEventSharerViewController () -> EventExportType
    func isSavingCompleteForEventSharerViewController () -> Bool
    func savedPictureForEventSharerViewController () -> UIImage
    func videoSavingProgressForEventSharerViewController () -> Double
    func savedVideoURLForEventSharerViewController () -> NSURL
    func sharingDestinationForEventSharerViewController () -> EventSharingDestination
    func eventSharerViewControllerWillDismiss ()
}

//--------------------------------------------------------------------------------------------------


class EventSharerViewController : UIViewController, FBSDKSharingDelegate,
                                  MFMessageComposeViewControllerDelegate
{
    static let instagramAspectRatio = 1.0
    static let instagramMaxVideoDuration = 15.0
    static let instagramAdjustedMaxVideoDuration = 14.9
    static let instagramVideoPixelSizeFactor = 1.0

    static let facebookAspectRatio = 1.0
    static let facebookVideoPixelSizeFactor = 1.5

    static let twitterAspectRatio = 3.0/4.0
    static let twitterMaxVideoDuration = 15.0
    static let twitterVideoBitRateMbps = 7.0
    static let twitterVideoPixelSizeFactor = 1.5
    let twitterMediaUploadURLStr = "https://upload.twitter.com/1.1/media/upload.json"
    let twitterStatusUpdateURLStr = "https://api.twitter.com/1.1/statuses/update.json"
    let twitterUploadChunkSizeKB = 2048

    weak var inputDelegate:EventSharerViewControllerInputDelegate!

    @IBOutlet private weak var cancelBN:UIButton!
    @IBOutlet private weak var previewView:UIView!
    @IBOutlet private weak var sharingDestinationIconView:UIImageView!

    private let HUDOffsetFromBottom:Float = 72.0
    private var inputData:[String: AnyObject]!
    private var eventRecord:EventRecord!
    private var exportType:EventExportType!
    private var sharingDestination:EventSharingDestination!
    private var snapshot:UIView!
    private var waitTimer:NSTimer!
    private var videoSavingProgressHUD:MBProgressHUD!
    private var picture:UIImage!
    private var videoURL:NSURL!
    private var applicationDidEnterBackgroundObserver:NSObjectProtocol!
    private var videoView:LoopedVideoView!
    private var uploadingProgressHUD:MBProgressHUD!
    private var documentInteractionController:UIDocumentInteractionController!
    private var dismissOnNextViewDidAppear = false

    //----------------------------------------------------------------------------------------------

    deinit
    {
        if let applicationDidEnterBackgroundObserver = self.applicationDidEnterBackgroundObserver
        {
            NSNotificationCenter.defaultCenter().removeObserver(
                applicationDidEnterBackgroundObserver)
        }
    }

    //----------------------------------------------------------------------------------------------

    override func viewDidLoad ()
    {
        super.viewDidLoad()

        self.inputData = self.inputDelegate.provideInputDataForEventSharerViewController()

        self.eventRecord = self.inputData["eventRecord"] as! EventRecord

        self.exportType = self.inputDelegate.exportTypeForEventSharerViewController()
        self.sharingDestination =
            self.inputDelegate.sharingDestinationForEventSharerViewController()

        self.view.tintColor = AppConfiguration.tintColor
        self.view.backgroundColor = AppConfiguration.bluishColorDarkerP

        //self.previewView.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.25)
        self.previewView.backgroundColor = UIColor.clearColor()
        self.previewView.alpha = 0.0

        self.sharingDestinationIconView.shownAlpha = 0.5
        self.sharingDestinationIconView.hidden = true

        self.snapshot = self.inputData["snapshot"] as! UIView
        self.view.insertSubview(self.snapshot, belowSubview: self.cancelBN)

        if self.exportType! == .Video
        {
            self.videoSavingProgressHUD = MBProgressHUD.showHUDAddedTo(self.view, animated: true)
            self.videoSavingProgressHUD.mode = .AnnularDeterminate
            self.videoSavingProgressHUD.labelText = "Recording video..."
            self.videoSavingProgressHUD.labelFont = UIFont.systemFontOfSize(14.0)
            self.videoSavingProgressHUD.dimBackground = false
            self.videoSavingProgressHUD.opacity = 0.33
            self.videoSavingProgressHUD.userInteractionEnabled = false
            self.videoSavingProgressHUD.removeFromSuperViewOnHide = true
            self.videoSavingProgressHUD.yOffset = Float(-self.view.bounds.height*0.25)
        }

        self.applicationDidEnterBackgroundObserver =
            NSNotificationCenter.defaultCenter().addObserverForName(
                UIApplicationDidEnterBackgroundNotification, object: nil,
                queue: NSOperationQueue.mainQueue()) { [weak self] _ in
                    guard let sSelf = self else
                    {
                        return
                    }

                    sSelf.dismiss()
                }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func viewDidAppear (animated:Bool)
    {
        super.viewDidAppear(animated)

        if self.dismissOnNextViewDidAppear
        {
            self.dismiss()
            return
        }

        UIView.animateWithDuration(0.5) {
            self.snapshot.alpha = 0.2
        }

        self.waitTimer =
            NSTimer.scheduledTimerWithTimeInterval(
                0.05, target: self, selector: "checkOnSaving", userInfo: nil, repeats: true)
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

    func checkOnSaving ()
    {
        if !self.inputDelegate.isSavingCompleteForEventSharerViewController()
        {
            if self.exportType! == .Video
            {
                let progress = self.inputDelegate.videoSavingProgressForEventSharerViewController()
                self.videoSavingProgressHUD.progress = Float(progress)
            }
        }
        else
        {
            self.waitTimer.invalidate()
            self.waitTimer = nil

            let previewViewAppearanceClosure = { [weak self] in
                guard let sSelf = self else
                {
                    return
                }

                UIView.animateWithDuration(0.5) {
                    sSelf.snapshot.alpha = 0.0
                    sSelf.previewView.alpha = 1.0
                }
            }

            if self.exportType! == .Picture
            {
                self.picture = self.inputDelegate.savedPictureForEventSharerViewController()

                let pictureImageView = UIImageView(frame: self.previewView.bounds)
                pictureImageView.contentMode = .ScaleAspectFit
                pictureImageView.image = self.picture
                self.previewView.addSubview(pictureImageView)

                previewViewAppearanceClosure()
            }
            else  // .Video
            {
                self.videoSavingProgressHUD.hide(true)

                self.videoURL = self.inputDelegate.savedVideoURLForEventSharerViewController()

                self.videoView = LoopedVideoView(frame: self.previewView.bounds)
                self.videoView.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect
                self.previewView.addSubview(self.videoView)
                self.videoView.readyForDisplayClosure = { [weak self] in
                    guard let sSelf = self else
                    {
                        return
                    }

                    sSelf.videoView.play()
                    previewViewAppearanceClosure()
                }
                self.videoView.videoURL = self.videoURL
            }

            var sharingDestinationIconName:String!

            var showUploadingProgressHUD = false
            let uploadingProgressHUDMode:MBProgressHUDMode = .Indeterminate
            var uploadingProgressHUDLabelText = "Uploading..."
            let uploadingProgressHUDLabelTextSize = 16.0
            var uploadingProgressHUDDetailsLabelText:String!

            switch self.sharingDestination!
            {
            case .Instagram:
                sharingDestinationIconName = "Instagram"

                showUploadingProgressHUD = true
                uploadingProgressHUDLabelText = "Preparing Instagram..."
                if self.exportType! == .Picture
                {
                    //uploadingProgressHUDDetailsLabelText =
                    //    "Instagram app allows for maximizing image size."
                }
                else  // .Video
                {
                    //uploadingProgressHUDDetailsLabelText =
                    //    "Instagram app allows for maximizing video size."
                }

            case .Facebook:
                sharingDestinationIconName = "Facebook"

                showUploadingProgressHUD = true
                uploadingProgressHUDLabelText = "Preparing Facebook..."
                if self.exportType! == .Video
                {
                    uploadingProgressHUDDetailsLabelText =
                        "For best video quality, enable HD video uploading in Facebook settings."
                }

            case .Twitter:
                sharingDestinationIconName = "Twitter"

                showUploadingProgressHUD = true

            case .Messages:
                sharingDestinationIconName = "Messages"

                showUploadingProgressHUD = true
                uploadingProgressHUDLabelText = "Preparing Messages..."

            case .OtherShares:
                sharingDestinationIconName = "OtherShares"

                showUploadingProgressHUD = true
                uploadingProgressHUDLabelText = "Preparing..."

            case .PhotoLibrary:
                sharingDestinationIconName = "PhotoLibrary"

                showUploadingProgressHUD = true
                uploadingProgressHUDLabelText =
                    "Saving to \(AppConfiguration.photoLibraryAlbumTitle)..."
            }

            self.sharingDestinationIconView.image = UIImage(named: sharingDestinationIconName)
            self.sharingDestinationIconView.hiddenAnimated = false

            if showUploadingProgressHUD
            {
                self.uploadingProgressHUD = MBProgressHUD.showHUDAddedTo(self.view, animated: true)
                self.uploadingProgressHUD.mode = uploadingProgressHUDMode
                self.uploadingProgressHUD.labelText = uploadingProgressHUDLabelText
                self.uploadingProgressHUD.labelFont =
                    UIFont.systemFontOfSize(CGFloat(uploadingProgressHUDLabelTextSize))
                if let detailsLabelText = uploadingProgressHUDDetailsLabelText
                {
                    self.uploadingProgressHUD.detailsLabelText = detailsLabelText
                }
                self.uploadingProgressHUD.dimBackground = false
                self.uploadingProgressHUD.opacity = 0.5
                self.uploadingProgressHUD.userInteractionEnabled = false
                self.uploadingProgressHUD.removeFromSuperViewOnHide = true
                self.uploadingProgressHUD.yOffset =
                    Float(self.view.bounds.midY) - self.HUDOffsetFromBottom
            }

            on_main_with_delay(0.33) {
                self.doSharing()
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func doSharing ()
    {
        if self.sharingDestination! == .Instagram
        {
            let instagramAppURL = NSURL(string: "instagram://app")!
            if UIApplication.sharedApplication().canOpenURL(instagramAppURL)
            {
                if self.exportType! == .Picture
                {
                    //let imageURL = makeTempFileURL(AppConfiguration.tempDirURL, ext: "igo")
                    //let imageData = UIImageJPEGRepresentation(self.picture, 1.0)!
                    //imageData.writeToURL(imageURL, atomically: true)
                    //
                    //self.documentInteractionController =
                    //    UIDocumentInteractionController(URL: imageURL)
                    //self.documentInteractionController.UTI = "com.instagram.exclusivegram"
                    //self.dismissOnNextViewDidAppear = true
                    //self.documentInteractionController.presentOpenInMenuFromRect(
                    //    CGRectZero, inView: self.view, animated: true)

                    self.addImageToPhotoLibrary(
                        self.picture, completion: { [weak self] success, error, assetURLStr in
                            guard let sSelf = self else
                            {
                                return
                            }

                            if success
                            {
                                sSelf.openInstagramForAsset(assetURLStr!)
                            }

                            sSelf.dismiss()
                        })
                }
                else  // .Video
                {
                    self.addVideoToPhotoLibrary(
                        self.videoURL, completion: { [weak self] success, error, assetURLStr in
                            guard let sSelf = self else
                            {
                                return
                            }

                            if success
                            {
                                sSelf.openInstagramForAsset(assetURLStr!)
                            }

                            sSelf.dismiss()
                        })
                }
            }
            else
            {
                doOKAlertWithTitle(nil, message: "Instagram app not found") {
                    self.dismiss()
                }
            }
        }
        else if self.sharingDestination! == .Facebook
        {
            if self.exportType! == .Picture
            {
                self.addImageToPhotoLibrary(
                    self.picture, completion: { [weak self] success, error, assetURLStr in
                        guard let sSelf = self else
                        {
                            return
                        }

                        if success
                        {
                            let fbImage = FBSDKSharePhoto()
                            fbImage.image = sSelf.picture
                            fbImage.userGenerated = true
                            let fbImageContent = FBSDKSharePhotoContent()
                            fbImageContent.photos = [fbImage]

                            sSelf.uploadingProgressHUD?.hide(true)

                            FBSDKShareDialog.showFromViewController(
                                sSelf, withContent: fbImageContent, delegate: sSelf)
                        }
                        else
                        {
                            sSelf.dismiss()
                        }
                    })
            }
            else  // .Video
            {
                self.addVideoToPhotoLibrary(
                    self.videoURL, completion: { [weak self] success, error, assetURLStr in
                        guard let sSelf = self else
                        {
                            return
                        }

                        if success
                        {
                            let videoAssetURL = NSURL(string: assetURLStr!)
                            let fbVideo = FBSDKShareVideo()
                            fbVideo.videoURL = videoAssetURL
                            let fbVideoContent = FBSDKShareVideoContent()
                            fbVideoContent.video = fbVideo

                            sSelf.uploadingProgressHUD?.hide(true)
                            sSelf.videoView.pause()

                            FBSDKShareDialog.showFromViewController(
                                sSelf, withContent: fbVideoContent, delegate: sSelf)
                        }
                        else
                        {
                            sSelf.dismiss()
                        }
                    })
            }
        }
        else if self.sharingDestination! == .Twitter
        {
            let statusText = ""
            if self.exportType! == .Picture
            {
                self.addImageToPhotoLibrary(
                    self.picture, completion: { [weak self] success, error, assetURLStr in
                        guard let sSelf = self else
                        {
                            return
                        }

                        if success
                        {
                            let imageURL = makeTempFileURL(AppConfiguration.tempDirURL)
                            let imageData = UIImageJPEGRepresentation(sSelf.picture, 1.0)!
                            imageData.writeToURL(imageURL, atomically: true)

                            let mimeType = "image/jpeg"
                            sSelf.twitterUploadMedia(
                                imageURL, mimeType: mimeType, statusText: statusText)
                        }
                        else
                        {
                            sSelf.dismiss()
                        }
                    })
            }
            else  // .Video
            {
                self.addVideoToPhotoLibrary(
                    self.videoURL, completion: { [weak self] success, error, assetURLStr in
                        guard let sSelf = self else
                        {
                            return
                        }

                        if success
                        {
                            let mimeType = "video/mp4"
                            sSelf.twitterUploadMedia(
                                sSelf.videoURL, mimeType: mimeType, statusText: statusText)
                        }
                        else
                        {
                            sSelf.dismiss()
                        }
                    })
            }
        }
        else if self.sharingDestination! == .Messages
        {
            if MFMessageComposeViewController.canSendText() &&
               MFMessageComposeViewController.canSendAttachments()
            {
                var altFilename = self.eventRecord.title.UNIXFileNameSafeString
                if altFilename.isEmpty
                {
                    altFilename = "File"
                }

                if self.exportType! == .Picture
                {
                    if MFMessageComposeViewController.isSupportedAttachmentUTI(String(kUTTypeImage))
                    {
                        self.addImageToPhotoLibrary(
                            self.picture, completion: { [weak self] success, error, assetURLStr in
                                guard let sSelf = self else
                                {
                                    return
                                }

                                if success
                                {
                                    let messageComposer = MFMessageComposeViewController()
                                    messageComposer.messageComposeDelegate = sSelf

                                    let imageURL = makeTempFileURL(AppConfiguration.tempDirURL)
                                    let imageData = UIImageJPEGRepresentation(sSelf.picture, 1.0)!
                                    imageData.writeToURL(imageURL, atomically: true)
                                    messageComposer.addAttachmentURL(
                                        imageURL, withAlternateFilename: "\(altFilename).jpg")

                                    sSelf.uploadingProgressHUD?.hide(true)

                                    sSelf.presentViewController(
                                        messageComposer, animated: true, completion: nil)
                                }
                                else
                                {
                                    sSelf.dismiss()
                                }
                            })
                    }
                    else
                    {
                        doOKAlertWithTitle(nil, message: "Unable to send pictures via Messages") {
                            self.dismiss()
                        }
                    }
                }
                else  // .Video
                {
                    if MFMessageComposeViewController.isSupportedAttachmentUTI(String(kUTTypeVideo))
                    {
                        self.addVideoToPhotoLibrary(
                            self.videoURL, completion: { [weak self] success, error, assetURLStr in
                                guard let sSelf = self else
                                {
                                    return
                                }
        
                                if success
                                {
                                    let messageComposer = MFMessageComposeViewController()
                                    messageComposer.messageComposeDelegate = sSelf

                                    messageComposer.addAttachmentURL(
                                        sSelf.videoURL, withAlternateFilename: "\(altFilename).mp4")

                                    sSelf.uploadingProgressHUD?.hide(true)
                                    sSelf.videoView.pause()
                                    
                                    sSelf.presentViewController(
                                        messageComposer, animated: true, completion: nil)
                                }
                                else
                                {
                                    sSelf.dismiss()
                                }
                            })
                    }
                    else
                    {
                        doOKAlertWithTitle(nil, message: "Unable to send videos via Messages") {
                            self.dismiss()
                        }
                    }
                }
            }
            else
            {
                doOKAlertWithTitle(nil, message: "Unable to send messages") {
                    self.dismiss()
                }
            }
        }
        else if self.sharingDestination! == .OtherShares
        {
            let item:AnyObject
            if self.exportType! == .Picture
            {
                item = self.picture
            }
            else  // .Video
            {
                item = self.videoURL
            }

            let activityVC =
                UIActivityViewController(activityItems: [item], applicationActivities: nil)
            activityVC.excludedActivityTypes = [
                UIActivityTypePostToFacebook,
                "com.facebook.Facebook.ShareExtension",
                "com.apple.UIKit.activity.PostToFacebook",
                UIActivityTypePostToTwitter,
                UIActivityTypeMessage,
            ]
            activityVC.completionWithItemsHandler =
            { (activityType:String?, completed:Bool, returnedItems:[AnyObject]?,
               activityError:NSError?) -> Void in
                self.dismiss()
            }

            self.uploadingProgressHUD?.hide(true)

            self.presentViewController(activityVC, animated: true, completion: nil)
        }
        else if self.sharingDestination! == .PhotoLibrary
        {
            if self.exportType! == .Picture
            {
                self.addImageToPhotoLibrary(
                    self.picture, completion: { [weak self] success, error, assetURLStr in
                        guard let sSelf = self else
                        {
                            return
                        }

                        if success
                        {
                            sSelf.doCompletion()
                        }
                        else
                        {
                            sSelf.dismiss()
                        }
                    })
            }
            else  // .Video
            {
                self.addVideoToPhotoLibrary(
                    self.videoURL, completion: { [weak self] success, error, assetURLStr in
                        guard let sSelf = self else
                        {
                            return
                        }

                        if success
                        {
                            sSelf.doCompletion()
                        }
                        else
                        {
                            sSelf.dismiss()
                        }
                    })
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func openInstagramForAsset (assetURLStr:String)
    {
        let assetURLEnc = assetURLStr.URLEncodedString
        let igURLStr = "instagram://library?AssetPath=\(assetURLEnc)"
        let igURL = NSURL(string: igURLStr)!
        let sharedApp = UIApplication.sharedApplication()
        if sharedApp.canOpenURL(igURL)
        {
            sharedApp.openURL(igURL)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func doCompletion ()
    {
        self.uploadingProgressHUD?.hide(true)

        let completeIcon = UIImage(named: "Checkmark")!
        let iconSideSize = 48.0
        let completeIconView =
            UIImageView(
                frame: CGRect(
                    origin: CGPointZero, size: CGSize(width: iconSideSize, height: iconSideSize)))
        completeIconView.image = completeIcon

        let completeHUD = MBProgressHUD.showHUDAddedTo(self.view, animated: true)
        completeHUD.mode = .CustomView
        completeHUD.customView = completeIconView
        completeHUD.labelText = "Complete"
        completeHUD.labelFont = UIFont.systemFontOfSize(16.0)
        completeHUD.dimBackground = false
        completeHUD.opacity = 0.5
        completeHUD.userInteractionEnabled = false
        completeHUD.yOffset = Float(self.view.bounds.midY) - self.HUDOffsetFromBottom

        on_main_with_delay(2.0) {
            completeHUD.hide(true)

            on_main_with_delay(0.25) {
                self.dismiss()
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func errorAlertWillAppear ()
    {
        self.uploadingProgressHUD?.hide(true)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func sharer (sharer:FBSDKSharing!, didCompleteWithResults results:[NSObject: AnyObject]!)
    {
        self.FBSDKShareDialogDidComplete()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func sharer (sharer:FBSDKSharing!, didFailWithError error:NSError!)
    {
        let message = NSError.localizedDescriptionAndReasonForError(error)
        doOKAlertWithTitle("Facebook Error", message: message) {
            self.FBSDKShareDialogDidComplete()
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func sharerDidCancel (sharer:FBSDKSharing!)
    {
        self.FBSDKShareDialogDidComplete()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func FBSDKShareDialogDidComplete ()
    {
        self.dismiss()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func messageComposeViewController (
        controller:MFMessageComposeViewController, didFinishWithResult result:MessageComposeResult)
    {
        self.dismiss()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func twitterUploadMedia (mediaURL:NSURL, mimeType:String, statusText:String)
    {
        let fileSize = NSFileManager.sizeOfFileAtURL(mediaURL)
        let fileData = try! NSData(contentsOfURL: mediaURL, options: .DataReadingMappedAlways)

        var doTwitterErrorMessage:((error:NSError?) -> Void)!

        var uploadNextChunkOrFinalize:((userID:String, mediaID:String) -> Void)!
        let initUpload = { [weak self] (userID:String) in
            guard let sSelf = self else
            {
                return
            }

            // INIT
            let message = [
                "command": "INIT",
                "media_type": mimeType,
                "total_bytes": String(fileSize)
            ]
            let twClientInit = TWTRAPIClient(userID: userID)
            let requestInit =
                twClientInit.URLRequestWithMethod(
                    "POST", URL: sSelf.twitterMediaUploadURLStr, parameters: message, error: nil)
            twClientInit.sendTwitterRequest(requestInit,
                completion: { response, data, error in
                    if self == nil
                    {
                        return
                    }

                    if error == nil && data != nil
                    {
                        let initJSON = JSON(data: data!)
                        if let mediaID = initJSON["media_id_string"].string
                        {
                            uploadNextChunkOrFinalize(userID: userID, mediaID: mediaID)
                        }
                        else
                        {
                            doTwitterErrorMessage(error: nil)
                        }
                    }
                    else
                    {
                        if error?.code != 89
                        {
                            doTwitterErrorMessage(error: error)
                        }
                        else
                        {
                            // "Invalid or expired auth token (code 89)"
                            let errorDesc = "Please try again later"
                            let errorDescLStr = NSLocalizedString(errorDesc, comment: "")
                            let userInfo = [NSLocalizedDescriptionKey: errorDescLStr]
                            let customError =
                                NSError(domain: NSCocoaErrorDomain, code: 0, userInfo: userInfo)
                            doTwitterErrorMessage(error: customError)
                        }
                    }
                })
        }

        var segmentsByteRanges = [(Int, NSRange)]()
        var currSegmentIndex = 0
        var currBytePos = 0
        while true
        {
            if currBytePos == fileSize
            {
                break
            }

            var byteLength = self.twitterUploadChunkSizeKB*1024
            var nextBytePos = currBytePos + byteLength
            if nextBytePos > fileSize
            {
                byteLength = fileSize - currBytePos
                nextBytePos = fileSize
            }

            let byteRange = NSRange(location: currBytePos, length: byteLength)
            segmentsByteRanges.append((currSegmentIndex, byteRange))

            currSegmentIndex++
            currBytePos = nextBytePos
        }

        var finalizeUpload:((userID:String, mediaID:String) -> Void)!
        uploadNextChunkOrFinalize = { [weak self] (userID:String, mediaID:String) in
            guard let sSelf = self else
            {
                return
            }

            if segmentsByteRanges.isEmpty
            {
                finalizeUpload(userID: userID, mediaID: mediaID)
                return
            }

            let segmentIndexAndByteRange = segmentsByteRanges.removeFirst()
            let segmentIndex = segmentIndexAndByteRange.0
            let segmentByteRange = segmentIndexAndByteRange.1
            let subdata = fileData.subdataWithRange(segmentByteRange)

            let subdataStr =
                subdata.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))

            // APPEND
            let message = [
                "command": "APPEND",
                "media_id": mediaID,
                "segment_index": String(segmentIndex),
                "media": subdataStr
            ]
            let twClientAppend = TWTRAPIClient(userID: userID)
            let requestAppend =
                twClientAppend.URLRequestWithMethod(
                    "POST", URL: sSelf.twitterMediaUploadURLStr, parameters: message, error: nil)
            twClientAppend.sendTwitterRequest(requestAppend,
                completion: { response, data, error in
                    if self == nil
                    {
                        return
                    }

                    if error == nil
                    {
                        currSegmentIndex++

                        uploadNextChunkOrFinalize(userID: userID, mediaID: mediaID)
                    }
                    else
                    {
                        doTwitterErrorMessage(error: error)
                    }
                })
        }

        var updateStatus:((userID:String, mediaID:String) -> Void)!
        finalizeUpload = { [weak self] (userID:String, mediaID:String) in
            guard let sSelf = self else
            {
                return
            }

            // FINALIZE
            let message = [
                "command": "FINALIZE",
                "media_id": mediaID
            ]
            let twClientFinalize = TWTRAPIClient(userID: userID)
            let requestFinalize =
                twClientFinalize.URLRequestWithMethod(
                    "POST", URL: sSelf.twitterMediaUploadURLStr, parameters: message, error: nil)
            twClientFinalize.sendTwitterRequest(requestFinalize,
                completion: { response, data, error in
                    if self == nil
                    {
                        return
                    }

                    if error == nil
                    {
                        updateStatus(userID: userID, mediaID: mediaID)
                    }
                    else
                    {
                        doTwitterErrorMessage(error: error)
                    }
                })
        }

        updateStatus = { [weak self] (userID:String, mediaID:String) in
            guard let sSelf = self else
            {
                return
            }

            // Status update.
            let message = [
                "status": statusText,
                "wrap_links": "true",
                "media_ids": mediaID
            ]
            let twClientStatusUpdate = TWTRAPIClient(userID: userID)
            let requestStatusUpdate =
                twClientStatusUpdate.URLRequestWithMethod(
                    "POST", URL: sSelf.twitterStatusUpdateURLStr, parameters: message, error: nil)
            twClientStatusUpdate.sendTwitterRequest(requestStatusUpdate,
                completion: { [weak self] response, data, error in
                    guard let sSelf = self else
                    {
                        return
                    }

                    if error == nil ||
                       error?.code == 54
                    {
                        sSelf.doCompletion()
                    }
                    else
                    {
                        doTwitterErrorMessage(error: error)
                    }
                })
        }

        doTwitterErrorMessage = { [weak self] (error:NSError?) in
            guard let sSelf = self else
            {
                return
            }

            sSelf.errorAlertWillAppear()

            let message = NSError.localizedDescriptionAndReasonForError(error)
            doOKAlertWithTitle("Twitter Error", message: message) {
                sSelf.dismiss()
            }
        }

        Twitter.sharedInstance().logInWithCompletion({ [weak self] session, error in
            if self == nil
            {
                return
            }

            if let session = session
            {
                let userID = session.userID
                initUpload(userID)
            }
            else
            {
                doTwitterErrorMessage(error: error)
            }
        })
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func dismiss ()
    {
        self.waitTimer?.invalidate()
        self.waitTimer = nil

        self.inputDelegate?.eventSharerViewControllerWillDismiss()
    }

    //----------------------------------------------------------------------------------------------

    @IBAction private func cancelBNAction ()
    {
        self.dismiss()
    }

    //----------------------------------------------------------------------------------------------

    private func addImageToPhotoLibrary (
        image:UIImage, completion:((success:Bool, error:NSError?, assetURLStr:String?) -> Void))
    {
        let photoLibrary = PHPhotoLibrary.sharedPhotoLibrary()
        var imageAssetPlaceholder:PHObjectPlaceholder!
        photoLibrary.performChanges({
                let request = PHAssetChangeRequest.creationRequestForAssetFromImage(image)
                imageAssetPlaceholder = request.placeholderForCreatedAsset
            },
            completionHandler: { [weak self] success, error in
                guard let sSelf = self else
                {
                    return
                }

                if success
                {
                    let localID = imageAssetPlaceholder.localIdentifier

                    let fetchResult =
                        PHAsset.fetchAssetsWithLocalIdentifiers([localID], options: nil)
                    if let imageAsset = fetchResult.firstObject as? PHAsset
                    {
                        sSelf.addAssetToTheAlbum(
                            imageAsset, completion: { [weak self] success, error in
                                guard let sSelf = self else
                                {
                                    return
                                }

                                if success
                                {
                                    let assetURLStr =
                                        sSelf.dynamicType.imageAssetURLStringForLocalID(localID)

                                    on_main() {
                                        completion(
                                            success: true, error: nil, assetURLStr: assetURLStr)
                                    }
                                }
                                else
                                {
                                    on_main() {
                                        completion(success: false, error: error, assetURLStr: nil)
                                    }
                                }
                            })
                    }
                    else
                    {
                        on_main() {
                            completion(success: false, error: nil, assetURLStr: nil)
                        }
                    }
                }
                else
                {
                    on_main() {
                        completion(success: false, error: error, assetURLStr: nil)
                    }
                }
            })
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func addVideoToPhotoLibrary (
        videoURL:NSURL, completion:((success:Bool, error:NSError?, assetURLStr:String?) -> Void))
    {
        let photoLibrary = PHPhotoLibrary.sharedPhotoLibrary()
        var videoAssetPlaceholder:PHObjectPlaceholder!
        photoLibrary.performChanges({
                let request =
                    PHAssetChangeRequest.creationRequestForAssetFromVideoAtFileURL(videoURL)!
                videoAssetPlaceholder = request.placeholderForCreatedAsset
            },
            completionHandler: { [weak self] success, error in
                guard let sSelf = self else
                {
                    return
                }

                if success
                {
                    let localID = videoAssetPlaceholder.localIdentifier

                    let fetchResult =
                        PHAsset.fetchAssetsWithLocalIdentifiers([localID], options: nil)
                    if let videoAsset = fetchResult.firstObject as? PHAsset
                    {
                        sSelf.addAssetToTheAlbum(
                            videoAsset, completion: { [weak self] success, error in
                                guard let sSelf = self else
                                {
                                    return
                                }

                                if success
                                {
                                    let assetURLStr =
                                        sSelf.dynamicType.videoAssetURLStringForLocalID(localID)

                                    on_main() {
                                        completion(
                                            success: true, error: nil, assetURLStr: assetURLStr)
                                    }
                                }
                                else
                                {
                                    on_main() {
                                        completion(success: false, error: error, assetURLStr: nil)
                                    }
                                }
                            })
                    }
                    else
                    {
                        on_main() {
                            completion(success: false, error: nil, assetURLStr: nil)
                        }
                    }
                }
                else
                {
                    on_main() {
                        completion(success: false, error: error, assetURLStr: nil)
                    }
                }
            })
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func addAssetToTheAlbum (
        asset:PHAsset, completion:((success:Bool, error:NSError?) -> Void))
    {
        let albumTitle = AppConfiguration.photoLibraryAlbumTitle

        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumTitle)
        let fetchResult =
            PHAssetCollection.fetchAssetCollectionsWithType(
                PHAssetCollectionType.Album, subtype: PHAssetCollectionSubtype.Any,
                options: fetchOptions)
        let photoLibrary = PHPhotoLibrary.sharedPhotoLibrary()
        if let album = fetchResult.firstObject as? PHAssetCollection
        {
            // The album already exists.
            photoLibrary.performChanges({
                    if let request = PHAssetCollectionChangeRequest(forAssetCollection: album)
                    {
                        request.addAssets([asset])
                    }
                },
                completionHandler: { success, error in
                    completion(success: success, error: error)
                })
        }
        else
        {
            // Create the album.
            photoLibrary.performChanges({
                let request =
                    PHAssetCollectionChangeRequest.creationRequestForAssetCollectionWithTitle(
                        albumTitle)
                    request.addAssets([asset])
                },
                completionHandler: { success, error in
                    completion(success: success, error: error)
                })
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private class func imageAssetURLStringForLocalID (localID:String) -> String
    {
        let assetID =
            localID.stringByReplacingOccurrencesOfString(
                "/.*", withString: "", options: .RegularExpressionSearch, range: nil)
        let ext = "JPG"
        let assetURLStr = "assets-library://asset/asset.\(ext)?id=\(assetID)&ext=\(ext)"
        return assetURLStr
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private class func videoAssetURLStringForLocalID (localID:String) -> String
    {
        let assetID =
            localID.stringByReplacingOccurrencesOfString(
                "/.*", withString: "", options: .RegularExpressionSearch, range: nil)
        let ext = "mp4"
        let assetURLStr = "assets-library://asset/asset.\(ext)?id=\(assetID)&ext=\(ext)"
        return assetURLStr
    }

    //----------------------------------------------------------------------------------------------
}



