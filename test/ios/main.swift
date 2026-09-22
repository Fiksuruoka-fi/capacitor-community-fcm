import Foundation
import Capacitor
import FirebaseMessaging
import FirebaseInstallations

func drainMainQueue() {
    var finished = false
    DispatchQueue.main.async { finished = true }
    while !finished { RunLoop.current.run(until: Date().addingTimeInterval(0.001)) }
}

func fixture(ready: Bool = true) -> FCMPlugin {
    let sdk = Messaging.messaging()
    sdk.apnsToken = ready ? Data([1]) : nil
    sdk.reads = []
    sdk.deleteError = nil
    Installations.installations().deleteError = nil
    return FCMPlugin()
}

func completeReads(_ token: String?, _ error: Error? = nil) {
    let reads = Messaging.messaging().reads
    Messaging.messaging().reads = []
    for read in reads { read(token, error) }
    drainMainQueue()
}

let failure = NSError(domain: "fixture", code: 1)

do {
    let plugin = fixture(ready: false)
    let call = CAPPluginCall()
    plugin.getToken(call)
    plugin.messaging(Messaging.messaging(), didReceiveRegistrationToken: "before-apns")
    drainMainQueue()
    assert(call.resolutions.isEmpty && Messaging.messaging().reads.isEmpty)
    plugin.didRegisterWithToken(notification: NSNotification(name: .capacitorDidRegisterForRemoteNotifications, object: Data([1])))
    drainMainQueue()
    completeReads("ready-token")
    assert(call.resolutions.count == 1 && call.resolutions[0]["token"] as? String == "ready-token")
    assert(plugin.events.count == 1 && plugin.events[0].2)
}

do {
    let plugin = fixture()
    for _ in 0..<2 {
        let call = CAPPluginCall()
        plugin.getToken(call)
        drainMainQueue()
        assert(Messaging.messaging().reads.count == 1)
        completeReads("unchanged")
        assert(call.resolutions.count == 1)
    }
    assert(plugin.events.isEmpty, "Explicit reads must not trigger a read/event feedback loop")
}

do {
    let plugin = fixture()
    let calls = [CAPPluginCall(), CAPPluginCall()]
    for call in calls { plugin.getToken(call) }
    drainMainQueue()
    let completions = Messaging.messaging().reads
    completeReads("current")
    for completion in completions { completion("late-duplicate", nil) }
    drainMainQueue()
    assert(calls.allSatisfy { $0.resolutions.count == 1 && $0.rejections.isEmpty })
}

for (token, error) in [(nil as String?, failure as Error?), (nil, nil), ("", nil)] {
    let plugin = fixture()
    let call = CAPPluginCall()
    plugin.getToken(call)
    drainMainQueue()
    completeReads(token, error)
    assert(call.rejections.count == 1 && call.resolutions.isEmpty)
}

for ready in [false, true] {
    let plugin = fixture(ready: ready)
    plugin.tokenTimeoutSeconds = 0
    let call = CAPPluginCall()
    plugin.getToken(call)
    drainMainQueue()
    drainMainQueue()
    completeReads("too-late")
    assert(call.rejections.count == 1 && call.resolutions.isEmpty)
}

do {
    let plugin = fixture(ready: false)
    let call = CAPPluginCall()
    plugin.getToken(call)
    plugin.didFailToRegister(notification: NSNotification(name: .capacitorDidFailToRegisterForRemoteNotifications, object: nil))
    drainMainQueue()
    assert(call.rejections.count == 1)
}

do {
    let plugin = fixture()
    let call = CAPPluginCall()
    plugin.getToken(call)
    drainMainQueue()
    let obsolete = Messaging.messaging().reads.removeFirst()
    plugin.didRegisterWithToken(notification: NSNotification(name: .capacitorDidRegisterForRemoteNotifications, object: Data([2])))
    drainMainQueue()
    obsolete("old-apns-binding", nil)
    drainMainQueue()
    assert(call.resolutions.isEmpty)
    completeReads("new-apns-binding")
    assert(call.resolutions.count == 1)
}

do {
    let plugin = fixture()
    let call = CAPPluginCall()
    Installations.installations().deleteError = failure
    plugin.deleteInstance(call)
    drainMainQueue()
    assert(call.rejections.count == 1 && call.resolutions.isEmpty)
    let refresh = CAPPluginCall()
    Messaging.messaging().deleteError = failure
    plugin.refreshToken(refresh)
    drainMainQueue()
    assert(refresh.rejections.count == 1 && Messaging.messaging().reads.isEmpty)
}

print("iOS bridge fixtures passed: readiness, retention, repeated reads, concurrency, timeout, errors and APNs changes")
