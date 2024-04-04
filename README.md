## Instructions

### PreRequisites

- Foundry
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

### Deployment Process

To deploy the v1 smart contract system on to a public testnet or mainnet, you’ll need the following:
- RPC URL of the network that you’re trying to deploy to (as for us, we’re targeting Base Sepolia testnet as our target chain in the testnet phase)
- Export private key of a deployer account in the terminal, and fund it with some test ETH to be able to cover the gas fees for the smart contract deployments
- For Base Sepolia, there is a reliable [testnet faucet](https://www.alchemy.com/faucets/base-sepolia) deployed by Alchemy
- Deploy smart contracts using the following command:

```shell
$ forge script script/DeployV1.s.sol --broadcast --rpc-url <your_rpc_url> --private-key $PRIVATE_KEY
```

### Deployment Verification

To verify the deployed smart contracts on Etherscan, you’ll need to export your Etherscan API key as `ETHERSCAN_API_KEY` in the terminal, and then run the following command:

```shell
$ forge verify-contract <0x_contract_address> ContractName --watch --chain-id <chain_id>
```

**Notes:**
- You can use an optional parameter `--constructor-args` to pass the constructor arguments of the smart contract in the ABI-encoded format
- The chain ID for Base Sepolia is `84532`.

### Latest Deployments

<details>

<summary>Base Sepolia</summary>

- [AtomWallet implementation](https://sepolia.basescan.org/address/0x67601BcddCD15C1da7dbb449ec196b9eAc84A4c6)
- [AtomWalletBeacon](https://sepolia.basescan.org/address/0x9fBb10f4027f001c12086f98CE5145B694B4016C)
- [EthMultiVault implementation](https://sepolia.basescan.org/address/0x54d9e246D1DE5ff8bF196d5585D5D625Def86871)
- [EthMultiVault proxy](https://sepolia.basescan.org/address/0x2a30dCDAd9fe511A358F5C99060068956c00edb4)
- [ProxyAdmin](https://sepolia.basescan.org/address/0x76A44BaDDD4c490273E7D39D0276CfFAaC6eD275)
