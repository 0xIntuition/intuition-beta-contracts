# Intuition Protocol

Intuition is an Ethereum-based attestation protocol harnessing the wisdom of the crowds to create an open knowledge and reputation graph. Our infrastructure makes it easy for applications and their users to capture, explore, and curate verifiable data. We’ve prioritized making developer integrations easy and have implemented incentive structures that prioritize ‘useful’ data and discourage spam.

In bringing this new data layer to the decentralized web, we’re opening the flood gates to countless new use cases that we believe will kick off a consumer application boom.

The Intuition Knowledge Graph will be recognized as an organic flywheel, where the more developers that implement it, the more valuable the data it houses becomes.

## Documentation

To get a basic understanding of the Intuition protocol, please check out the following:

- [Official Website](https://intuition.systems)
- [Official Documentation](https://docs.intuition.systems)
- [Deep Dive into Our Smart Contracts](https://intuition.gitbook.io/intuition-or-beta-contracts)

### Known Nuances

- Share prices are weird, but elegantly achieve our desired functionality - which is, Users earn fee revenue when they are shareholders of a vault and other users deposit/redeem from the vault while they remain shareholders. This novel share price mechanism is used in lieu of a side-pocket reward pool for gas efficiency.
  - For example: User A deposits 1 ETH into a vault with a share price of 1 ETH. There is a 5% entry fee applied. User receives 0.95 shares. Assuming no other depositors in the vault, the Vault now has 1 ETH and 0.95 shares outstanding -> share price is now 1.052.
  - User A now redeems their shares from the pool, paying a 5% exit fee to the vault. The vault now has 0.05 ETH and 0 shares; for this reason, we mint some number of 'ghost shares' to the 0 address upon vault instantiation, so that the number of outstanding shares will never be 0; however, because of the small number of outstanding 'ghost' shares, share price becomes arbitrarily high because of the large discrepancy between [Oustanding Shares] and [Assets in the Vault].

## Building and Running Tests

To build the project and run tests, follow these steps:

### Prerequisites

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

### Run Manticore (Symbol Execution)

- Make sure you have [Docker](https://docker.com/products/docker-desktop) installed on your local machine

- Build the Docker image:

```shell
  $ docker build -t manticore-analysis .
```

- Run the Docker container:

```shell
  $ docker run --rm -v "$(pwd)":/app manticore-analysis
```

#### Run 

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
