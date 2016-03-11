class BackgroundPictureRecord : BackgroundRecord
{
    var itemID:Int!
    private var _picture:UIImage!
    var picture:UIImage!
    {
        get {
            if self._picture == nil
            {
                self._picture = UIImage(data: self.pictureData)!
            }
            return self._picture
        }

        set {
            assert(newValue != nil)
            self.pictureData = UIImageJPEGRepresentation(newValue, 1.0)
            self._picture = nil
        }
    }
    private var pictureData:NSData!
    var subAlign:String!

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
        aCoder.encodeObject(self.pictureData, forKey: "pictureData")
        aCoder.encodeObject(self.subAlign, forKey: "subAlign")
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    required init? (coder aDecoder:NSCoder)
    {
        self.itemID =
            aDecoder.decodeObjectForKey("itemID") as! Int
        self.pictureData =
            aDecoder.decodeObjectForKey("pictureData") as! NSData
        self.subAlign =
            aDecoder.decodeObjectForKey("subAlign") as! String

        super.init(coder: aDecoder)
    }

    //----------------------------------------------------------------------------------------------
}



