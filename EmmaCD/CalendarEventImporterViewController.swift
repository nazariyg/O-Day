import EventKit


//--------------------------------------------------------------------------------------------------

protocol CalendarEventImporterViewControllerDelegate : class
{
    func provideInputDataForCalendarEventImporterViewController () -> [String: AnyObject]
    func calendarEventImporterViewControllerDidAddEvents ()
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

private class CalendarEventRecord
{
    let title:String
    let date:NSDate
    let formattedDate:String
    var isSelected = false

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    init (title:String, date:NSDate, formattedDate:String)
    {
        self.title = title
        self.date = date
        self.formattedDate = formattedDate
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
}

//--------------------------------------------------------------------------------------------------


class CalendarEventImporterViewController : UITableViewController
{
    weak var delegate:CalendarEventImporterViewControllerDelegate!

    private var events = [CalendarEventRecord]()

    //----------------------------------------------------------------------------------------------

    override func viewDidLoad ()
    {
        super.viewDidLoad()

        let inputData = self.delegate.provideInputDataForCalendarEventImporterViewController()
        let eventStore = inputData["eventStore"] as! EKEventStore

        self.title = "Calendar events"

        self.view.backgroundColor = AppConfiguration.bluishColorSemiDarker
        self.view.tintColor = AppConfiguration.tintColor

        self.navigationController!.navigationBar.barStyle = .BlackTranslucent
        self.navigationController!.navigationBar.barTintColor = AppConfiguration.bluishColor
        self.navigationController!.navigationBar.titleTextAttributes =
            [NSForegroundColorAttributeName: AppConfiguration.tintColor]
        self.navigationController!.navigationBar.tintColor = AppConfiguration.tintColor

        let currDate = NSDate()
        let calendar = NSCalendar.currentCalendar()
        let eventsSpanStartDate = currDate
        let eventsSpanEndDate =
            calendar.dateByAddingUnit(.Year, value: 10, toDate: currDate, options: [])!
        let predicate =
            eventStore.predicateForEventsWithStartDate(
                eventsSpanStartDate, endDate: eventsSpanEndDate, calendars: nil)
        var calendarEvents = eventStore.eventsMatchingPredicate(predicate)
        calendarEvents.sortInPlace({ $0.startDate.compare($1.startDate) == .OrderedAscending })
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateStyle = .MediumStyle
        for calendarEvent in calendarEvents
        {
            let title = calendarEvent.title
            let date = calendarEvent.startDate
            let formattedDate = dateFormatter.stringFromDate(date)

            let calendarEventRecord =
                CalendarEventRecord(title: title, date: date, formattedDate: formattedDate)
            self.events.append(calendarEventRecord)
        }

        if self.events.isEmpty
        {
            on_main() {
                doOKAlertWithTitle(nil, message: "No events found", okHandler: {
                    self.dismiss()
                })
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

    override func numberOfSectionsInTableView (tableView:UITableView) -> Int
    {
        return 1
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func tableView (tableView:UITableView, numberOfRowsInSection section:Int) -> Int
    {
        return self.events.count
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func tableView (
        tableView:UITableView, cellForRowAtIndexPath indexPath:NSIndexPath) ->
            UITableViewCell
    {
        let calendarEventRecord = self.events[indexPath.row]

        let cell = self.tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)

        cell.textLabel?.text = calendarEventRecord.title
        cell.detailTextLabel?.text = calendarEventRecord.formattedDate

        cell.accessoryType = calendarEventRecord.isSelected ? .Checkmark : .None

        let bgColorView = UIView()
        bgColorView.backgroundColor = AppConfiguration.bluishColor
        cell.selectedBackgroundView = bgColorView

        return cell
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func tableView (tableView:UITableView, didSelectRowAtIndexPath indexPath:NSIndexPath)
    {
        let calendarEventRecord = self.events[indexPath.row]
        calendarEventRecord.isSelected = !calendarEventRecord.isSelected
        
        if let cell = self.tableView.cellForRowAtIndexPath(indexPath)
        {
            cell.accessoryType = calendarEventRecord.isSelected ? .Checkmark : .None
        }

        self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func dismiss ()
    {
        self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }

    //----------------------------------------------------------------------------------------------

    @IBAction func cancelBNAction (sender:AnyObject)
    {
        self.dismiss()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction func doneBNAction (sender:AnyObject)
    {
        // IAP
        let ud = NSUserDefaults.standardUserDefaults()
        if !ud.boolForKey("appIsFullVersion")
        {
            let message = "This feature is only available in the Full Version."
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .Alert)
            let iapTitle = "Upgrade to the Full Version"
            alert.addAction(UIAlertAction(title: iapTitle, style: .Default, handler: { _ in
                appD().upgradeAppToFullVersion()
            }))
            alert.addAction(UIAlertAction(title: "Close", style: .Cancel, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)

            return
        }

        var didAddAnyEvents = false
        let fm = NSFileManager()
        for calendarEventRecord in self.events
        {
            if calendarEventRecord.isSelected
            {
                let eventID = NSProcessInfo.processInfo().globallyUniqueString
                let eventDirURL =
                    AppConfiguration.eventsDirURL.URLByAppendingPathComponent(
                        eventID, isDirectory: true)
                try! fm.createDirectoryAtURL(
                    eventDirURL, withIntermediateDirectories: true, attributes: nil)
                let eventRecordURL = eventDirURL.URLByAppendingPathComponent("E")

                let eventRecord = EventRecord()
                eventRecord.id = eventID
                eventRecord.title = calendarEventRecord.title
                eventRecord.dateTime = calendarEventRecord.date
                eventRecord.useTime = true
                eventRecord.repeatType = .DontRepeat
                eventRecord.notification = false
                NSKeyedArchiver.archiveRootObject(eventRecord, toFile: eventRecordURL.path!)

                didAddAnyEvents = true
            }
        }

        if didAddAnyEvents
        {
            self.delegate.calendarEventImporterViewControllerDidAddEvents()
        }

        self.dismiss()
    }

    //----------------------------------------------------------------------------------------------
}



