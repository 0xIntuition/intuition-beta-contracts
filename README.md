# Intuition Protocol

Intuition is an Ethereum-based attestation protocol harnessing the wisdom of the crowds to create an open knowledge and reputation graph. Our infrastructure makes it easy for applications and their users to capture, explore, and curate verifiable data. We’ve prioritized making developer integrations easy and have implemented incentive structures that prioritize ‘useful’ data and discourage spam.

In bringing this new data layer to the decentralized web, we’re opening the flood gates to countless new use cases that we believe will kick off a consumer application boom.

The Intuition Knowledge Graph will be recognized as an organic flywheel, where the more developers that implement it, the more valuable the data it houses becomes.

## Documentation

To get a basic understanding of the Intuition protocol, please check out the following:
- [Official Website](https://intuition.systems)
- [Official Documentation](https://docs.intuition.systems)
- [Deep Dive into Our Smart Contracts](https://intuition.gitbook.io/intuition-or-beta-contracts)

## Building and Running Tests

To build the project and run tests, follow these steps:

### Prerequisites

- [Node.js](https://nodejs.org/en/download/)
- [Foundry](https://getfoundry.sh)

### Step by Step Guide

#### Install Dependencies

```shell
$ npm i
$ forge install
```

#### Build

```shell
$ forge build
```

#### Run Tests

```shell
$ forge test -vvv
```

### Deployment Process using OpenZeppelin Defender

To deploy the v1 smart contract system on to a public testnet or mainnet, you’ll need the following:
- Set the credentials DEFENDER_KEY and DEFENDER_SECRET on a .env file
- RPC URL of the network that you’re trying to deploy to (as for us, we’re targeting Base Sepolia testnet as our target chain for the testnet deployments)
- Export private key of a deployer account in the terminal, and fund it with some test ETH to be able to cover the gas fees for the smart contract deployments
- For Base Sepolia, there is a reliable [testnet faucet](https://alchemy.com/faucets/base-sepolia) deployed by Alchemy
- Deploy smart contracts using the following command:

```shell
$ forge script script/Deploy.s.sol --broadcast --rpc-url <your_rpc_url> --private-key $PRIVATE_KEY
```

After the deployment go to the Deploy dashboard on OpenZeppelin Defender and approve

### Deployment Verification

To verify the deployed smart contracts on Etherscan, you’ll need to export your Etherscan API key as `ETHERSCAN_API_KEY` in the terminal, and then run the following command:

```shell
$ forge verify-contract <0x_contract_address> ContractName --watch --chain-id <chain_id>
```

**Notes:**
- When verifying your smart contracts, you can use an optional parameter `--constructor-args` to pass the constructor arguments of the smart contract in the ABI-encoded format
- The chain ID for Base Sepolia is `84532`, whereas the chain ID for Base Mainnet is `8453`

### Upgrade Process

To upgrade the smart contract you need:
- Deploy a new version of contracts you want to upgrade, for example `EthMultiVault`. You need to add the directive `@custom:oz-upgrades-from` on the line before where you define the contract and set the version of the upgrade on the `init` function (e.g. `reinitializer(2)`)
- If using a multisig as an upgrade admin, schedule the upgrade for some time in the future (e.g. 2 days) using this script to generate the parameters that can be used in Safe Transaction Builder:

```shell
$ forge script script/TimelockController.s.sol
```

- After the delay passes (e.g. 2 days) you can call this again, just change the method on the target to `execute`


| Name | Proxy | Implementation | Notes |
| -------- | -------- | -------- | -------- |
| [`AtomWallet`](https://github.com/0xIntuition/intuition-contracts/blob/tob-audit/src/AtomWallet.sol) | [`0xE67B767bc5f0f6Aacb9647c46A2D3Cb03E1DC053`](https://sepolia.basescan.org/address/0xE67B767bc5f0f6Aacb9647c46A2D3Cb03E1DC053) | [`0xBA33302d829aCe2a26F1b40C6F8F7736390d096C`](https://sepolia.basescan.org/address/0xBA33302d829aCe2a26F1b40C6F8F7736390d096C) | AtomWalletBeacon: [`BeaconProxy`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/proxy/beacon/BeaconProxy.sol) <br /> Atom Wallets: [`UpgradeableBeacon`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/proxy/beacon/UpgradeableBeacon.sol) |
| [`EthMultiVault`](https://github.com/0xIntuition/intuition-contracts/blob/tob-audit/src/EthMultiVault.sol) | [`0x78f576A734dEEFFd0C3550E6576fFf437933D9D5`](https://sepolia.basescan.org/address/0x78f576A734dEEFFd0C3550E6576fFf437933D9D5) | [`0x3C760876f5199065ED35D167e93D79c20a1f168E`](https://sepolia.basescan.org/address/0x3C760876f5199065ED35D167e93D79c20a1f168E) | Proxy: [`TUP@5.0.2`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/proxy/transparent/TransparentUpgradeableProxy.sol) |
| [`ProxyAdmin`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/proxy/transparent/ProxyAdmin.sol) | - | [`0x8279459E49727Fb71ba423C9bFcF601547D8a00a`](https://sepolia.basescan.org/address/0x8279459E49727Fb71ba423C9bFcF601547D8a00a) | Used for upgrading `EthMultiVault` proxy contract |
| [`TimelockController`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/governance/TimelockController.sol) | - | [`0x00D4BBE40d9689AAbfB68A222790081BD3cdCc56`](https://sepolia.basescan.org/address/0x00D4BBE40d9689AAbfB68A222790081BD3cdCc56) | Owner of the `ProxyAdmin` and `AtomWalletBeacon` |
