import UIKit


class KBDismissiveTableView : UITableView
{
    //----------------------------------------------------------------------------------------------

    override func touchesBegan (touches:Set<UITouch>, withEvent event:UIEvent?)
    {
        super.touchesBegan(touches, withEvent: event)

        self.endEditing(true)
    }

    //----------------------------------------------------------------------------------------------
}



