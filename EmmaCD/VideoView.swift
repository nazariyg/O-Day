import AVFoundation


class VideoView : UIView
{
    var readyForDisplayClosure:(() -> Void)?
    var isPlayingClosure:(() -> Void)?

    private var observedPlayerLayer:AVPlayerLayer!
    private var observedPlayer:AVPlayer!

    //----------------------------------------------------------------------------------------------

    override init (frame:CGRect)
    {
        super.init(frame: frame)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    required init? (coder aDecoder:NSCoder)
    {
        super.init(coder: aDecoder)
    }

    //----------------------------------------------------------------------------------------------

    var videoURL:NSURL?
    {
        didSet {
            if let videoURL = self.videoURL
            {
                let player = AVPlayer(URL: videoURL)
                let playerLayer = self.layer as! AVPlayerLayer

                self.observedPlayerLayer?.removeObserver(self, forKeyPath: "readyForDisplay")
                playerLayer.addObserver(
                    self, forKeyPath: "readyForDisplay", options: [.Old, .New], context: nil)
                self.observedPlayerLayer = playerLayer

                playerLayer.player = player
            }
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    var player:AVPlayer?
    {
        return (self.layer as! AVPlayerLayer).player
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    var playerLayer:AVPlayerLayer
    {
        return self.layer as! AVPlayerLayer
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    var readyForDisplay:Bool
    {
        return (self.layer as! AVPlayerLayer).readyForDisplay
    }

    //----------------------------------------------------------------------------------------------

    deinit
    {
        self.observedPlayerLayer?.removeObserver(
            self, forKeyPath: "readyForDisplay")
        self.observedPlayer?.removeObserver(self, forKeyPath: "rate")
    }

    //----------------------------------------------------------------------------------------------

    override class func layerClass () -> AnyClass
    {
        return AVPlayerLayer.self
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func play ()
    {
        self.player?.play()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func pause ()
    {
        self.player?.pause()
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func currentTime () -> CMTime?
    {
        if let time = self.player?.currentTime()
        {
            return CMTIME_IS_VALID(time) ? time : nil
        }
        else
        {
            return nil
        }
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func seekToTime (time:CMTime)
    {
        self.player?.seekToTime(time)
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    func rate () -> Float?
    {
        return self.player?.rate
    }

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    override func observeValueForKeyPath (
        keyPath:String?, ofObject object:AnyObject?, change:[String: AnyObject]?,
        context:UnsafeMutablePointer<Void>)
    {
        dispatch_async(dispatch_get_main_queue()) {
            if let keyPath = keyPath, object = object, change = change
            {
                if self.observedPlayerLayer != nil &&
                   (object as? AVPlayerLayer) == self.observedPlayerLayer &&
                   keyPath == "readyForDisplay" &&
                   (change["old"] as! Int) == 0 && (change["new"] as! Int) == 1
                {
                    let player = (self.layer as! AVPlayerLayer).player!
                    self.observedPlayer?.removeObserver(self, forKeyPath: "rate")
                    player.addObserver(
                        self, forKeyPath: "rate", options: [.Old, .New], context: nil)
                    self.observedPlayer = player

                    self.readyForDisplayClosure?()
                }
                else if self.observedPlayer != nil &&
                        (object as? AVPlayer) == self.observedPlayer &&
                        keyPath == "rate" &&
                        (change["old"] as! Int) == 0 && (change["new"] as! Int) == 1
                {
                    self.isPlayingClosure?()
                }
            }
        }
    }

    //----------------------------------------------------------------------------------------------
}



