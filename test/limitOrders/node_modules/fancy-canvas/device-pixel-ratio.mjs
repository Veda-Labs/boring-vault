var Observable = /** @class */ (function () {
    function Observable(win) {
        var _this = this;
        this._resolutionListener = function () { return _this._onResolutionChanged(); };
        this._resolutionMediaQueryList = null;
        this._observers = [];
        this._window = win;
        this._installResolutionListener();
    }
    Observable.prototype.dispose = function () {
        this._uninstallResolutionListener();
        this._window = null;
    };
    Object.defineProperty(Observable.prototype, "value", {
        get: function () {
            return this._window.devicePixelRatio;
        },
        enumerable: false,
        configurable: true
    });
    Observable.prototype.subscribe = function (next) {
        var _this = this;
        var observer = { next: next };
        this._observers.push(observer);
        return {
            unsubscribe: function () {
                _this._observers = _this._observers.filter(function (o) { return o !== observer; });
            },
        };
    };
    Observable.prototype._installResolutionListener = function () {
        if (this._resolutionMediaQueryList !== null) {
            throw new Error('Resolution listener is already installed');
        }
        var dppx = this._window.devicePixelRatio;
        this._resolutionMediaQueryList = this._window.matchMedia("all and (resolution: ".concat(dppx, "dppx)"));
        // IE and some versions of Edge do not support addEventListener/removeEventListener, and we are going to use the deprecated addListener/removeListener
        this._resolutionMediaQueryList.addListener(this._resolutionListener);
    };
    Observable.prototype._uninstallResolutionListener = function () {
        if (this._resolutionMediaQueryList !== null) {
            // IE and some versions of Edge do not support addEventListener/removeEventListener, and we are going to use the deprecated addListener/removeListener
            this._resolutionMediaQueryList.removeListener(this._resolutionListener);
            this._resolutionMediaQueryList = null;
        }
    };
    Observable.prototype._reinstallResolutionListener = function () {
        this._uninstallResolutionListener();
        this._installResolutionListener();
    };
    Observable.prototype._onResolutionChanged = function () {
        var _this = this;
        this._observers.forEach(function (observer) { return observer.next(_this._window.devicePixelRatio); });
        this._reinstallResolutionListener();
    };
    return Observable;
}());
export function createObservable(win) {
    return new Observable(win);
}
