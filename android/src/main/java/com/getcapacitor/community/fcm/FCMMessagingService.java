package com.getcapacitor.community.fcm;

import androidx.annotation.NonNull;
import com.capacitorjs.plugins.pushnotifications.MessagingService;

/**
 * Subclass of Capacitor PushNotifications' MessagingService that forwards
 * onNewToken events to FCMPlugin so the JS layer can listen via the
 * `tokenReceived` event.
 *
 * <p>Registered in this plugin's AndroidManifest.xml; the same manifest uses
 * tools:node="remove" to drop PushNotifications' default service entry. Android
 * FCM only routes MESSAGING_EVENT to a single FirebaseMessagingService, so this
 * subclass takes its place. super.onNewToken() is invoked first to preserve all
 * of PushNotifications' existing token-handling behaviour (the JS-side
 * `PushNotifications.registration` event still fires as before).
 */
public class FCMMessagingService extends MessagingService {

    @Override
    public void onNewToken(@NonNull String token) {
        super.onNewToken(token);
        FCMPlugin.onNewTokenReceived(token);
    }
}
