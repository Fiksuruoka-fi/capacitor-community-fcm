import Foundation
import Capacitor
import UserNotifications

import FirebaseCore
import FirebaseMessaging
import FirebaseInstallations

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitor.ionicframework.com/docs/plugins/ios
 *
 * Created by Stewan Silva on 1/23/19.
 */
@objc(FCMPlugin)
public class FCMPlugin: CAPPlugin, MessagingDelegate {
    private var pendingTokenCalls: [UUID: CAPPluginCall] = [:]
    private var lastNotifiedToken: String?
    var tokenTimeoutSeconds: Double = 15

    override public func load() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        Messaging.messaging().delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(self.didRegisterWithToken(notification:)), name: .capacitorDidRegisterForRemoteNotifications, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.didFailToRegister(notification:)), name: .capacitorDidFailToRegisterForRemoteNotifications, object: nil)
    }

    @objc func didRegisterWithToken(notification: NSNotification) {
        guard let deviceToken = notification.object as? Data else {
            return
        }
        DispatchQueue.main.async {
            Messaging.messaging().apnsToken = deviceToken
            for id in self.pendingTokenCalls.keys {
                self.readCurrentToken(id)
            }
            // Recover a delegate notification that arrived before APNs mapping.
            Messaging.messaging().token { token, error in
                DispatchQueue.main.async {
                    guard error == nil, Messaging.messaging().apnsToken == deviceToken else { return }
                    self.emitToken(token)
                }
            }
        }
    }

    @objc func didFailToRegister(notification: NSNotification) {
        DispatchQueue.main.async {
            self.rejectPendingTokens("APNs registration failed")
        }
    }

    private func emitToken(_ token: String?) {
        guard Messaging.messaging().apnsToken != nil,
              let token = token, !token.isEmpty, token != lastNotifiedToken else { return }
        lastNotifiedToken = token
        notifyListeners("tokenReceived", data: ["token": token], retainUntilConsumed: true)
    }

    private func rejectPendingTokens(_ message: String) {
        let calls = pendingTokenCalls.values
        pendingTokenCalls.removeAll()
        for call in calls { call.reject(message) }
    }

    private func readCurrentToken(_ id: UUID) {
        guard pendingTokenCalls[id] != nil,
              let apnsToken = Messaging.messaging().apnsToken else { return }
        Messaging.messaging().token { token, error in
            DispatchQueue.main.async {
                guard let call = self.pendingTokenCalls[id] else { return }
                guard Messaging.messaging().apnsToken == apnsToken else { return }
                self.pendingTokenCalls.removeValue(forKey: id)
                if error != nil {
                    call.reject("Failed to get FCM registration token")
                } else if let token = token, !token.isEmpty {
                    call.resolve(["token": token])
                } else {
                    call.reject("FCM returned an empty registration token")
                }
            }
        }
    }

    @objc func subscribeTo(_ call: CAPPluginCall) {
        let topicName = call.getString("topic") ?? ""
        Messaging.messaging().subscribe(toTopic: topicName) { error in
            // print("Subscribed to weather topic")
            if (error) != nil {
                print("ERROR while trying to subscribe topic \(topicName)")
                call.reject("Can't subscribe to topic \(topicName)")
            } else {
                call.resolve([
                    "message": "subscribed to topic \(topicName)"
                ])
            }
        }
    }

    @objc func unsubscribeFrom(_ call: CAPPluginCall) {
        let topicName = call.getString("topic") ?? ""
        Messaging.messaging().unsubscribe(fromTopic: topicName) { error in
            if (error) != nil {
                call.reject("Can't unsubscribe from topic \(topicName)")
            } else {
                call.resolve([
                    "message": "unsubscribed from topic \(topicName)"
                ])
            }
        }
    }

    @objc func getToken(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            let id = UUID()
            self.pendingTokenCalls[id] = call
            DispatchQueue.main.asyncAfter(deadline: .now() + self.tokenTimeoutSeconds) {
                self.pendingTokenCalls.removeValue(forKey: id)?.reject("Timed out waiting for an APNs-ready FCM token")
            }
            self.readCurrentToken(id)
        }
    }

    @objc func refreshToken(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.rejectPendingTokens("FCM token is being refreshed")
            self.lastNotifiedToken = nil
            Messaging.messaging().deleteToken { error in
                if error != nil {
                    call.reject("Failed to delete FCM token")
                } else {
                    self.getToken(call)
                }
            }
        }
    }

    @objc func deleteInstance(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.rejectPendingTokens("Firebase installation is being deleted")
            self.lastNotifiedToken = nil
            Installations.installations().delete { error in
                if error != nil {
                    call.reject("Cannot delete Firebase installation")
                    return
                }
                call.resolve()
            }
        }
    }

    @objc func setAutoInit(_ call: CAPPluginCall) {
        let enabled: Bool = call.getBool("enabled") ?? false
        Messaging.messaging().isAutoInitEnabled = enabled
        call.resolve()
    }

    @objc func isAutoInitEnabled(_ call: CAPPluginCall) {
        call.resolve([
            "enabled": Messaging.messaging().isAutoInitEnabled
        ])
    }

    @objc public func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        DispatchQueue.main.async {
            // Rotation wakes the app; only an explicit SDK read settles getToken.
            self.emitToken(fcmToken)
        }
    }
}
