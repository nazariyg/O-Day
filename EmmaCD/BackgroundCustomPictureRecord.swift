class BackgroundCustomPictureRecord : BackgroundRecord
{
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

    //----------------------------------------------------------------------------------------------

    override init ()
    {
        super.init()
    }

    //----------------------------------------------------------------------------------------------

    override func encodeWithCoder (aCoder:NSCoder)
    {
        super.encodeWithCoder(aCoder)

        aCoder.encodeObject(self.pictureData, forKey: "pictureData")
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    required init? (coder aDecoder:NSCoder)
    {
        self.pictureData = aDecoder.decodeObjectForKey("pictureData") as! NSData

        super.init(coder: aDecoder)
    }

    //----------------------------------------------------------------------------------------------
}



