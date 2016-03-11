class TitleStyleRecord : NSObject, NSCoding
{
    var fontName:String!
    var color:UIColor!
    private var _snapshot:UIImage!
    var snapshot:UIImage!
    {
        get {
            if self._snapshot == nil
            {
                self._snapshot = UIImage(data: self.snapshotData)!
            }
            return self._snapshot
        }

        set {
            assert(newValue != nil)
            self.snapshotData = UIImagePNGRepresentation(newValue)
            self._snapshot = nil
        }
    }
    private var snapshotData:NSData!

    //----------------------------------------------------------------------------------------------

    override init ()
    {
        super.init()
    }

    //----------------------------------------------------------------------------------------------

    func encodeWithCoder (aCoder:NSCoder)
    {
        aCoder.encodeObject(self.fontName, forKey: "fontName")
        aCoder.encodeObject(self.color, forKey: "color")
        aCoder.encodeObject(self.snapshotData, forKey: "snapshotData")
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    required init? (coder aDecoder:NSCoder)
    {
        self.fontName = aDecoder.decodeObjectForKey("fontName") as! String
        self.color = aDecoder.decodeObjectForKey("color") as! UIColor
        self.snapshotData = aDecoder.decodeObjectForKey("snapshotData") as! NSData

        super.init()
    }

    //----------------------------------------------------------------------------------------------
}



