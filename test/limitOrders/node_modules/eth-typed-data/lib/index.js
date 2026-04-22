"use strict";

var _interopRequireDefault = require("@babel/runtime/helpers/interopRequireDefault");

Object.defineProperty(exports, "__esModule", {
  value: true
});
Object.defineProperty(exports, "verify", {
  enumerable: true,
  get: function get() {
    return _verify.verify;
  }
});
exports.default = void 0;

var _Domain = _interopRequireDefault(require("./Domain"));

var _verify = require("./verify");

var _default = _Domain.default;
exports.default = _default;