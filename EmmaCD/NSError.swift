extension NSError
{
    class func localizedDescriptionAndReasonForError (error:NSError?) -> String
    {
        let errorMessage = error?.localizedDescription ?? "Unknown error"
        let errorReason = error?.localizedFailureReason ?? ""
        let message =
            errorMessage +
            (!errorReason.isEmpty ? "\n" : "") + errorReason
        return message
    }
}



