import SwiftUI
import UIKit

struct NonBouncingVerticalScrollView<Content: View>: UIViewRepresentable {
    let showsIndicators: Bool
    let content: Content

    init(
        showsIndicators: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.showsIndicators = showsIndicators
        self.content = content()
    }

    func makeUIView(context: Context) -> ManualHostingScrollView<Content> {
        let view = ManualHostingScrollView(rootView: content)
        view.showsVerticalScrollIndicator = showsIndicators
        return view
    }

    func updateUIView(_ scrollView: ManualHostingScrollView<Content>, context: Context) {
        scrollView.update(rootView: content)
        scrollView.showsVerticalScrollIndicator = showsIndicators
    }

    final class ManualHostingScrollView<HostedContent: View>: UIScrollView {
        private let hostingController: UIHostingController<HostedContent>

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

            if contentOffset.y < 0 {
                contentOffset.y = 0
            } else if contentOffset.y > maxOffsetY {
                contentOffset.y = maxOffsetY
            }
        }
    }
}
