import Viewmorphic


class BackgroundOverlayRecord : BackgroundRecord
{
    private var _inputImage:UIImage!
    var inputImage:UIImage!
    {
        get {
            if self._inputImage == nil
            {
                self._inputImage = UIImage(data: self.inputImageData)!
            }
            return self._inputImage
        }

        set {
            assert(newValue != nil)
            self.inputImageData = UIImageJPEGRepresentation(newValue, 1.0)
            self._inputImage = nil
        }
    }
    private var inputImageData:NSData!
    var inputImageBrightness:Double!
    var itemID:Int!
    var videoRelPath:String!
    var subAlign:String!
    var timeAlign:String!
    var nativeLoop:Bool!
    var jointTime:Double!
    var hdBitrate:Double!
    var blenderType:Blender.BlenderType!
    var cropRegion:CGRect!
    var transform:CGAffineTransform!
    var hue:Double!
    var zoomBlur:Double!
    var overlaySettings:NSData!
    var item:NSData!
    var resolution:String!

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

        aCoder.encodeObject(self.inputImageData, forKey: "inputImageData")
        aCoder.encodeObject(self.inputImageBrightness, forKey: "inputImageBrightness")
        aCoder.encodeObject(self.itemID, forKey: "itemID")
        aCoder.encodeObject(self.videoRelPath, forKey: "videoRelPath")
        aCoder.encodeObject(self.subAlign, forKey: "subAlign")
        aCoder.encodeObject(self.timeAlign, forKey: "timeAlign")
        aCoder.encodeObject(self.nativeLoop, forKey: "nativeLoop")
        aCoder.encodeObject(self.jointTime, forKey: "jointTime")
        aCoder.encodeObject(self.hdBitrate, forKey: "hdBitrate")
        aCoder.encodeObject(
            self.dynamicType.stringFromBlenderType(self.blenderType), forKey: "blenderType")
        aCoder.encodeObject(
            self.cropRegion != nil ? NSValue(CGRect: self.cropRegion) : nil,
            forKey: "cropRegion")
        aCoder.encodeObject(
            self.transform != nil ? NSValue(CGAffineTransform: self.transform) : nil,
            forKey: "transform")
        aCoder.encodeObject(self.hue, forKey: "hue")
        aCoder.encodeObject(self.zoomBlur, forKey: "zoomBlur")
        aCoder.encodeObject(self.overlaySettings, forKey: "overlaySettings")
        aCoder.encodeObject(self.item, forKey: "item")
        aCoder.encodeObject(self.resolution, forKey: "resolution")
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    required init? (coder aDecoder:NSCoder)
    {
        self.inputImageData =
            aDecoder.decodeObjectForKey("inputImageData") as! NSData
        self.inputImageBrightness =
            aDecoder.decodeObjectForKey("inputImageBrightness") as? Double
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
        self.hdBitrate =
            aDecoder.decodeObjectForKey("hdBitrate") as! Double
        self.blenderType =
            self.dynamicType.blenderTypeFromString(
                aDecoder.decodeObjectForKey("blenderType") as! String)
        self.cropRegion =
            (aDecoder.decodeObjectForKey("cropRegion") as? NSValue)?.CGRectValue()
        self.transform =
            (aDecoder.decodeObjectForKey("transform") as? NSValue)?.CGAffineTransformValue()
        self.hue =
            aDecoder.decodeObjectForKey("hue") as? Double
        self.zoomBlur =
            aDecoder.decodeObjectForKey("zoomBlur") as? Double
        self.overlaySettings =
            aDecoder.decodeObjectForKey("overlaySettings") as! NSData
        self.item =
            aDecoder.decodeObjectForKey("item") as! NSData
        self.resolution =
            aDecoder.decodeObjectForKey("resolution") as! String

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

    class func stringFromBlenderType (blenderType:Blender.BlenderType) -> String
    {
        let blenderTypeString:String
        switch blenderType
        {
        case .Multiply:
            blenderTypeString = "Multiply"
        case .HardLight:
            blenderTypeString = "HardLight"
        case .Screen:
            blenderTypeString = "Screen"
        case .Add:
            blenderTypeString = "Add"
        case .DesaturatedScreen:
            blenderTypeString = "DesaturatedScreen"
        default:
            assert(false)
            blenderTypeString = "Screen"
        }
        return blenderTypeString
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    class func blenderTypeFromString (blenderTypeString:String) -> Blender.BlenderType
    {
        let blenderType:Blender.BlenderType
        switch blenderTypeString
        {
        case "Multiply":
            blenderType = .Multiply
        case "HardLight":
            blenderType = .HardLight
        case "Screen":
            blenderType = .Screen
        case "Add":
            blenderType = .Add
        case "DesaturatedScreen":
            blenderType = .DesaturatedScreen
        default:
            assert(false)
            blenderType = .Screen
        }
        return blenderType
    }

    //----------------------------------------------------------------------------------------------
}



