package com.getcapacitor.community.fcm;

import android.util.Log;
import androidx.annotation.NonNull;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.google.firebase.installations.FirebaseInstallations;
import com.google.firebase.messaging.FirebaseMessaging;

@CapacitorPlugin(name = "FCM")
public class FCMPlugin extends Plugin {

    public static final String TAG = "FirebaseMessaging";
    private static final String EVENT_TOKEN_RECEIVED = "tokenReceived";

    // Track the live plugin instance + buffer the last token in case
    // onNewToken fires before the plugin has finished loading.
    private static FCMPlugin instance;
    private static String pendingToken;

    @Override
    public void load() {
        super.load();
        instance = this;
        if (pendingToken != null) {
            dispatchTokenReceived(pendingToken);
            pendingToken = null;
        }
    }

    @Override
    protected void handleOnDestroy() {
        if (instance == this) {
            instance = null;
        }
        super.handleOnDestroy();
    }

    /**
     * Static entry point called from FCMMessagingService whenever
     * FirebaseMessagingService.onNewToken fires. Buffers the token if the
     * plugin hasn't loaded yet (e.g. cold-start race) and dispatches it
     * via notifyListeners on the next load() call.
     */
    public static void onNewTokenReceived(@NonNull String token) {
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
        FirebaseMessaging.getInstance()
            .getToken()
            .addOnCompleteListener(getActivity(), tokenResult -> {
                if (!tokenResult.isSuccessful()) {
                    Exception exception = tokenResult.getException();
                    Log.w(TAG, "Fetching FCM registration token failed", exception);
                    call.reject(
                        "Failed to get FCM registration token",
                        exception != null ? exception.getLocalizedMessage() : null
                    );
                    return;
                }
                JSObject data = new JSObject();
                data.put("token", tokenResult.getResult());
                call.resolve(data);
            });
    }

    @PluginMethod
    public void refreshToken(final PluginCall call) {
        FirebaseMessaging.getInstance()
            .deleteToken()
            .addOnCompleteListener(result -> {
                FirebaseMessaging.getInstance()
                    .getToken()
                    .addOnCompleteListener(getActivity(), tokenResult -> {
                        JSObject data = new JSObject();
                        data.put("token", tokenResult.getResult());
                        call.resolve(data);
                    })
                    .addOnFailureListener(e -> call.reject("Failed to get FCM registration token", e));
            })
            .addOnFailureListener(e -> call.reject("Failed to delete FCM registration token", e));
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
}
