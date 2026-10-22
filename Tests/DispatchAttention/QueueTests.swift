import Foundation

@main struct QueueTests {
    static func payload(_ id: String, _ type: String = "dispatch") -> AppNotificationPayload {
        AppNotificationPayload.from(userInfo: ["id": id, "type": type, "callType": "FIRE", "address": "1 Test Street"])!
    }
    static func main() {
        var queue = DispatchAttentionQueue()
        queue.enqueue(payload("message", "department_message"))
        queue.enqueue(payload("closed", "dispatch_closed"))
        assert(queue.current == nil, "Only new dispatches create attention popups")
        queue.enqueue(payload("first"))
        queue.enqueue(payload("first", "dispatch_critical"))
        queue.enqueue(payload("second", "dispatch_critical"))
        assert(queue.pending.map(\.id) == ["first", "second"], "Duplicates must not create repeated popups")
        queue.remove(dispatchId: "first")
        assert(queue.current?.id == "second", "Dismissing or closing the current dispatch advances the queue")
        queue.enqueue(payload("first"))
        assert(queue.pending.count == 1, "Redelivery must not reopen a dismissed popup")
        queue.enqueue(payload("third"))
        queue.remove(dispatchId: "third")
        assert(queue.current?.id == "second", "A queued closure must not dismiss a different current call")
        queue.remove(dispatchId: "second")
        assert(queue.current == nil)
        // Retention is bounded, while still suppressing duplicates of pending dispatches.
        queue.enqueue(payload("pending"))
        for index in 0..<250 { queue.enqueue(payload("call-\(index)")) }
        queue.enqueue(payload("pending"))
        assert(queue.pending.filter { $0.id == "pending" }.count == 1)
        queue = DispatchAttentionQueue()
        assert(queue.current == nil, "Signing out clears pending details")
        print("PASS: dispatch-only, duplicate suppression, ordered queue, closures, bounded history, session reset")
    }
}
