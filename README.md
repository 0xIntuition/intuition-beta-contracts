# Intuition Protocol

Intuition is an Ethereum-based attestation protocol harnessing the wisdom of the crowds to create an open knowledge and reputation graph. Our infrastructure makes it easy for applications and their users to capture, explore, and curate verifiable data. We’ve prioritized making developer integrations easy and have implemented incentive structures that prioritize ‘useful’ data and discourage spam.

In bringing this new data layer to the decentralized web, we’re opening the flood gates to countless new use cases that we believe will kick off a consumer application boom.

The Intuition Knowledge Graph will be recognized as an organic flywheel, where the more developers that implement it, the more valuable the data it houses becomes.

## Getting Started

- [Intuition Protocol](#intuition-protocol)
  - [Getting Started](#getting-started)
  - [Documentation](#documentation)
    - [Rationale](#rationale)
  - [Building and Running Tests](#building-and-running-tests)
    - [Prerequisites](#prerequisites)
    - [Step by Step Guide](#step-by-step-guide)
      - [Install Dependencies](#install-dependencies)
      - [Build](#build)
      - [Run Tests](#run-tests)
      - [Run Fuzz Tests](#run-fuzz-tests)
      - [Run Slither (Static Analysis)](#run-slither-static-analysis)
      - [Run Manticore (Symbolic Execution)](#run-manticore-symbolic-execution)
    - [Deployment Process](#deployment-process)
    - [Deployment Verification](#deployment-verification)
  - [Deployed Contracts](#deployed-contracts)
    - [Base Mainnet](#base-mainnet)
    - [Base Sepolia](#base-sepolia)
    - [Linea Mainnet](#linea-mainnet)

## Documentation

To get a basic understanding of the Intuition protocol, please check out the following:

- [Official Website](https://intuition.systems)
- [Official Documentation](https://docs.intuition.systems)
- [Deep Dive into Our Smart Contracts](https://intuition.gitbook.io/intuition-or-beta-contracts)
- [Full Contracts Documentation](https://0xintuition.github.io/intuition-beta-contracts)

### Rationale

- This repository contains a sort of frankenstein of the previously audited EthMultiVault and the new Bonding Curve Registry features.
- All bonding curve related activities have their own methods / routes in the EthMultiVault.
- This results in duplicative code, but enables us to keep the old EthMultiVault and the new Bonding Curve Registry features separate.
- The next version of the MultiVault will consolidate and converge these disparate pathways into a far more elegant and organized system.

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

#### Run Fuzz Tests

- Make sure you have at least node 16 and python 3.6 installed on your local machine
- Add your FUZZ_AP_KEY to the .env file locally
- Run the following command to install the `diligence-fuzzing` package:

```shell
$ pip3 install diligence-fuzzing
```

- After the installation is completed, run the fuzzing CLI:

```shell
$ fuzz forge test
```

- Finally, check your Diligence Fuzzing dashboard to see the results of the fuzzing tests

#### Run Slither (Static Analysis)

- Install the `slither-analyzer` package:

```shell
  $ pip3 install slither-analyzer
```

- After the installation is completed, run the slither analysis bash script:

```shell
  $ npm run slither
```

#### Run Manticore (Symbolic Execution)

- Make sure you have [Docker](https://docker.com/products/docker-desktop) installed on your local machine

- Build the Docker image:

```shell
  $ docker build -t manticore-analysis .
```

- Run the Docker container:

```shell
  $ docker run --rm -v "$(pwd)":/app manticore-analysis
```

### Deployment Process

To deploy the Beta smart contract system on to a public testnet or mainnet, you’ll need the following:

- RPC URL of the network that you’re trying to deploy to (as for us, we’re targeting Base Sepolia testnet as our target chain for the testnet deployments)
- Export `PRIVATE_KEY` of a deployer account in the terminal, and fund it with some test ETH to be able to cover the gas fees for the smart contract deployments
- For Base Sepolia, there is a reliable [testnet faucet](https://alchemy.com/faucets/base-sepolia) deployed by Alchemy
- Deploy smart contracts using the following command:

```shell
$ forge script script/Deploy.s.sol --broadcast --rpc-url <your_rpc_url> --private-key $PRIVATE_KEY
```

### Deployment Verification

To verify the deployed smart contracts on Etherscan, you’ll need to export your Etherscan API key as `ETHERSCAN_API_KEY` in the terminal, and then run the following command:

```shell
$ forge verify-contract <0x_contract_address> ContractName --watch --chain-id <chain_id>
```

**Notes:**

- When verifying your smart contracts, you can use an optional parameter `--constructor-args` to pass the constructor arguments of the smart contract in the ABI-encoded format
- The chain ID for Base Sepolia is `84532`, whereas the chain ID for Base Mainnet is `8453`

## Deployed Contracts

### Base Mainnet

ProxyAdmin: 0xc920E2F5eB6925faE85C69a98a2df6f56a7a245A
TimelockController (proxy admin owner): 0xE4992f9805D7737b5bDaDBEF5688087CF25D4B89
EthMultiVault (proxy address): 0x430BbF52503Bd4801E51182f4cB9f8F534225DE5
Admin Safe: 0xa28d4AAcA48bE54824dA53a19b05121DE71Ef480

### Base Sepolia

ProxyAdmin: 0xD4436f981D2dcE0C074Eca869fdA1650227c7Efe
TimelockController (proxy admin owner): 0xe6BE2A42cCAeB73909A79CC89299eBDA7bAa7Ea2
EthMultiVault (proxy address): 0x1A6950807E33d5bC9975067e6D6b5Ea4cD661665
Admin Safe: 0xEcAc3Da134C2e5f492B702546c8aaeD2793965BB

### Linea Mainnet

ProxyAdmin: 0x89e65a3c49cb1DF3D8Ee6036a158A728603CC1AD
TimelockController (proxy admin owner): 0xA71B2185D10CaB95Cd0d2DA2B9b0210f8ed31A66
EthMultiVault (proxy address): 0xB4375293a13017BCe71a034bB588786A3D3C7295
Admin Safe: 0x323e9506B929C21AE602D64d3807721AA49b4884
