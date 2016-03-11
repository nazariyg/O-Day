func doOKAlertWithTitle (title:String?, message:String?, okHandler:(() -> Void)? = nil)
{
    let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
    alert.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: { _ in
        okHandler?()
    }))
    currentlyVisibleViewController()?.presentViewController(
        alert, animated: true, completion: nil)
}



