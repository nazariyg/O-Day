import EventKit


func authorizeCalendarUsageIfNeededWithSuccessClosure (
    eventStore:EKEventStore, successClosure:(() -> Void)? = nil, failureClosure:(() -> Void)? = nil)
{
    let entityType = EKEntityType.Event

    let status = EKEventStore.authorizationStatusForEntityType(entityType)

    switch status
    {
    case .Authorized:
        successClosure?()
    case .NotDetermined:
        eventStore.requestAccessToEntityType(entityType, completion: { granted, error in
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
        })
    case .Denied:
        let alert =
            UIAlertController(
                title: "Authorization",
                message: "Would you like to let this app use your Calendar?",
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



