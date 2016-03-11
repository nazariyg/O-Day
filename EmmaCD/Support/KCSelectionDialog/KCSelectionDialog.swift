//
//  KCSelectionDialog.swift
//  Sample
//
//  Created by LeeSunhyoup on 2015. 9. 28..
//  Copyright © 2015년 KCSelectionView. All rights reserved.
//

import UIKit

public class KCSelectionDialog: UIView {
    public var items: [KCSelectionDialogItem] = []

    public var dialogWidth: CGFloat = 300
    public var titleHeight: CGFloat = 50
    public var buttonHeight: CGFloat = 50
    public var closeButtonHeight: CGFloat = 50
    public var cornerRadius: CGFloat = 7
    public var itemPadding: CGFloat = 10
    public var buttonTextFontSize: CGFloat = 17
    
    public var useMotionEffects: Bool = true
    public var motionEffectExtent: Int = 10
    
    public var title: String? = "Title"
    public var closeButtonTitle: String? = "Close"
    public var closeButtonColor: UIColor?
    public var closeButtonColorHighlighted: UIColor?
    public var buttonBackgroundColorHighlighted: UIColor?
    
    private var dialogView: UIView?
    
    public init() {
        super.init(frame: CGRectMake(0, 0, UIScreen.mainScreen().bounds.size.width, UIScreen.mainScreen().bounds.size.height))
        setObservers()
    }
    
    public init(title: String, closeButtonTitle cancelString: String) {
        self.title = title
        self.closeButtonTitle = cancelString
        super.init(frame: CGRectMake(0, 0, UIScreen.mainScreen().bounds.size.width, UIScreen.mainScreen().bounds.size.height))
        setObservers()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setObservers()
    }
    
    public func show() {
        dialogView = createDialogView()
        guard let dialogView = dialogView else { return }
        
        //self.layer.shouldRasterize = true
        //self.layer.rasterizationScale = UIScreen.mainScreen().scale

        self.backgroundColor = UIColor(white: 0, alpha: 0)

        dialogView.layer.opacity = 0.5
        dialogView.layer.transform = CATransform3DMakeScale(1.3, 1.3, 1)
        self.addSubview(dialogView)
        
        self.frame = CGRectMake(0, 0, self.frame.width, self.frame.height)
        UIApplication.sharedApplication().keyWindow?.addSubview(self)
        
        UIView.animateWithDuration(0.2, delay: 0, options: UIViewAnimationOptions.CurveEaseInOut, animations: {
            self.backgroundColor = UIColor(white: 0, alpha: 0.4)
            dialogView.layer.opacity = 1
            dialogView.layer.transform = CATransform3DMakeScale(1, 1, 1)
            }, completion: nil)
    }
    
    public func close() {
        guard let dialogView = dialogView else { return }
        let currentTransform = dialogView.layer.transform
        
        dialogView.layer.opacity = 1
        
        UIView.animateWithDuration(0.2, delay: 0, options: UIViewAnimationOptions.TransitionNone, animations: {
            self.backgroundColor = UIColor(white: 0, alpha: 0)
            dialogView.layer.transform = CATransform3DConcat(currentTransform, CATransform3DMakeScale(0.6, 0.6, 1))
            dialogView.layer.opacity = 0
            }, completion: { (finished: Bool) in
                for view in self.subviews {
                    view.removeFromSuperview()
                }
                
                self.removeFromSuperview()
        })
    }
    
    public func addItem(item itemTitle: String) {
        let item = KCSelectionDialogItem(item: itemTitle)
        items.append(item)
    }
    
    public func addItem(item itemTitle: String, icon: UIImage) {
        let item = KCSelectionDialogItem(item: itemTitle, icon: icon)
        items.append(item)
    }
    
    public func addItem(item itemTitle: String, didTapHandler: (() -> Void)) {
        let item = KCSelectionDialogItem(item: itemTitle, didTapHandler: didTapHandler)
        items.append(item)
    }
    
    public func addItem(item itemTitle: String, icon: UIImage, didTapHandler: (() -> Void)) {
        let item = KCSelectionDialogItem(item: itemTitle, icon: icon, didTapHandler: didTapHandler)
        items.append(item)
    }
    
    public func addItem(item: KCSelectionDialogItem) {
        items.append(item)
    }
    
    private func setObservers() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "deviceOrientationDidChange:", name: UIDeviceOrientationDidChangeNotification, object: nil)
    }
    
    private func createDialogView() -> UIView {
        let screenSize = self.calculateScreenSize()
        let dialogSize = self.calculateDialogSize()

        let frame = CGRectMake(
            (screenSize.width - dialogSize.width) / 2,
            (screenSize.height - dialogSize.height) / 2,
            dialogSize.width,
            dialogSize.height
        )
        let subFrame = CGRect(origin: CGPointZero, size: frame.size)

        let view = UIView(frame: subFrame)
        view.addSubview(createTitleLabel())
        view.addSubview(createContainerView())
        view.addSubview(createCloseButton())

        let be = UIBlurEffect(style: .Light)
        let blView = UIVisualEffectView(effect: be)
        blView.frame = subFrame
        let viView = UIVisualEffectView(effect: UIVibrancyEffect(forBlurEffect: be))
        viView.frame = subFrame
        viView.backgroundColor = self.backgroundColor
        blView.contentView.addSubview(viView)
        viView.contentView.addSubview(view)

        let dialogView = UIView(frame: frame)
        dialogView.addSubview(blView)
        dialogView.layer.cornerRadius = cornerRadius
        dialogView.layer.masksToBounds = true

        if useMotionEffects {
            applyMotionEffects(dialogView)
        }

        //dialogView.layer.shouldRasterize = true
        //dialogView.layer.rasterizationScale = UIScreen.mainScreen().scale

        return dialogView
    }
    
    private func createContainerView() -> UIView {
        let containerView = UIView(frame: CGRectMake(0, titleHeight, dialogWidth, CGFloat(items.count)*buttonHeight))
        for (index, item) in items.enumerate() {
            let itemButton = UIButton(frame: CGRectMake(0, CGFloat(index)*buttonHeight + 1, dialogWidth, buttonHeight - 1))
            let itemTitleLabel = UILabel(frame: CGRectMake(itemPadding, 0, 255, buttonHeight))
            itemTitleLabel.text = item.itemTitle
            itemTitleLabel.textColor = self.tintColor
            itemTitleLabel.font = UIFont.systemFontOfSize(buttonTextFontSize)
            itemButton.addSubview(itemTitleLabel)
            let highColor =
                self.buttonBackgroundColorHighlighted ??
                    UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
            itemButton.setBackgroundImage(UIImage.createImageWithColor(highColor), forState: .Highlighted)
            itemButton.addTarget(item, action: "handlerTap", forControlEvents: .TouchUpInside)
            itemButton.addTarget(self, action: "close", forControlEvents: .TouchUpInside)
            
            if item.icon != nil {
                let scale:CGFloat = 0.54
                let imageWidth = item.icon!.size.width*scale
                let imageHeight = item.icon!.size.height*scale
                itemTitleLabel.frame.origin.x = imageWidth + itemPadding*2
                itemTitleLabel.frame.size.width -= imageWidth + itemPadding
                let itemIcon = UIImageView(frame: CGRectMake(itemPadding, (buttonHeight - imageHeight)/2.0, imageWidth, imageHeight))
                itemIcon.image = item.icon
                itemButton.addSubview(itemIcon)
            }
            containerView.addSubview(itemButton)
            
            let divider = UIView(frame: CGRectMake(0, CGFloat(index)*buttonHeight+buttonHeight, dialogWidth, 0.5))
            divider.backgroundColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
            //containerView.addSubview(divider)
            containerView.frame.size.height += buttonHeight
        }

        return containerView
    }
    
    private func createTitleLabel() -> UIView {
        let view = UILabel(frame: CGRectMake(0, 0, dialogWidth, titleHeight))
        
        view.text = title
        view.textColor = self.tintColor
        view.textAlignment = .Center
        view.font = UIFont.boldSystemFontOfSize(18.0)
        
        let bottomLayer = CALayer()
        bottomLayer.frame = CGRectMake(0, view.bounds.size.height, view.bounds.size.width, 0.5)
        bottomLayer.backgroundColor = UIColor(red: 198/255, green: 198/255, blue: 198/255, alpha: 1).CGColor
        view.layer.addSublayer(bottomLayer)
        
        return view
    }
    
    private func createCloseButton() -> UIButton {
        let button = UIButton(frame: CGRectMake(0, titleHeight + CGFloat(items.count)*buttonHeight, dialogWidth, closeButtonHeight))
        
        button.addTarget(self, action: "close", forControlEvents: UIControlEvents.TouchUpInside)
        
        let colorNormal = closeButtonColor != nil ? closeButtonColor : button.tintColor
        let colorHighlighted = closeButtonColorHighlighted != nil ? closeButtonColorHighlighted : colorNormal?.colorWithAlphaComponent(0.5)
        
        button.setTitle(closeButtonTitle, forState: UIControlState.Normal)
        button.setTitleColor(colorNormal, forState: UIControlState.Normal)
        button.setTitleColor(colorHighlighted, forState: UIControlState.Highlighted)
        button.setTitleColor(colorHighlighted, forState: UIControlState.Disabled)
        
        let topLayer = CALayer()
        topLayer.frame = CGRectMake(0, 0, dialogWidth, 0.5)
        topLayer.backgroundColor = UIColor(red: 198/255, green: 198/255, blue: 198/255, alpha: 1).CGColor
        button.layer.addSublayer(topLayer)
        
        return button
    }
    
    private func calculateDialogSize() -> CGSize {
        return CGSizeMake(dialogWidth, CGFloat(items.count)*buttonHeight + titleHeight + closeButtonHeight)
    }
    
    private func calculateScreenSize() -> CGSize {
        let width = UIScreen.mainScreen().bounds.width
        let height = UIScreen.mainScreen().bounds.height
        return CGSizeMake(width, height)
    }
    
    private func applyMotionEffects(view: UIView) {
        let horizontalEffect = UIInterpolatingMotionEffect(keyPath: "center.x", type: UIInterpolatingMotionEffectType.TiltAlongHorizontalAxis)
        horizontalEffect.minimumRelativeValue = -motionEffectExtent
        horizontalEffect.maximumRelativeValue = +motionEffectExtent
        
        let verticalEffect = UIInterpolatingMotionEffect(keyPath: "center.y", type: UIInterpolatingMotionEffectType.TiltAlongVerticalAxis)
        verticalEffect.minimumRelativeValue = -motionEffectExtent
        verticalEffect.maximumRelativeValue = +motionEffectExtent
        
        let motionEffectGroup = UIMotionEffectGroup()
        motionEffectGroup.motionEffects = [horizontalEffect, verticalEffect]
        
        view.addMotionEffect(motionEffectGroup)
    }
    
    internal func deviceOrientationDidChange(notification: NSNotification) {
        self.frame = CGRectMake(0, 0, UIScreen.mainScreen().bounds.size.width, UIScreen.mainScreen().bounds.size.height)
        
        let screenSize = self.calculateScreenSize()
        let dialogSize = self.calculateDialogSize()
        
        dialogView?.frame = CGRectMake(
            (screenSize.width - dialogSize.width) / 2,
            (screenSize.height - dialogSize.height) / 2,
            dialogSize.width,
            dialogSize.height
            )
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIDeviceOrientationDidChangeNotification, object: nil)
    }
}
