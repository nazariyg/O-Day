class BackgroundVideoRecord : BackgroundRecord
{
    var itemID:Int!
    var videoRelPath:String!
    var subAlign:String!
    var timeAlign:String!
    var nativeLoop:Bool!
    var jointTime:Double!

    var videoRelPathIsTemp = false

    //----------------------------------------------------------------------------------------------

    override init ()
    {
        super.init()
    }

    //----------------------------------------------------------------------------------------------

    override func encodeWithCoder (aCoder:NSCoder)
    {
        super.encodeWithCoder(aCoder)

        aCoder.encodeObject(self.itemID, forKey: "itemID")
        aCoder.encodeObject(self.videoRelPath, forKey: "videoRelPath")
        aCoder.encodeObject(self.subAlign, forKey: "subAlign")
        aCoder.encodeObject(self.timeAlign, forKey: "timeAlign")
        aCoder.encodeObject(self.nativeLoop, forKey: "nativeLoop")
        aCoder.encodeObject(self.jointTime, forKey: "jointTime")
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    required init? (coder aDecoder:NSCoder)
    {
        self.itemID =
            aDecoder.decodeObjectForKey("itemID") as! Int
        self.videoRelPath =
            aDecoder.decodeObjectForKey("videoRelPath") as! String
        self.subAlign =
            aDecoder.decodeObjectForKey("subAlign") as! String
        self.timeAlign =
            aDecoder.decodeObjectForKey("timeAlign") as! String
        self.nativeLoop =
            aDecoder.decodeObjectForKey("nativeLoop") as! Bool
        self.jointTime =
            aDecoder.decodeObjectForKey("jointTime") as! Double

        super.init(coder: aDecoder)
    }

    //----------------------------------------------------------------------------------------------

    var videoURL:NSURL
    {
        if !self.videoRelPathIsTemp
        {
            return AppConfiguration.eventsDirURL.URLByAppendingPathComponent(self.videoRelPath)
        }
        else
        {
            return AppConfiguration.tempDirURL.URLByAppendingPathComponent(self.videoRelPath)
        }
    }

    //----------------------------------------------------------------------------------------------
}



