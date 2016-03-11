import UIKit


class KBDismissiveView : UIView
{
    //----------------------------------------------------------------------------------------------

    override func touchesBegan (touches:Set<UITouch>, withEvent event:UIEvent?)
    {
        self.endEditing(true)
    }

    //----------------------------------------------------------------------------------------------
}



