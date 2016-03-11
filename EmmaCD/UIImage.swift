import CoreImage


extension UIImage
{
    //----------------------------------------------------------------------------------------------

    var pixelWidth:Int
    {
        return Int(self.size.width*self.scale)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    var pixelHeight:Int
    {
        return Int(self.size.height*self.scale)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func copiedImage () -> UIImage
    {
        UIGraphicsBeginImageContextWithOptions(self.size, false, 0)
        self.drawInRect(CGRect(origin: CGPointZero, size: self.size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func croppedImageInRect (cropRect:CGRect) -> UIImage
    {
        let scaledCropRect =
            CGRectMake(
                cropRect.origin.x*self.scale,
                cropRect.origin.y*self.scale,
                cropRect.size.width*self.scale,
                cropRect.size.height*self.scale)
        let cgCroppedImage = CGImageCreateWithImageInRect(self.CGImage, scaledCropRect)!
        let croppedImage =
            UIImage(CGImage: cgCroppedImage, scale: self.scale, orientation: self.imageOrientation)
        return croppedImage
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func resizedImageToNewPixelWidth (newPixelWidth:Int, newPixelHeight:Int) -> UIImage
    {
        // Resize with the highest interpolation quality.  Useful mostly for general-purpose
        // resampling and upsampling.

        let cgImage = self.CGImage
        let bitsPerComponent = CGImageGetBitsPerComponent(cgImage)
        let colorSpace = CGImageGetColorSpace(cgImage)
        let context =
            CGBitmapContextCreate(
                nil, newPixelWidth, newPixelHeight, bitsPerComponent, 0, colorSpace,
                CGImageAlphaInfo.PremultipliedLast.rawValue)
        CGContextSetInterpolationQuality(context, .High)
        CGContextDrawImage(
            context, CGRectMake(0.0, 0.0, CGFloat(newPixelWidth), CGFloat(newPixelHeight)), cgImage)
        let cgResizedImage = CGBitmapContextCreateImage(context)!
        let resizedImage =
            UIImage(CGImage: cgResizedImage, scale: self.scale, orientation: self.imageOrientation)
        return resizedImage
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func resizedImageWithScale (scale:Double) -> UIImage
    {
        let newPixelWidth = Int(round(Double(self.pixelWidth)*scale))
        let newPixelHeight = Int(round(Double(self.pixelHeight)*scale))
        return self.resizedImageToNewPixelWidth(newPixelWidth, newPixelHeight: newPixelHeight)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func scaledDownImageToNewPixelWidth (newPixelWidth:Int, newPixelHeight:Int) -> UIImage
    {
        // Lanczos resampling.  Useful mostly for downsampling.

        typealias CIImage = CoreImage.CIImage

        let scale = Double(newPixelWidth)/Double(self.pixelWidth)
        let oldAspectRatio = Double(self.pixelWidth)/Double(self.pixelHeight)
        let newAspectRatio = Double(newPixelWidth)/Double(newPixelHeight)
        let aspectRatio = newAspectRatio/oldAspectRatio

        let filter = CIFilter(name: "CILanczosScaleTransform")!
        filter.setValue(CIImage(CGImage: self.CGImage!), forKey: "inputImage")
        filter.setValue(scale, forKey: "inputScale")
        filter.setValue(aspectRatio, forKey: "inputAspectRatio")
        let outputImage = filter.valueForKey("outputImage") as! CIImage

        let context = CIContext(options: [kCIContextUseSoftwareRenderer: false])
        let scaledImage =
            UIImage(
                CGImage: context.createCGImage(outputImage, fromRect: outputImage.extent),
                scale: self.scale, orientation: self.imageOrientation)
        return scaledImage
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func normalizedImage () -> UIImage
    {
        if self.imageOrientation == .Up
        {
            return self
        }
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        self.drawInRect(CGRect(origin: CGPointZero, size: self.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage
    }

    //----------------------------------------------------------------------------------------------

    class func solidColorImageOfSize (size:CGSize, color:UIColor) -> UIImage
    {
        UIGraphicsBeginImageContext(size)
        let context = UIGraphicsGetCurrentContext()
        CGContextSetFillColorWithColor(context, color.CGColor)
        CGContextFillRect(context, CGRect(origin: CGPointZero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

    //----------------------------------------------------------------------------------------------
}



