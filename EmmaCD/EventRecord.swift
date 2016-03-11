import Viewmorphic


class EventRecord : NSObject, NSCoding
{
    enum RepeatType : Int
    {
        case DontRepeat
        case EveryWeek
        case EveryMonth
        case EveryYear
    }

    var id:String!
    var title:String!
    var dateTime:NSDate!
    var useTime:Bool!
    var backgroundRecord:BackgroundRecord!
    var timeStyleRecord:TimeStyleRecord!
    var titleStyleRecord:TitleStyleRecord!
    var frameStyleRecord:FrameStyleRecord!
    var tags:[String]!
    var repeatType:RepeatType!
    var notification:Bool!

    var isDemo:Bool!

    //----------------------------------------------------------------------------------------------

    override init ()
    {
        super.init()
    }

    //----------------------------------------------------------------------------------------------

    func encodeWithCoder (aCoder:NSCoder)
    {
        aCoder.encodeObject(self.id, forKey: "id")
        aCoder.encodeObject(self.title, forKey: "title")
        aCoder.encodeObject(self.dateTime, forKey: "dateTime")
        aCoder.encodeObject(self.useTime, forKey: "useTime")
        aCoder.encodeObject(self.backgroundRecord, forKey: "backgroundRecord")
        aCoder.encodeObject(self.timeStyleRecord, forKey: "timeStyleRecord")
        aCoder.encodeObject(self.titleStyleRecord, forKey: "titleStyleRecord")
        aCoder.encodeObject(self.frameStyleRecord, forKey: "frameStyleRecord")
        aCoder.encodeObject(self.tags, forKey: "tags")
        aCoder.encodeObject(self.repeatType.rawValue, forKey: "repeatType")
        aCoder.encodeObject(self.notification, forKey: "notification")

        aCoder.encodeObject(self.isDemo, forKey: "isDemo")
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    required init? (coder aDecoder:NSCoder)
    {
        self.id = aDecoder.decodeObjectForKey("id") as! String
        self.title = aDecoder.decodeObjectForKey("title") as! String
        self.dateTime = aDecoder.decodeObjectForKey("dateTime") as! NSDate
        self.useTime = aDecoder.decodeObjectForKey("useTime") as! Bool
        self.backgroundRecord = aDecoder.decodeObjectForKey("backgroundRecord") as? BackgroundRecord
        self.timeStyleRecord = aDecoder.decodeObjectForKey("timeStyleRecord") as? TimeStyleRecord
        self.titleStyleRecord = aDecoder.decodeObjectForKey("titleStyleRecord") as? TitleStyleRecord
        self.frameStyleRecord = aDecoder.decodeObjectForKey("frameStyleRecord") as? FrameStyleRecord
        self.tags = aDecoder.decodeObjectForKey("tags") as? [String]
        self.repeatType = RepeatType(rawValue: aDecoder.decodeObjectForKey("repeatType") as! Int)
        self.notification = aDecoder.decodeObjectForKey("notification") as! Bool

        self.isDemo = aDecoder.decodeObjectForKey("isDemo") as? Bool

        super.init()
    }

    //----------------------------------------------------------------------------------------------

    var meta:JSON
    {
        get {
            let eventDirURL =
                AppConfiguration.eventsDirURL.URLByAppendingPathComponent(
                    self.id, isDirectory: true)
            let metaURL = eventDirURL.URLByAppendingPathComponent("M.json")

            let fm = NSFileManager()
            if fm.fileExistsAtPath(metaURL.path!)
            {
                let metaData = NSData(contentsOfURL: metaURL)!
                return JSON(data: metaData)
            }
            else
            {
                return JSON([String: AnyObject]())
            }
        }

        set {
            let eventDirURL =
                AppConfiguration.eventsDirURL.URLByAppendingPathComponent(
                    self.id, isDirectory: true)
            let metaURL = eventDirURL.URLByAppendingPathComponent("M.json")

            let metaData = try! newValue.rawData()
            metaData.writeToURL(metaURL, atomically: true)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func backgroundOpeningImageForContainerSize (containerSize:CGSize? = nil) -> UIImage
    {
        if let backgroundCustomPictureRecord =
           self.backgroundRecord as? BackgroundCustomPictureRecord
        {
            return backgroundCustomPictureRecord.picture
        }
        else if let backgroundOverlayRecord = self.backgroundRecord as? BackgroundOverlayRecord
        {
            let image:UIImage
            let blenderType = backgroundOverlayRecord.blenderType
            if !(blenderType == .Multiply ||
                 blenderType == .HardLight)
            {
                if let brightness = backgroundOverlayRecord.inputImageBrightness
                {
                    image =
                        NodeSystem.filteredImageFromImage(
                            backgroundOverlayRecord.inputImage, filterType: .Brightness,
                            settings: ["brightness": brightness])
                }
                else
                {
                    image = backgroundOverlayRecord.inputImage
                }
            }
            else
            {
                image =
                    UIImage.solidColorImageOfSize(
                        CGSize(width: 16.0, height: 16.0), color: UIColor.blackColor())
            }
            return image
        }
        else if let backgroundPictureRecord = self.backgroundRecord as? BackgroundPictureRecord
        {
            if let containerSize = containerSize
            {
                return subAlignedImage(
                    backgroundPictureRecord.picture, forAspectSize: containerSize,
                    withCode: backgroundPictureRecord.subAlign)
            }
            else
            {
                return backgroundPictureRecord.picture
            }
        }
        else if let backgroundVideoRecord = self.backgroundRecord as? BackgroundVideoRecord
        {
            if let containerSize = containerSize
            {
                return subAlignedImage(
                    backgroundVideoRecord.snapshot, forAspectSize: containerSize,
                    withCode: backgroundVideoRecord.subAlign)
            }
            else
            {
                return backgroundVideoRecord.snapshot
            }
        }
        else
        {
            return AppConfiguration.defaultPicture
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func hasAnyVideos () -> Bool
    {
        if !(self.backgroundRecord is BackgroundOverlayRecord) &&
           !(self.backgroundRecord is BackgroundVideoRecord)
        {
            return false
        }
        else
        {
            return true
        }
    }

    //----------------------------------------------------------------------------------------------

    class func saveEventRecord (eventRecord:EventRecord)
    {
        let id = eventRecord.id
        let fm = NSFileManager()
        let eventDirURL =
            AppConfiguration.eventsDirURL.URLByAppendingPathComponent(id, isDirectory: true)
        try! fm.createDirectoryAtURL(
            eventDirURL, withIntermediateDirectories: true, attributes: nil)
        let eventRecordFileURL = eventDirURL.URLByAppendingPathComponent("E")
        NSKeyedArchiver.archiveRootObject(eventRecord, toFile: eventRecordFileURL.path!)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    class func deleteEventWithID (id:String)
    {
        let eventDirURL =
            AppConfiguration.eventsDirURL.URLByAppendingPathComponent(id, isDirectory: true)
        NSFileManager.clearDir(eventDirURL, includingDirItself: true)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    class func collectTagsFromEvents (unique unique:Bool) -> [String]
    {
        var eventsTags = [String]()

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
                    let eventRecord =
                        NSKeyedUnarchiver.unarchiveObjectWithFile(eventRecordFileURL.path!)
                    if let eventRecord = eventRecord as? EventRecord
                    {
                        if let tags = eventRecord.tags
                        {
                            eventsTags.appendContentsOf(tags)
                        }
                    }
                }
            }
        }

        if unique
        {
            eventsTags = Array(Set(eventsTags))
        }

        return eventsTags
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    class func createDemoEvents ()
    {
        let calendar = NSCalendar.currentCalendar()
        let currDate = NSDate()
        let currYear = calendar.component(.Year, fromDate: currDate)

        var bmData:NSData!

        let demoEvent2 = {
            let tarURL = NSBundle.mainBundle().URLForResource("DemoEvent2.tar", withExtension: nil)!
            let tarData = NSData(contentsOfURL: tarURL)
            let fm = NSFileManager()
            let nsFilesDict = try! fm.readFilesWithTarData(tarData, progress: nil) as NSDictionary
            let filesDict = nsFilesDict as! [String: NSData]

            let eventID = NSProcessInfo.processInfo().globallyUniqueString
            let eventDirURL =
            AppConfiguration.eventsDirURL.URLByAppendingPathComponent(
                eventID, isDirectory: true)
            try! fm.createDirectoryAtURL(
                eventDirURL, withIntermediateDirectories: true, attributes: nil)
            let eventRecordURL = eventDirURL.URLByAppendingPathComponent("E")
            let eventMetaURL = eventDirURL.URLByAppendingPathComponent("M.json")
            filesDict["./2/E"]!.writeToURL(eventRecordURL, atomically: true)
            bmData = filesDict["./2/M.json"]!
            bmData.writeToURL(eventMetaURL, atomically: true)
            let eventRecord =
            NSKeyedUnarchiver.unarchiveObjectWithFile(eventRecordURL.path!) as! EventRecord
            eventRecord.id = eventID
            eventRecord.isDemo = true

            let dateComps = NSDateComponents()
            dateComps.calendar = calendar
            dateComps.year = currYear
            dateComps.month = 12
            dateComps.day = 25
            var dec25 = dateComps.date!
            if currDate.compare(dec25) == .OrderedDescending
            {
                let dateCompsNext = NSDateComponents()
                dateCompsNext.month = 12
                dateCompsNext.day = 25
                dec25 =
                    calendar.nextDateAfterDate(
                        currDate, matchingComponents: dateCompsNext,
                        options: .MatchNextTimePreservingSmallerUnits)!
            }
            eventRecord.dateTime = dec25
            eventRecord.timeStyleRecord.timeStyle = .S8p

            EventRecord.saveEventRecord(eventRecord)
        }
        demoEvent2()

        let demoEvent0 = {
            let tarURL = NSBundle.mainBundle().URLForResource("DemoEvent0.tar", withExtension: nil)!
            let tarData = NSData(contentsOfURL: tarURL)
            let fm = NSFileManager()
            let nsFilesDict = try! fm.readFilesWithTarData(tarData, progress: nil) as NSDictionary
            let filesDict = nsFilesDict as! [String: NSData]

            let eventID = NSProcessInfo.processInfo().globallyUniqueString
            let eventDirURL =
                AppConfiguration.eventsDirURL.URLByAppendingPathComponent(
                    eventID, isDirectory: true)
            try! fm.createDirectoryAtURL(
                eventDirURL, withIntermediateDirectories: true, attributes: nil)
            let eventRecordURL = eventDirURL.URLByAppendingPathComponent("E")
            let eventVideoURL = eventDirURL.URLByAppendingPathComponent("V.mp4")
            let eventMetaURL = eventDirURL.URLByAppendingPathComponent("M.json")
            filesDict["./0/E"]!.writeToURL(eventRecordURL, atomically: true)
            filesDict["./0/V.mp4"]!.writeToURL(eventVideoURL, atomically: true)
            bmData.writeToURL(eventMetaURL, atomically: true)
            let eventRecord =
                NSKeyedUnarchiver.unarchiveObjectWithFile(eventRecordURL.path!) as! EventRecord
            eventRecord.id = eventID
            eventRecord.isDemo = true

            eventRecord.title = "My Event"

            eventRecord.dateTime =
                calendar.dateByAddingUnit(.Day, value: 1, toDate: currDate, options: [])!
            eventRecord.useTime = true

            let overlayRecord = eventRecord.backgroundRecord as! BackgroundOverlayRecord
            overlayRecord.videoRelPath = "\(eventID)/V.mp4"
            let inputImage = UIImage(named: "DemoEvent0Image")!
            overlayRecord.inputImage = inputImage
            overlayRecord.snapshot = inputImage

            EventRecord.saveEventRecord(eventRecord)
        }
        demoEvent0()

        let demoEvent1 = {
            let tarURL = NSBundle.mainBundle().URLForResource("DemoEvent1.tar", withExtension: nil)!
            let tarData = NSData(contentsOfURL: tarURL)
            let fm = NSFileManager()
            let nsFilesDict = try! fm.readFilesWithTarData(tarData, progress: nil) as NSDictionary
            let filesDict = nsFilesDict as! [String: NSData]

            let eventID = NSProcessInfo.processInfo().globallyUniqueString
            let eventDirURL =
                AppConfiguration.eventsDirURL.URLByAppendingPathComponent(
                    eventID, isDirectory: true)
            try! fm.createDirectoryAtURL(
                eventDirURL, withIntermediateDirectories: true, attributes: nil)
            let eventRecordURL = eventDirURL.URLByAppendingPathComponent("E")
            let eventMetaURL = eventDirURL.URLByAppendingPathComponent("M.json")
            filesDict["./1/E"]!.writeToURL(eventRecordURL, atomically: true)
            filesDict["./1/M.json"]!.writeToURL(eventMetaURL, atomically: true)
            let eventRecord =
                NSKeyedUnarchiver.unarchiveObjectWithFile(eventRecordURL.path!) as! EventRecord
            eventRecord.id = eventID
            eventRecord.isDemo = true

            let dateComps = NSDateComponents()
            dateComps.calendar = calendar
            dateComps.year = currYear
            dateComps.month = 7
            dateComps.day = 15
            var jul15 = dateComps.date!
            if currDate.compare(jul15) == .OrderedDescending
            {
                let dateCompsNext = NSDateComponents()
                dateCompsNext.month = 7
                dateCompsNext.day = 15
                jul15 =
                    calendar.nextDateAfterDate(
                        currDate, matchingComponents: dateCompsNext,
                        options: .MatchNextTimePreservingSmallerUnits)!
            }
            eventRecord.dateTime = jul15

            EventRecord.saveEventRecord(eventRecord)
        }
        demoEvent1()
    }

    //----------------------------------------------------------------------------------------------
}



