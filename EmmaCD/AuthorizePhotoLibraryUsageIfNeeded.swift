import Photos


func authorizePhotoLibraryUsageIfNeededWithSuccessClosure (
    successClosure:(() -> Void)? = nil, failureClosure:(() -> Void)? = nil)
{
    let status = PHPhotoLibrary.authorizationStatus()

    switch status
    {
    case .Authorized:
        successClosure?()
    case .NotDetermined:
        PHPhotoLibrary.requestAuthorization { status in
            on_main() {
                if status == .Authorized
                {
                    successClosure?()
                }
                else
                {
                    failureClosure?()
                }
            }
        }
    case .Denied:
        let alert =
            UIAlertController(
                title: "Authorization",
                message: "Would you like to let this app use your Photo Library?",
                preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "No", style: .Cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { _ in
            let url = NSURL(string: UIApplicationOpenSettingsURLString)!
            UIApplication.sharedApplication().openURL(url)
        }))
        currentlyVisibleViewController()?.presentViewController(
            alert, animated: true, completion: nil)

        failureClosure?()
    case .Restricted:
        failureClosure?()
    }
}



