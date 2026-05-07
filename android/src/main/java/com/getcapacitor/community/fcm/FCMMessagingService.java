package com.getcapacitor.community.fcm;

import android.util.Log;
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
 * subclass takes its place.
 *
 * <p><b>Ordering:</b> super.onNewToken() is invoked first to preserve all of
 * PushNotifications' existing token-handling behaviour (its JS-side
 * `registration` event still fires as before, even if the fiksuruoka handler
 * does not currently subscribe to it for token persistence). If super throws,
 * we log and continue — `tokenReceived` is the authoritative source for the
 * JS layer and must not be skipped because of a fault upstream.
 */
public class FCMMessagingService extends MessagingService {

    private static final String TAG = "FCMMessagingService";

    @Override
    public void onNewToken(@NonNull String token) {
        try {
            super.onNewToken(token);
        } catch (Exception e) {
            Log.w(TAG, "PushNotifications.onNewToken threw an exception", e);
            // Continue — `tokenReceived` is the authoritative source.
        }
        FCMPlugin.onNewTokenReceived(token);
    }
}
