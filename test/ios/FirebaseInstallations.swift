import Foundation

public class Installations {
    private static let shared = Installations()
    public static func installations() -> Installations { shared }
    public var deleteError: Error?
    public func delete(completion: (Error?) -> Void) { completion(deleteError) }
}
