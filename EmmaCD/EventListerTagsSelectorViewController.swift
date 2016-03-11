//--------------------------------------------------------------------------------------------------

protocol EventListerTagsSelectorViewControllerDelegate : class
{
    func currentlySelectedTagForEventListerTagsSelectorViewController () -> String?
    func eventListerTagsSelectorViewControllerDidSelectTag (anyTags anyTags:Bool, tag:String?)
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

private class ListedTagRecord
{
    let anyTags:Bool
    var tagName:String!
    var numOccurrences:Int!

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    init (anyTags:Bool, tagName:String!, numOccurrences:Int!)
    {
        self.anyTags = anyTags
        self.tagName = tagName
        self.numOccurrences = numOccurrences
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
}

//--------------------------------------------------------------------------------------------------


class EventListerTagsSelectorViewController : UITableViewController
{
    weak var delegate:EventListerTagsSelectorViewControllerDelegate!

    private var currSelectedTag:String!
    private var tags:[ListedTagRecord]!

    //----------------------------------------------------------------------------------------------

    override func viewDidLoad ()
    {
        super.viewDidLoad()

        self.currSelectedTag =
            self.delegate.currentlySelectedTagForEventListerTagsSelectorViewController()

        self.view.tintColor = AppConfiguration.tintColor
        self.view.backgroundColor = AppConfiguration.bluishColor

        let allAssignedTags =
            EventRecord.collectTagsFromEvents(unique: false).map { $0.lowercaseString }

        var allTagsUnique = AppConfiguration.builtInEventTags.map { $0.lowercaseString }
        allTagsUnique.appendContentsOf(allAssignedTags)
        allTagsUnique = Array(Set(allTagsUnique))

        allTagsUnique.sortInPlace({ $0.compare($1) == .OrderedAscending })

        self.tags = [ListedTagRecord]()

        self.tags.append(ListedTagRecord(anyTags: true, tagName: nil, numOccurrences: nil))

        for uniqueTag in allTagsUnique
        {
            var numOccurrences = 0
            for assignedTag in allAssignedTags
            {
                if assignedTag == uniqueTag
                {
                    numOccurrences++
                }
            }

            self.tags.append(
                ListedTagRecord(
                    anyTags: false, tagName: uniqueTag.uppercaseString,
                    numOccurrences: numOccurrences))
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
        return self.tags.count
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func tableView (
        tableView:UITableView, cellForRowAtIndexPath indexPath:NSIndexPath) ->
            UITableViewCell
    {
        let cell = self.tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)

        cell.contentView.backgroundColor = UIColor.clearColor()
        cell.backgroundColor = UIColor.clearColor()

        let bgColorView = UIView()
        bgColorView.backgroundColor = UIColor.whiteColor().colorWithAlphaComponent(0.1)
        cell.selectedBackgroundView = bgColorView

        if cell.contentView.viewWithTag(1) == nil
        {
            let highlightView = UIView(frame: cell.contentView.bounds)
            highlightView.tag = 1
            highlightView.backgroundColor = UIColor.whiteColor().colorWithAlphaComponent(0.1)
            cell.contentView.addSubview(highlightView)
        }
        cell.contentView.viewWithTag(1)!.hidden = true

        let listedTagRecord = self.tags[indexPath.row]
        if listedTagRecord.anyTags
        {
            cell.textLabel?.font = UIFont.boldSystemFontOfSize(16.0)
            cell.textLabel?.text = "All events".uppercaseString

            cell.detailTextLabel?.text = ""

            if self.currSelectedTag == nil
            {
                cell.contentView.viewWithTag(1)!.hidden = false
            }
        }
        else
        {
            cell.textLabel?.font = UIFont.systemFontOfSize(16.0)
            cell.textLabel?.text = listedTagRecord.tagName

            cell.detailTextLabel?.text = String(listedTagRecord.numOccurrences)

            if let currSelectedTag = self.currSelectedTag
            {
                if listedTagRecord.tagName.lowercaseString == currSelectedTag.lowercaseString
                {
                    cell.contentView.viewWithTag(1)!.hidden = false
                }
            }
        }

        return cell
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func tableView (tableView:UITableView, didSelectRowAtIndexPath indexPath:NSIndexPath)
    {
        let listedTagRecord = self.tags[indexPath.row]

        if let numOccurrences = listedTagRecord.numOccurrences where numOccurrences == 0
        {
            self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
            if let cell = self.tableView.cellForRowAtIndexPath(indexPath)
            {
                let noEventsLB = UILabel(frame: cell.bounds)
                noEventsLB.textColor = UIColor.whiteColor().colorWithAlphaComponent(0.75)
                noEventsLB.textAlignment = .Center
                noEventsLB.font = UIFont.systemFontOfSize(14.0)
                noEventsLB.text = "No events with this tag."
                noEventsLB.alpha = 0.0
                cell.addSubview(noEventsLB)

                appD().ignoringInteractionEvents.begin()
                UIView.animateWithDuration(0.2) {
                    cell.contentView.alpha = 0.0
                    noEventsLB.alpha = 1.0

                    on_main_with_delay(1.0) {
                        UIView.animateWithDuration(0.2, animations: {
                            cell.contentView.alpha = 1.0
                            noEventsLB.alpha = 0.0
                        },
                        completion: { _ in
                            appD().ignoringInteractionEvents.end()
                            noEventsLB.removeFromSuperview()
                        })
                    }
                }
            }
            return
        }

        if listedTagRecord.anyTags
        {
            self.delegate.eventListerTagsSelectorViewControllerDidSelectTag(
                anyTags: true, tag: nil)
        }
        else
        {
            let tag = listedTagRecord.tagName.lowercaseString
            self.delegate.eventListerTagsSelectorViewControllerDidSelectTag(
                anyTags: false, tag: tag)
        }
    }

    //----------------------------------------------------------------------------------------------
}



