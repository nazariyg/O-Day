class FrameStyleRecord : NSObject, NSCoding
{
    var frameImage:UIImage!
    var frameID:Int!
    var textRect:CGRect!
    var hasFill:Bool!
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
        aCoder.encodeObject(self.frameImage, forKey: "frameImage")
        aCoder.encodeObject(self.frameID, forKey: "frameID")
        aCoder.encodeObject(NSValue(CGRect: self.textRect), forKey: "textRect")
        aCoder.encodeObject(self.hasFill, forKey: "hasFill")
        aCoder.encodeObject(self.snapshotData, forKey: "snapshotData")
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    required init? (coder aDecoder:NSCoder)
    {
        self.frameImage = aDecoder.decodeObjectForKey("frameImage") as! UIImage
        self.frameID = aDecoder.decodeObjectForKey("frameID") as! Int
        self.textRect = (aDecoder.decodeObjectForKey("textRect") as! NSValue).CGRectValue()
        self.hasFill = aDecoder.decodeObjectForKey("hasFill") as! Bool
        self.snapshotData = aDecoder.decodeObjectForKey("snapshotData") as! NSData

        super.init()
    }

    //----------------------------------------------------------------------------------------------

    class func layoutFrameImageView (
        frameImageView:UIImageView, inView view:UIView, withTextRect textRect:CGRect,
        offsetX:CGFloat, frameID:Int) ->
            CGRect
    {
        let paddingFactorH:CGFloat = 0.12
        let paddingFactorVCentric:CGFloat = 0.27
        let minTextWidth:CGFloat = view.bounds.width*0.66
        let paddingFactorHStep2:CGFloat = paddingFactorH*0.33
        let paddingFactorVStep2:CGFloat = 0.075  // 0.25
        let maxFrameArea:CGFloat = view.bounds.width*view.bounds.height*0.375
        let customScaleFactor:CGFloat = 0.95
        let outerTextRectHeightFactor:CGFloat = 1.0
        let outerTextRectHeightIncreaseExcludeIDs = [
            30,
            36,
            76,
            83,
            92,
        ]

        let midX = offsetX + view.bounds.width/2.0
        var ivFrame = CGRectZero
        ivFrame.size.width = view.bounds.width*(1.0 - paddingFactorH*2.0)
        let imageAspect = frameImageView.image!.size.height/frameImageView.image!.size.width
        ivFrame.size.height = ivFrame.size.width*imageAspect
        ivFrame.origin.x = midX - ivFrame.size.width/2.0
        ivFrame.origin.y = view.bounds.height*paddingFactorVCentric - ivFrame.size.height/2.0

        frameImageView.frame = ivFrame
        view.addSubview(frameImageView)

        let imageWidth = CGFloat(frameImageView.image!.pixelWidth)
        let imageHeight = CGFloat(frameImageView.image!.pixelHeight)
        let normTextRect =
            CGRect(
                x: textRect.origin.x/imageWidth,
                y: textRect.origin.y/imageHeight,
                width: textRect.width/imageWidth,
                height: textRect.height/imageHeight)
        var ivTextRect =
            CGRect(
                x: normTextRect.origin.x*ivFrame.width,
                y: normTextRect.origin.y*ivFrame.height,
                width: normTextRect.width*ivFrame.width,
                height: normTextRect.height*ivFrame.height)
        var outerTextRect = view.convertRect(ivTextRect, fromView: frameImageView)
        var scale = outerTextRect.width < minTextWidth ? minTextWidth/outerTextRect.width : 1.0
        let frameArea = ivFrame.width*ivFrame.height*scale*scale
        if frameArea > maxFrameArea
        {
            scale = sqrt(maxFrameArea/(ivFrame.width*ivFrame.height))
        }
        var ivFrameTargetWidth = ivFrame.width*scale
        var ivFrameTargetHeight = ivFrame.height*scale
        let maxWidth = view.bounds.width*(1.0 - paddingFactorHStep2*2.0)
        if ivFrameTargetWidth > maxWidth
        {
            let rescale = maxWidth/ivFrameTargetWidth
            ivFrameTargetWidth = maxWidth
            ivFrameTargetHeight *= rescale
        }
        let customScale = self.customScaleForFrameWithID(frameID)*customScaleFactor
        ivFrameTargetWidth *= customScale
        ivFrameTargetHeight *= customScale
        ivFrame.insetInPlace(
            dx: -(ivFrameTargetWidth - ivFrame.width)/2.0,
            dy: -(ivFrameTargetHeight - ivFrame.height)/2.0)
        let minY = view.bounds.height*paddingFactorVStep2
        if ivFrame.origin.y < minY
        {
            ivFrame.origin.y = minY
        }
        frameImageView.frame = ivFrame
        ivTextRect =
            CGRect(
                x: normTextRect.origin.x*ivFrame.width,
                y: normTextRect.origin.y*ivFrame.height,
                width: normTextRect.width*ivFrame.width,
                height: normTextRect.height*ivFrame.height)
        outerTextRect = view.convertRect(ivTextRect, fromView: frameImageView)
        if !outerTextRectHeightIncreaseExcludeIDs.contains(frameID)
        {
            outerTextRect.insetInPlace(
                dx: 0.0,
                dy: -outerTextRect.height*outerTextRectHeightFactor/2.0)
        }
        return outerTextRect
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    class func customScaleForFrameWithID (id:Int) -> CGFloat
    {
        switch id
        {
        case 7:
            return 0.95
        case 16:
            return 1.12
        case 32:
            return 1.05
        case 33:
            return 1.033
        case 35:
            return 1.05
        case 36:
            return 1.05
        case 39:
            return 1.033
        case 40:
            return 1.05
        case 51:
            return 1.05
        case 54:
            return 0.95
        case 58:
            return 1.14
        case 62:
            return 1.05
        case 83:
            return 1.05
        case 89:
            return 0.95
        case 91:
            return 1.1
        case 93:
            return 1.1
        default:
            return 1.0
        }
    }

    //----------------------------------------------------------------------------------------------
}



