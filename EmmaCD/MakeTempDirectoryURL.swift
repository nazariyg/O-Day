func makeTempDirectoryURL (parentTempDirURL:NSURL) -> NSURL
{
    _ = try? NSFileManager().createDirectoryAtURL(
        parentTempDirURL, withIntermediateDirectories: true, attributes: nil)

    let gus = NSProcessInfo.processInfo().globallyUniqueString
    let tempDirectoryName = gus
    let tempDirectoryURL =
        parentTempDirURL.URLByAppendingPathComponent(tempDirectoryName, isDirectory: true)
    return tempDirectoryURL
}



