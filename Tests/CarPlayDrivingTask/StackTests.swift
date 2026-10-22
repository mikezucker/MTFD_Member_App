import Foundation

final class CPTemplate {}
final class InterfaceController {
    var templates: [CPTemplate]
    var onPop: (() -> Void)?
    init(depth: Int) { templates = (0..<depth).map { _ in CPTemplate() } }
    func popTemplate(animated: Bool, completion: (Bool, Error?) -> Void) {
        guard templates.count > 1 else { completion(false, nil); return }
        templates.removeLast()
        onPop?()
        completion(true, nil)
    }
    func pushTemplate(_ template: CPTemplate, animated: Bool, completion: ((Bool, Error?) -> Void)?) {
        templates.append(template)
        completion?(true, nil)
    }
}

final class Driver {
    enum CarPlayScreen { case root, active, recent, detail }
    var interfaceController: InterfaceController?
    var currentScreen: CarPlayScreen = .active
    var detailParentScreen: CarPlayScreen?
    var selectedActiveDispatchId: String?
    var supportsThreeTemplates = false

    // PRODUCTION_DETAIL_METHOD

    func open(_ detail: CPTemplate, recent: Bool = false) {
        openDispatchDetail(detail, parentScreen: recent ? .recent : .active,
                           activeDispatchId: recent ? nil : "dispatch-123")
    }
}

@main struct StackTests {
    static func main() {
        for (modern, depth, expectedDepth) in [(false, 2, 2), (true, 2, 3), (true, 3, 3), (false, 1, 2)] {
            let driver = Driver()
            let controller = InterfaceController(depth: depth)
            driver.interfaceController = controller
            driver.supportsThreeTemplates = modern
            controller.onPop = {
                driver.currentScreen = .root
                driver.detailParentScreen = nil
                driver.selectedActiveDispatchId = nil
            }
            let root = controller.templates[0]
            let detail = CPTemplate()
            driver.open(detail)
            precondition(controller.templates.count == expectedDepth)
            precondition(controller.templates.first === root && controller.templates.last === detail)
            precondition(driver.currentScreen == .detail && driver.detailParentScreen == .active)
            precondition(driver.selectedActiveDispatchId == "dispatch-123")
        }
        print("PASS: older iOS stays within two templates and retains detail identity after popping")
        print("PASS: newer iOS allows three templates and replaces an existing detail at the limit")
        let driver = Driver()
        driver.interfaceController = InterfaceController(depth: 2)
        driver.selectedActiveDispatchId = "previous-dispatch"
        driver.open(CPTemplate(), recent: true)
        precondition(driver.detailParentScreen == .recent && driver.selectedActiveDispatchId == nil)
        print("PASS: recent dispatch detail clears the previous active dispatch identity")
    }
}
