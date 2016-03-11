class BackgroundRecord : NSObject, NSCoding
{
    private static let squareSnapshotMaxSidePixelSize = 280

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
            self.snapshotData = UIImageJPEGRepresentation(newValue, 1.0)
            self._snapshot = nil

            let squareImage = self.dynamicType.squareSnapshotFromImage(newValue)
            self.squareSnapshotData = UIImageJPEGRepresentation(squareImage, 1.0)
            self._squareSnapshot = nil
        }
    }
    private var snapshotData:NSData!

    private var _squareSnapshot:UIImage!
    var squareSnapshot:UIImage!
    {
        if self._squareSnapshot == nil
        {
            self._squareSnapshot = UIImage(data: self.squareSnapshotData)!
        }
        return self._squareSnapshot
    }
    private var squareSnapshotData:NSData!

    private static var _squareDefaultPicture:UIImage!

    //----------------------------------------------------------------------------------------------

    override init ()
    {
        super.init()
    }

    //----------------------------------------------------------------------------------------------

    func encodeWithCoder (aCoder:NSCoder)
    {
        aCoder.encodeObject(self.snapshotData, forKey: "snapshotData")
        aCoder.encodeObject(self.squareSnapshotData, forKey: "squareSnapshotData")
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    required init? (coder aDecoder:NSCoder)
    {
        self.snapshotData = aDecoder.decodeObjectForKey("snapshotData") as! NSData
        self.squareSnapshotData = aDecoder.decodeObjectForKey("squareSnapshotData") as! NSData

        super.init()
    }

    //----------------------------------------------------------------------------------------------

    static var squareDefaultPicture:UIImage
    {
        if self._squareDefaultPicture == nil
        {
            let image = AppConfiguration.defaultPicture
            self._squareDefaultPicture = self.squareSnapshotFromImage(image)
        }
        return self._squareDefaultPicture
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    class func squareSnapshotFromImage (image:UIImage) -> UIImage
    {
        let minSideSize = min(image.size.width, image.size.height)
        let minSideHalfSize = minSideSize/2.0
        let center = CGPoint(x: image.size.width/2.0, y: image.size.height/2.0)
        let cropRect =
            CGRect(
                x: center.x - minSideHalfSize,
                y: center.y - minSideHalfSize,
                width: minSideSize,
                height: minSideSize)
        var squareImage = image.croppedImageInRect(cropRect)
        let sidePixelSize = squareImage.pixelWidth
        if sidePixelSize > self.squareSnapshotMaxSidePixelSize
        {
            let scale = Double(self.squareSnapshotMaxSidePixelSize)/Double(sidePixelSize)
            squareImage = squareImage.resizedImageWithScale(scale)
        }
        return squareImage
    }

    //----------------------------------------------------------------------------------------------
}



