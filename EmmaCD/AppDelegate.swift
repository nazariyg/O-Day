import UIKit
import AVFoundation
import FBSDKCoreKit
import FBSDKShareKit
import Fabric
import TwitterKit
import Crashlytics
import Alamofire
import StoreKit


@UIApplicationMain
class AppDelegate : UIResponder, UIApplicationDelegate, FBSDKSharingDelegate,
                    SKProductsRequestDelegate, SKPaymentTransactionObserver
{
    var window:UIWindow?

    let ignoringInteractionEvents = NestableIgnoringInteractionEvents()

    //----------------------------------------------------------------------------------------------

    func application (
        application:UIApplication,
        didFinishLaunchingWithOptions launchOptions:[NSObject: AnyObject]?) -> Bool
    {
        let ud = NSUserDefaults.standardUserDefaults()

        let initUD:[String: AnyObject] = [
            "appFirstRun": true,
            "autoDeletePassedEvents": false,

            "appIsFullVersion": false,

            "appNumRuns": 0,
            "userNumUpdatedEvents": 0,
            "userAgreedToRateReviewR": false,
            "userAgreedToRateReview": false,
            "userAgreedToShareApp": false,
            "userRefusedToRateReview": false,
        ]
        ud.registerDefaults(initUD)

        let request = Alamofire.request(.GET, AppConfiguration.appSuperConfigURL)
        request.response { _, response, data, _ in
            if let response = response, data = data where response.statusCode == 200
            {
                let ud = NSUserDefaults.standardUserDefaults()
                ud.setObject(data, forKey: "appSuperConfig")
                ud.synchronize()

                let superConfig = JSON(data: data)
                AppConfiguration.processSuperConfig(superConfig)
            }
        }
        if let appSuperConfigData = ud.objectForKey("appSuperConfig") as? NSData
        {
            let superConfig = JSON(data: appSuperConfigData)
            AppConfiguration.processSuperConfig(superConfig)
        }

        AppConfiguration.clearTempDir()

        // Facebook
        FBSDKApplicationDelegate.sharedInstance().application(
            application, didFinishLaunchingWithOptions: launchOptions)

        // Twitter, Crashlytics
        Fabric.with([Twitter.self, Crashlytics.self])

        // Demo events.
        var numExistingEvents = 0
        let fm = NSFileManager()
        let eventDirURLs =
            try! fm.contentsOfDirectoryAtURL(
                AppConfiguration.eventsDirURL, includingPropertiesForKeys: nil,
                options: .SkipsHiddenFiles)
        for eventDirURL in eventDirURLs
        {
            var isDir:ObjCBool = false
            fm.fileExistsAtPath(eventDirURL.path!, isDirectory: &isDir)
            if isDir
            {
                let eventRecordFileURL = eventDirURL.URLByAppendingPathComponent("E")
                if fm.fileExistsAtPath(eventRecordFileURL.path!)
                {
                    numExistingEvents += 1
                }
            }
        }
        if ud.boolForKey("appFirstRun") && numExistingEvents == 0
        {
            EventRecord.createDemoEvents()
        }

        if ud.boolForKey("appFirstRun")
        {
            let currDate = NSDate()
            ud.setObject(currDate, forKey: "appFirstRunDate")
        }

        ud.setBool(false, forKey: "appFirstRun")

        self.registerForLocalNotifications()

        SKPaymentQueue.defaultQueue().addTransactionObserver(self)

        ud.setInteger(ud.integerForKey("appNumRuns") + 1, forKey: "appNumRuns")

        UISwitch.appearance().onTintColor = AppConfiguration.bluishColor
        _ = try? AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryAmbient)

        // Ready to appear.

        let window = UIWindow(frame: UIScreen.mainScreen().bounds)
        window.backgroundColor = UIColor.whiteColor()

        let rootViewController =
        UIStoryboard(name: "EventLister", bundle: nil).instantiateInitialViewController()!
        window.rootViewController = rootViewController

        self.window = window
        self.window!.makeKeyAndVisible()

        self.window!.layer.cornerRadius = ceil(5.0*UIScreen.mainScreen().bounds.width/320.0)
        self.window!.layer.masksToBounds = true

        return true
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func application (
        application:UIApplication, openURL url:NSURL, sourceApplication:String?,
        annotation:AnyObject) ->
            Bool
    {
        // Facebook.
        return FBSDKApplicationDelegate.sharedInstance().application(
            application, openURL: url, sourceApplication: sourceApplication, annotation: annotation)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func applicationWillResignActive (application:UIApplication)
    {
        // Sent when the application is about to move from active to inactive state.  This can
        // occur for certain types of temporary interruptions (such as an incoming phone call or 
        // SMS message) or when the user quits the application and it begins the transition to 
        // the background state.  Use this method to pause ongoing tasks, disable timers, and 
        // throttle down OpenGL ES frame rates.  Games should use this method to pause the game.
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func applicationDidEnterBackground (application:UIApplication)
    {
        // Use this method to release shared resources, save user data, invalidate timers, and 
        // store enough application state information to restore your application to its current 
        // state in case it is terminated later.  If your application supports background 
        // execution, this method is called instead of applicationWillTerminate: when
        // the user quits.
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func applicationWillEnterForeground (application:UIApplication)
    {
        // Called as part of the transition from the background to the inactive state; here you can
        // undo many of the changes made on entering the background.

        self.registerForLocalNotifications()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func applicationDidBecomeActive (application:UIApplication)
    {
        // Restart any tasks that were paused (or not yet started) while the application was 
        // inactive.  If the application was previously in the background, optionally refresh 
        // the user interface.

        FBSDKAppEvents.activateApp()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func applicationWillTerminate (application:UIApplication)
    {
        // Called when the application is about to terminate.  Save data if appropriate.  See also 
        // applicationDidEnterBackground:.

        AppConfiguration.clearTempDir()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func registerForLocalNotifications ()
    {
        let app = UIApplication.sharedApplication()

        let notifTypes:UIUserNotificationType = [.Alert, .Sound]
        let notifCategory = UIMutableUserNotificationCategory()
        notifCategory.identifier = AppConfiguration.eventDidArriveNotificationCategoryID
        let notifSettings =
            UIUserNotificationSettings(forTypes: notifTypes, categories: Set([notifCategory]))
        app.registerUserNotificationSettings(notifSettings)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func rateReview ()
    {
        let url = AppConfiguration.appStoreURLForRateReview
        let app = UIApplication.sharedApplication()
        if app.canOpenURL(url)
        {
            app.openURL(url)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func shareAppOnFacebook ()
    {
        let vc:UIViewController! = currentlyVisibleViewController()
        if vc == nil
        {
            return
        }

        let fbLinkContent = FBSDKShareLinkContent()
        fbLinkContent.contentURL = AppConfiguration.appStoreURLForSharing
        FBSDKShareDialog.showFromViewController(vc, withContent: fbLinkContent, delegate: self)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func sharer (sharer:FBSDKSharing!, didCompleteWithResults results:[NSObject: AnyObject]!)
    {
        // Empty.
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func sharer (sharer:FBSDKSharing!, didFailWithError error:NSError!)
    {
        let message = NSError.localizedDescriptionAndReasonForError(error)
        doOKAlertWithTitle("Facebook Error", message: message)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func sharerDidCancel (sharer:FBSDKSharing!)
    {
        // Empty.
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func iapProductIDs () -> [String]
    {
        let productIDsFileURL =
            NSBundle.mainBundle().URLForResource("ProductIDs.plist", withExtension: nil)!
        let productIDs = NSArray(contentsOfURL: productIDsFileURL)! as! [String]
        return productIDs
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func upgradeAppToFullVersion ()
    {
        if !SKPaymentQueue.canMakePayments()
        {
            doOKAlertWithTitle(nil, message: "You are not allowed to make payments.")
            return
        }

        self.ignoringInteractionEvents.begin()

        let productIDs = self.iapProductIDs()
        let productRequest = SKProductsRequest(productIdentifiers: Set<String>([productIDs.first!]))
        productRequest.delegate = self
        productRequest.start()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func restorePurchases ()
    {
        SKPaymentQueue.defaultQueue().restoreCompletedTransactions()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func productsRequest (request:SKProductsRequest, didReceiveResponse response:SKProductsResponse)
    {
        self.ignoringInteractionEvents.end()

        if response.products.isEmpty
        {
            print("Error: SKProductsResponse is empty.")
            return
        }

        let fullVersionProduct = response.products[0]
        let payment = SKPayment(product: fullVersionProduct)
        SKPaymentQueue.defaultQueue().addPayment(payment)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func request (request:SKRequest, didFailWithError error:NSError)
    {
        self.ignoringInteractionEvents.end()

        doOKAlertWithTitle("Error", message: NSError.localizedDescriptionAndReasonForError(error))
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func paymentQueue (
        queue:SKPaymentQueue, updatedTransactions transactions:[SKPaymentTransaction])
    {
        let knownProductIDs = self.iapProductIDs()

        for transaction in transactions
        {
            if transaction.transactionState == .Purchased ||
               transaction.transactionState == .Restored
            {
                let productID = transaction.payment.productIdentifier
                if productID == knownProductIDs.first!
                {
                    let ud = NSUserDefaults.standardUserDefaults()
                    ud.setBool(true, forKey: "appIsFullVersion")
                }
                else
                {
                    print("Unknown product ID: \(productID)")
                }
            }

            if transaction.transactionState == .Purchased ||
               transaction.transactionState == .Restored ||
               transaction.transactionState == .Failed
            {
                queue.finishTransaction(transaction)
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func paymentQueueRestoreCompletedTransactionsFinished (queue:SKPaymentQueue)
    {
        doOKAlertWithTitle(nil, message: "Your purchases have been restored.")
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func paymentQueue (
        queue:SKPaymentQueue, restoreCompletedTransactionsFailedWithError error:NSError)
    {
        doOKAlertWithTitle("Error", message: NSError.localizedDescriptionAndReasonForError(error))
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func shouldUpdateEventWithEventRecord (
        eventRecord:EventRecord, yesClosure:((dismiss:Bool) -> Void))
    {
        // Configuration.
        let maxUpdatedEvents = AppConfiguration.uneMaxUpdatedEvents
        let complianceUpdatedEventsReward = AppConfiguration.uneComplianceUpdatedEventsReward
        let minAppNumRunsForAsking = 10
        let minAppNumRunDaysForAsking = 3
        let minNumDaysBetweenAsking = 5

        let ud = NSUserDefaults.standardUserDefaults()

        let updateEventClosure = { (dismiss:Bool) in
            // Create or edit an event.
            yesClosure(dismiss: dismiss)

            ud.setInteger(
                ud.integerForKey("userNumUpdatedEvents") + 1, forKey: "userNumUpdatedEvents")

            // Asking for rate & review, separate from the IAP-related nagging.
            if ud.integerForKey("appNumRuns") >= minAppNumRunsForAsking
            {
                let appFirstRunDate:NSDate! = ud.objectForKey("appFirstRunDate") as? NSDate
                if appFirstRunDate == nil
                {
                    return
                }
                let currDate = NSDate()
                let dateComps =
                    NSCalendar.currentCalendar().components(
                        [.Day], fromDate: appFirstRunDate, toDate: currDate, options: [])
                if dateComps.day >= minAppNumRunDaysForAsking
                {
                    if !ud.boolForKey("userAgreedToRateReviewR") &&
                       !ud.boolForKey("userRefusedToRateReview")
                    {
                        if let larrDate = ud.objectForKey("lastAskedToRateReviewDate") as? NSDate
                        {
                            let dateComps =
                                NSCalendar.currentCalendar().components(
                                    [.Day], fromDate: larrDate, toDate: currDate, options: [])
                            if dateComps.day < minNumDaysBetweenAsking
                            {
                                return
                            }
                        }

                        let message =
                            "If you like \(AppConfiguration.appName), would you also like to" +
                            " rate it on the App Store?"
                        let alert =
                            UIAlertController(title: nil, message: message, preferredStyle: .Alert)
                        let aTitle0 = "Rate This App"
                        alert.addAction(UIAlertAction(title: aTitle0, style: .Default,
                            handler: { _ in
                                self.rateReview()
                                ud.setBool(true, forKey: "userAgreedToRateReviewR")
                            }))
                        let aTitle1 = "Never"
                        alert.addAction(UIAlertAction(title: aTitle1, style: .Default,
                            handler: { _ in
                                ud.setBool(true, forKey: "userRefusedToRateReview")
                            }))
                        alert.addAction(UIAlertAction(title: "Close", style: .Cancel, handler: nil))
                        on_main_with_delay(1.5) {
                            guard let vc = currentlyVisibleViewController() else
                            {
                                return
                            }
                            vc.presentViewController(alert, animated: true, completion: nil)

                            let currDate = NSDate()
                            ud.setObject(currDate, forKey: "lastAskedToRateReviewDate")
                        }
                    }
                }
            }
        }

        if ud.boolForKey("appIsFullVersion")
        {
            updateEventClosure(true)
            return
        }

        // IAP-related nagging.

        let justAskForUpgradeToFullVersion = {
            let message = "Saving additional events requires Full Version."
            let alert =
                UIAlertController(title: nil, message: message, preferredStyle: .Alert)
            let iapTitle = "Upgrade to Full Version"
            alert.addAction(UIAlertAction(title: iapTitle, style: .Default, handler: { _ in
                self.upgradeAppToFullVersion()
            }))
            alert.addAction(UIAlertAction(title: "Close", style: .Cancel, handler: nil))
            guard let vc = currentlyVisibleViewController() else
            {
                return
            }
            vc.presentViewController(alert, animated: true, completion: nil)
        }

        if ud.integerForKey("userNumUpdatedEvents") < maxUpdatedEvents
        {
            updateEventClosure(true)
        }
        else
        {
            if !AppConfiguration.une
            {
                justAskForUpgradeToFullVersion()
                return
            }

            guard let vc = currentlyVisibleViewController() else
            {
                return
            }

            if !ud.boolForKey("userAgreedToRateReviewR") &&
               !ud.boolForKey("userAgreedToRateReview")
            {
                let message =
                    "Saving additional events requires Full Version.\n" +
                    "But if you like our work, you can go on with saving after" +
                    " you give us a handful of stars on the App Store."
                let alert =
                    UIAlertController(title: nil, message: message, preferredStyle: .Alert)
                let iapTitle = "Rate This App"
                alert.addAction(UIAlertAction(title: iapTitle, style: .Default, handler: { _ in
                    self.rateReview()
                    ud.setBool(true, forKey: "userAgreedToRateReview")
                    ud.setInteger(
                        maxUpdatedEvents - complianceUpdatedEventsReward - 1,
                        forKey: "userNumUpdatedEvents")

                    on_main_with_delay(2.0) {
                        updateEventClosure(true)
                    }
                }))
                alert.addAction(UIAlertAction(title: "Close", style: .Cancel, handler: nil))
                vc.presentViewController(alert, animated: true, completion: nil)
            }
            else if !ud.boolForKey("userAgreedToShareApp")
            {
                let message =
                    "Saving additional events requires Full Version.\n" +
                    "But if you like our work, you can go on with saving after" +
                    " you share our app on Facebook."
                let alert =
                    UIAlertController(title: nil, message: message, preferredStyle: .Alert)
                let aTitle = "Share This App"
                alert.addAction(UIAlertAction(title: aTitle, style: .Default, handler: { _ in
                    self.shareAppOnFacebook()
                    ud.setBool(true, forKey: "userAgreedToShareApp")
                    ud.setInteger(
                        maxUpdatedEvents - complianceUpdatedEventsReward - 1 - 1,
                        forKey: "userNumUpdatedEvents")

                    updateEventClosure(false)
                }))
                alert.addAction(UIAlertAction(title: "Close", style: .Cancel, handler: nil))
                vc.presentViewController(alert, animated: true, completion: nil)
            }
            else
            {
                justAskForUpgradeToFullVersion()
            }
        }
    }

    //----------------------------------------------------------------------------------------------
}



