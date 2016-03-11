import UIKit


class TableViewCell : UITableViewCell
{
    //----------------------------------------------------------------------------------------------

    override func awakeFromNib ()
    {
        super.awakeFromNib()

        self.detailTextLabel?.textColor = AppConfiguration.tintColor
    }

    //----------------------------------------------------------------------------------------------
}



