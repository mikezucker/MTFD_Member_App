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

final class MTFDNonBouncingHostingScrollView: UIScrollView {
    private let hostingController: UIHostingController<AnyView>
    private var allowsPullToRefresh = false
    private var isClampingContentOffset = false

    init(rootView: AnyView) {
        self.hostingController = UIHostingController(rootView: rootView)

        super.init(frame: .zero)

        backgroundColor = .clear
        clipsToBounds = true
        bounces = false
        alwaysBounceVertical = false
        alwaysBounceHorizontal = false
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never

        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = true
        addSubview(hostingController.view)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configureRefreshControl(_ control: UIRefreshControl?) {
        refreshControl = control
        allowsPullToRefresh = control != nil

        bounces = false
        alwaysBounceVertical = false
        alwaysBounceHorizontal = false
    }

    func update(rootView: AnyView) {
        hostingController.rootView = rootView
        setNeedsLayout()
        layoutIfNeeded()
    }

    override var contentOffset: CGPoint {
        didSet {
            clampCurrentContentOffset()
        }
    }

    override func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
        super.setContentOffset(clampedContentOffset(contentOffset), animated: animated)
    }

    private func clampedContentOffset(_ proposedOffset: CGPoint) -> CGPoint {
        let maxOffsetY = max(0, contentSize.height - bounds.height)
        return CGPoint(
            x: 0,
            y: min(max(proposedOffset.y, 0), maxOffsetY)
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

        isScrollEnabled = contentHeight > bounds.height
        clampCurrentContentOffset()
    }
}
