func subAlignView (
    view:UIView, inSuperview superview:UIView, forAspect aspect:String, withCode subAlign:String)
{
    let containerAspect = superview.frame.height/superview.frame.width
    let snappedContainerAspect:String
    if abs(containerAspect - 16.0/9.0) < abs(containerAspect - 4.0/3.0)
    {
        snappedContainerAspect = "9x16"
    }
    else
    {
        snappedContainerAspect = "3x4"
    }

    var frame = superview.bounds
    if snappedContainerAspect == "9x16" && aspect == "3x4"
    {
        let height = superview.bounds.height
        let width = height/4.0*3.0
        let y = 0.0
        if subAlign == "l"
        {
            let x = 0.0
            frame = CGRectMake(CGFloat(x), CGFloat(y), CGFloat(width), CGFloat(height))
        }
        else if subAlign == "r"
        {
            let x = -(width - superview.bounds.width)
            frame = CGRectMake(CGFloat(x), CGFloat(y), CGFloat(width), CGFloat(height))
        }
    }
    else if snappedContainerAspect == "3x4" && aspect == "9x16"
    {
        let width = superview.bounds.width
        let height = width/9.0*16.0
        let x = 0.0
        if subAlign == "t"
        {
            let y = 0.0
            frame = CGRectMake(CGFloat(x), CGFloat(y), CGFloat(width), CGFloat(height))
        }
        else if subAlign == "b"
        {
            let y = -(height - superview.bounds.height)
            frame = CGRectMake(CGFloat(x), CGFloat(y), CGFloat(width), CGFloat(height))
        }
    }
    view.frame = frame
}



