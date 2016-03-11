class NestableIgnoringInteractionEvents
{
    private var stackSize = 0

    //----------------------------------------------------------------------------------------------

    func begin ()
    {
        if self.stackSize == 0
        {
            UIApplication.sharedApplication().beginIgnoringInteractionEvents()
        }
        self.stackSize++
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func end ()
    {
        self.stackSize--
        if self.stackSize < 0
        {
            print("NestableIgnoringInteractionEvents: unbalanced 'end' method call")
            self.stackSize = 0
        }

        if self.stackSize == 0
        {
            UIApplication.sharedApplication().endIgnoringInteractionEvents()
        }
    }

    //----------------------------------------------------------------------------------------------
}



