extension String
{
    //----------------------------------------------------------------------------------------------

    var normLength:Int
    {
        return NSAttributedString(string: self).length
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    var URLEncodedString:String
    {
        let unreservedChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        let unreservedCharset = NSCharacterSet(charactersInString: unreservedChars)
        let encodedString =
            self.stringByAddingPercentEncodingWithAllowedCharacters(unreservedCharset)
        return encodedString ?? self
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    var UNIXFileNameSafeString:String
    {
        return self.stringByReplacingOccurrencesOfString(
            "[^\\x20-\\x2E\\x30-\\x7E]", withString: "", options: .RegularExpressionSearch,
            range: nil)
    }

    //----------------------------------------------------------------------------------------------
}



