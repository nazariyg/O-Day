class AppConfiguration
{
    enum AppMode
    {
        case Dev
        case Prod
    }

    static let appMode:AppMode = .Prod

    static var serverURL:String
    {
        switch self.appMode
        {
        case .Dev:
            return "Omitted."
        case .Prod:
            return "Omitted."
        }
    }

    static let appIDForServer = "Omitted."
    static let serverURLForAPI = serverURL + "api/"
    static let serverHeaders = [String: String]()

    static var appSuperConfigURL:String
    {
        return self.serverURL + "c"
    }

    static let appName = "O'Day"

    static var appFeedbackEmail = "oday.feedback@gmail.com"
    static var appStoreURLForRateReview =
        NSURL(string: "itms-apps://itunes.apple.com/app/id1082332853")!
    static var appStoreURLForSharing = NSURL(string: "https://itunes.apple.com/app/id1082332853")!

    static var une = true
    static var uneMaxUpdatedEvents = 5
    static var uneComplianceUpdatedEventsReward = 1

    static var sharingRequiresFullVersion = true

    static let tintColor = UIColor.whiteColor()
    static let reddishColor = UIColor.redColor()
    static let bluishColor = UIColor(hue: 2.0/3.0, saturation: 0.5, brightness: 1.0, alpha: 1.0)
    static let bluishColorSemiDarker =
        UIColor(patternImage: UIImage(named: "BluishBackgroundPatternSemiDarker")!)
    static let bluishColorDarkerP =
        UIColor(patternImage: UIImage(named: "BluishBackgroundPatternDarker")!)
    static let bluishColorDarker =
        UIColor(hue: 2.0/3.0, saturation: 0.5, brightness: 0.5, alpha: 1.0)
    static let bluishColorLighter =
        UIColor(hue: 2.0/3.0, saturation: 0.25, brightness: 1.0, alpha: 1.0)
    static let backgroundChooserBackgroundColor =
        UIColor(patternImage: UIImage(named: "BluishBackgroundPattern")!)
    static let purpleColor = UIColor(red: 200.0/255, green: 96.0/255, blue: 198.0/255, alpha: 1.0)

    static var expectedDownloadSpeedMbps = 6.0

    static var breathDuration = 4.5
    static var heartbeatDuration = 60.0/75.0
    
    static let resolutions = ["ld", "md", "sd", "hd"]

    static let defaultTitle = "My Title"
    static let titleDefaultFontName = "HelveticaNeue-Thin"
    static let titleFontSize = 64.0
    static let titleFontSizeFramed = 64.0  //36.0
    static let titleTwoLinesScale = 0.75
    static let titlePaddingHFactor = 0.1
    static let titleMaxNumCharactersInLine = 16

    static let digitsViewPaddingHFactor = 0.075

    static let defaultPicture = UIImage(named: "DefaultPicture")!

    static var exportEventsWithAppLogo = true
    static let appLogoWidthFactor = 0.16
    static let appLogoOffset = CGPoint(x: 12.0, y: 18.0)
    static var appLogoAlpha = 0.2

    static var photoLibraryAlbumTitle = "\(AppConfiguration.appName) Album"

    static let builtInEventTags = [
        "anniversary",
        "birthday",
        "travel",
        "holiday",
        "education",
        "personal",
    ]

    static let eventDidArriveNotificationCategoryID = "eventDidArrive"

    private enum NetworkType
    {
        case WiFi
        case Cellular
    }

    private static var lastNetworkType:NetworkType!
    private static var lastNetworkTypeTimestamp:NSDate!
    static var lastNetworkTypeCacheMinutes = 5

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    static var tempDirURL:NSURL
    {
        return NSURL(
            fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    class func clearTempDir ()
    {
        let fm = NSFileManager()
        let enumerator =
            fm.enumeratorAtURL(self.tempDirURL, includingPropertiesForKeys: nil, options: [],
                errorHandler: nil)
        while let fileURL = enumerator?.nextObject() as? NSURL
        {
            _ = try? fm.removeItemAtURL(fileURL)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    class func dropTempDirURLFromURL (url:NSURL) -> String
    {
        let path =
            url.path!.stringByReplacingOccurrencesOfString(
                self.tempDirURL.path!, withString: "", options: .AnchoredSearch)
        assert(path != url.path!)
        return path
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    class func urlIsTemp (url:NSURL) -> Bool
    {
        return url.path!.hasPrefix(self.tempDirURL.path!)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    static var eventsDirURL:NSURL
    {
        let fm = NSFileManager()
        let docsDirURL =
            try! fm.URLForDirectory(
                .DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
        let dirURL = docsDirURL.URLByAppendingPathComponent("Events", isDirectory: true)
        try! fm.createDirectoryAtURL(dirURL, withIntermediateDirectories: true, attributes: nil)
        return dirURL
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    class func dropEventsDirURLFromURL (url:NSURL) -> String
    {
        let path =
            url.path!.stringByReplacingOccurrencesOfString(
                self.eventsDirURL.path!, withString: "", options: .AnchoredSearch)
        assert(path != url.path!)
        return path
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    static var aspectForServer:String
    {
        if self.uii == .Phone
        {
            // Including 4/4s.
            return "9x16"
        }
        else  // .Pad
        {
            return "3x4"
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    static var vPreviewSDIsMinRes = "sd"
    static var vPreviewPhoneWiFiHDDownloadSecondsCV = 5.0
    static var vPreviewPhoneWiFiHDDownloadSecondsHDBitrateCV = 7.9
    static var vPreviewPhoneWiFiHDDownloadSecondsHDBitrateRes0 = "md"
    static var vPreviewPhoneWiFiHDDownloadSecondsHDBitrateRes1 = "md"
    static var vPreviewPhoneWiFiHDDownloadSecondsRes1 = "hd"
    static var vPreviewPhoneNotWiFiRes = "md"

    class func videoResolutionForPreview (
        hdBitrate:Double, hdByteSize:Double, sdIsMin:Bool) -> String
    {
        if sdIsMin
        {
            return self.vPreviewSDIsMinRes
        }

        let hdDownloadSeconds = (hdByteSize*8/1000000)/self.expectedDownloadSpeedMbps

        switch self.appMode
        {
        case .Dev:
            return "sd"
        case .Prod:
            if self.uii == .Phone
            {
                if self.networkType() == .WiFi
                {
                    if hdBitrate > self.vPreviewPhoneWiFiHDDownloadSecondsHDBitrateCV
                    {
                        return self.vPreviewPhoneWiFiHDDownloadSecondsHDBitrateRes0
                    }
                    else
                    {
                        return self.vPreviewPhoneWiFiHDDownloadSecondsHDBitrateRes1
                    }
                }
                else
                {
                    return self.vPreviewPhoneNotWiFiRes
                }
            }
            else  // .Pad
            {
                if self.networkType() == .WiFi
                {
                    if hdDownloadSeconds > 5.0
                    {
                        if hdBitrate > 5.1
                        {
                            return "sd"
                        }
                        else
                        {
                            return "md"
                        }
                    }
                    else
                    {
                        return "hd"
                    }
                }
                else
                {
                    return "md"
                }
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    static var vUseHDSizeMBCV = 50.0
    static var vUseHDSizeMBRes0 = "hd"
    static var vUseHDSizeMBRes1 = "sd"

    class func videoResolutionForUse (hdBitrate:Double, hdByteSize:Double) -> String
    {
        let hdSizeMB = hdByteSize/1048576

        if hdSizeMB < self.vUseHDSizeMBCV
        {
            return self.vUseHDSizeMBRes0
        }
        else
        {
            return self.vUseHDSizeMBRes1
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    static var pPreviewWiFiRes = "hd"
    static var pPreviewNotWiFiRes = "sd"

    static var pictureResolutionForPreview:String
    {
        if self.networkType() == .WiFi
        {
            return self.pPreviewWiFiRes
        }
        else
        {
            return self.pPreviewNotWiFiRes
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    static var pUseRes = "hd"

    static var pictureResolutionForUse:String
    {
        return self.pUseRes
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    class func makeupSelectionDialog (dialog:KCSelectionDialog)
    {
        dialog.dialogWidth = 280.0
        dialog.backgroundColor = UIColor.whiteColor().colorWithAlphaComponent(0.33)
        dialog.tintColor = UIColor.whiteColor()
        dialog.buttonBackgroundColorHighlighted =
            dialog.backgroundColor!.colorWithAlphaComponent(0.15)
        dialog.closeButtonColor = UIColor.whiteColor()
        dialog.closeButtonColorHighlighted = UIColor.whiteColor()
        dialog.buttonTextFontSize = 18.0
        dialog.buttonHeight = 56.0
        dialog.itemPadding = 32.0
        dialog.titleHeight = dialog.buttonHeight*0.8
        dialog.closeButtonHeight = dialog.buttonHeight*0.8
        dialog.useMotionEffects = false
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private static let uii = {
        return UIDevice.currentDevice().userInterfaceIdiom
    }()

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    class func processSuperConfig (superConfig:JSON)
    {
        if let appFeedbackEmail = superConfig["appFeedbackEmail"].string
        {
            self.appFeedbackEmail = appFeedbackEmail
        }
        if let appStoreURLForRateReview = superConfig["appStoreURLForRateReview"].string
        {
            self.appStoreURLForRateReview = NSURL(string: appStoreURLForRateReview)!
        }
        if let appStoreURLForSharing = superConfig["appStoreURLForSharing"].string
        {
            self.appStoreURLForSharing = NSURL(string: appStoreURLForSharing)!
        }
        if let expectedDownloadSpeedMbps = superConfig["expectedDownloadSpeedMbps"].double
        {
            self.expectedDownloadSpeedMbps = expectedDownloadSpeedMbps
        }
        if let breathDuration = superConfig["breathDuration"].double
        {
            self.breathDuration = breathDuration
        }
        if let heartbeatDuration = superConfig["heartbeatDuration"].double
        {
            self.heartbeatDuration = heartbeatDuration
        }
        if let exportEventsWithAppLogo = superConfig["exportEventsWithAppLogo"].bool
        {
            self.exportEventsWithAppLogo = exportEventsWithAppLogo
        }
        if let appLogoAlpha = superConfig["appLogoAlpha"].double
        {
            self.appLogoAlpha = appLogoAlpha
        }
        if let photoLibraryAlbumTitle = superConfig["photoLibraryAlbumTitle"].string
        {
            self.photoLibraryAlbumTitle = photoLibraryAlbumTitle
        }
        if let lastNetworkTypeCacheMinutes = superConfig["lastNetworkTypeCacheMinutes"].int
        {
            self.lastNetworkTypeCacheMinutes = lastNetworkTypeCacheMinutes
        }

        if let vPreviewSDIsMinRes = superConfig["vPreviewSDIsMinRes"].string
        {
            self.vPreviewSDIsMinRes = vPreviewSDIsMinRes
        }
        if let vPreviewPhoneWiFiHDDownloadSecondsCV =
           superConfig["vPreviewPhoneWiFiHDDownloadSecondsCV"].double
        {
            self.vPreviewPhoneWiFiHDDownloadSecondsCV = vPreviewPhoneWiFiHDDownloadSecondsCV
        }
        if let vPreviewPhoneWiFiHDDownloadSecondsHDBitrateCV =
           superConfig["vPreviewPhoneWiFiHDDownloadSecondsHDBitrateCV"].double
        {
            self.vPreviewPhoneWiFiHDDownloadSecondsHDBitrateCV =
                vPreviewPhoneWiFiHDDownloadSecondsHDBitrateCV
        }
        if let vPreviewPhoneWiFiHDDownloadSecondsHDBitrateRes0 =
           superConfig["vPreviewPhoneWiFiHDDownloadSecondsHDBitrateRes0"].string
        {
            self.vPreviewPhoneWiFiHDDownloadSecondsHDBitrateRes0 =
                vPreviewPhoneWiFiHDDownloadSecondsHDBitrateRes0
        }
        if let vPreviewPhoneWiFiHDDownloadSecondsHDBitrateRes1 =
           superConfig["vPreviewPhoneWiFiHDDownloadSecondsHDBitrateRes1"].string
        {
            self.vPreviewPhoneWiFiHDDownloadSecondsHDBitrateRes1 =
                vPreviewPhoneWiFiHDDownloadSecondsHDBitrateRes1
        }
        if let vPreviewPhoneWiFiHDDownloadSecondsRes1 =
           superConfig["vPreviewPhoneWiFiHDDownloadSecondsRes1"].string
        {
            self.vPreviewPhoneWiFiHDDownloadSecondsRes1 = vPreviewPhoneWiFiHDDownloadSecondsRes1
        }
        if let vPreviewPhoneNotWiFiRes = superConfig["vPreviewPhoneNotWiFiRes"].string
        {
            self.vPreviewPhoneNotWiFiRes = vPreviewPhoneNotWiFiRes
        }

        if let vUseHDSizeMBCV = superConfig["vUseHDSizeMBCV"].double
        {
            self.vUseHDSizeMBCV = vUseHDSizeMBCV
        }
        if let vUseHDSizeMBRes0 = superConfig["vUseHDSizeMBRes0"].string
        {
            self.vUseHDSizeMBRes0 = vUseHDSizeMBRes0
        }
        if let vUseHDSizeMBRes1 = superConfig["vUseHDSizeMBRes1"].string
        {
            self.vUseHDSizeMBRes1 = vUseHDSizeMBRes1
        }

        if let pPreviewWiFiRes = superConfig["pPreviewWiFiRes"].string
        {
            self.pPreviewWiFiRes = pPreviewWiFiRes
        }
        if let pPreviewNotWiFiRes = superConfig["pPreviewNotWiFiRes"].string
        {
            self.pPreviewNotWiFiRes = pPreviewNotWiFiRes
        }

        if let pUseRes = superConfig["pUseRes"].string
        {
            self.pUseRes = pUseRes
        }

        if let une = superConfig["une"].bool
        {
            self.une = une
        }
        if let uneMaxUpdatedEvents = superConfig["uneMaxUpdatedEvents"].int
        {
            self.uneMaxUpdatedEvents = uneMaxUpdatedEvents
        }
        if let uneComplianceUpdatedEventsReward =
           superConfig["uneComplianceUpdatedEventsReward"].int
        {
            self.uneComplianceUpdatedEventsReward = uneComplianceUpdatedEventsReward
        }

        if let sharingRequiresFullVersion = superConfig["sharingRequiresFullVersion"].bool
        {
            self.sharingRequiresFullVersion = sharingRequiresFullVersion
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private class func networkType () -> NetworkType
    {
        var doGetNetworkType = false
        let currDate = NSDate()

        if self.lastNetworkType == nil
        {
            doGetNetworkType = true
        }
        else
        {
            let cal = NSCalendar.currentCalendar()
            let diff = cal.components(
                .Minute, fromDate: self.lastNetworkTypeTimestamp, toDate: currDate, options: [])
            if diff.minute >= self.lastNetworkTypeCacheMinutes
            {
                doGetNetworkType = true
            }
        }

        if doGetNetworkType
        {
            let reachability = Reachability.reachabilityForInternetConnection()
            let reachabilityStatus = reachability.currentReachabilityStatus()
            self.lastNetworkType = reachabilityStatus == ReachableViaWiFi ? .WiFi : .Cellular

            self.lastNetworkTypeTimestamp = currDate
        }

        return self.lastNetworkType
    }

    //----------------------------------------------------------------------------------------------
}



