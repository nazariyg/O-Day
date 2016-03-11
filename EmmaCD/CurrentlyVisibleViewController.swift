func currentlyVisibleViewController () -> UIViewController?
{
    if let rootVC = UIApplication.sharedApplication().keyWindow?.rootViewController
    {
        var viewController = rootVC
        while viewController.presentedViewController != nil
        {
            viewController = viewController.presentedViewController!
        }
        return viewController
    }
    else
    {
        return nil
    }
}



