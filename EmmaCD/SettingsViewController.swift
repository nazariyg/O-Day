import EventKit
import MessageUI


//--------------------------------------------------------------------------------------------------

protocol SettingsViewControllerDelegate : class
{
    func provideInputDataForSettingsViewController () -> [String: AnyObject]
    func settingsViewControllerDidChangeEvents (deletedOrChangedEventIDs:[String])
}

//--------------------------------------------------------------------------------------------------


class SettingsViewController : StaticDataTableViewController,
                               CalendarEventImporterViewControllerDelegate,
                               MFMailComposeViewControllerDelegate,
                               UINavigationControllerDelegate
{
    weak var delegate:SettingsViewControllerDelegate!
    private var inputData:[String: AnyObject]!

    @IBOutlet private weak var upgradeAppRow:UITableViewCell!
    @IBOutlet private weak var restorePurchasesRow:UITableViewCell!
    @IBOutlet private weak var autoDeletePassedEventsSW:UISwitch!
    @IBOutlet private weak var addEventsFromCalendarRow:UITableViewCell!
    @IBOutlet private weak var deleteDemoEventsRow:UITableViewCell!
    @IBOutlet private weak var shareRow:UITableViewCell!
    @IBOutlet private weak var rateReviewRow:UITableViewCell!
    @IBOutlet private weak var sendFeedbackRow:UITableViewCell!

    private let upgradeAppRowIP = NSIndexPath(forRow: 0, inSection: 0)
    private let restorePurchasesRowIP = NSIndexPath(forRow: 1, inSection: 0)

    private let addEventsFromCalendarRowIP = NSIndexPath(forRow: 0, inSection: 2)
    private let deleteDemoEventsRowIP = NSIndexPath(forRow: 1, inSection: 2)

    private let shareRowIP = NSIndexPath(forRow: 0, inSection: 3)
    private let rateReviewRowIP = NSIndexPath(forRow: 1, inSection: 3)
    private let sendFeedbackRowIP = NSIndexPath(forRow: 2, inSection: 3)

    private let eventStore = EKEventStore()

    //----------------------------------------------------------------------------------------------

    override func viewDidLoad ()
    {
        super.viewDidLoad()

        self.inputData = self.delegate.provideInputDataForSettingsViewController()

        self.title = "Settings & Misc"

        self.view.tintColor = AppConfiguration.tintColor
        self.navigationController!.navigationBar.tintColor = AppConfiguration.tintColor

        self.navigationController!.navigationBar.barStyle = .BlackTranslucent
        self.navigationController!.navigationBar.barTintColor = AppConfiguration.bluishColor
        self.navigationController!.navigationBar.titleTextAttributes =
            [NSForegroundColorAttributeName: AppConfiguration.tintColor]

        self.tableView.backgroundColor = AppConfiguration.bluishColorSemiDarker
        self.tableView.separatorStyle = .None

        self.hideSectionsWithHiddenRows = true
        self.insertTableViewRowAnimation = .Fade
        self.deleteTableViewRowAnimation = .Fade

        let ud = NSUserDefaults.standardUserDefaults()

        self.autoDeletePassedEventsSW.on = ud.boolForKey("autoDeletePassedEvents")

        for cell in [
            self.upgradeAppRow,
            self.restorePurchasesRow,
            self.addEventsFromCalendarRow,
            self.deleteDemoEventsRow,
            self.shareRow,
            self.rateReviewRow,
            self.sendFeedbackRow]
        {
            let bgColorView = UIView()
            bgColorView.backgroundColor = AppConfiguration.bluishColor
            cell.selectedBackgroundView = bgColorView
        }

        let events = self.inputData["events"] as! [EventRecord]
        var hasAnyDemoEvents = false
        for eventRecord in events
        {
            if let isDemo = eventRecord.isDemo where isDemo
            {
                hasAnyDemoEvents = true
                break
            }
        }
        if !hasAnyDemoEvents
        {
            self.cell(self.deleteDemoEventsRow, setHidden: true)
        }

        if ud.boolForKey("appIsFullVersion")
        {
            self.cell(self.upgradeAppRow, setHidden: true)

            if appD().iapProductIDs().count == 1
            {
                self.cell(self.restorePurchasesRow, setHidden: true)
            }
        }

        self.reloadDataAnimated(false)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func didReceiveMemoryWarning ()
    {
        super.didReceiveMemoryWarning()

        //
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func tableView (tableView:UITableView, didSelectRowAtIndexPath indexPath:NSIndexPath)
    {
        if indexPath == self.upgradeAppRowIP
        {
            appD().upgradeAppToFullVersion()

            self.dismiss()
        }
        else if indexPath == self.restorePurchasesRowIP
        {
            appD().restorePurchases()

            self.dismiss()
        }
        else if indexPath == self.addEventsFromCalendarRowIP
        {
            authorizeCalendarUsageIfNeededWithSuccessClosure(
                self.eventStore, successClosure: {
                    let sb = UIStoryboard(name: "CalendarEventImporter", bundle: nil)
                    let parentVC = sb.instantiateInitialViewController()!
                    let calendarEventImporterVC =
                        parentVC.childViewControllers.first! as! CalendarEventImporterViewController
                    calendarEventImporterVC.delegate = self

                    self.presentViewController(parentVC, animated: true, completion: nil)
                },
                failureClosure: nil)
        }
        else if indexPath == self.deleteDemoEventsRowIP
        {
            var deletedEventIDs = [String]()
            let events = self.inputData["events"] as! [EventRecord]
            for eventRecord in events
            {
                if let isDemo = eventRecord.isDemo where isDemo
                {
                    EventRecord.deleteEventWithID(eventRecord.id)
                    deletedEventIDs.append(eventRecord.id)
                }
            }
            if !deletedEventIDs.isEmpty
            {
                self.delegate.settingsViewControllerDidChangeEvents(deletedEventIDs)
            }

            self.cell(self.deleteDemoEventsRow, setHidden: true)
            self.reloadDataAnimated(true)

            let hud = MBProgressHUD.showHUDAddedTo(self.parentViewController!.view, animated: true)
            hud.removeFromSuperViewOnHide = true
            hud.mode = .Text
            hud.labelText = "Complete"
            hud.labelFont = UIFont.systemFontOfSize(14.0)
            hud.hide(true, afterDelay: 1.5)

            return
        }
        else if indexPath == self.shareRowIP
        {
            appD().shareAppOnFacebook()
        }
        else if indexPath == self.rateReviewRowIP
        {
            appD().rateReview()
        }
        else if indexPath == self.sendFeedbackRowIP
        {
            if MFMailComposeViewController.canSendMail()
            {
                let body = "\n\n\n\n\n" + systemInformationString()

                let mailComposer = MFMailComposeViewController()
                mailComposer.mailComposeDelegate = self

                mailComposer.setSubject("\(AppConfiguration.appName) Feedback")
                mailComposer.setToRecipients([AppConfiguration.appFeedbackEmail])
                mailComposer.setMessageBody(body, isHTML: false)

                self.presentViewController(mailComposer, animated: true, completion: nil)
            }
        }

        self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func provideInputDataForCalendarEventImporterViewController () -> [String: AnyObject]
    {
        var data = [String: AnyObject]()
        data["eventStore"] = self.eventStore
        return data
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func calendarEventImporterViewControllerDidAddEvents ()
    {
        self.delegate.settingsViewControllerDidChangeEvents([])
        self.dismiss()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func mailComposeController (
        controller:MFMailComposeViewController, didFinishWithResult result:MFMailComposeResult,
        error:NSError?)
    {
        self.dismissViewControllerAnimated(true, completion: nil)

        if result == MFMailComposeResultSent
        {
            self.dismiss()
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func dismiss ()
    {
        self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }

    //----------------------------------------------------------------------------------------------

    @IBAction private func autoDeletePassedEventsSWAction ()
    {
        let ud = NSUserDefaults.standardUserDefaults()
        ud.setBool(self.autoDeletePassedEventsSW.on, forKey: "autoDeletePassedEvents")
    }
    
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction private func doneBNAction (sender:AnyObject)
    {
        self.dismiss()
    }

    //----------------------------------------------------------------------------------------------
}



