class TitleLabel : UILabel
{
    var doMidYCorrection = false

    private static let labelPaddingFactors =
        UIEdgeInsets(top: 2.0, left: 2.0, bottom: 2.0, right: 2.0)
    private static let defaultColor = UIColor.whiteColor()
    private static let minFontSize = 10.0
    private static let shadowRadius = 3.0
    private static let shadowOpacity = 0.25

    private var fontSize:Double!
    private var internalFrameSet = false
    private var drawInnerLabelBounds = false
    private var refMidY:CGFloat!

    //----------------------------------------------------------------------------------------------

    init (frame:CGRect, fontSize:Double)
    {
        self.internalFrameSet = true
        super.init(
            frame: self.dynamicType.paddedTitleLabelFrameForReferenceFrame(
                frame, reverse: true, fontSize: fontSize))
        self.internalFrameSet = false

        self.fontSize = fontSize

        let refFont = UIFont(name: AppConfiguration.titleDefaultFontName, size: CGFloat(fontSize))!
        self.refMidY = (refFont.ascender + refFont.descender)/2.0

        self.textAlignment = .Center
        self.adjustsFontSizeToFitWidth = true
        self.minimumScaleFactor = CGFloat(self.dynamicType.minFontSize/self.fontSize)
        self.baselineAdjustment = .AlignCenters

        self.fontName = AppConfiguration.titleDefaultFontName
        self.font = UIFont(name: self.fontName, size: CGFloat(fontSize))

        self.textColor = self.dynamicType.defaultColor

        self.text = AppConfiguration.defaultTitle
        self.didSetText()

        self.layer.shouldRasterize = true
        self.layer.rasterizationScale = UIScreen.mainScreen().scale
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    required init? (coder aDecoder:NSCoder)
    {
        super.init(coder: aDecoder)
    }

    //----------------------------------------------------------------------------------------------

    override var frame:CGRect
    {
        didSet {
            if self.internalFrameSet
            {
                return
            }

            self.internalFrameSet = true
            self.frame =
                self.dynamicType.paddedTitleLabelFrameForReferenceFrame(
                    self.frame, reverse: true, fontSize: self.fontSize)
            self.internalFrameSet = false
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    var fontName:String!
    {
        didSet {
            if self.fontName == nil
            {
                return
            }

            if let text = self.text
            {
                if text.normLength <= AppConfiguration.titleMaxNumCharactersInLine
                {
                    self.font = UIFont(name: self.fontName, size: CGFloat(self.fontSize))
                }
                else
                {
                    let useFontSize = self.fontSize*AppConfiguration.titleTwoLinesScale
                    self.font = UIFont(name: self.fontName, size: CGFloat(useFontSize))
                }
            }
            else
            {
                self.font = UIFont(name: self.fontName, size: CGFloat(self.fontSize))
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override var text:String?
    {
        didSet {
            self.didSetText()
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func didSetText ()
    {
        if let text = self.text
        {
            if text.normLength <= AppConfiguration.titleMaxNumCharactersInLine
            {
                self.numberOfLines = 1

                self.font = UIFont(name: self.fontName, size: CGFloat(self.fontSize))
            }
            else
            {
                self.numberOfLines = 2

                let useFontSize = self.fontSize*AppConfiguration.titleTwoLinesScale
                self.font = UIFont(name: self.fontName, size: CGFloat(useFontSize))
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override var textColor:UIColor!
    {
        didSet {
            if self.textColor == nil
            {
                return
            }

            let textColorIsWhite = self.textColor == UIColor.whiteColor()
            self.layer.shadowColor =
                textColorIsWhite ?
                    UIColor.blackColor().CGColor :
                    UIColor.whiteColor().CGColor
            self.layer.shadowRadius = CGFloat(self.dynamicType.shadowRadius)
            self.layer.shadowOpacity = Float(self.dynamicType.shadowOpacity)
            if !textColorIsWhite
            {
                self.layer.shadowOpacity *= 2.0
            }
            self.layer.shadowOffset = CGSizeZero
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func drawTextInRect (rect:CGRect)
    {
        let paddedRect =
            self.dynamicType.paddedTitleLabelFrameForReferenceFrame(
                rect, reverse: false, fontSize: self.fontSize)

        if self.drawInnerLabelBounds
        {
            let cx = UIGraphicsGetCurrentContext()
            CGContextSetLineWidth(cx, 1.0)
            CGContextSetStrokeColorWithColor(cx, UIColor.greenColor().CGColor)
            CGContextAddRect(cx, paddedRect)
            CGContextStrokePath(cx)
        }

        super.drawTextInRect(paddedRect)

        if self.doMidYCorrection
        {
            let varName = "actualScaleFactor"
            let adjustedTextScale = self.valueForKey(varName) as! CGFloat
            let midY = (self.font.ascender + self.font.descender)/2.0
            let translation = (self.refMidY - midY)*adjustedTextScale
            let transform = CGAffineTransformMakeTranslation(0.0, translation)
            self.transform = transform
        }
    }

    //----------------------------------------------------------------------------------------------

    class func paddedTitleLabelFrameForReferenceFrame (
        frame:CGRect, reverse:Bool, fontSize:Double) ->
            CGRect
    {
        var value = CGFloat(fontSize)
        if reverse
        {
            value *= -1.0
        }
        let padding =
            UIEdgeInsets(
                top: value*self.labelPaddingFactors.top,
                left: value*self.labelPaddingFactors.left,
                bottom: value*self.labelPaddingFactors.bottom,
                right: value*self.labelPaddingFactors.right)
        return UIEdgeInsetsInsetRect(frame, padding)
    }

    //----------------------------------------------------------------------------------------------
}



