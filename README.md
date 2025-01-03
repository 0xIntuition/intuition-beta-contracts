# Intuition Protocol

Intuition is an Ethereum-based attestation protocol harnessing the wisdom of the crowds to create an open knowledge and reputation graph. Our infrastructure makes it easy for applications and their users to capture, explore, and curate verifiable data. We’ve prioritized making developer integrations easy and have implemented incentive structures that prioritize ‘useful’ data and discourage spam.

In bringing this new data layer to the decentralized web, we’re opening the flood gates to countless new use cases that we believe will kick off a consumer application boom.

The Intuition Knowledge Graph will be recognized as an organic flywheel, where the more developers that implement it, the more valuable the data it houses becomes.

## Getting Started

- [Intuition Protocol](#intuition-protocol)
  - [Getting Started](#getting-started)
  - [Documentation](#documentation)
    - [Known Nuances](#known-nuances)
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

## Documentation

To get a basic understanding of the Intuition protocol, please check out the following:

- [Official Website](https://intuition.systems)
- [Official Documentation](https://docs.intuition.systems)
- [Deep Dive into Our Smart Contracts](https://intuition.gitbook.io/intuition-or-beta-contracts)

### Known Nuances

- Share prices may get arbitrarily large as deposits/withdraws occur after Vault asset and share amounts approach 0 (i.e. if all users have withdrawn from the Vault), but this still elegantly achieves our desired functionality - which is, Users earn fee revenue when they are shareholders of a vault and deposit/redeem activities occur while they remain shareholders. This novel share price mechanism is used in lieu of a side-pocket reward pool for gas efficiency.
- The Admin can pause the contracts, though there is an emergency withdraw that allows users to withdraw from the contract even while paused. This emergency withdraw bypasses all fees, to reduce the surface area of attack.
- Exit fees are configurable, but have a maximum limit which they can be set to, preventing loss of user funds. Users also have the timelock window to withdraw from the contracts if they do not agree with a parameter change.

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
