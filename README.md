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
