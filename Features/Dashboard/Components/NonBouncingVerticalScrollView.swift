import SwiftUI
import UIKit

struct NonBouncingVerticalScrollView<Content: View>: UIViewRepresentable {
    let showsIndicators: Bool
    let onRefresh: (() async -> Void)?
    let content: Content

    init(
        showsIndicators: Bool = false,
        onRefresh: (() async -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.showsIndicators = showsIndicators
        self.onRefresh = onRefresh
        self.content = content()
    }

    func makeCoordinator() -> MTFDNonBouncingScrollCoordinator {
        MTFDNonBouncingScrollCoordinator(onRefresh: onRefresh)
    }

    func makeUIView(context: Context) -> MTFDNonBouncingHostingScrollView {
        let view = MTFDNonBouncingHostingScrollView(rootView: AnyView(content))
        view.showsVerticalScrollIndicator = showsIndicators
        view.configureRefreshControl(onRefresh == nil ? nil : context.coordinator.refreshControl)
        return view
    }

    func updateUIView(_ scrollView: MTFDNonBouncingHostingScrollView, context: Context) {
        context.coordinator.onRefresh = onRefresh

        scrollView.update(rootView: AnyView(content))
        scrollView.showsVerticalScrollIndicator = showsIndicators
        scrollView.configureRefreshControl(onRefresh == nil ? nil : context.coordinator.refreshControl)
    }
}

final class MTFDNonBouncingScrollCoordinator: NSObject {
    var onRefresh: (() async -> Void)?
    let refreshControl = UIRefreshControl()

    init(onRefresh: (() async -> Void)?) {
        self.onRefresh = onRefresh
        super.init()

        refreshControl.tintColor = .white
        refreshControl.addTarget(
            self,
            action: #selector(handleRefresh),
            for: .valueChanged
        )
    }

    deinit {
        refreshControl.removeTarget(
            self,
            action: #selector(handleRefresh),
            for: .valueChanged
        )
    }

    @objc private func handleRefresh() {
        guard let onRefresh else {
            refreshControl.endRefreshing()
            return
        }

        Task { @MainActor [weak self] in
            await onRefresh()
            self?.refreshControl.endRefreshing()
        }
    }
}

final class MTFDNonBouncingHostingScrollView: UIScrollView, UIGestureRecognizerDelegate {
    private let hostingController: UIHostingController<AnyView>
    private let pullIndicatorContainer = UIView()
    private let pullIndicatorImageView = UIImageView(image: UIImage(systemName: "arrow.down"))
    private let pullHaptic = UIImpactFeedbackGenerator(style: .light)
    private var allowsPullToRefresh = false
    private var isClampingContentOffset = false
    private var didTriggerPullHaptic = false

    init(rootView: AnyView) {
        self.hostingController = UIHostingController(rootView: rootView)

        super.init(frame: .zero)

        backgroundColor = .clear
        clipsToBounds = true
        bounces = false
        bouncesZoom = false
        alwaysBounceVertical = false
        alwaysBounceHorizontal = false
        isDirectionalLockEnabled = true
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        contentInset = .zero
        scrollIndicatorInsets = .zero
        panGestureRecognizer.delegate = self

        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = true
        addSubview(hostingController.view)

        pullIndicatorContainer.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        pullIndicatorContainer.layer.cornerRadius = 14
        pullIndicatorContainer.alpha = 0
        pullIndicatorContainer.isUserInteractionEnabled = false

        pullIndicatorImageView.tintColor = .white
        pullIndicatorImageView.contentMode = .scaleAspectFit
        pullIndicatorImageView.isUserInteractionEnabled = false

        pullIndicatorContainer.addSubview(pullIndicatorImageView)
        addSubview(pullIndicatorContainer)
        pullHaptic.prepare()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configureRefreshControl(_ control: UIRefreshControl?) {
        refreshControl = control
        allowsPullToRefresh = control != nil

        bounces = allowsPullToRefresh
        bouncesZoom = false
        alwaysBounceVertical = allowsPullToRefresh
        alwaysBounceHorizontal = false
        contentInset = .zero
        scrollIndicatorInsets = .zero
        updatePullIndicator()
    }

    func update(rootView: AnyView) {
        hostingController.rootView = rootView
        setNeedsLayout()
        layoutIfNeeded()
    }

    override var contentOffset: CGPoint {
        didSet {
            clampCurrentContentOffset()
            updatePullIndicator()
        }
    }

    override func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
        super.setContentOffset(clampedContentOffset(contentOffset), animated: animated)
    }

    private func clampedContentOffset(_ proposedOffset: CGPoint) -> CGPoint {
        let maxOffsetY = max(0, contentSize.height - bounds.height)
        let minOffsetY: CGFloat = allowsPullToRefresh ? -refreshPullDistanceLimit : 0

        return CGPoint(
            x: 0,
            y: min(max(proposedOffset.y, minOffsetY), maxOffsetY)
        )
    }

    private func clampCurrentContentOffset() {
        guard !isClampingContentOffset else { return }

        let clampedOffset = clampedContentOffset(contentOffset)
        guard clampedOffset != contentOffset else { return }

        isClampingContentOffset = true
        contentOffset = clampedOffset
        isClampingContentOffset = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let targetWidth = bounds.width
        guard targetWidth > 0 else { return }

        let fittingSize = CGSize(
            width: targetWidth,
            height: UIView.layoutFittingCompressedSize.height
        )

        let measuredSize = hostingController.sizeThatFits(in: fittingSize)
        let contentHeight = max(measuredSize.height, 1)

        hostingController.view.frame = CGRect(
            x: 0,
            y: 0,
            width: targetWidth,
            height: contentHeight
        )

        contentSize = CGSize(
            width: targetWidth,
            height: contentHeight
        )

        isScrollEnabled = allowsPullToRefresh || contentHeight > bounds.height
        clampCurrentContentOffset()
        updatePullIndicator()
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === panGestureRecognizer else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }

        let touchLocation = panGestureRecognizer.location(in: self)
        if let touchedView = hitTest(touchLocation, with: nil),
           touchedView.isDescendantOfNestedScrollView(inside: self) {
            return false
        }

        guard allowsPullToRefresh || contentSize.height > bounds.height else {
            return false
        }

        let velocity = panGestureRecognizer.velocity(in: self)
        return abs(velocity.y) > abs(velocity.x)
    }

    private func updatePullIndicator() {
        guard allowsPullToRefresh, refreshControl?.isRefreshing != true else {
            pullIndicatorContainer.alpha = 0
            didTriggerPullHaptic = false
            return
        }

        let pullDistance = max(0, -contentOffset.y)
        let progress = min(1, pullDistance / refreshTriggerDistance)

        if progress >= 1, !didTriggerPullHaptic {
            didTriggerPullHaptic = true
            pullHaptic.impactOccurred()
            pullHaptic.prepare()
        } else if pullDistance <= 0 {
            didTriggerPullHaptic = false
        }

        let indicatorSize: CGFloat = 28
        pullIndicatorContainer.frame = CGRect(
            x: (bounds.width - indicatorSize) / 2,
            y: contentOffset.y + 12,
            width: indicatorSize,
            height: indicatorSize
        )

        pullIndicatorImageView.frame = pullIndicatorContainer.bounds.insetBy(dx: 7, dy: 7)
        pullIndicatorContainer.alpha = progress
        pullIndicatorContainer.transform = CGAffineTransform(
            scaleX: 0.82 + (0.18 * progress),
            y: 0.82 + (0.18 * progress)
        )
        bringSubviewToFront(pullIndicatorContainer)
    }
}

private let refreshPullDistanceLimit: CGFloat = 180
private let refreshTriggerDistance: CGFloat = 70

private extension UIView {
    func isDescendantOfNestedScrollView(inside parentScrollView: UIScrollView) -> Bool {
        var candidate: UIView? = self

        while let view = candidate {
            if let scrollView = view as? UIScrollView, scrollView !== parentScrollView {
                return true
            }

            if view === parentScrollView {
                return false
            }

            candidate = view.superview
        }

        return false
    }
}
