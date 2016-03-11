import UIKit


//--------------------------------------------------------------------------------------------------

protocol EventEditViewControllerInputOutput : class
{
    func provideInputDataForEventEditViewController () -> [String: AnyObject]
    func eventEditViewControllerWillDeleteEventWithID (eventID:String)
    func acceptOutputDataFromEventEditViewController (data:[String: AnyObject])
    func eventEditViewControllerDidCancel ()
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

class WhiteTextDatePicker : UIDatePicker
{
    private var changed = false

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func addSubview (view:UIView)
    {
        if !changed
        {
            changed = true
            let varName = "textColor"
            self.setValue(UIColor.whiteColor(), forKey: varName)
        }
        super.addSubview(view)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
}

//--------------------------------------------------------------------------------------------------


class EventEditViewController : StaticDataTableViewController,
                                BackgroundChooserViewControllerOutput,
                                TimeStyleChooserViewControllerInputOutput,
                                TitleStyleChooserViewControllerInputOutput,
                                FrameStyleChooserViewControllerInputOutput,
                                EventEditTagsChooserViewControllerInputOutput
{
    weak var inputOutputDelegate:EventEditViewControllerInputOutput!
    private var inputEventRecord:EventRecord!

    private var currBackgroundRecord:BackgroundRecord!
    private var currTimeStyleRecord:TimeStyleRecord!
    private var currTitleStyleRecord:TitleStyleRecord!
    private var currFrameStyleRecord:FrameStyleRecord!
    private var currTags:[String]!

    @IBOutlet private weak var titleRow:UITableViewCell!
    @IBOutlet private weak var titleTF:UITextField!
    @IBOutlet private weak var dateRow:UITableViewCell!
    @IBOutlet private weak var datePickerRow:UITableViewCell!
    @IBOutlet private weak var datePicker:UIDatePicker!
    @IBOutlet private weak var timeRow:UITableViewCell!
    @IBOutlet private weak var timeSW:UISwitch!
    @IBOutlet private weak var timeRowDetailLB:UILabel!
    @IBOutlet private weak var timePickerRow:UITableViewCell!
    @IBOutlet private weak var timePicker:UIDatePicker!
    @IBOutlet private weak var backgroundSnapshotView:UIImageView!
    @IBOutlet private weak var timeStyleSnapshotView:UIImageView!
    @IBOutlet private weak var titleStyleSnapshotView: UIImageView!
    @IBOutlet private weak var frameStyleSnapshotView:UIImageView!
    @IBOutlet private weak var repeatSW:UISwitch!
    @IBOutlet private weak var everyWeekRow:UITableViewCell!
    @IBOutlet private weak var everyMonthRow:UITableViewCell!
    @IBOutlet private weak var everyYearRow:UITableViewCell!
    @IBOutlet private weak var notificationSW:UISwitch!
    @IBOutlet private weak var deleteEventRow:UITableViewCell!

    @IBOutlet private weak var backgroundRow:UIView!
    @IBOutlet private weak var timeStyleRow:UIView!
    @IBOutlet private weak var titleStyleRow:UIView!
    @IBOutlet private weak var frameStyleRow:UIView!
    @IBOutlet private weak var backgroundRowPrompt:UILabel!
    @IBOutlet private weak var timeStyleRowPrompt:UILabel!
    @IBOutlet private weak var titleStyleRowPrompt:UILabel!
    @IBOutlet private weak var frameStyleRowPrompt:UILabel!
    @IBOutlet private weak var tagsRowLB:UILabel!

    private var dateFormatter:NSDateFormatter!
    private var timeFormatter:NSDateFormatter!
    private var dateTimeFormatter:NSDateFormatter!
    private let dateRowIP = NSIndexPath(forRow: 1, inSection: 0)
    private let datePickerRowIP = NSIndexPath(forRow: 2, inSection: 0)
    private let dateTimePickerRowAnimationDuration = 0.4
    private let dateTimePickerRowDisplayScale = 0.9
    private let dateTimePickerRowOtherScale = 0.88
    private var datePickerRowFullHeight:Double!
    private let timeRowIP = NSIndexPath(forRow: 3, inSection: 0)
    private let timePickerRowIP = NSIndexPath(forRow: 4, inSection: 0)
    private var timePickerRowFullHeight:Double!

    private let tagsRowIP = NSIndexPath(forRow: 0, inSection: 1)

    private let backgroundRowIP = NSIndexPath(forRow: 0, inSection: 2)

    private let timeStyleRowIP = NSIndexPath(forRow: 0, inSection: 3)

    private let titleStyleRowIP = NSIndexPath(forRow: 0, inSection: 4)

    private let frameStyleRowIP = NSIndexPath(forRow: 0, inSection: 5)

    private let repeatSectionIndex = 6
    private let repeatRadioGroupFirstRowIndex = 1
    private var repeatRadioGroup:[UITableViewCell]!
    private var repeatRadioGroupIPs:[NSIndexPath]!

    private let deleteEventRowIP = NSIndexPath(forRow: 0, inSection: 8)

    private var someSnapshotsNeedDisplay = false

    //----------------------------------------------------------------------------------------------

    override func viewDidLoad ()
    {
        super.viewDidLoad()

        let inputData = self.inputOutputDelegate.provideInputDataForEventEditViewController()
        self.inputEventRecord = inputData["eventRecord"] as? EventRecord

        if let isDemo = self.inputEventRecord?.isDemo where isDemo
        {
            self.dismiss()
        }

        self.view.tintColor = AppConfiguration.tintColor
        self.navigationController!.navigationBar.tintColor = AppConfiguration.tintColor

        self.navigationController!.navigationBar.barStyle = .BlackTranslucent
        self.navigationController!.navigationBar.barTintColor = AppConfiguration.bluishColor
        self.navigationController!.navigationBar.titleTextAttributes =
            [NSForegroundColorAttributeName: AppConfiguration.tintColor]

        self.tableView.backgroundColor = AppConfiguration.bluishColorSemiDarker
        self.tableView.separatorStyle = .None

        self.titleTF.keyboardAppearance = .Dark

        let color = UIColor.clearColor()
        self.backgroundRow.backgroundColor = color
        self.timeStyleRow.backgroundColor = color
        self.titleStyleRow.backgroundColor = color
        self.frameStyleRow.backgroundColor = color

        self.repeatRadioGroup = [
            self.everyWeekRow,
            self.everyMonthRow,
            self.everyYearRow,
        ]
        self.repeatRadioGroupIPs = (0..<self.repeatRadioGroup.count).map {
            return NSIndexPath(
                forRow: self.repeatRadioGroupFirstRowIndex + $0,
                inSection: self.repeatSectionIndex)
        }
        for cell in self.repeatRadioGroup
        {
            let backgroundView = UIView(frame: cell.bounds)
            backgroundView.backgroundColor = AppConfiguration.bluishColor
            cell.selectedBackgroundView = backgroundView
        }

        self.dateFormatter = NSDateFormatter()
        self.dateFormatter.dateStyle = .LongStyle
        self.timeFormatter = NSDateFormatter()
        self.timeFormatter.timeStyle = .ShortStyle
        self.dateTimeFormatter = NSDateFormatter()
        self.dateTimeFormatter.dateStyle = .MediumStyle
        self.dateTimeFormatter.timeStyle = .ShortStyle

        self.timeRowDetailLB.text = ""
        self.timeRowDetailLB.textColor = AppConfiguration.tintColor

        if self.inputEventRecord == nil
        {
            // Adding an event.

            self.title = "New event"

            self.datePicker.date =
                NSCalendar.currentCalendar().dateByAddingUnit(
                    .Day, value: 1, toDate: NSDate(), options: [])!

            on_main_with_delay(0.25) {
                self.titleTF.becomeFirstResponder()
            }
        }
        else
        {
            // Editing an event.

            self.title = "Edit event"
            self.navigationItem.rightBarButtonItem =
                UIBarButtonItem(
                    barButtonSystemItem: .Done, target: self, action: "addOrDoneNavBNAction")

            self.titleTF.text = self.inputEventRecord.title ?? AppConfiguration.defaultTitle

            if let dateTime = self.inputEventRecord.dateTime
            {
                self.datePicker.date = dateTime

                if let useTime = self.inputEventRecord.useTime where useTime
                {
                    self.timeSW.on = true

                    self.timePicker.date = dateTime
                    self.timePickerValueChangedAction()
                }
            }
            else
            {
                self.datePicker.date = NSDate()
            }

            self.currBackgroundRecord = self.inputEventRecord.backgroundRecord
            self.currTimeStyleRecord = self.inputEventRecord.timeStyleRecord
            self.currTitleStyleRecord = self.inputEventRecord.titleStyleRecord
            self.currFrameStyleRecord = self.inputEventRecord.frameStyleRecord

            self.currTags = self.inputEventRecord.tags

            if let repeatType = self.inputEventRecord.repeatType where repeatType != .DontRepeat
            {
                self.repeatSW.on = true

                for radioRow in self.repeatRadioGroup
                {
                    radioRow.accessoryType = .None
                }
                var checkmarkIndex:Int!
                switch repeatType
                {
                case .EveryWeek:
                    checkmarkIndex = 0
                case .EveryMonth:
                    checkmarkIndex = 1
                case .EveryYear:
                    checkmarkIndex = 2
                default:
                    break
                }
                self.repeatRadioGroup[checkmarkIndex].accessoryType = .Checkmark
            }

            self.notificationSW.on = self.inputEventRecord.notification ?? false

            if let currBackgroundRecord = self.currBackgroundRecord
            {
                self.backgroundRowPrompt.hidden = true
                self.backgroundSnapshotView.image = currBackgroundRecord.snapshot
            }
            if let currTimeStyleRecord = self.currTimeStyleRecord
            {
                self.timeStyleRowPrompt.hidden = true
                self.timeStyleSnapshotView.image = currTimeStyleRecord.snapshot
            }
            if let currTitleStyleRecord = self.currTitleStyleRecord
            {
                self.titleStyleRowPrompt.hidden = true
                self.titleStyleSnapshotView.image = currTitleStyleRecord.snapshot
            }
            if let currFrameStyleRecord = self.currFrameStyleRecord
            {
                self.frameStyleRowPrompt.hidden = true
                self.frameStyleSnapshotView.image = currFrameStyleRecord.snapshot
            }
        }

        self.updateTagsLB()

        self.datePickerValueChangedAction()

        self.datePickerRowFullHeight =
            Double(self.tableView(self.tableView, heightForRowAtIndexPath: self.datePickerRowIP))
        self.timePickerRowFullHeight =
            Double(self.tableView(self.tableView, heightForRowAtIndexPath: self.timePickerRowIP))

        self.hideSectionsWithHiddenRows = true
        self.insertTableViewRowAnimation = .Fade
        self.deleteTableViewRowAnimation = .Fade
        self.cell(self.datePickerRow, setHeight: 0.0)
        self.cell(self.timeRow, setHeight: 0.0)
        self.cell(self.timePickerRow, setHeight: 0.0)
        if !self.repeatSW.on
        {
            self.cells(self.repeatRadioGroup, setHidden: true)
        }
        if self.inputEventRecord == nil
        {
            self.cell(self.deleteEventRow, setHidden: true)
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

    override func preferredStatusBarStyle () -> UIStatusBarStyle
    {
        return .LightContent
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func tableView (
        tableView:UITableView, willDisplayHeaderView view:UIView, forSection section:Int)
    {
        let header = view as! UITableViewHeaderFooterView

        header.textLabel?.textColor = UIColor.whiteColor()

        let tag = 424242
        let alreadyAdded = header.viewWithTag(tag) != nil
        if !alreadyAdded
        {
            var separatorFrame = header.bounds
            separatorFrame.size.height = 1.0
            let separator = UIView(frame: separatorFrame)
            separator.tag = tag
            separator.backgroundColor =
                UIColor(red: 204.0/255, green: 102.0/255, blue: 255.0/255, alpha: 0.42)
            header.addSubview(separator)
        }
        let separator = header.viewWithTag(tag)!
        if header.textLabel?.text != " "
        {
            separator.frame.origin.y = header.bounds.height - 1.0
        }
        else
        {
            separator.frame.origin.y = header.bounds.height*0.66
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func tableView (tableView:UITableView, didSelectRowAtIndexPath indexPath:NSIndexPath)
    {
        if self.titleTF.isFirstResponder()
        {
            self.titleTF.resignFirstResponder()
            return
        }

        if indexPath == self.dateRowIP
        {
            let displayScale = CGFloat(self.dateTimePickerRowDisplayScale)
            let otherScale = CGFloat(self.dateTimePickerRowOtherScale)
            if !self.isRowShownAtIndexPath(self.datePickerRowIP)
            {
                self.cell(self.datePickerRow, setHeight: CGFloat(self.datePickerRowFullHeight))
                self.cell(self.timeRow, setHeight: self.tableView.rowHeight)
                self.datePickerRow.contentView.alpha = 0.0
                self.datePickerRow.contentView.transform =
                    CGAffineTransformMakeScale(otherScale, otherScale)
                appD().ignoringInteractionEvents.begin()
                UIView.animateWithDuration(
                    self.dateTimePickerRowAnimationDuration, delay: 0.0, options: .CurveEaseInOut,
                    animations: {
                        self.reloadDataAnimated(true)
                        self.datePickerRow.contentView.alpha = 1.0
                        self.datePickerRow.contentView.transform =
                            CGAffineTransformMakeScale(displayScale, displayScale)
                    },
                    completion: { _ in
                        self.timeSWActionInternal(true)
                        appD().ignoringInteractionEvents.end()
                    })
            }
            else
            {
                self.cell(self.datePickerRow, setHeight: 0.0)
                self.cell(self.timeRow, setHeight: 0.0)
                self.cell(self.timePickerRow, setHeight: 0.0)
                appD().ignoringInteractionEvents.begin()
                UIView.animateWithDuration(
                    self.dateTimePickerRowAnimationDuration, delay: 0.0, options: .CurveEaseInOut,
                    animations: {
                        self.reloadDataAnimated(true)
                        self.datePickerRow.contentView.alpha = 0.0
                        self.datePickerRow.contentView.transform =
                            CGAffineTransformMakeScale(otherScale, otherScale)
                    },
                    completion: { _ in
                        appD().ignoringInteractionEvents.end()
                    })
            }
        }
        else if indexPath == self.backgroundRowIP
        {
            let sb = UIStoryboard(name: "BackgroundChooser", bundle: nil)
            let backgroundChooserVC =
                sb.instantiateInitialViewController() as! BackgroundChooserViewController
            backgroundChooserVC.inputOutputDelegate = self
            self.presentViewController(backgroundChooserVC, animated: true, completion: nil)
        }
        else if indexPath == self.timeStyleRowIP
        {
            let sb = UIStoryboard(name: "TimeStyleChooser", bundle: nil)
            let timeStyleChooserVC =
                sb.instantiateInitialViewController() as! TimeStyleChooserViewController
            timeStyleChooserVC.inputOutputDelegate = self
            self.presentViewController(timeStyleChooserVC, animated: true, completion: nil)
        }
        else if indexPath == self.titleStyleRowIP
        {
            let sb = UIStoryboard(name: "TitleStyleChooser", bundle: nil)
            let titleStyleChooserVC =
                sb.instantiateInitialViewController() as! TitleStyleChooserViewController
            titleStyleChooserVC.inputOutputDelegate = self
            self.presentViewController(titleStyleChooserVC, animated: true, completion: nil)
        }
        else if indexPath == self.frameStyleRowIP
        {
            let sb = UIStoryboard(name: "FrameStyleChooser", bundle: nil)
            let frameStyleChooserVC =
                sb.instantiateInitialViewController() as! FrameStyleChooserViewController
            frameStyleChooserVC.inputOutputDelegate = self
            self.presentViewController(frameStyleChooserVC, animated: true, completion: nil)
        }
        else if indexPath == self.tagsRowIP
        {
            let sb = UIStoryboard(name: "EventEditTagsChooser", bundle: nil)
            let parentVC = sb.instantiateInitialViewController()!
            let tagsVC = parentVC.childViewControllers.first! as! EventEditTagsChooserViewController
            tagsVC.inputOutputDelegate = self
            self.presentViewController(parentVC, animated: true, completion: nil)
        }
        else if self.repeatRadioGroupIPs.contains(indexPath)
        {
            for radioRow in self.repeatRadioGroup
            {
                radioRow.accessoryType = .None
            }
            let checkmarkIndex = indexPath.row - self.repeatRadioGroupFirstRowIndex
            self.repeatRadioGroup[checkmarkIndex].accessoryType = .Checkmark
        }
        else if indexPath == self.deleteEventRowIP
        {
            let alert =
                UIAlertController(
                    title: nil,
                    message: "Are you sure you want to delete this event?",
                    preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "No", style: .Cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "Yes", style: .Default, handler: { _ in
                self.deleteThisEvent()
            }))
            on_main() {
                self.presentViewController(alert, animated: true, completion: nil)
            }
        }

        self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func deleteThisEvent ()
    {
        let id = self.inputEventRecord.id

        self.inputOutputDelegate.eventEditViewControllerWillDeleteEventWithID(id)

        EventRecord.deleteEventWithID(id)

        var outputData = [String: AnyObject]()
        outputData["deletedEventID"] = id
        self.inputOutputDelegate.acceptOutputDataFromEventEditViewController(outputData)

        self.dismiss()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func dismiss ()
    {
        self.view.endEditing(true)

        self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)

        AppConfiguration.clearTempDir()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func timeSWActionInternal (isInternal:Bool)
    {
        let displayScale = CGFloat(self.dateTimePickerRowDisplayScale)
        let otherScale = CGFloat(self.dateTimePickerRowOtherScale)
        if self.timeSW.on && !self.isRowShownAtIndexPath(self.timePickerRowIP)
        {
            self.cell(self.timePickerRow, setHeight: CGFloat(self.timePickerRowFullHeight))
            self.timePickerRow.contentView.alpha = 0.0
            self.timePickerRow.contentView.transform =
                CGAffineTransformMakeScale(otherScale, otherScale)
            appD().ignoringInteractionEvents.begin()
            UIView.animateWithDuration(
                self.dateTimePickerRowAnimationDuration, delay: 0.0, options: .CurveEaseInOut,
                animations: {
                    self.reloadDataAnimated(true)
                    self.timePickerRow.contentView.alpha = 1.0
                    self.timePickerRow.contentView.transform =
                        CGAffineTransformMakeScale(displayScale, displayScale)
                },
                completion: { _ in
                    let scrollPos:UITableViewScrollPosition = !isInternal ? .Middle : .None
                    self.tableView.scrollToRowAtIndexPath(
                        self.timePickerRowIP, atScrollPosition: scrollPos, animated: true)
                    appD().ignoringInteractionEvents.end()
                })

            self.timePickerValueChangedAction()
        }
        else if self.isRowShownAtIndexPath(self.timePickerRowIP)
        {
            self.cell(self.timePickerRow, setHeight: 0.0)
            appD().ignoringInteractionEvents.begin()
            UIView.animateWithDuration(
                self.dateTimePickerRowAnimationDuration, delay: 0.0, options: .CurveEaseInOut,
                animations: {
                    self.reloadDataAnimated(true)
                    self.timePickerRow.contentView.alpha = 0.0
                    self.timePickerRow.contentView.transform =
                        CGAffineTransformMakeScale(otherScale, otherScale)
                },
                completion: { _ in
                    appD().ignoringInteractionEvents.end()
                })

            self.timeRowDetailLB.text = ""
        }

        self.datePickerValueChangedAction()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func isRowShownAtIndexPath (indexPath:NSIndexPath) -> Bool
    {
        return self.tableView(self.tableView, heightForRowAtIndexPath: indexPath) != 0.0
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func makeDateTime (date date:NSDate, time:NSDate) -> NSDate?
    {
        let calendar = NSCalendar.currentCalendar()

        let dateComps = calendar.components([.Year, .Month, .Day], fromDate: date)
        let timeComps = calendar.components([.Hour, .Minute], fromDate: time)

        let dateTimeComps = NSDateComponents()
        dateTimeComps.calendar = calendar
        dateTimeComps.year = dateComps.year
        dateTimeComps.month = dateComps.month
        dateTimeComps.day = dateComps.day
        dateTimeComps.hour = timeComps.hour
        dateTimeComps.minute = timeComps.minute
        return dateTimeComps.date
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func provideInputDataForBackgroundChooserViewController () -> [String: AnyObject]
    {
        var data = [String: AnyObject]()
        if let backgroundOverlayRecord = self.currBackgroundRecord as? BackgroundOverlayRecord
        {
            data["backgroundOverlayRecord"] = backgroundOverlayRecord
        }
        else if let backgroundCustomPictureRecord =
                self.currBackgroundRecord as? BackgroundCustomPictureRecord
        {
            data["backgroundCustomPictureRecord"] = backgroundCustomPictureRecord
        }
        return data
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func acceptOutputDataFromBackgroundChooserViewController (data:[String: AnyObject])
    {
        self.currBackgroundRecord = data["backgroundRecord"] as! BackgroundRecord
        self.someSnapshotsNeedDisplay = true
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func provideInputDataForTimeStyleChooserViewController () -> [String: AnyObject]
    {
        var data = [String: AnyObject]()
        if let currBackgroundRecord = self.currBackgroundRecord
        {
            data["backgroundImage"] = currBackgroundRecord.snapshot
        }
        data["snapshotSize"] = NSValue(CGSize: self.timeStyleSnapshotView.bounds.size)
        return data
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func acceptOutputDataFromTimeStyleChooserViewController (data:[String: AnyObject])
    {
        self.currTimeStyleRecord = data["timeStyleRecord"] as! TimeStyleRecord
        self.someSnapshotsNeedDisplay = true
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func provideInputDataForTitleStyleChooserViewController () -> [String: AnyObject]
    {
        var data = [String: AnyObject]()
        if let title = self.titleTF.text where !title.isEmpty
        {
            data["title"] = title
        }
        if let currBackgroundRecord = self.currBackgroundRecord
        {
            data["backgroundImage"] = currBackgroundRecord.snapshot
        }
        data["snapshotSize"] = NSValue(CGSize: self.titleStyleSnapshotView.bounds.size)
        return data
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func acceptOutputDataFromTitleStyleChooserViewController (data: [String: AnyObject])
    {
        self.currTitleStyleRecord = data["titleStyleRecord"] as! TitleStyleRecord
        self.someSnapshotsNeedDisplay = true
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func provideInputDataForFrameStyleChooserViewController () -> [String: AnyObject]
    {
        var data = [String: AnyObject]()
        if let title = self.titleTF.text where !title.isEmpty
        {
            data["title"] = title
        }
        if let currBackgroundRecord = self.currBackgroundRecord
        {
            data["backgroundImage"] = currBackgroundRecord.snapshot
        }
        if let titleStyleRecord = self.currTitleStyleRecord
        {
            data["titleStyleRecord"] = titleStyleRecord
        }
        return data
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func acceptOutputDataFromFrameStyleChooserViewController (data:[String: AnyObject])
    {
        self.currFrameStyleRecord = data["frameStyleRecord"] as? FrameStyleRecord
        self.someSnapshotsNeedDisplay = true
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func viewWillAppear (animated:Bool)
    {
        super.viewWillAppear(animated)

        self.updateTagsLB()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func viewDidAppear (animated:Bool)
    {
        super.viewDidAppear(animated)

        if !self.someSnapshotsNeedDisplay
        {
            return
        }
        self.someSnapshotsNeedDisplay = false

        if let currBackgroundRecord = self.currBackgroundRecord
        {
            self.backgroundRowPrompt.hidden = true

            if currBackgroundRecord.snapshot !== self.backgroundSnapshotView.image
            {
                UIView.transitionWithView(
                    self.backgroundSnapshotView, duration: 0.2, options: .TransitionCrossDissolve,
                    animations: {
                        self.backgroundSnapshotView.image = currBackgroundRecord.snapshot
                    },
                    completion: nil)
            }
        }

        if let currTimeStyleRecord = self.currTimeStyleRecord
        {
            self.timeStyleRowPrompt.hidden = true

            if currTimeStyleRecord.snapshot !== self.timeStyleSnapshotView.image
            {
                UIView.transitionWithView(
                    self.timeStyleSnapshotView, duration: 0.2, options: .TransitionCrossDissolve,
                    animations: {
                        self.timeStyleSnapshotView.image = currTimeStyleRecord.snapshot
                    },
                    completion: nil)
            }
        }

        if let currTitleStyleRecord = self.currTitleStyleRecord
        {
            self.titleStyleRowPrompt.hidden = true

            if currTitleStyleRecord.snapshot !== self.titleStyleSnapshotView.image
            {
                UIView.transitionWithView(
                    self.titleStyleSnapshotView, duration: 0.2, options: .TransitionCrossDissolve,
                    animations: {
                        self.titleStyleSnapshotView.image = currTitleStyleRecord.snapshot
                    },
                    completion: nil)
            }
        }

        if let currFrameStyleRecord = self.currFrameStyleRecord
        {
            self.frameStyleRowPrompt.hidden = true

            if currFrameStyleRecord.snapshot !== self.frameStyleSnapshotView.image
            {
                UIView.transitionWithView(
                    self.frameStyleSnapshotView, duration: 0.2, options: .TransitionCrossDissolve,
                    animations: {
                        self.frameStyleSnapshotView.image = currFrameStyleRecord.snapshot
                    },
                    completion: nil)
            }
        }
        else
        {
            self.frameStyleRowPrompt.hidden = false
            self.frameStyleSnapshotView.image = nil
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func updateTagsLB ()
    {
        if let tags = self.currTags where !tags.isEmpty
        {
            let sortedTags = tags.sort({ $0.compare($1) == .OrderedAscending })
            let joinedTags = sortedTags.map({ $0.uppercaseString }).joinWithSeparator(", ")

            self.tagsRowLB.font = UIFont.systemFontOfSize(16.0)
            self.tagsRowLB.text = joinedTags
            self.tagsRowLB.alpha = 1.0
        }
        else
        {
            self.tagsRowLB.font = UIFont.systemFontOfSize(14.0)
            self.tagsRowLB.text = "Tap to customize."
            self.tagsRowLB.alpha = 0.33
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func provideInputDataForEventEditTagsChooserViewController () -> [String: AnyObject]
    {
        var data = [String: AnyObject]()
        data["tags"] = self.currTags
        return data
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func acceptOutputDataFromEventEditTagsChooserViewController (data:[String: AnyObject])
    {
        self.currTags = data["tags"] as? [String]
    }

    //----------------------------------------------------------------------------------------------

    @IBAction private func addOrDoneNavBNAction ()
    {
        let eventRecord = EventRecord()

        var title = AppConfiguration.defaultTitle
        if let currTitle = self.titleTF.text where !currTitle.isEmpty
        {
            title = currTitle
        }
        eventRecord.title =
            title.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())

        if !self.timeSW.on
        {
            let date = self.datePicker.date
            let calendar = NSCalendar.currentCalendar()
            let time =
                calendar.dateBySettingHour(0, minute: 0, second: 0, ofDate: date, options: [])
            if time == nil
            {
                doOKAlertWithTitle(
                    "Invalid date",
                    message: "Please try changing date values.")

                return
            }
            eventRecord.dateTime =
                self.makeDateTime(
                    date: date,
                    time: time!)

            eventRecord.useTime = false
        }
        else
        {
            let dateTime =
                self.makeDateTime(
                    date: self.datePicker.date,
                    time: self.timePicker.date)
            if dateTime == nil
            {
                doOKAlertWithTitle(
                    "Invalid date or time",
                    message: "Please try changing date/time values.")

                return
            }
            eventRecord.dateTime = dateTime

            eventRecord.useTime = true
        }

        eventRecord.backgroundRecord = self.currBackgroundRecord

        eventRecord.timeStyleRecord = self.currTimeStyleRecord
        var doAdjustNumDigitPlaces = true
        if let inputEventRecord = self.inputEventRecord
        {
            if inputEventRecord.dateTime?.compare(eventRecord.dateTime) == .OrderedSame &&
               inputEventRecord.timeStyleRecord?.timeStyle == eventRecord.timeStyleRecord?.timeStyle
            {
                doAdjustNumDigitPlaces = false
            }
        }
        if let timeStyleRecord = eventRecord.timeStyleRecord where doAdjustNumDigitPlaces
        {
            let currDate = NSDate()
            if timeStyleRecord.timeStyle == .D3p_H_Mi_S ||
               timeStyleRecord.timeStyle == .D4p_H_Mi_S
            {
                let dateComps =
                    NSCalendar.currentCalendar().components(
                        [.Day, .Hour, .Minute, .Second],
                        fromDate: currDate,
                        toDate: eventRecord.dateTime,
                        options: [])
                let digits = String(abs(dateComps.day)).characters.map { String($0) }
                if digits.count <= 3
                {
                    timeStyleRecord.timeStyle = .D3p_H_Mi_S
                }
                else
                {
                    timeStyleRecord.timeStyle = .D4p_H_Mi_S
                }
            }
            else if timeStyleRecord.timeStyle == .D3p_S ||
                    timeStyleRecord.timeStyle == .D4p_S
            {
                let dateComps =
                    NSCalendar.currentCalendar().components(
                        [.Second],
                        fromDate: currDate,
                        toDate: eventRecord.dateTime,
                        options: [])
                let d = Int(floor(Double(abs(dateComps.second))/86400.0))
                let digits = String(d).characters.map { String($0) }
                if digits.count <= 3
                {
                    timeStyleRecord.timeStyle = .D3p_S
                }
                else
                {
                    timeStyleRecord.timeStyle = .D4p_S
                }
            }
            else if timeStyleRecord.timeStyle == .S6p ||
                    timeStyleRecord.timeStyle == .S8p
            {
                let dateComps =
                    NSCalendar.currentCalendar().components(
                        [.Second],
                        fromDate: currDate,
                        toDate: eventRecord.dateTime,
                        options: [])
                let digits = String(abs(dateComps.second)).characters.map { String($0) }
                if digits.count <= 6
                {
                    timeStyleRecord.timeStyle = .S6p
                }
                else
                {
                    timeStyleRecord.timeStyle = .S8p
                }
            }
            else if timeStyleRecord.timeStyle == .Heartbeats6p ||
                    timeStyleRecord.timeStyle == .Heartbeats8p
            {
                let s = eventRecord.dateTime.timeIntervalSinceDate(currDate)
                var numHeartbeats = Int(floor(abs(s)/AppConfiguration.heartbeatDuration))
                if currDate.compare(eventRecord.dateTime) == .OrderedAscending
                {
                    numHeartbeats++
                }
                let digits = String(numHeartbeats).characters.map { String($0) }
                if digits.count <= 6
                {
                    timeStyleRecord.timeStyle = .Heartbeats6p
                }
                else
                {
                    timeStyleRecord.timeStyle = .Heartbeats8p
                }
            }
        }

        eventRecord.titleStyleRecord = self.currTitleStyleRecord

        eventRecord.frameStyleRecord = self.currFrameStyleRecord

        eventRecord.tags = self.currTags

        eventRecord.repeatType = .DontRepeat
        if self.repeatSW.on
        {
            for (i, radioRow) in self.repeatRadioGroup.enumerate()
            {
                if radioRow.accessoryType == .Checkmark
                {
                    switch i
                    {
                    case 0:
                        eventRecord.repeatType = .EveryWeek
                    case 1:
                        eventRecord.repeatType = .EveryMonth
                    case 2:
                        eventRecord.repeatType = .EveryYear
                    default:
                        break
                    }

                    break
                }
            }
        }

        eventRecord.notification = self.notificationSW.on

        let id:String
        if self.inputEventRecord == nil
        {
            // Make an ID for the new event.
            id = NSProcessInfo.processInfo().globallyUniqueString
        }
        else
        {
            id = self.inputEventRecord.id
        }
        eventRecord.id = id

        let updateEventClosure = { (dismiss:Bool) in
            let fm = NSFileManager()

            let eventDirURL =
                AppConfiguration.eventsDirURL.URLByAppendingPathComponent(id, isDirectory: true)
            try! fm.createDirectoryAtURL(
                eventDirURL, withIntermediateDirectories: true, attributes: nil)

            let videoURL = eventDirURL.URLByAppendingPathComponent("V.mp4")
            if let backgroundOverlayRecord =
               eventRecord.backgroundRecord as? BackgroundOverlayRecord
            {
                if backgroundOverlayRecord.videoRelPathIsTemp
                {
                    // Move the video file.
                    if fm.fileExistsAtPath(videoURL.path!)
                    {
                        try! fm.removeItemAtURL(videoURL)
                    }
                    try! fm.moveItemAtURL(backgroundOverlayRecord.videoURL, toURL: videoURL)
                    backgroundOverlayRecord.videoRelPath =
                        AppConfiguration.dropEventsDirURLFromURL(videoURL)
                    backgroundOverlayRecord.videoRelPathIsTemp = false
                }
            }
            else if let backgroundVideoRecord =
                    eventRecord.backgroundRecord as? BackgroundVideoRecord
            {
                if backgroundVideoRecord.videoRelPathIsTemp
                {
                    // Move the video file.
                    if fm.fileExistsAtPath(videoURL.path!)
                    {
                        try! fm.removeItemAtURL(videoURL)
                    }
                    try! fm.moveItemAtURL(backgroundVideoRecord.videoURL, toURL: videoURL)
                    backgroundVideoRecord.videoRelPath =
                        AppConfiguration.dropEventsDirURLFromURL(videoURL)
                    backgroundVideoRecord.videoRelPathIsTemp = false
                }
            }
            else if fm.fileExistsAtPath(videoURL.path!)
            {
                try! fm.removeItemAtURL(videoURL)
            }

            let eventRecordFileURL = eventDirURL.URLByAppendingPathComponent("E")
            NSKeyedArchiver.archiveRootObject(eventRecord, toFile: eventRecordFileURL.path!)

            var outputData = [String: AnyObject]()
            outputData["changedEventID"] = id
            outputData["eventRecord"] = eventRecord
            self.inputOutputDelegate.acceptOutputDataFromEventEditViewController(outputData)

            if dismiss
            {
                self.dismiss()
            }
        }

        // IAP
        appD().shouldUpdateEventWithEventRecord(eventRecord, yesClosure: updateEventClosure)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction private func cancelNavBarButtonAction ()
    {
        self.inputOutputDelegate.eventEditViewControllerDidCancel()
        
        self.dismiss()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction private func datePickerValueChangedAction ()
    {
        if !self.timeSW.on
        {
            self.dateRow.detailTextLabel!.text =
                self.dateFormatter.stringFromDate(self.datePicker.date)
        }
        else
        {
            let dateTime = self.makeDateTime(date: self.datePicker.date, time: self.timePicker.date)
            if dateTime != nil
            {
                self.dateRow.detailTextLabel!.text =
                    self.dateTimeFormatter.stringFromDate(dateTime!)
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction private func timeSWAction ()
    {
        self.timeSWActionInternal(false)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction private func timePickerValueChangedAction ()
    {
        self.timeRowDetailLB.text = self.timeFormatter.stringFromDate(self.timePicker.date)
        self.datePickerValueChangedAction()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction private func repeatSWAction ()
    {
        if self.repeatSW.on
        {
            CATransaction.begin()
            CATransaction.setCompletionBlock {
                self.tableView.scrollToRowAtIndexPath(
                    self.repeatRadioGroupIPs.last!, atScrollPosition: .None, animated: true)
            }

            self.cells(self.repeatRadioGroup, setHidden: false)
            self.reloadDataAnimated(true)

            CATransaction.commit()
        }
        else
        {
            self.cells(self.repeatRadioGroup, setHidden: true)
            self.reloadDataAnimated(true)
        }
    }

    //----------------------------------------------------------------------------------------------
}



