import UIKit


//--------------------------------------------------------------------------------------------------

protocol OverlayChooserOptionsViewControllerAltOutput : class
{
    func acceptOutputDataFromOverlayChooserOptionsViewControllerAlt (data:[String: AnyObject])
}

//--------------------------------------------------------------------------------------------------


class OverlayChooserOptionsViewControllerAlt : StaticDataTableViewController
{
    weak var delegate:OverlayChooserOptionsViewControllerAltOutput!

    @IBOutlet private weak var miscRow:UITableViewCell!

    //----------------------------------------------------------------------------------------------

    override func viewDidLoad ()
    {
        super.viewDidLoad()

        self.tableView.contentInset = UIEdgeInsets(top: 10.0, left: 0.0, bottom: 0.0, right: 0.0)
        self.tableView.backgroundColor = UIColor.whiteColor().colorWithAlphaComponent(0.1)

        //
        self.cell(self.miscRow, setHidden: true)
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
        var query:String!

        if indexPath.section == 0
        {
            var row = 0

            if indexPath.row == row++
            {
                query = "Omitted."
            }
            if indexPath.row == row++
            {
                query = "Omitted."
            }
            if indexPath.row == row++
            {
                query = "Omitted."
            }
            if indexPath.row == row++
            {
                query = "Omitted."
            }
            if indexPath.row == row++
            {
                query = "Omitted."
            }
            if indexPath.row == row++
            {
                query = "Omitted."
            }
            if indexPath.row == row++
            {
                query = "Omitted."
            }
            if indexPath.row == row++
            {
                query = "Omitted."
            }
            if indexPath.row == row++
            {
                query = "Omitted."
            }
            if indexPath.row == row++
            {
                query = "Omitted."
            }
            if indexPath.row == row++
            {
                query = "Omitted."
            }
            if indexPath.row == row++
            {
                query = "Omitted."
            }
            if indexPath.row == row++
            {
                query = "Omitted."
            }
        }

        if indexPath.section == 1 && indexPath.row == 0
        {
            self.dismiss()
        }

        if let query = query
        {
            self.didSelectCategoryForSearchQuery(query)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func tableView (
        tableView:UITableView, didHighlightRowAtIndexPath indexPath:NSIndexPath)
    {
        let highlightedColor = AppConfiguration.bluishColor

        self.tableView.cellForRowAtIndexPath(indexPath)?.textLabel?.textColor = highlightedColor
        if let contentView = self.tableView.cellForRowAtIndexPath(indexPath)?.contentView
        {
            for subview in contentView.subviews
            {
                if let label = subview as? UILabel
                {
                    label.textColor = highlightedColor
                }
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func tableView (
        tableView:UITableView, didUnhighlightRowAtIndexPath indexPath:NSIndexPath)
    {
        self.tableView.cellForRowAtIndexPath(indexPath)?.textLabel?.textColor =
            UIColor.whiteColor()
        if let contentView = self.tableView.cellForRowAtIndexPath(indexPath)?.contentView
        {
            for subview in contentView.subviews
            {
                if let label = subview as? UILabel
                {
                    label.textColor = UIColor.whiteColor()
                }
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func didSelectCategoryForSearchQuery (query:String)
    {
        var outputData = [String: AnyObject]()
        outputData["query"] = query
        self.delegate.acceptOutputDataFromOverlayChooserOptionsViewControllerAlt(outputData)

        self.dismiss()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func dismiss ()
    {
        self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }

    //----------------------------------------------------------------------------------------------
}



