# EthMultiVault Critical Vulnerability Unofficial Post-Mortem

## Executive Summary

On Aug 4, 2025, a critical vulnerability was discovered in the EthMultiVault contract deployed at `0x430bbf52503bd4801e51182f4cb9f8f534225de5` on the Base chain. The vulnerability allowed attackers to inflate vault accounting by claiming arbitrary deposit amounts without sending the corresponding ETH. This resulted in vault 512 reporting 5,848 ETH in totalAssets while the entire contract held only 68 ETH.

## Timeline of Events

### Discovery

- Initial Report: Critical discrepancy identified where vault 512 showed 5,848.409 ETH in totalAssets despite only 68 ETH total deposits across the entire contract
- Investigation Started: Deep dive into potential attack vectors including share inflation, fee manipulation, and state corruption

### Root Cause Analysis

- Block 33761654: Attack transaction identified (`0x00f12744f4dfe2885ca157c37f043551eec2ede47e524af4e034b341c639c98f`)
- Attack Method: Multicall pattern exploiting missing validation in `batchDeposit` function
- Vulnerability: `batchDeposit` and `batchDepositCurve` functions accepted user-supplied deposit amounts without validating `msg.value`

## Technical Details

### The Vulnerability

The `batchDeposit` function processed deposits based on an `amounts` array parameter but never verified that the actual ETH sent (`msg.value`) matched the claimed amounts:

```solidity
for (uint256 i = 0; i < termIds.length; i++) {
    uint256 protocolFee = protocolFeeAmount(amounts[i], termIds[i]);
    uint256 userDepositAfterprotocolFee = amounts[i] - protocolFee;

    // BUG: Uses amounts[i] without checking msg.value
    shares[i] = _deposit(receiver, termIds[i], userDepositAfterprotocolFee);
    _transferFeesToProtocolMultisig(protocolFee);
}
```

### Attack Execution

The attacker exploited this through a multicall transaction:

1. Called `batchDeposit([512], [5908.47 ETH])` with `msg.value = 0`
2. Called `depositAtom(512, 0.0288 ETH)` with actual ETH to appear legitimate
3. Result: Vault 512's totalAssets inflated from 0.010 ETH to 5,848.412 ETH

## Impact Assessment

### Direct Impact

- No direct loss of funds as the contract's actual ETH balance remained unchanged
- Vault 512's share price and totalAssets severely inflated
- Protocol integrity compromised with false accounting data

## Resolution

### Immediate Fix

Added validation to ensure `msg.value` matches the sum of claimed deposit amounts:

```solidity
uint256 totalRequired = 0;
for (uint256 i = 0; i < termIds.length; i++) {
    if (termIds[i] == 0 || termIds[i] > count) {
        revert Errors.EthMultiVault_VaultDoesNotExist();
    }
    if (amounts[i] < generalConfig.minDeposit) {
        revert Errors.EthMultiVault_MinimumDeposit();
    }
    totalRequired += amounts[i];
}

if (msg.value != totalRequired) {
    revert Errors.EthMultiVault_IncorrectETHAmount();
}
```

### Defense in Depth

Previously implemented protection in `_setVaultTotals` prevented totalAssets from exceeding contract balance, providing an additional safety layer.

## Lessons Learned

### What Went Wrong

1. Input Validation Gap: Critical assumption that user-supplied array values would match msg.value
2. Insufficient Testing: Edge case of mismatched values not covered in test suite
3. Code Review Miss: Vulnerability in high-value functions not caught during review

## Conclusion

This vulnerability highlighted the critical importance of validating all user inputs, especially in financial functions. While the defense-in-depth approach prevented catastrophic failure, the root cause allowed significant accounting manipulation. The swift resolution and comprehensive fix demonstrate the team's commitment to security, but this incident reinforces the need for exhaustive input validation and testing of edge cases in DeFi protocols.
