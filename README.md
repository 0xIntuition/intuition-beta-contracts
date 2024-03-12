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

To verify the deployed smart contracts on Etherscan, you’ll need to export your Etherscan API key as `ETHERSCAN_API_KEY` in the terminal, and then run the following command:

```shell
$ forge verify-contract <0x_contract_address> ContractName --watch --chain-id <chain_id>
```

**Notes:**
- You can use an optional parameter `--constructor-args` to pass the constructor arguments of the smart contract in the ABI-encoded format
- The chain ID for OP Sepolia is `11155420`.

### Latest Deployments

<details>

<summary>Optimism Sepolia</summary>

- [Proxy](https://sepolia-optimism.etherscan.io/address/0x68A9d5849dAEa051E33E568092508468EA329a3E)
- [Implementation](https://sepolia-optimism.etherscan.io/address/0x34f8e22ba28a1a140fA888F99Dd1aA606aF15628)
