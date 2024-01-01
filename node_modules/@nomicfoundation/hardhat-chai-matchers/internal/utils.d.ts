/// <reference types="chai" />
export declare function assertIsNotNull<T>(value: T, valueName: string): asserts value is Exclude<T, null>;
export declare function preventAsyncMatcherChaining(context: object, matcherName: string, chaiUtils: Chai.ChaiUtils, allowSelfChaining?: boolean): void;
//# sourceMappingURL=utils.d.ts.map