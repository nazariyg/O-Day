class UISegmentedTextControl : UISegmentedControl
{
    private var didInit = false

    //----------------------------------------------------------------------------------------------

    override init (frame:CGRect)
    {
        super.init(frame: frame)

        self.commonInit()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    required init? (coder aDecoder:NSCoder)
    {
        super.init(coder: aDecoder)

        self.commonInit()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func commonInit ()
    {
        self.textFontNormal = UIFont.systemFontOfSize(16.0)
        self.textColorNormal = self.tintColor
        self.textFontSelected = UIFont.boldSystemFontOfSize(18.0)
        self.textColorSelected = self.tintColor

        let backgroundImage =
            UIImage.solidColorImageOfSize(
                self.bounds.size, color: UIColor.clearColor())
        let dividerImage =
            UIImage.solidColorImageOfSize(
                CGSize(width: 1.0, height: 1.0), color: UIColor.clearColor())
        self.setBackgroundImage(backgroundImage, forState: .Normal, barMetrics: .Default)
        self.setDividerImage(
            dividerImage, forLeftSegmentState: .Normal, rightSegmentState: .Normal,
            barMetrics: .Default)

        self.didInit = true

        self.updateAppearance()
    }

    //----------------------------------------------------------------------------------------------

    var textFontNormal:UIFont!
    {
        didSet {
            self.updateAppearance()
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    var textColorNormal:UIColor!
    {
        didSet {
            self.updateAppearance()
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    var textFontSelected:UIFont!
    {
        didSet {
            self.updateAppearance()
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    var textColorSelected:UIColor!
    {
        didSet {
            self.updateAppearance()
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func updateAppearance ()
    {
        if !self.didInit
        {
            return
        }

        self.setTitleTextAttributes([
                NSFontAttributeName: self.textFontNormal,
                NSForegroundColorAttributeName: self.textColorNormal],
            forState: .Normal)
        self.setTitleTextAttributes([
                NSFontAttributeName: self.textFontSelected,
                NSForegroundColorAttributeName: self.textColorSelected],
            forState: .Selected)
    }

    //----------------------------------------------------------------------------------------------
}



