import Viewmorphic


//--------------------------------------------------------------------------------------------------

protocol TitleStyleChooserViewControllerInputOutput : class
{
    func provideInputDataForTitleStyleChooserViewController () -> [String: AnyObject]
    func acceptOutputDataFromTitleStyleChooserViewController (data:[String: AnyObject])
}

//--------------------------------------------------------------------------------------------------


class TitleStyleChooserViewController : UIViewController, UITableViewDataSource, UITableViewDelegate
{
    weak var inputOutputDelegate:TitleStyleChooserViewControllerInputOutput!
    private var inputData:[String: AnyObject]!

    @IBOutlet private weak var stylesTableViewContainer:UIView!
    @IBOutlet private weak var stylesTableView:UITableView!
    @IBOutlet private weak var backgroundImageViewContainer:UIView!
    @IBOutlet private weak var backgroundImageView:UIImageView!
    @IBOutlet private weak var cancelBN:UIButton!
    @IBOutlet private weak var doneBN:UIButton!
    @IBOutlet private weak var recolorSliderContainer:UIView!
    @IBOutlet private weak var blackLB:UILabel!
    @IBOutlet private weak var coloredLB:UILabel!

    private var titleValue:String!
    private var rowHeight:Double!
    private var stylesFocusOffset:Double!
    private var currFocusedStyleRowIndex:Int!
    private let cornerRadius = 12.0
    private var stylesTableViewPrevOffset:CGFloat!
    private var hueSlider:TGPDiscreteSlider!
    private var focusStyleIfNeededTimer:NSTimer!
    private let cellPaddingV = 12.0
    private var recolorSlider:TGPDiscreteSlider!
    private var currTextColor:UIColor!
    private var once = 0

    private var fontNames = [
        "MarketingScript",
        "Pacifico-Regular",
        "ThatsFontFolksItalic",
        "LittleDays",
        "ATypewriterForMe",
        "BallparkWeiner",
        "BlackJackRegular",
        "Kurnia",
        "Nickainley",
        "OstrichSans-Heavy",
        "Typewriter_Condensed_Demi",
        "SwistblnkMonthoers",
        "peachsundress~",
        "Wenceslas",
        "BlackboardUltra",
        "FinelinerScript",
        "akaFrivolity",
        "Sweethearts_Love_Letters",
        "Archistico-Bold",
        "Lobster1.4",
        "CardenioModern-Reg",
        "Playdate",
        "Typewriterhand",
        "DCC-Thealiensarecoming",
        "Feronia",
        "FonesiaLight",
        "goodvibesregular",
        "GruenewaldVA-Regular",
        "HurufMiranti",
        "MistressScript",
        "MoradoFelt-Regular",
        "SaniretroRegular",
        "SpringsteelSerif-Thin",
        "Ralphie_Brown",
        "Florence-Regular",
        "LitosScript",

        "AlwaysTogether",
        "BehindLines",
        "TegakBersambung_IWK",
        "Making-Lettering-Tall_demo",
        "SunshineState",
        "DirtyEgo",
        "Sketchtica",
        "ItalianRevolution",
        "OnTheWagon",
        "Punk'snotdead",
        "WeAreInLove",
        "ClaireHand-Light",
        "RhumbaScript",
        "RiotSquad",
        "OptimusPrinceps",
        "CollegeSemiCondensed",
        "SLABSTHIN",
        "SaladFingers",
        "Duality-Regular",
        "FontleroyBrown",
        "Jandles-Regular",
        "Love",
        "Maharani",
        "Scrappy-looking-demo",
        "BernardoModaSemibold",
        "Betty",
        "Darlin'Pop",
        "CastalStreet-Bold",
        "ChristmasCardII",
        "Dumbledor3Thin",
        "ank*",
        "calendarnotetfb",
        "Hoedown",
        "SkeletonKey",
        "take_out_the_garbage",
        "Witched",
        "ZombieHolocaust",

        "DINAlternate-Bold",
        "AvenirNext-UltraLight",
        "AvenirNextCondensed-Regular",
        "AmericanTypewriter-Light",
        "SnellRoundhand-Bold",
        //
        "HelveticaNeue-Thin",
        "HelveticaNeue",
        "HelveticaNeue-ThinItalic",
        "HelveticaNeue-Italic",
        "Cochin-Italic",
        "GillSans-LightItalic",
        "Palatino-Roman",
    ]

    //----------------------------------------------------------------------------------------------

    required init? (coder aDecoder:NSCoder)
    {
        super.init(coder: aDecoder)

        self.fontNames = self.fontNames.filter { (fontName:String) -> Bool in
            return UIFont(name: fontName, size: CGFloat(AppConfiguration.titleFontSize)) != nil
        }
    }

    //----------------------------------------------------------------------------------------------

    override func viewDidLoad ()
    {
        super.viewDidLoad()

        self.inputData =
            self.inputOutputDelegate.provideInputDataForTitleStyleChooserViewController()

        self.titleValue = (self.inputData["title"] as? String) ?? AppConfiguration.defaultTitle

        if self.titleValue.normLength <= AppConfiguration.titleMaxNumCharactersInLine
        {
            self.rowHeight = AppConfiguration.titleFontSize*1.4
            self.stylesFocusOffset = AppConfiguration.titleFontSize*2.2
        }
        else
        {
            self.rowHeight = AppConfiguration.titleFontSize*2.2
            self.stylesFocusOffset = AppConfiguration.titleFontSize*1.4
        }

        self.currFocusedStyleRowIndex = 0

        self.currTextColor = UIColor.whiteColor()

        self.view.backgroundColor = AppConfiguration.backgroundChooserBackgroundColor

        self.cancelBN.setTitleColor(AppConfiguration.bluishColor, forState: .Normal)
        self.doneBN.setTitleColor(AppConfiguration.bluishColor, forState: .Normal)

        self.backgroundImageViewContainer.layer.cornerRadius = CGFloat(self.cornerRadius)

        var backgroundImage:UIImage! = self.inputData["backgroundImage"] as? UIImage
        if backgroundImage == nil
        {
            backgroundImage = AppConfiguration.defaultPicture
        }
        backgroundImage =
            NodeSystem.filteredImageFromImage(
                backgroundImage, filterType: .GaussianBlur, settings: ["blurRadiusInPixels": 26.0])
        backgroundImage =
            NodeSystem.filteredImageFromImage(
                backgroundImage, filterType: .Gamma, settings: ["gamma": 1.5])
        self.backgroundImageView.image = backgroundImage
        self.backgroundImageView.layer.cornerRadius = CGFloat(self.cornerRadius)
        self.backgroundImageView.layer.masksToBounds = true

        self.stylesTableView.dataSource = self
        self.stylesTableView.delegate = self
        self.stylesTableView.separatorStyle = .None
        self.stylesTableView.backgroundColor = UIColor.clearColor()
        self.stylesTableView.rowHeight = CGFloat(self.rowHeight)
        self.stylesTableView.showsVerticalScrollIndicator = false
        self.stylesTableView.decelerationRate = 0.98
        self.stylesTableView.contentInset.top = CGFloat(self.stylesFocusOffset)
        self.stylesTableView.contentInset.bottom =
            self.view.bounds.height - CGFloat(self.stylesFocusOffset + self.rowHeight)

        self.focusStyleIfNeededTimer =
            NSTimer.scheduledTimerWithTimeInterval(
                0.1, target: self, selector: "focusStyleIfNeeded", userInfo: nil, repeats: true)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func viewDidLayoutSubviews ()
    {
        super.viewDidLayoutSubviews()

        dispatch_once(&self.once) {
            self.stylesTableViewContainer.layoutSubviews()

            self.backgroundImageViewContainer.layer.shadowOpacity = 0.33
            self.backgroundImageViewContainer.layer.shadowColor =
                AppConfiguration.bluishColor.CGColor
            self.backgroundImageViewContainer.layer.shadowRadius = 12.0
            self.backgroundImageViewContainer.layer.shadowOffset = CGSizeZero
            let shadowPath =
                UIBezierPath(
                    roundedRect: self.backgroundImageViewContainer.bounds,
                    cornerRadius: CGFloat(self.cornerRadius))
            self.backgroundImageViewContainer.layer.shadowPath = shadowPath.CGPath

            self.recolorSlider = TGPDiscreteSlider(frame: self.recolorSliderContainer.bounds)
            self.recolorSlider.value = 1
            self.recolorSlider.tickCount = 3
            self.recolorSlider.incrementValue = 1
            self.recolorSlider.tickStyle = 2
            self.makeupDiscreteSlider(self.recolorSlider)
            self.recolorSlider.addTarget(
                self, action: "recolorSliderValueChanged", forControlEvents: .ValueChanged)
            self.recolorSlider.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
            self.recolorSliderContainer.addSubview(self.recolorSlider)

            for label in [self.blackLB, self.coloredLB]
            {
                label.shownAlpha = 0.66
                label.layer.shadowColor = UIColor.blackColor().CGColor
                label.layer.shadowOpacity = 0.5
                label.layer.shadowOffset = CGSizeZero
                label.layer.shadowRadius = 3.0
            }

            let hueSliderPaddingX:CGFloat = 42.0
            let hueSliderPaddingY:CGFloat = 88.0
            var frame = self.view.frame
            frame.size.height = 50.0
            frame.origin.y += self.view.frame.height - frame.size.height - hueSliderPaddingY
            frame.insetInPlace(
                dx: (frame.width - (frame.width - hueSliderPaddingX*2.0))/2.0, dy: 0.0)
            frame.origin.x = hueSliderPaddingX
            self.hueSlider = TGPDiscreteSlider(frame: frame)
            self.hueSlider.tickCount = 512
            self.hueSlider.incrementValue = 1
            self.hueSlider.tickStyle = 3
            self.makeupDiscreteSlider(self.hueSlider)
            self.hueSlider.trackStyle = 4
            self.hueSlider.trackImage = "Spectrum"
            self.hueSlider.addTarget(
                self, action: "hueSliderValueChanged", forControlEvents: .ValueChanged)
            self.hueSlider.autoresizingMask = [.FlexibleRightMargin]
            self.hueSlider.alpha = 0.0
            self.view.addSubview(self.hueSlider)

            let focusTop =
                CGFloat(self.stylesFocusOffset)/self.stylesTableViewContainer.bounds.height
            let focusBottom =
                focusTop + CGFloat(self.rowHeight)/self.stylesTableViewContainer.bounds.height
            let colors = [
                UIColor.whiteColor().colorWithAlphaComponent(0.0).CGColor,
                UIColor.whiteColor().colorWithAlphaComponent(0.14).CGColor,
                UIColor.whiteColor().colorWithAlphaComponent(1.0).CGColor,
                UIColor.whiteColor().colorWithAlphaComponent(1.0).CGColor,
                UIColor.whiteColor().colorWithAlphaComponent(0.14).CGColor,
                UIColor.whiteColor().colorWithAlphaComponent(0.0).CGColor,
            ]
            let locations = [
                focusTop*0.15,
                focusTop - 0.033,
                focusTop,
                focusBottom,
                focusBottom + 0.033,
                focusBottom + (1.0 - focusBottom)*0.72,
            ]
            let stylesTableViewFadeOut = CAGradientLayer()
            stylesTableViewFadeOut.frame = self.stylesTableViewContainer.bounds
            stylesTableViewFadeOut.colors = colors
            stylesTableViewFadeOut.locations = locations
            self.stylesTableViewContainer.layer.mask = stylesTableViewFadeOut

            self.scrollViewDidScroll(self.stylesTableView)
            self.stylesTableView.reloadData()
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func makeupDiscreteSlider (slider:TGPDiscreteSlider)
    {
        slider.opaque = false
        slider.minimumValue = 0.0
        slider.trackStyle = 2
        slider.trackThickness = 0.5
        slider.tickSize = CGSize(width: 10.0, height: 10.0)
        slider.tintColor = AppConfiguration.bluishColor
        slider.thumbStyle = 2
        slider.thumbColor = UIColor.whiteColor()
        slider.thumbSize = CGSize(width: 30.0, height: 30.0)
        slider.thumbSRadius = 2.0
        slider.thumbSOffset = CGSizeZero
        slider.shownAlpha = 0.66

        slider.layer.shouldRasterize = true
        slider.layer.rasterizationScale = UIScreen.mainScreen().scale
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func viewWillAppear (animated:Bool)
    {
        super.viewWillAppear(animated)

        self.scrollViewDidScroll(self.stylesTableView)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func didReceiveMemoryWarning ()
    {
        super.didReceiveMemoryWarning()

        //
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func prefersStatusBarHidden () -> Bool
    {
        return true
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func numberOfSectionsInTableView (tableView:UITableView) -> Int
    {
        return 1
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func tableView (tableView:UITableView, numberOfRowsInSection section:Int) -> Int
    {
        return self.fontNames.count
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func tableView (tableView:UITableView, heightForRowAtIndexPath indexPath:NSIndexPath) -> CGFloat
    {
        return CGFloat(self.rowHeight)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func tableView (
        tableView:UITableView, cellForRowAtIndexPath indexPath:NSIndexPath) ->
            UITableViewCell
    {
        let cell =
            self.stylesTableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)

        for subview in cell.contentView.subviews
        {
            subview.removeFromSuperview()
        }

        let fontName = self.fontNames[indexPath.row]

        let refWidth = UIScreen.mainScreen().bounds.width
        let fontSize =
            AppConfiguration.titleFontSize*Double(cell.contentView.bounds.width/refWidth)

        let paddingFactor = CGFloat(AppConfiguration.titlePaddingHFactor)
        let titleFrame =
            cell.contentView.bounds.insetBy(
                dx: cell.contentView.bounds.width*paddingFactor,
                dy: CGFloat(self.cellPaddingV))

        let titleLB = TitleLabel(frame: titleFrame, fontSize: fontSize)
        titleLB.text = self.titleValue
        titleLB.fontName = fontName
        titleLB.textColor = self.currTextColor
        titleLB.doMidYCorrection = true

        cell.contentView.addSubview(titleLB)

        cell.contentView.clipsToBounds = false
        cell.clipsToBounds = false

        return cell
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func stylesTableViewFocus ()
    {
        if self.stylesTableView.dragging
        {
            if self.currFocusedStyleRowIndex == nil
            {
                self.currFocusedStyleRowIndex = 0
            }
            return
        }

        let normOffset = self.stylesTableView.contentOffset.y + CGFloat(self.stylesFocusOffset)

        let numRows = self.fontNames.count
        self.currFocusedStyleRowIndex =
            Int(round(normOffset/self.stylesTableView.contentSize.height*CGFloat(numRows)))
        if self.currFocusedStyleRowIndex < 0
        {
            self.currFocusedStyleRowIndex = 0
        }
        else if self.currFocusedStyleRowIndex > numRows - 1
        {
            self.currFocusedStyleRowIndex = numRows - 1
        }
        let snappedOffset = CGFloat(self.currFocusedStyleRowIndex)*CGFloat(self.rowHeight)

        let targetOffset = snappedOffset - CGFloat(self.stylesFocusOffset)
        if self.stylesTableView.contentOffset.y != targetOffset
        {
            self.stylesTableView.setContentOffset(CGPoint(x: 0.0, y: targetOffset), animated: true)
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func focusStyleIfNeeded ()
    {
        if let stylesTableViewPrevOffset = self.stylesTableViewPrevOffset where
           self.stylesTableView.contentOffset.y == stylesTableViewPrevOffset
        {
            self.stylesTableViewFocus()
        }

        self.stylesTableViewPrevOffset = self.stylesTableView.contentOffset.y
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func scrollViewWillBeginDragging (scrollView:UIScrollView)
    {
        self.stylesTableView.setContentOffset(self.stylesTableView.contentOffset, animated: false)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func recoloringStateDidChange ()
    {
        let sliderValueInt = Int(round(self.recolorSlider.value))

        if sliderValueInt == 0
        {
            self.currTextColor = UIColor(white: 0.1, alpha: 1.0)
        }
        else if sliderValueInt == 2
        {
            let hueSliderValue = Double(self.hueSlider.value)/Double(self.hueSlider.tickCount - 1)
            let tintColor =
                UIColor(
                    hue: CGFloat(hueSliderValue), saturation: 0.86, brightness: 0.96, alpha: 1.0)
            self.currTextColor = tintColor
        }
        else
        {
            self.currTextColor = UIColor.whiteColor()
        }
        self.stylesTableView.reloadData()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func recolorSliderValueChanged ()
    {
        self.recoloringStateDidChange()

        let sliderValueInt = Int(round(self.recolorSlider.value))
        self.hueSlider.hiddenAnimated = sliderValueInt != 2
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func hueSliderValueChanged ()
    {
        self.recoloringStateDidChange()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func scrollViewDidScroll (scrollView:UIScrollView)
    {
        for cell in self.stylesTableView.visibleCells
        {
            let y =
                self.stylesTableViewContainer.convertPoint(
                    CGPointZero, fromView: cell.contentView).y
            let diffY =
                (CGFloat(self.stylesFocusOffset) - y)/self.stylesTableViewContainer.bounds.height
            let absDiffY = abs(diffY)
            var r = -pow(absDiffY*1.25, 0.66)
            if diffY < 0.0
            {
                r = -r
            }
            var t = CATransform3DMakeRotation(r, 1.0, 0.0, 0.0)
            let s = 1.0 + pow(absDiffY*1.125, 2.0)
            t = CATransform3DScale(t, s, s, 1.0)
            cell.contentView.layer.transform = t
            var transform = CATransform3DIdentity
            var d = 1000.0*(1.0 - absDiffY)*1.5
            if d < 500.0
            {
                d = 500.0
            }
            transform.m34 = -1.0/d
            cell.layer.sublayerTransform = transform
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func dismiss ()
    {
        self.focusStyleIfNeededTimer?.invalidate()

        self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    private func outputTitleStyle ()
    {
        self.stylesTableViewFocus()

        let fontName = self.fontNames[self.currFocusedStyleRowIndex]
        let color = self.currTextColor

        let snapshotContainer = UIView()
        let snapshotSize = (self.inputData["snapshotSize"] as! NSValue).CGSizeValue()
        snapshotContainer.frame = CGRect(origin: CGPointZero, size: snapshotSize)
        let refWidth = UIScreen.mainScreen().bounds.width
        let fontSize = AppConfiguration.titleFontSize*Double(snapshotSize.width/refWidth)
        let paddingFactor = CGFloat(AppConfiguration.titlePaddingHFactor)
        let titleFrame =
            snapshotContainer.bounds.insetBy(
                dx: snapshotSize.width*paddingFactor,
                dy: 12.0)
        let titleLB = TitleLabel(frame: titleFrame, fontSize: fontSize)
        titleLB.text = "Sample Text"
        titleLB.fontName = fontName
        titleLB.textColor = color
        titleLB.doMidYCorrection = true
        snapshotContainer.addSubview(titleLB)
        UIGraphicsBeginImageContextWithOptions(snapshotContainer.bounds.size, false, 0)
        snapshotContainer.drawViewHierarchyInRect(
            snapshotContainer.bounds, afterScreenUpdates: true)
        let snapshot = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        let titleStyleRecord = TitleStyleRecord()
        titleStyleRecord.fontName = fontName
        titleStyleRecord.color = color
        titleStyleRecord.snapshot = snapshot

        var outputData = [String: AnyObject]()
        outputData["titleStyleRecord"] = titleStyleRecord
        self.inputOutputDelegate.acceptOutputDataFromTitleStyleChooserViewController(outputData)

        self.dismiss()
    }

    //----------------------------------------------------------------------------------------------

    @IBAction private func cancelBNAction ()
    {
        self.dismiss()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction private func doneBNAction ()
    {
        self.outputTitleStyle()
    }

    //----------------------------------------------------------------------------------------------
}



