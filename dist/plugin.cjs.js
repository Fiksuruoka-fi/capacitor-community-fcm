'use strict';

var core = require('@capacitor/core');

const FCM = core.registerPlugin('FCM', {
    web: () => Promise.resolve().then(function () { return web; }).then((m) => new m.FCMWeb()),
});

class FCMWeb extends core.WebPlugin {
    constructor() {
        super();
    }
    subscribeTo(_options) {
        throw this.unimplemented('Not implemented on web.');
    }
    unsubscribeFrom(_options) {
        throw this.unimplemented('Not implemented on web.');
    }
    getToken() {
        throw this.unimplemented('Not implemented on web.');
    }
    deleteInstance() {
        throw this.unimplemented('Not implemented on web.');
    }
    setAutoInit(_options) {
        throw this.unimplemented('Not implemented on web.');
    }
    isAutoInitEnabled() {
        throw this.unimplemented('Not implemented on web.');
    }
    refreshToken() {
        throw this.unimplemented('Not implemented on web.');
    }
}
new FCMWeb();

var web = /*#__PURE__*/Object.freeze({
    __proto__: null,
    FCMWeb: FCMWeb
});

exports.FCM = FCM;
//# sourceMappingURL=plugin.cjs.js.map
