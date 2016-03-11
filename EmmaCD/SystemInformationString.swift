private func deviceRemainingFreeSpaceInBytes () -> Int64?
{
    let documentDirectoryPath =
    NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
    var attributes: [String: AnyObject]
    do
    {
        attributes =
            try NSFileManager.defaultManager().attributesOfFileSystemForPath(
                documentDirectoryPath.last! as String)
        let freeSize = attributes[NSFileSystemFreeSize] as? NSNumber
        if freeSize != nil
        {
            return freeSize?.longLongValue
        }
        else
        {
            return nil
        }
    }
    catch
    {
        return nil
    }
}

func systemInformationString () -> String
{
    let iOSVersion = UIDevice.currentDevice().systemVersion
    let appVersion =
        NSBundle.mainBundle().objectForInfoDictionaryKey(
            "CFBundleShortVersionString") as! String
    let appVersionB =
        NSBundle.mainBundle().objectForInfoDictionaryKey(
            "CFBundleVersion") as! String
    var freeDiskSpaceMB:Double!
    if let freeDiskSpaceBytes = deviceRemainingFreeSpaceInBytes()
    {
        freeDiskSpaceMB = round(Double(freeDiskSpaceBytes)/1048576)
    }

    var sysInfo = ""

    sysInfo += "App version: \(appVersion) (build \(appVersionB))"

    sysInfo += "\niOS version: \(iOSVersion)"

    let screenSize = UIScreen.mainScreen().bounds.size
    sysInfo += "\nScreen size: \(Int(screenSize.width))x\(Int(screenSize.height))"

    if let freeDiskSpaceMB = freeDiskSpaceMB
    {
        let amount = String(format: "%.2f", freeDiskSpaceMB)
        sysInfo += "\nFree disk space: \(amount) MB"
    }
    return sysInfo
}



