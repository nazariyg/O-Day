class TintTextField : UITextField
{
    var tintedClearImage:UIImage?

    //----------------------------------------------------------------------------------------------

    override func layoutSubviews ()
    {
        super.layoutSubviews()
        tintClearImage()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func tintClearImage ()
    {
        for view in subviews
        {
            if view is UIButton
            {
                let button = view as! UIButton
                if let uiImage = button.imageForState(.Highlighted)
                {
                    if tintedClearImage == nil
                    {
                        tintedClearImage = self.dynamicType.tintImage(uiImage, color: tintColor)
                    }
                    button.setImage(tintedClearImage, forState: .Normal)
                    button.setImage(tintedClearImage, forState: .Highlighted)
                }
            }
        }
    }

    //----------------------------------------------------------------------------------------------

    class func tintImage (image:UIImage, color:UIColor) -> UIImage
    {
        let size = image.size
        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        let context = UIGraphicsGetCurrentContext()
        image.drawAtPoint(CGPointZero, blendMode: .Normal, alpha: 1.0)
        CGContextSetFillColorWithColor(context, color.CGColor)
        CGContextSetBlendMode(context, .SourceIn)
        CGContextSetAlpha(context, 1.0)
        let rect =
            CGRectMake(
                CGPointZero.x,
                CGPointZero.y,
                image.size.width,
                image.size.height)
        CGContextFillRect(UIGraphicsGetCurrentContext(), rect)
        let tintedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return tintedImage
    }

    //----------------------------------------------------------------------------------------------
}



