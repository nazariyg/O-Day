class NestableActivityIndicatorViewController
{
    private let activityIndicator:UIActivityIndicatorView
    private var nextActivityID = 0
    private var currActivities = Set<Int>()

    //----------------------------------------------------------------------------------------------

    init (activityIndicator:UIActivityIndicatorView)
    {
        self.activityIndicator = activityIndicator
        self.activityIndicator.hidesWhenStopped = true
    }

    //----------------------------------------------------------------------------------------------

    func activityIDForStartedActivity () -> Int
    {
        let id = self.nextActivityID
        self.nextActivityID = self.nextActivityID &+ 1
        self.currActivities.insert(id)

        if !self.activityIndicator.isAnimating()
        {
            self.startAnimatingAI()
        }

        return id
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func activityIDForStartedActivityWithGraceTime (time:Double) -> Int
    {
        let id = self.nextActivityID
        self.nextActivityID++
        self.currActivities.insert(id)

        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, Int64(time*Double(NSEC_PER_SEC))),
            dispatch_get_main_queue()) {
                if self.currActivities.contains(id)
                {
                    // The activity is still on.
                    self.startAnimatingAI()
                }
            }

        return id
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func stopIndicatingActivityWithID (activityID:Int)
    {
        self.currActivities.remove(activityID)

        if self.currActivities.isEmpty
        {
            // No activities are currently in progress.
            self.stopAnimatingAI()
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func hasAnyActivity () -> Bool
    {
        return !self.currActivities.isEmpty
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func startAnimatingAI ()
    {
        self.activityIndicator.startAnimating()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func stopAnimatingAI ()
    {
        self.activityIndicator.stopAnimating()
    }

    //----------------------------------------------------------------------------------------------
}



