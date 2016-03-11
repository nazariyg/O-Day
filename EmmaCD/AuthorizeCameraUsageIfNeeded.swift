import AVFoundation


func authorizeCameraUsageIfNeededWithSuccessClosure (
    successClosure:(() -> Void)? = nil, failureClosure:(() -> Void)? = nil)
{
    let status = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)

    switch status
    {
    case .Authorized:
        successClosure?()
    case .NotDetermined:
        AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo) { granted in
            on_main() {
                if granted
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
                message: "Would you like to let this app use your camera?",
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



