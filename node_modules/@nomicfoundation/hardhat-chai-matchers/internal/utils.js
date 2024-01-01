"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.preventAsyncMatcherChaining = exports.assertIsNotNull = void 0;
const constants_1 = require("./constants");
const errors_1 = require("./errors");
function assertIsNotNull(value, valueName) {
    if (value === null) {
        throw new errors_1.HardhatChaiMatchersAssertionError(`${valueName} should not be null`);
    }
}
exports.assertIsNotNull = assertIsNotNull;
function preventAsyncMatcherChaining(context, matcherName, chaiUtils, allowSelfChaining = false) {
    const previousMatcherName = chaiUtils.flag(context, constants_1.PREVIOUS_MATCHER_NAME);
    if (previousMatcherName === undefined) {
        chaiUtils.flag(context, constants_1.PREVIOUS_MATCHER_NAME, matcherName);
        return;
    }
    if (previousMatcherName === matcherName && allowSelfChaining) {
        return;
    }
    throw new errors_1.HardhatChaiMatchersNonChainableMatcherError(matcherName, previousMatcherName);
}
exports.preventAsyncMatcherChaining = preventAsyncMatcherChaining;
//# sourceMappingURL=utils.js.map