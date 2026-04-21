"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.Web3 = exports.web3 = void 0;
var web3_1 = __importDefault(require("web3"));
exports.Web3 = web3_1.default;
exports.web3 = new web3_1.default();
