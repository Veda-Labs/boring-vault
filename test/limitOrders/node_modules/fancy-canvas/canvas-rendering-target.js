"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.tryCreateCanvasRenderingTarget2D = exports.createCanvasRenderingTarget2D = exports.CanvasRenderingTarget2D = void 0;
/**
 * @experimental
 */
var CanvasRenderingTarget2D = /** @class */ (function () {
    function CanvasRenderingTarget2D(context, mediaSize, bitmapSize) {
        if (mediaSize.width === 0 || mediaSize.height === 0) {
            throw new TypeError('Rendering target could only be created on a media with positive width and height');
        }
        this._mediaSize = mediaSize;
        // !Number.isInteger(bitmapSize.width) || !Number.isInteger(bitmapSize.height)
        if (bitmapSize.width === 0 || bitmapSize.height === 0) {
            throw new TypeError('Rendering target could only be created using a bitmap with positive integer width and height');
        }
        this._bitmapSize = bitmapSize;
        this._context = context;
    }
    CanvasRenderingTarget2D.prototype.useMediaCoordinateSpace = function (f) {
        try {
            this._context.save();
            // do not use resetTransform to support old versions of Edge
            this._context.setTransform(1, 0, 0, 1, 0, 0);
            this._context.scale(this._horizontalPixelRatio, this._verticalPixelRatio);
            return f({
                context: this._context,
                mediaSize: this._mediaSize,
            });
        }
        finally {
            this._context.restore();
        }
    };
    CanvasRenderingTarget2D.prototype.useBitmapCoordinateSpace = function (f) {
        try {
            this._context.save();
            // do not use resetTransform to support old versions of Edge
            this._context.setTransform(1, 0, 0, 1, 0, 0);
            return f({
                context: this._context,
                mediaSize: this._mediaSize,
                bitmapSize: this._bitmapSize,
                horizontalPixelRatio: this._horizontalPixelRatio,
                verticalPixelRatio: this._verticalPixelRatio,
            });
        }
        finally {
            this._context.restore();
        }
    };
    Object.defineProperty(CanvasRenderingTarget2D.prototype, "_horizontalPixelRatio", {
        get: function () {
            return this._bitmapSize.width / this._mediaSize.width;
        },
        enumerable: false,
        configurable: true
    });
    Object.defineProperty(CanvasRenderingTarget2D.prototype, "_verticalPixelRatio", {
        get: function () {
            return this._bitmapSize.height / this._mediaSize.height;
        },
        enumerable: false,
        configurable: true
    });
    return CanvasRenderingTarget2D;
}());
exports.CanvasRenderingTarget2D = CanvasRenderingTarget2D;
/**
 * @experimental
 */
function createCanvasRenderingTarget2D(binding, contextOptions) {
    var mediaSize = binding.canvasElementClientSize;
    var bitmapSize = binding.bitmapSize;
    var context = binding.canvasElement.getContext('2d', contextOptions);
    if (context === null) {
        throw new Error('Could not get 2d drawing context from bound canvas element. Has the canvas already been set to a different context mode?');
    }
    return new CanvasRenderingTarget2D(context, mediaSize, bitmapSize);
}
exports.createCanvasRenderingTarget2D = createCanvasRenderingTarget2D;
/**
 * @experimental
 */
function tryCreateCanvasRenderingTarget2D(binding, contextOptions) {
    var mediaSize = binding.canvasElementClientSize;
    if (mediaSize.width === 0 || mediaSize.height === 0) {
        return null;
    }
    var bitmapSize = binding.bitmapSize;
    if (bitmapSize.width === 0 || bitmapSize.height === 0) {
        return null;
    }
    var context = binding.canvasElement.getContext('2d', contextOptions);
    if (context === null) {
        return null;
    }
    return new CanvasRenderingTarget2D(context, mediaSize, bitmapSize);
}
exports.tryCreateCanvasRenderingTarget2D = tryCreateCanvasRenderingTarget2D;
