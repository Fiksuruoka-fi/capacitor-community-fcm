import Foundation

@objc public protocol MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken token: String?)
}

@objc public class Messaging: NSObject {
    private static let shared = Messaging()
    public static func messaging() -> Messaging { shared }
    public var apnsToken: Data?
    public weak var delegate: MessagingDelegate?
    public var isAutoInitEnabled = true
    public var reads: [(String?, Error?) -> Void] = []
    public var deleteError: Error?
    public func token(completion: @escaping (String?, Error?) -> Void) { reads.append(completion) }
    public func deleteToken(completion: (Error?) -> Void) { completion(deleteError) }
    public func subscribe(toTopic: String, completion: (Error?) -> Void) { completion(nil) }
    public func unsubscribe(fromTopic: String, completion: (Error?) -> Void) { completion(nil) }
}
