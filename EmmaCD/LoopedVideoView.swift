import AVFoundation


class LoopedVideoView : VideoView
{
    var totallySeamlessLoopsPowerOfTwo = 6

    private var playedToEndObserver:NSObjectProtocol!

    //----------------------------------------------------------------------------------------------

    override var videoURL:NSURL?
    {
        didSet {
            if let playedToEndObserver = self.playedToEndObserver
            {
                NSNotificationCenter.defaultCenter().removeObserver(playedToEndObserver)
            }

            if let videoURL = self.videoURL
            {
                let asset = AVURLAsset(URL: videoURL, options: nil)

                var nextComp:AVMutableComposition!

                var prevComp = AVMutableComposition()
                let timeRange =
                    CMTimeRangeMake(
                        kCMTimeZero,
                        CMTimeMake(asset.duration.value, asset.duration.timescale))
                _ = try? prevComp.insertTimeRange(timeRange, ofAsset: asset, atTime: kCMTimeZero)
                for _ in 0..<self.totallySeamlessLoopsPowerOfTwo
                {
                    nextComp = prevComp.mutableCopy() as! AVMutableComposition
                    let timeRange =
                        CMTimeRangeMake(
                            kCMTimeZero,
                            CMTimeMake(prevComp.duration.value, prevComp.duration.timescale))
                    let inserted:Void? =
                        try? nextComp.insertTimeRange(
                            timeRange, ofAsset: prevComp, atTime: nextComp.duration)
                    if inserted == nil
                    {
                        break
                    }
                    prevComp = nextComp
                }

                let player = AVPlayer(playerItem: AVPlayerItem(asset: nextComp))

                self.playedToEndObserver =
                    NSNotificationCenter.defaultCenter().addObserverForName(
                        AVPlayerItemDidPlayToEndTimeNotification, object: player.currentItem,
                        queue: NSOperationQueue.mainQueue()) { [weak player] _ in
                            guard let player = player else
                            {
                                return
                            }

                            player.seekToTime(kCMTimeZero)
                            player.play()
                        }

                (self.layer as! AVPlayerLayer).player = player
            }
        }
    }

    //----------------------------------------------------------------------------------------------

    deinit
    {
        if let playedToEndObserver = self.playedToEndObserver
        {
            NSNotificationCenter.defaultCenter().removeObserver(playedToEndObserver)
        }
    }

    //----------------------------------------------------------------------------------------------
}



