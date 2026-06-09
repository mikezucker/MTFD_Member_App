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

    func makeCoordinator() -> Coordinator {
        Coordinator(onRefresh: onRefresh)
    }

    func makeUIView(context: Context) -> ManualHostingScrollView<Content> {
        let view = ManualHostingScrollView(rootView: content)
        view.showsVerticalScrollIndicator = showsIndicators
        view.configureRefreshControl(onRefresh == nil ? nil : context.coordinator.refreshControl)
        return view
    }

    func updateUIView(_ scrollView: ManualHostingScrollView<Content>, context: Context) {
        context.coordinator.onRefresh = onRefresh

        scrollView.update(rootView: content)
        scrollView.showsVerticalScrollIndicator = showsIndicators
        scrollView.configureRefreshControl(onRefresh == nil ? nil : context.coordinator.refreshControl)
    }

    final class Coordinator: NSObject {
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

        @objc private func handleRefresh() {
            print("🔄 NonBouncingVerticalScrollView refresh triggered")

            guard let onRefresh else {
                refreshControl.endRefreshing()
                return
            }

            Task { @MainActor in
                await onRefresh()
                refreshControl.endRefreshing()
            }
        }
    }

    final class ManualHostingScrollView<HostedContent: View>: UIScrollView {
        private let hostingController: UIHostingController<HostedContent>
        private var allowsPullToRefresh = false

        init(rootView: HostedContent) {
            self.hostingController = UIHostingController(rootView: rootView)

            super.init(frame: .zero)

            backgroundColor = .clear
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

            if allowsPullToRefresh {
                bounces = true
                alwaysBounceVertical = true
            } else {
                bounces = false
                alwaysBounceVertical = false
            }

            alwaysBounceHorizontal = false
        }

        func update(rootView: HostedContent) {
            hostingController.rootView = rootView
            setNeedsLayout()
            layoutIfNeeded()
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

            let maxOffsetY = max(0, contentSize.height - bounds.height)

            let isUserPullingOrRefreshing = isTracking || isDragging || isDecelerating || refreshControl?.isRefreshing == true

            if !allowsPullToRefresh && contentOffset.y < 0 {
                contentOffset.y = 0
            } else if !isUserPullingOrRefreshing && contentOffset.y > maxOffsetY {
                contentOffset.y = maxOffsetY
            }
        }
    }
}
