class TimeStyleRecord : NSObject, NSCoding
{
    enum TimeStyle : Int
    {
        case Y_Mo_D_H_Mi_S
        case Mo_D_H_Mi_S
        case D3p_H_Mi_S
        case D4p_H_Mi_S
        case D3p_S
        case D4p_S
        case S6p
        case S8p
        case D
        case Breaths
        case Heartbeats6p
        case Heartbeats8p
    }

    var timeStyle:TimeStyle!
    var digitStyleID:Int!
    private var _snapshot:UIImage!
    var snapshot:UIImage!
    {
        get {
            if self._snapshot == nil
            {
                self._snapshot = UIImage(data: self.snapshotData)!
            }
            return self._snapshot
        }

        set {
            assert(newValue != nil)
            self.snapshotData = UIImagePNGRepresentation(newValue)
            self._snapshot = nil
        }
    }
    private var snapshotData:NSData!

    private static let labelFont = UIFont(name: "EuphemiaUCAS-Bold", size: 10.0)
    private static let labelFontBreaths = UIFont(name: "EuphemiaUCAS-Italic", size: 14.0)
    private static let labelFontHeartbeats = UIFont(name: "EuphemiaUCAS-Italic", size: 14.0)

    //----------------------------------------------------------------------------------------------

    override init ()
    {
        super.init()
    }

    //----------------------------------------------------------------------------------------------

    func encodeWithCoder (aCoder:NSCoder)
    {
        aCoder.encodeObject(self.timeStyle.rawValue, forKey: "timeStyle")
        aCoder.encodeObject(self.digitStyleID, forKey: "digitStyleID")
        aCoder.encodeObject(self.snapshotData, forKey: "snapshotData")
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    required init? (coder aDecoder:NSCoder)
    {
        self.timeStyle = TimeStyle(rawValue: aDecoder.decodeObjectForKey("timeStyle") as! Int)
        self.digitStyleID = aDecoder.decodeObjectForKey("digitStyleID") as! Int
        self.snapshotData = aDecoder.decodeObjectForKey("snapshotData") as! NSData

        super.init()
    }

    //----------------------------------------------------------------------------------------------

    class func setLabelAppearanceForDigitsView (digitsView:DigitsView, timeStyle:TimeStyle)
    {
        switch timeStyle
        {
        case .Breaths, .Heartbeats6p, .Heartbeats8p:
            digitsView.labelAlpha = 1.0
            digitsView.labelShadowColor = UIColor.whiteColor()
            digitsView.labelShadowAlpha = 1.0
            digitsView.labelShadowRadius = 5.0
        default:
            digitsView.labelAlpha = 0.75
            digitsView.labelShadowColor = UIColor.blackColor()
            digitsView.labelShadowAlpha = 0.66
            digitsView.labelShadowRadius = 2.0
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    class func digitsViewGroupsForTimeStyle (
        timeStyle:TimeStyle, fromDate:NSDate, toDate:NSDate) ->
            [DigitsView.Group]
    {
        let labelYears = DigitsView.Group.Label(text: "YEARS", font: self.labelFont)
        let labelMonths = DigitsView.Group.Label(text: "MONTHS", font: self.labelFont)
        let labelDays = DigitsView.Group.Label(text: "DAYS", font: self.labelFont)
        let labelHours = DigitsView.Group.Label(text: "HOURS", font: self.labelFont)
        let labelMinutes = DigitsView.Group.Label(text: "MINUTES", font: self.labelFont)
        let labelSeconds = DigitsView.Group.Label(text: "SECONDS", font: self.labelFont)
        let labelBreaths =
            DigitsView.Group.Label(
                text: "Breaths", font: self.labelFontBreaths,
                color: UIColor(red: 0.12, green: 0.12, blue: 1.0, alpha: 1.0))
        let labelHeartbeats =
            DigitsView.Group.Label(
                text: "Heartbeats", font: self.labelFontHeartbeats,
                color: UIColor(red: 1.0, green: 0.12, blue: 0.12, alpha: 1.0))

        var groups:[DigitsView.Group] = []
        switch timeStyle
        {
        case .Y_Mo_D_H_Mi_S:
            let dateComps =
                NSCalendar.currentCalendar().components(
                    [.Year, .Month, .Day, .Hour, .Minute, .Second],
                    fromDate: fromDate,
                    toDate: toDate,
                    options: [])
            let y = dateComps.year
            let mo = dateComps.month
            let d = dateComps.day
            let h = dateComps.hour
            let mi = dateComps.minute
            let s = dateComps.second

            groups.append(DigitsView.Group(numPlaces: 2, value: y, label: labelYears))
            groups.append(DigitsView.Group(numPlaces: 2, value: mo, label: labelMonths))
            groups.append(DigitsView.Group(numPlaces: 2, value: d, label: labelDays))
            groups.append(DigitsView.Group(numPlaces: 2, value: h, label: labelHours))
            groups.append(DigitsView.Group(numPlaces: 2, value: mi, label: labelMinutes))
            groups.append(DigitsView.Group(numPlaces: 2, value: s, label: labelSeconds))
        case .Mo_D_H_Mi_S:
            let dateComps =
                NSCalendar.currentCalendar().components(
                    [.Month, .Day, .Hour, .Minute, .Second],
                    fromDate: fromDate,
                    toDate: toDate,
                    options: [])
            let mo = dateComps.month
            let d = dateComps.day
            let h = dateComps.hour
            let mi = dateComps.minute
            let s = dateComps.second

            groups.append(DigitsView.Group(numPlaces: 3, value: mo, label: labelMonths))
            groups.append(DigitsView.Group(numPlaces: 2, value: d, label: labelDays))
            groups.append(DigitsView.Group(numPlaces: 2, value: h, label: labelHours))
            groups.append(DigitsView.Group(numPlaces: 2, value: mi, label: labelMinutes))
            groups.append(DigitsView.Group(numPlaces: 2, value: s, label: labelSeconds))
        case .D3p_H_Mi_S:
            let dateComps =
                NSCalendar.currentCalendar().components(
                    [.Day, .Hour, .Minute, .Second],
                    fromDate: fromDate,
                    toDate: toDate,
                    options: [])
            let d = dateComps.day
            let h = dateComps.hour
            let mi = dateComps.minute
            let s = dateComps.second

            groups.append(DigitsView.Group(numPlaces: 3, value: d, label: labelDays))
            groups.append(DigitsView.Group(numPlaces: 2, value: h, label: labelHours))
            groups.append(DigitsView.Group(numPlaces: 2, value: mi, label: labelMinutes))
            groups.append(DigitsView.Group(numPlaces: 2, value: s, label: labelSeconds))
        case .D4p_H_Mi_S:
            let dateComps =
                NSCalendar.currentCalendar().components(
                    [.Day, .Hour, .Minute, .Second],
                    fromDate: fromDate,
                    toDate: toDate,
                    options: [])
            let d = dateComps.day
            let h = dateComps.hour
            let mi = dateComps.minute
            let s = dateComps.second

            groups.append(DigitsView.Group(numPlaces: 4, value: d, label: labelDays))
            groups.append(DigitsView.Group(numPlaces: 2, value: h, label: labelHours))
            groups.append(DigitsView.Group(numPlaces: 2, value: mi, label: labelMinutes))
            groups.append(DigitsView.Group(numPlaces: 2, value: s, label: labelSeconds))
        case .D3p_S:
            let dateComps =
                NSCalendar.currentCalendar().components(
                    [.Second],
                    fromDate: fromDate,
                    toDate: toDate,
                    options: [])
            let d = Int(floor(Double(abs(dateComps.second))/86400.0))
            var s = abs(dateComps.second) % 86400
            if fromDate.compare(toDate) == .OrderedAscending
            {
                s++
            }

            groups.append(DigitsView.Group(numPlaces: 3, value: d, label: labelDays))
            groups.append(DigitsView.Group(numPlaces: 5, value: s, label: labelSeconds))
        case .D4p_S:
            let dateComps =
                NSCalendar.currentCalendar().components(
                    [.Second],
                    fromDate: fromDate,
                    toDate: toDate,
                    options: [])
            let d = Int(floor(Double(abs(dateComps.second))/86400.0))
            var s = abs(dateComps.second) % 86400
            if fromDate.compare(toDate) == .OrderedAscending
            {
                s++
            }

            groups.append(DigitsView.Group(numPlaces: 4, value: d, label: labelDays))
            groups.append(DigitsView.Group(numPlaces: 5, value: s, label: labelSeconds))
        case .S6p:
            let dateComps =
                NSCalendar.currentCalendar().components(
                    [.Second],
                    fromDate: fromDate,
                    toDate: toDate,
                    options: [])
            let s = dateComps.second

            groups.append(DigitsView.Group(numPlaces: 6, value: s, label: labelSeconds))
        case .S8p:
            let dateComps =
                NSCalendar.currentCalendar().components(
                    [.Second],
                    fromDate: fromDate,
                    toDate: toDate,
                    options: [])
            let s = dateComps.second

            groups.append(DigitsView.Group(numPlaces: 8, value: s, label: labelSeconds))
        case .D:
            let dateComps =
                NSCalendar.currentCalendar().components(
                    [.Day],
                    fromDate: fromDate,
                    toDate: toDate,
                    options: [])
            var d = dateComps.day
            if fromDate.compare(toDate) == .OrderedAscending
            {
                d++
            }

            groups.append(DigitsView.Group(numPlaces: 4, value: d, label: labelDays))
        case .Breaths:
            let s = toDate.timeIntervalSinceDate(fromDate)
            var numBreaths = Int(floor(abs(s)/AppConfiguration.breathDuration))
            if fromDate.compare(toDate) == .OrderedAscending
            {
                numBreaths++
            }

            groups.append(DigitsView.Group(
                numPlaces: 6, value: numBreaths, label: labelBreaths))
        case .Heartbeats6p:
            let s = toDate.timeIntervalSinceDate(fromDate)
            var numHeartbeats = Int(floor(abs(s)/AppConfiguration.heartbeatDuration))
            if fromDate.compare(toDate) == .OrderedAscending
            {
                numHeartbeats++
            }

            groups.append(DigitsView.Group(
                numPlaces: 6, value: numHeartbeats, label: labelHeartbeats))
        case .Heartbeats8p:
            let s = toDate.timeIntervalSinceDate(fromDate)
            var numHeartbeats = Int(floor(abs(s)/AppConfiguration.heartbeatDuration))
            if fromDate.compare(toDate) == .OrderedAscending
            {
                numHeartbeats++
            }

            groups.append(DigitsView.Group(
                numPlaces: 8, value: numHeartbeats, label: labelHeartbeats))
        }
        return groups
    }

    //----------------------------------------------------------------------------------------------
}



