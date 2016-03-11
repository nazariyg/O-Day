extension NSFileManager
{
    //----------------------------------------------------------------------------------------------

    class func sizeOfFileAtURL (fileURL:NSURL) -> Int
    {
        let fm = NSFileManager()
        return (try! fm.attributesOfItemAtPath(fileURL.path!)[NSFileSize]) as! Int
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    class func clearDir (dirURL:NSURL, includingDirItself:Bool)
    {
        let fm = NSFileManager()

        let enumerator =
        fm.enumeratorAtURL(dirURL, includingPropertiesForKeys: nil, options: [],
            errorHandler: nil)
        while let itemURL = enumerator?.nextObject() as? NSURL
        {
            var isDir:ObjCBool = false
            fm.fileExistsAtPath(itemURL.path!, isDirectory: &isDir)
            if !isDir
            {
                try! fm.removeItemAtURL(itemURL)
            }
            else
            {
                self.clearDir(itemURL, includingDirItself: true)
            }
        }

        if includingDirItself
        {
            try! fm.removeItemAtURL(dirURL)
        }
    }

    //----------------------------------------------------------------------------------------------
}



