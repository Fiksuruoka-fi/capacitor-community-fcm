import type { PluginListenerHandle } from '@capacitor/core';
/**
 * A transport notification that should wake the app's synchronization path.
 */
export type TokenReceivedEvent = {
    /**
     * The token observed when the event was emitted. Buffered events can be old;
     * call getToken() before persisting the device's current state.
     */
    token: string;
};
export interface FCMPlugin {
    /**
     * Subscribe to fcm topic
     * @param options
     */
    subscribeTo(options: {
        topic: string;
    }): Promise<{
        message: string;
    }>;
    /**
     * Unsubscribe from fcm topic
     * @param options
     */
    unsubscribeFrom(options: {
        topic: string;
    }): Promise<{
        message: string;
    }>;
    /**
     * Read the current Firebase SDK registration token, including unchanged values.
     * Start PushNotifications.register() first. On iOS this waits for APNs mapping
     * and then calls the SDK getter; it never returns a plugin-local cached token.
     * Rejects on an SDK error, empty token, or a 15-second readiness/read timeout.
     * Resolving this promise does not acknowledge a backend write or consent.
     */
    getToken(): Promise<{
        token: string;
    }>;
    /**
     * Delete the native FCM token, then read its replacement with getToken().
     * Do not use for heartbeats, consent changes or account reassociation.
     */
    refreshToken(): Promise<{
        token: string;
    }>;
    /**
     * Remove local fcm instance completely
     */
    deleteInstance(): Promise<boolean>;
    /**
     * Enabled/disabled auto initialization.
     * @param options
     */
    setAutoInit(options: {
        enabled: boolean;
    }): Promise<void>;
    /**
     * Retrieve the auto initialization status.
     */
    isAutoInitEnabled(): Promise<{
        enabled: boolean;
    }>;
    /**
     * Listen for token changes. Both native bridges retain events for a late
     * listener within the current native process. This is not a durable backend
     * queue: keep explicit reads on startup/foreground and retry failed writes.
     * iOS coalesces repeated notifications of the same value; getToken() still
     * returns that value on every explicit read. Android forwards onNewToken.
     *
     * @example
     * ```ts
     * const handle = await FCM.addListener('tokenReceived', () => {
     *   void retryPendingDeviceSync(); // Re-read token and current app consent.
     * });
     * // later: await handle.remove();
     * ```
     */
    addListener(eventName: 'tokenReceived', listenerFunc: (event: TokenReceivedEvent) => void): Promise<PluginListenerHandle>;
    /**
     * Remove all event listeners registered on this plugin.
     */
    removeAllListeners(): Promise<void>;
}
