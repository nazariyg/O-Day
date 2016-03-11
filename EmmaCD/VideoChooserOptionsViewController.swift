import UIKit


//--------------------------------------------------------------------------------------------------

protocol VideoChooserOptionsViewControllerOutput : class
{
    func acceptOutputDataFromVideoChooserOptionsViewController (data:[String: AnyObject])
}

//--------------------------------------------------------------------------------------------------


class VideoChooserOptionsViewController : UITableViewController
{
    weak var delegate:VideoChooserOptionsViewControllerOutput!

    //----------------------------------------------------------------------------------------------

    override func viewDidLoad ()
    {
        super.viewDidLoad()

        self.tableView.contentInset = UIEdgeInsets(top: 10.0, left: 0.0, bottom: 0.0, right: 0.0)
        self.tableView.backgroundColor = UIColor.whiteColor().colorWithAlphaComponent(0.1)
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
                query = "=ic_emo_happy"
            }
            if indexPath.row == row++
            {
                query = "=ic_emo_dreamy"
            }
            if indexPath.row == row++
            {
                query = "=ic_emo_sad"
            }
            if indexPath.row == row++
            {
                query = "=ic_emo_angry"
            }
        }

        if indexPath.section == 1
        {
            var row = 0

            if indexPath.row == row++
            {
                query = "=ic_emo_yes"
            }
            if indexPath.row == row++
            {
                query = "=ic_emo_no"
            }
            if indexPath.row == row++
            {
                query = "=ic_emo_maybe"
            }
        }

        if indexPath.section == 2
        {
            var row = 0

            if indexPath.row == row++
            {
                query = "fabric"
            }
            if indexPath.row == row++
            {
                query = "=ic_waterdrops"
            }
            if indexPath.row == row++
            {
                query = "watch time"
            }
            if indexPath.row == row++
            {
                query = "vacation"
            }
            if indexPath.row == row++
            {
                query = "travel"
            }
            if indexPath.row == row++
            {
                query = "city"
            }
            if indexPath.row == row++
            {
                query = "christmas"
            }
            if indexPath.row == row++
            {
                query = "party"
            }
            if indexPath.row == row++
            {
                query = "spring"
            }
            if indexPath.row == row++
            {
                query = "summer"
            }
            if indexPath.row == row++
            {
                query = "autumn"
            }
            if indexPath.row == row++
            {
                query = "winter"
            }
            if indexPath.row == row++
            {
                query = "=ic_sea"
            }
            if indexPath.row == row++
            {
                query = "=ic_cloud_fly_thru"
            }
            if indexPath.row == row++
            {
                query = "nature"
            }
            if indexPath.row == row++
            {
                query = "money"
            }
            if indexPath.row == row++
            {
                query = "happy new year"
            }
            if indexPath.row == row++
            {
                query = "love -ic_flower"
            }
            if indexPath.row == row++
            {
                query = "school"
            }
            if indexPath.row == row++
            {
                query = "university"
            }
            if indexPath.row == row++
            {
                query = "christian"
            }
            if indexPath.row == row++
            {
                query = "=ic_flower"
            }
            if indexPath.row == row++
            {
                query = "=ic_secondary-ic_waterdrops-ic_cloud_fly_thru-ic_flower-ic_sea"
            }
        }

        if indexPath.section == 3 && indexPath.row == 0
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
        self.delegate.acceptOutputDataFromVideoChooserOptionsViewController(outputData)

        self.dismiss()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func dismiss ()
    {
        self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }

    //----------------------------------------------------------------------------------------------
}



