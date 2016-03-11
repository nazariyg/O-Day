func makeTempFileURL (tempDirURL:NSURL, ext:String = "") -> NSURL
{
    _ = try? NSFileManager().createDirectoryAtURL(
        tempDirURL, withIntermediateDirectories: true, attributes: nil)

    let gus = NSProcessInfo.processInfo().globallyUniqueString
    let tempFileName:String
    if ext != ""
    {
        tempFileName = String(format: "%@.%@", gus, ext)
    }
    else
    {
        tempFileName = gus
    }
    let tempFileURL = tempDirURL.URLByAppendingPathComponent(tempFileName)
    return tempFileURL
}



