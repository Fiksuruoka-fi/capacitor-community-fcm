package com.getcapacitor.community.fcm;

import android.os.Handler;
import android.os.Looper;
import androidx.annotation.NonNull;
import androidx.core.app.NotificationManagerCompat;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.google.firebase.installations.FirebaseInstallations;
import com.google.firebase.messaging.FirebaseMessaging;
import java.util.concurrent.atomic.AtomicBoolean;

@CapacitorPlugin(name = "FCM")
public class FCMPlugin extends Plugin {

    public static final String TAG = "FirebaseMessaging";
    private static final String EVENT_TOKEN_RECEIVED = "tokenReceived";

    // Track the live plugin instance + buffer the last token in case
    // onNewToken fires before the plugin has finished loading.
    private static volatile FCMPlugin instance;
    // Retain the latest rotation until a bridge exists. JS re-reads SDK state.
    private static volatile String pendingToken;

    @Override
    public void load() {
        super.load();
        synchronized (FCMPlugin.class) {
            instance = this;
            if (pendingToken != null) {
                String token = pendingToken;
                pendingToken = null;
                dispatchTokenReceived(token);
            }
        }
    }

    @Override
    protected void handleOnDestroy() {
        synchronized (FCMPlugin.class) {
            if (instance == this) {
                instance = null;
            }
        }
        super.handleOnDestroy();
    }

    /**
     * Static entry point called from FCMMessagingService whenever
     * FirebaseMessagingService.onNewToken fires. Buffers the token if the
     * plugin hasn't loaded yet (e.g. cold-start race) and dispatches it
     * via notifyListeners on the next load() call.
     */
    public static synchronized void onNewTokenReceived(@NonNull String token) {
        if (instance != null) {
            instance.dispatchTokenReceived(token);
        } else {
            pendingToken = token;
        }
    }

    private void dispatchTokenReceived(@NonNull String token) {
        JSObject data = new JSObject();
        data.put("token", token);
        notifyListeners(EVENT_TOKEN_RECEIVED, data, true);
    }

    @PluginMethod
    public void subscribeTo(final PluginCall call) {
        final String topicName = call.getString("topic");

        FirebaseMessaging.getInstance()
            .subscribeToTopic(topicName)
            .addOnSuccessListener(aVoid -> {
                JSObject ret = new JSObject();
                ret.put("message", "Subscribed to topic " + topicName);
                call.resolve(ret);
            })
            .addOnFailureListener(e -> call.reject("Cant subscribe to topic" + topicName, e));
    }

    @PluginMethod
    public void unsubscribeFrom(final PluginCall call) {
        final String topicName = call.getString("topic");

        FirebaseMessaging.getInstance()
            .unsubscribeFromTopic(topicName)
            .addOnSuccessListener(aVoid -> {
                JSObject ret = new JSObject();
                ret.put("message", "Unsubscribed from topic " + topicName);
                call.resolve(ret);
            })
            .addOnFailureListener(e -> call.reject("Cant unsubscribe from topic" + topicName, e));
    }

    @PluginMethod
    public void deleteInstance(final PluginCall call) {
        FirebaseInstallations.getInstance()
            .delete()
            .addOnSuccessListener(aVoid -> call.resolve())
            .addOnFailureListener(e -> {
                e.printStackTrace();
                call.reject("Cant delete Firebase Instance ID", e);
            });
    }

    @PluginMethod
    public void getToken(final PluginCall call) {
        Handler handler = new Handler(Looper.getMainLooper());
        AtomicBoolean settled = new AtomicBoolean(false);
        Runnable timeout = () -> {
            if (settled.compareAndSet(false, true)) {
                call.reject("Timed out waiting for an FCM token");
            }
        };
        handler.postDelayed(timeout, 15000);
        FirebaseMessaging.getInstance()
            .getToken()
            .addOnCompleteListener(tokenResult -> {
                if (!settled.compareAndSet(false, true)) return;
                handler.removeCallbacks(timeout);
                if (!tokenResult.isSuccessful()) {
                    call.reject("Failed to get FCM registration token");
                    return;
                }
                String token = tokenResult.getResult();
                if (token == null || token.isEmpty()) {
                    call.reject("FCM returned an empty registration token");
                    return;
                }
                JSObject data = new JSObject();
                data.put("token", token);
                call.resolve(data);
            });
    }

    @PluginMethod
    public void refreshToken(final PluginCall call) {
        FirebaseMessaging.getInstance()
            .deleteToken()
            .addOnSuccessListener(result -> getToken(call))
            .addOnFailureListener(e -> call.reject("Failed to delete FCM registration token"));
    }

    @PluginMethod
    public void setAutoInit(final PluginCall call) {
        final boolean enabled = call.getBoolean("enabled", false);
        FirebaseMessaging.getInstance().setAutoInitEnabled(enabled);
        call.resolve();
    }

    @PluginMethod
    public void isAutoInitEnabled(final PluginCall call) {
        final boolean enabled = FirebaseMessaging.getInstance().isAutoInitEnabled();
        JSObject data = new JSObject();
        data.put("enabled", enabled);
        call.resolve(data);
    }

    /**
     * Report the OS notification switch, which Capacitor Push Notifications
     * cannot see below Android 13 because its checkPermissions resolves
     * "granted" without consulting NotificationManagerCompat.
     */
    @PluginMethod
    public void areNotificationsEnabled(final PluginCall call) {
        JSObject data = new JSObject();
        data.put("enabled", NotificationManagerCompat.from(getContext()).areNotificationsEnabled());
        call.resolve(data);
    }
}
