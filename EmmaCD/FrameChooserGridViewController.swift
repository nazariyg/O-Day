//--------------------------------------------------------------------------------------------------

protocol FrameChooserGridViewControllerInputOutput : class
{
    func provideInputDataForFrameChooserGridViewController () -> [String: AnyObject]
    func acceptOutputDataFromFrameChooserGridViewController (data:[String: AnyObject])
}

//--------------------------------------------------------------------------------------------------


class FrameChooserGridViewController : UINavigationController, UICollectionViewDataSource,
                                       UICollectionViewDelegate
{
    weak var inputOutputDelegate:FrameChooserGridViewControllerInputOutput!
    private var slots:[SlotRecord]!
    private var collectionViewController:UICollectionViewController!

    //----------------------------------------------------------------------------------------------

    override func viewDidLoad ()
    {
        super.viewDidLoad()

        let inputData =
            self.inputOutputDelegate.provideInputDataForFrameChooserGridViewController()
        self.slots = inputData["slots"] as! [SlotRecord]

        self.collectionViewController = self.topViewController as! UICollectionViewController
        self.collectionViewController.collectionView!.dataSource = self
        self.collectionViewController.collectionView!.delegate = self

        let flowLayout =
            self.collectionViewController.collectionViewLayout as! UICollectionViewFlowLayout
        flowLayout.sectionInset = UIEdgeInsets(top: 12.0, left: 12.0, bottom: 12.0, right: 12.0)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func didReceiveMemoryWarning ()
    {
        super.didReceiveMemoryWarning()

        //
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func numberOfSectionsInCollectionView (collectionView:UICollectionView) -> Int
    {
        return 1
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func collectionView (collectionView:UICollectionView, numberOfItemsInSection section:Int) -> Int
    {
        return self.slots.count
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func collectionView (
        collectionView:UICollectionView, cellForItemAtIndexPath indexPath:NSIndexPath) ->
            UICollectionViewCell
    {
        let cell =
            collectionView.dequeueReusableCellWithReuseIdentifier("Cell", forIndexPath: indexPath)

        for subview in cell.contentView.subviews
        {
            subview.removeFromSuperview()
        }

        let slotRecord = self.slots[indexPath.item]
        if slotRecord.isNoFrameSlot
        {
            let noFrameLabel = UILabel(frame: cell.contentView.bounds)
            noFrameLabel.text = "Frameless"
            noFrameLabel.textAlignment = .Center
            noFrameLabel.textColor = UIColor.whiteColor()
            noFrameLabel.font = UIFont.systemFontOfSize(14.0)
            noFrameLabel.alpha = 0.75
            cell.contentView.addSubview(noFrameLabel)
        }
        else
        {
            let frameImageView = UIImageView(frame: cell.contentView.bounds)
            frameImageView.contentMode = .ScaleAspectFit
            frameImageView.image = slotRecord.frameThumb
            cell.contentView.addSubview(frameImageView)
        }

        return cell
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func collectionView (
        collectionView:UICollectionView, didSelectItemAtIndexPath indexPath:NSIndexPath)
    {
        var outputData = [String: AnyObject]()
        outputData["slotIndex"] = indexPath.item
        self.inputOutputDelegate.acceptOutputDataFromFrameChooserGridViewController(outputData)

        self.dismiss(nil)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func dismiss (sender:AnyObject?)
    {
        self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }

    //----------------------------------------------------------------------------------------------
}



