//--------------------------------------------------------------------------------------------------

protocol EventEditTagsChooserViewControllerInputOutput : class
{
    func provideInputDataForEventEditTagsChooserViewController () -> [String: AnyObject]
    func acceptOutputDataFromEventEditTagsChooserViewController (data:[String: AnyObject])
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

private class TagRecord
{
    let tagName:String
    var isSelected:Bool

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    init (tagName:String, isSelected:Bool)
    {
        self.tagName = tagName
        self.isSelected = isSelected
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
}

//--------------------------------------------------------------------------------------------------


class EventEditTagsChooserViewController : UITableViewController, UITextFieldDelegate
{
    weak var inputOutputDelegate:EventEditTagsChooserViewControllerInputOutput!

    private let tagFontSize:CGFloat = 16.0

    private var tags:[TagRecord]!
    private var addNewTagMode = false

    //----------------------------------------------------------------------------------------------

    override func viewDidLoad ()
    {
        super.viewDidLoad()

        self.title = "Event tags"

        self.view.backgroundColor = AppConfiguration.bluishColorSemiDarker
        self.view.tintColor = AppConfiguration.tintColor

        self.navigationController!.navigationBar.barStyle = .BlackTranslucent
        self.navigationController!.navigationBar.barTintColor = AppConfiguration.bluishColor
        self.navigationController!.navigationBar.titleTextAttributes =
            [NSForegroundColorAttributeName: AppConfiguration.tintColor]

        let inputData =
            self.inputOutputDelegate.provideInputDataForEventEditTagsChooserViewController()
        let inputTags = inputData["tags"] as? [String]

        var builtInTags = [TagRecord]()
        if let inputTags = inputTags
        {
            for tag in AppConfiguration.builtInEventTags
            {
                let isSelected = inputTags.contains(tag)
                let tagRecord = TagRecord(tagName: tag.lowercaseString, isSelected: isSelected)
                builtInTags.append(tagRecord)
            }
        }
        else
        {
            for tag in AppConfiguration.builtInEventTags
            {
                let tagRecord = TagRecord(tagName: tag.lowercaseString, isSelected: false)
                builtInTags.append(tagRecord)
            }
        }
        builtInTags.sortInPlace({ $0.tagName.compare($1.tagName) == .OrderedAscending })

        var customTags = [TagRecord]()
        var customTagsStr = EventRecord.collectTagsFromEvents(unique: true)
        if let inputTags = inputTags
        {
            customTagsStr.appendContentsOf(inputTags)
        }
        customTagsStr = Array(Set(customTagsStr).subtract(AppConfiguration.builtInEventTags))
        if let inputTags = inputTags
        {
            for tag in customTagsStr
            {
                let isSelected = inputTags.contains(tag)
                let tagRecord = TagRecord(tagName: tag.lowercaseString, isSelected: isSelected)
                customTags.append(tagRecord)
            }
        }
        else
        {
            for tag in customTagsStr
            {
                let tagRecord = TagRecord(tagName: tag.lowercaseString, isSelected: false)
                customTags.append(tagRecord)
            }
        }
        customTags.sortInPlace({ $0.tagName.compare($1.tagName) == .OrderedAscending })

        self.tags = [TagRecord]()
        self.tags.appendContentsOf(builtInTags)
        self.tags.appendContentsOf(customTags)
        self.tags.sortInPlace({ $0.tagName.compare($1.tagName) == .OrderedAscending })
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

    override func tableView (tableView: UITableView, numberOfRowsInSection section:Int) -> Int
    {
        return self.tags.count + 1
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func tableView (
        tableView:UITableView, cellForRowAtIndexPath indexPath:NSIndexPath) -> UITableViewCell
    {
        let cellID:String
        if indexPath.row < self.tags.count
        {
            cellID = "Cell"
        }
        else
        {
            if !self.addNewTagMode
            {
                cellID = "Plus"
            }
            else
            {
                cellID = "NewTag"
            }
        }

        let cell = self.tableView.dequeueReusableCellWithIdentifier(cellID, forIndexPath: indexPath)

        cell.contentView.backgroundColor = UIColor.clearColor()
        cell.backgroundColor = UIColor.clearColor()

        if indexPath.row < self.tags.count
        {
            let tagRecord = self.tags[indexPath.row]
            cell.textLabel?.textColor = UIColor.whiteColor()
            cell.textLabel?.font = UIFont.systemFontOfSize(self.tagFontSize)
            cell.textLabel?.text = tagRecord.tagName.uppercaseString
            cell.accessoryType = tagRecord.isSelected ? .Checkmark : .None

            let bgColorView = UIView()
            bgColorView.backgroundColor = AppConfiguration.bluishColor
            cell.selectedBackgroundView = bgColorView
        }
        else
        {
            cell.selectionStyle = .None
            cell.textLabel?.text = ""
            cell.accessoryType = .None
        }

        return cell
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func tableView (
        tableView:UITableView, shouldHighlightRowAtIndexPath indexPath:NSIndexPath) ->
            Bool
    {
        if self.addNewTagMode
        {
            self.addNewTagMode = false
            let lastRowIP = NSIndexPath(forRow: self.tags.count, inSection: 0)
            self.tableView.reloadRowsAtIndexPaths([lastRowIP], withRowAnimation: .Fade)

            return false
        }
        else
        {
            return true
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func tableView (tableView:UITableView, didSelectRowAtIndexPath indexPath:NSIndexPath)
    {
        if indexPath.row >= self.tags.count
        {
            return
        }

        let tagRecord = self.tags[indexPath.row]
        tagRecord.isSelected = !tagRecord.isSelected

        if let cell = self.tableView.cellForRowAtIndexPath(indexPath)
        {
            cell.accessoryType = tagRecord.isSelected ? .Checkmark : .None
        }

        self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func tableView (
        tableView:UITableView, heightForRowAtIndexPath indexPath:NSIndexPath) ->
            CGFloat
    {
        if indexPath.row < self.tags.count
        {
            return self.tableView.rowHeight
        }
        else
        {
            if !self.addNewTagMode
            {
                return 96.0
            }
            else
            {
                return 50.0
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func textFieldShouldReturn (textField:UITextField) -> Bool
    {
        if let text = textField.text where !text.isEmpty
        {
            let lowercaseText = text.lowercaseString
            if !self.tags.contains({ $0.tagName == lowercaseText })
            {
                return true
            }
            else
            {
                doOKAlertWithTitle(
                    nil,
                    message: "A tag with this name already exists. Please choose another name.")
                return false
            }
        }
        else
        {
            return false
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func dismiss ()
    {
        self.view.endEditing(true)

        var selectedTags:[String]! = self.tags.filter({ $0.isSelected }).map({ $0.tagName })
        if !selectedTags.isEmpty
        {
            selectedTags = selectedTags.map { $0.lowercaseString }
        }
        else
        {
            selectedTags = nil
        }
        var outputData = [String: AnyObject]()
        outputData["tags"] = selectedTags
        self.inputOutputDelegate.acceptOutputDataFromEventEditTagsChooserViewController(outputData)

        self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }

    //----------------------------------------------------------------------------------------------

    @IBAction func backBarBNAction (sender:AnyObject)
    {
        self.dismiss()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction func plusBNAction ()
    {
        self.addNewTagMode = true

        let lastRowIP = NSIndexPath(forRow: self.tags.count, inSection: 0)

        self.tableView.reloadRowsAtIndexPaths([lastRowIP], withRowAnimation: .Fade)
        self.tableView.scrollToRowAtIndexPath(lastRowIP, atScrollPosition: .Bottom, animated: true)

        let newTagView = self.tableView.cellForRowAtIndexPath(lastRowIP)?.viewWithTag(1)
        if let newTagTF = newTagView as? UITextField
        {
            newTagTF.textColor = UIColor.whiteColor()
            newTagTF.font = UIFont.systemFontOfSize(self.tagFontSize)
            newTagTF.text = nil
            newTagTF.delegate = self
            newTagTF.becomeFirstResponder()
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction func addTagTFEditingDidEndOnExit (sender:AnyObject)
    {
        let newTagTF = sender as! UITextField
        if let text = newTagTF.text
        {
            var tagName = text.lowercaseString
            tagName =
                tagName.stringByTrimmingCharactersInSet(
                    NSCharacterSet.whitespaceAndNewlineCharacterSet())

            let tagRecord = TagRecord(tagName: tagName, isSelected: true)
            self.tags.append(tagRecord)

            self.addNewTagMode = false
            self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Fade)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction func addTagTFEditingDidEnd ()
    {
        if self.addNewTagMode
        {
            self.addNewTagMode = false
            let lastRowIP = NSIndexPath(forRow: self.tags.count, inSection: 0)
            self.tableView.reloadRowsAtIndexPaths([lastRowIP], withRowAnimation: .Fade)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction func addTagTFEditingChanged (sender:AnyObject)
    {
        let newTagTF = sender as! UITextField
        if let text = newTagTF.text
        {
            let uppercaseText = text.uppercaseString
            if text != uppercaseText
            {
                newTagTF.text = uppercaseText
            }
        }
    }

    //----------------------------------------------------------------------------------------------
}



