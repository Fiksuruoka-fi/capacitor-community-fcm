import Foundation

open class CAPPlugin: NSObject {
    public var events: [(String, [String: Any], Bool)] = []
    open func load() {}
    public func notifyListeners(_ name: String, data: [String: Any], retainUntilConsumed: Bool = false) {
        events.append((name, data, retainUntilConsumed))
    }
}

public class CAPPluginCall: NSObject {
    public var resolutions: [[String: Any]] = []
    public var rejections: [String] = []
    public func resolve(_ data: [String: Any] = [:]) { resolutions.append(data) }
    public func reject(_ message: String, _ code: String? = nil) { rejections.append(message) }
    public func getString(_ name: String) -> String? { nil }
    public func getBool(_ name: String) -> Bool? { nil }
}

public extension Notification.Name {
    static let capacitorDidRegisterForRemoteNotifications = Notification.Name("registered")
    static let capacitorDidFailToRegisterForRemoteNotifications = Notification.Name("failed")
}
