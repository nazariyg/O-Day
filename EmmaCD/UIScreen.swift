extension UIScreen
{
    enum AspectRatio
    {
        case AspectRatio3x4
        case AspectRatio9x16
    }

    //----------------------------------------------------------------------------------------------

    class var mainScreenAspectRatio:AspectRatio
    {
        let ms = self.mainScreen()
        let aspectRatioFP = ms.bounds.width/ms.bounds.height
        if abs(aspectRatioFP - 3.0/4.0) < abs(aspectRatioFP - 9.0/16.0)
        {
            return .AspectRatio3x4
        }
        else
        {
            return .AspectRatio9x16
        }
    }

    //----------------------------------------------------------------------------------------------
}



