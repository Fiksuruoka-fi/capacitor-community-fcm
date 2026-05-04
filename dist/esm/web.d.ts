import type { PluginListenerHandle } from '@capacitor/core';
import { WebPlugin } from '@capacitor/core';
import type { FCMPlugin, TokenReceivedEvent } from './definitions';
export declare class FCMWeb extends WebPlugin implements FCMPlugin {
    constructor();
    subscribeTo(_options: {
        topic: string;
    }): Promise<{
        message: string;
    }>;
    unsubscribeFrom(_options: {
        topic: string;
    }): Promise<{
        message: string;
    }>;
    getToken(): Promise<{
        token: string;
    }>;
    deleteInstance(): Promise<boolean>;
    setAutoInit(_options: {
        enabled: boolean;
    }): Promise<void>;
    isAutoInitEnabled(): Promise<{
        enabled: boolean;
    }>;
    refreshToken(): Promise<{
        token: string;
    }>;
    addListener(_eventName: 'tokenReceived', _listenerFunc: (event: TokenReceivedEvent) => void): Promise<PluginListenerHandle>;
}
declare const FCM: FCMWeb;
export { FCM };
