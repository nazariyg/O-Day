//--------------------------------------------------------------------------------------------------

func on_main (closure:() -> Void)
{
    dispatch_async(dispatch_get_main_queue(), closure)
}

//--------------------------------------------------------------------------------------------------

func on_main_with_delay (delay:Double, closure:() -> Void)
{
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, Int64(delay*Double(NSEC_PER_SEC))),
        dispatch_get_main_queue(), closure)
}

//--------------------------------------------------------------------------------------------------

func on_main_sync (closure:() -> Void)
{
    if !NSThread.isMainThread()
    {
        dispatch_sync(dispatch_get_main_queue(), closure)
    }
    else
    {
        closure()
    }
}

//--------------------------------------------------------------------------------------------------



