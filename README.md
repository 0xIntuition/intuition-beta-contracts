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
- RPC URL of the network that you’re trying to deploy to (as for us, we’re targeting OP Sepolia testnet as our target chain in the testnet phase)
- Export private key of a deployer account in the terminal, and fund it with some test ETH (or other relevant native token) to be able to cover the gas fees for the smart contract deployments
- For OP Sepolia, there is a reliable [testnet faucet](https://optimism-faucet.com/) deployed by Alchemy
- Deploy smart contracts using the following command:

```shell
$ forge script script/DeployV1.s.sol --broadcast --rpc-url <your_rpc_url> --private-key $PRIVATE_KEY
```

### Deployment Verification

To verify the deployed smart contracts on Etherscan, you’ll need to export your etherscan API key as `ETHERSCAN_API_KEY` in the terminal, and then run the following command:

```shell
$ forge verify-contract <0x_contract_address> ContractName --watch --chain-id <chain_id>
```

Note that the chain ID for OP Sepolia is `11155420`.

### Latest Deployments

<details>

<summary>Optimism Sepolia</summary>

- [Proxy](https://sepolia-optimism.etherscan.io/address/0x14561f6B2CDf5dec7BA95b303DED0b2C95A96635)
- [Implementation](https://sepolia-optimism.etherscan.io/address/0xcd5f13867D40F8f4b135f3d45Dc16D88EFEFE583)
