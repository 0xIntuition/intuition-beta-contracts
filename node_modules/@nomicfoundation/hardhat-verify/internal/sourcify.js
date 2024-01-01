"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.Sourcify = void 0;
const errors_1 = require("./errors");
const undici_1 = require("./undici");
const sourcify_types_1 = require("./sourcify.types");
class Sourcify {
    constructor(chainId, apiUrl, browserUrl) {
        this.chainId = chainId;
        this.apiUrl = apiUrl;
        this.browserUrl = browserUrl;
    }
    // https://sourcify.dev/server/api-docs/#/Repository/get_check_all_by_addresses
    async isVerified(address) {
        const parameters = new URLSearchParams({
            addresses: address,
            chainIds: `${this.chainId}`,
        });
        const url = new URL(`${this.apiUrl}/check-all-by-addresses`);
        url.search = parameters.toString();
        try {
            const response = await (0, undici_1.sendGetRequest)(url);
            const json = (await response.body.json());
            if (!(0, undici_1.isSuccessStatusCode)(response.statusCode)) {
                throw new errors_1.ContractVerificationInvalidStatusCodeError(url.toString(), response.statusCode, JSON.stringify(json));
            }
            if (!Array.isArray(json)) {
                throw new Error(`Unexpected response body: ${JSON.stringify(json)}`);
            }
            const contract = json.find((match) => match.address.toLowerCase() === address.toLowerCase());
            if (contract === undefined) {
                return false;
            }
            if ("status" in contract &&
                contract.status === sourcify_types_1.ContractStatus.NOT_FOUND) {
                return false;
            }
            if ("chainIds" in contract && contract.chainIds.length === 1) {
                const { status } = contract.chainIds[0];
                if (status === sourcify_types_1.ContractStatus.PERFECT ||
                    status === sourcify_types_1.ContractStatus.PARTIAL) {
                    return status;
                }
            }
            throw new Error(`Unexpected response body: ${JSON.stringify(json)}`);
        }
        catch (e) {
            if (e instanceof errors_1.ContractVerificationInvalidStatusCodeError) {
                throw e;
            }
            throw new errors_1.UnexpectedError(e, "Sourcify.isVerified");
        }
    }
    // https://sourcify.dev/server/api-docs/#/Stateless%20Verification/post_verify
    async verify(address, files, chosenContract) {
        const parameters = {
            address,
            files,
            chain: `${this.chainId}`,
        };
        if (chosenContract !== undefined) {
            parameters.chosenContract = `${chosenContract}`;
        }
        const url = new URL(this.apiUrl);
        try {
            const response = await (0, undici_1.sendPostRequest)(url, JSON.stringify(parameters), {
                "Content-Type": "application/json",
            });
            const json = (await response.body.json());
            if (!(0, undici_1.isSuccessStatusCode)(response.statusCode)) {
                throw new errors_1.ContractVerificationInvalidStatusCodeError(url.toString(), response.statusCode, JSON.stringify(json));
            }
            const sourcifyResponse = new SourcifyResponse(json);
            if (!sourcifyResponse.isOk()) {
                throw new Error(`Verify response is not ok: ${JSON.stringify(json)}`);
            }
            return sourcifyResponse;
        }
        catch (e) {
            if (e instanceof errors_1.ContractVerificationInvalidStatusCodeError) {
                throw e;
            }
            throw new errors_1.UnexpectedError(e, "Sourcify.verify");
        }
    }
    getContractUrl(address, contractStatus) {
        const matchType = contractStatus === sourcify_types_1.ContractStatus.PERFECT
            ? "full_match"
            : "partial_match";
        return `${this.browserUrl}/contracts/${matchType}/${this.chainId}/${address}/`;
    }
}
exports.Sourcify = Sourcify;
class SourcifyResponse {
    constructor(response) {
        if ("error" in response) {
            this.error = response.error;
        }
        else if (response.result[0].status === sourcify_types_1.ContractStatus.PERFECT) {
            this.status = sourcify_types_1.ContractStatus.PERFECT;
        }
        else if (response.result[0].status === sourcify_types_1.ContractStatus.PARTIAL) {
            this.status = sourcify_types_1.ContractStatus.PARTIAL;
        }
    }
    isPending() {
        return false;
    }
    isFailure() {
        return this.error !== undefined;
    }
    isSuccess() {
        return this.error === undefined;
    }
    isOk() {
        return (this.status === sourcify_types_1.ContractStatus.PERFECT ||
            this.status === sourcify_types_1.ContractStatus.PARTIAL);
    }
}
//# sourceMappingURL=sourcify.js.map