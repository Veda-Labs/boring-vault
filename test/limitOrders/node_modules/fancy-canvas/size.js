"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.equalSizes = exports.size = void 0;
function size(_a) {
    var width = _a.width, height = _a.height;
    if (width < 0) {
        throw new Error('Negative width is not allowed for Size');
    }
    if (height < 0) {
        throw new Error('Negative height is not allowed for Size');
    }
    return {
        width: width,
        height: height,
    };
}
exports.size = size;
function equalSizes(first, second) {
    return (first.width === second.width) &&
        (first.height === second.height);
}
exports.equalSizes = equalSizes;
