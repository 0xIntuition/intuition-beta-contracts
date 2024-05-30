## Instructions

### PreRequisites

- [Foundry](https://getfoundry.sh)
- (Optional) [VSCode Hardhat Solidity Plugin](https://marketplace.visualstudio.com/items?itemName=NomicFoundation.hardhat-solidity)
- (Optional) [VSCode Coverage Gutters](https://marketplace.visualstudio.com/items?itemName=ryanluker.vscode-coverage-gutters)

### Local Development

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
- RPC URL of the network that you’re trying to deploy to (as for us, we’re targeting Base Sepolia testnet as our target chain in the testnet phase)
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

### Upgrade Process

To upgrade the smart contract you need:
- Deploy a new version of EthMultiVault. You need to add the directive ```@custom:oz-upgrades-from``` on the line before where you define the contract and set the version of the upgrade on the ```init``` function (eg. reinitializer(2))
- Schedule the upgrade for some time in the future (eg. 2 days) using this script to generate the parameters that can be used in Safe Transaction Builder:

```shell
$ forge script script/TimelockController.s.sol
```

- After the delay passes (eg. 2 days) you can call this again, just change the method on the target to ```execute```

**Notes:**
- You can use an optional parameter `--constructor-args` to pass the constructor arguments of the smart contract in the ABI-encoded format
- The chain ID for Base Sepolia is `84532`.

### Example of Deployments

<details>

<summary>Base Mainnet</summary>

- [AtomWallet implementation](https://basescan.org/address/0x17a923696036e6af9ed92a50444dcc8872e35a28)
- [UpgradeableBeacon](https://basescan.org/address/0xb665e0cb8c5520f3894a68a4e077dcc7e2d6443b)
- [EthMultiVault implementation](https://basescan.org/address/0x0028ce4f7ba7f738766008457ca36eef7712d0e5)
- [EthMultiVault proxy](https://basescan.org/address/0x73edf2a6aca5ac52041d1d14deb3157a33b9ab6d)
- [ProxyAdmin](https://basescan.org/address/0x4Cc0d2D03dF9eea7fed2C94A53e0A54f7B4EB121)
- [TimelockController](https://basescan.org/address/0xe203084f698140BA986ceADa7E14E2FE077e51dA)

<summary>Base Sepolia</summary>

- [AtomWallet implementation](https://sepolia.basescan.org/address/0xBA33302d829aCe2a26F1b40C6F8F7736390d096C)
- [UpgradeableBeacon](https://sepolia.basescan.org/address/0xE67B767bc5f0f6Aacb9647c46A2D3Cb03E1DC053)
- [EthMultiVault implementation](https://sepolia.basescan.org/address/0x3C760876f5199065ED35D167e93D79c20a1f168E)
- [EthMultiVault proxy](https://sepolia.basescan.org/address/0x78f576A734dEEFFd0C3550E6576fFf437933D9D5)
- [ProxyAdmin](https://sepolia.basescan.org/address/0x8279459E49727Fb71ba423C9bFcF601547D8a00a)
- [TimelockController](https://sepolia.basescan.org/address/0x00D4BBE40d9689AAbfB68A222790081BD3cdCc56)