import UIKit


//--------------------------------------------------------------------------------------------------

protocol BackgroundChooserViewControllerOutput : class
{
    func provideInputDataForBackgroundChooserViewController () -> [String: AnyObject]
    func acceptOutputDataFromBackgroundChooserViewController (data:[String: AnyObject])
}

//--------------------------------------------------------------------------------------------------


class BackgroundChooserViewController : UIViewController,
                                        OverlayChooserViewControllerOutput,
                                        PictureChooserViewControllerOutput//,
                                        //VideoChooserViewControllerOutput
{
    weak var inputOutputDelegate:BackgroundChooserViewControllerOutput!
    private var inputData:[String: AnyObject]!

    @IBOutlet private weak var backgroundKindSC:UISegmentedTextControl!
    @IBOutlet private weak var panelView:UIView!

    private let initialBackgroundKindIndex = 0
    private var backgroundKinds:[UIViewController]!
    private var currBackgroundKind:UIViewController!

    //----------------------------------------------------------------------------------------------

    override func viewDidLoad ()
    {
        super.viewDidLoad()

        self.inputData =
            self.inputOutputDelegate.provideInputDataForBackgroundChooserViewController()

        self.view.backgroundColor = AppConfiguration.backgroundChooserBackgroundColor

        self.backgroundKindSC.textFontNormal = UIFont.systemFontOfSize(16.0)
        self.backgroundKindSC.textFontSelected = UIFont.boldSystemFontOfSize(18.0)
        self.backgroundKindSC.textColorNormal = AppConfiguration.bluishColorDarker
        self.backgroundKindSC.textColorSelected = AppConfiguration.bluishColor

        if UIDevice.currentDevice().userInterfaceIdiom == .Pad
        {
            self.backgroundKindSC.transform = CGAffineTransformMakeScale(1.25, 1.25)
        }

        self.backgroundKinds = []
        self.backgroundKinds.append(
            UIStoryboard(name: "OverlayChooser", bundle: nil).instantiateInitialViewController()!)
        self.backgroundKinds.append(
            UIStoryboard(name: "PictureChooser", bundle: nil).instantiateInitialViewController()!)

        (self.backgroundKinds[0] as! OverlayChooserViewController).inputOutputDelegate = self
        (self.backgroundKinds[1] as! PictureChooserViewController).outputDelegate = self

        let initialBackgroundKind = self.backgroundKinds[self.initialBackgroundKindIndex]
        self.addChildViewController(initialBackgroundKind)
        initialBackgroundKind.view.frame = self.panelView.bounds
        self.panelView.addSubview(initialBackgroundKind.view)
        initialBackgroundKind.didMoveToParentViewController(self)
        self.currBackgroundKind = initialBackgroundKind

        backgroundKindSC.selectedSegmentIndex = self.initialBackgroundKindIndex
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func didReceiveMemoryWarning ()
    {
        super.didReceiveMemoryWarning()

        //
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func dismiss (fromOverlayChooser:Bool = false)
    {
        if !fromOverlayChooser
        {
            on_main() {
                (self.backgroundKinds[0] as! OverlayChooserViewController).dismiss()
            }
            return
        }

        self.view.endEditing(true)

        self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func prefersStatusBarHidden () -> Bool
    {
        return true
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    @IBAction private func backgroundKindSCAction ()
    {
        appD().ignoringInteractionEvents.begin()

        self.currBackgroundKind.willMoveToParentViewController(nil)
        let nextBackgroundKind = self.backgroundKinds[self.backgroundKindSC.selectedSegmentIndex]
        self.addChildViewController(nextBackgroundKind)
        nextBackgroundKind.view.frame = self.panelView.bounds
        self.transitionFromViewController(
            self.currBackgroundKind, toViewController: nextBackgroundKind, duration: 0.1,
            options: [.TransitionCrossDissolve], animations: nil, completion: { _ in
                nextBackgroundKind.didMoveToParentViewController(self)
                self.currBackgroundKind.removeFromParentViewController()
                self.currBackgroundKind = nextBackgroundKind

                appD().ignoringInteractionEvents.end()
            })
    }

    //----------------------------------------------------------------------------------------------

    func provideInputDataForOverlayChooserViewController () -> [String: AnyObject]
    {
        var data = [String: AnyObject]()
        if let backgroundOverlayRecord =
           self.inputData["backgroundOverlayRecord"] as? BackgroundOverlayRecord
        {
            data["backgroundOverlayRecord"] = backgroundOverlayRecord
        }
        else if let backgroundCustomPictureRecord =
                self.inputData["backgroundCustomPictureRecord"] as? BackgroundCustomPictureRecord
        {
            data["backgroundCustomPictureRecord"] = backgroundCustomPictureRecord
        }
        return data
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func acceptOutputDataFromOverlayChooserViewController (data:[String: AnyObject])
    {
        var outputData = [String: AnyObject]()
        outputData["backgroundRecord"] =
            data["backgroundOverlayRecord"] ?? data["backgroundCustomPictureRecord"]
        self.inputOutputDelegate.acceptOutputDataFromBackgroundChooserViewController(outputData)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func acceptOutputDataFromPictureChooserViewController (data:[String: AnyObject])
    {
        var outputData = [String: AnyObject]()
        outputData["backgroundRecord"] = data["backgroundPictureRecord"]
        self.inputOutputDelegate.acceptOutputDataFromBackgroundChooserViewController(outputData)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func acceptOutputDataFromVideoChooserViewController (data:[String: AnyObject])
    {
        var outputData = [String: AnyObject]()
        outputData["backgroundRecord"] = data["backgroundVideoRecord"]
        self.inputOutputDelegate.acceptOutputDataFromBackgroundChooserViewController(outputData)
    }

    //----------------------------------------------------------------------------------------------
}



