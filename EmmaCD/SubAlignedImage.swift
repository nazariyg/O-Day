func subAlignedImage (image:UIImage, forAspectSize:CGSize, withCode subAlign:String) -> UIImage
{
    let imageAspect:String
    let imageAspectRatio = image.size.height/image.size.width
    if abs(imageAspectRatio - 16.0/9.0) < abs(imageAspectRatio - 4.0/3.0)
    {
        imageAspect = "9x16"
    }
    else
    {
        imageAspect = "3x4"
    }

    let containerAspect:String
    let forAspectRatio = forAspectSize.height/forAspectSize.width
    if abs(forAspectRatio - 16.0/9.0) < abs(forAspectRatio - 4.0/3.0)
    {
        containerAspect = "9x16"
    }
    else
    {
        containerAspect = "3x4"
    }

    var resImage = image

    let imageRect = CGRect(origin: CGPointZero, size: image.size)
    if containerAspect == "9x16" && imageAspect == "3x4"
    {
        let subWidth:CGFloat
        subWidth = image.size.height/forAspectSize.height*forAspectSize.width
        let subHeight = image.size.height
        if subAlign == "l"
        {
            // Left.
            let subRect =
                CGRectIntersection(
                    imageRect,
                    CGRectMake(0.0, 0.0, subWidth, subHeight))
            if !CGRectIsNull(subRect)
            {
                resImage = image.croppedImageInRect(subRect)
            }
        }
        else if subAlign == "r"
        {
            // Right.
            let subRect =
                CGRectIntersection(
                    imageRect,
                    CGRectMake(image.size.width - subWidth, 0.0, subWidth, subHeight))
            if !CGRectIsNull(subRect)
            {
                resImage = image.croppedImageInRect(subRect)
            }
        }
        else
        {
            // Center.
            let subRect =
                CGRectIntersection(
                    imageRect,
                    CGRectMake((image.size.width - subWidth)/2.0, 0.0, subWidth, subHeight))
            if !CGRectIsNull(subRect)
            {
                resImage = image.croppedImageInRect(subRect)
            }
        }
    }
    else if containerAspect == "3x4" && imageAspect == "9x16"
    {
        let subWidth = image.size.width
        let subHeight:CGFloat
        subHeight = image.size.width/forAspectSize.width*forAspectSize.height
        if subAlign == "t"
        {
            // Top.
            let subRect =
                CGRectIntersection(
                    imageRect,
                    CGRectMake(0.0, 0.0, subWidth, subHeight))
            if !CGRectIsNull(subRect)
            {
                resImage = image.croppedImageInRect(subRect)
            }
        }
        else if subAlign == "b"
        {
            // Bottom.
            let subRect =
                CGRectIntersection(
                    imageRect,
                    CGRectMake(0.0, image.size.height - subHeight, subWidth, subHeight))
            if !CGRectIsNull(subRect)
            {
                resImage = image.croppedImageInRect(subRect)
            }
        }
        else
        {
            // Center.
            let subRect =
                CGRectIntersection(
                    imageRect,
                    CGRectMake(0.0, (image.size.height - subHeight)/2.0, subWidth, subHeight))
            if !CGRectIsNull(subRect)
            {
                resImage = image.croppedImageInRect(subRect)
            }
        }
    }

    return resImage
}



