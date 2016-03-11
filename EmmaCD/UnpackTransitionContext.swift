func unpackTransitionContext (
    transitionContext:UIViewControllerContextTransitioning) -> (
        containerView:UIView,
        fromVC:UIViewController,
        toVC:UIViewController,
        fromView:UIView?,
        toView:UIView?,
        fromViewStartFrame:CGRect,
        toViewEndFrame:CGRect)
{
    let containerView = transitionContext.containerView()!
    let fromVC = transitionContext.viewControllerForKey(UITransitionContextFromViewControllerKey)!
    let toVC = transitionContext.viewControllerForKey(UITransitionContextToViewControllerKey)!
    let fromView = transitionContext.viewForKey(UITransitionContextFromViewKey)
    let toView = transitionContext.viewForKey(UITransitionContextToViewKey)
    let fromViewStartFrame = transitionContext.initialFrameForViewController(fromVC)
    let toViewEndFrame = transitionContext.finalFrameForViewController(toVC)

    return (containerView, fromVC, toVC, fromView, toView, fromViewStartFrame, toViewEndFrame)
}



