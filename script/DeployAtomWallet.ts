import { ethers } from "ethers";
require('dotenv').config();

const API_URL = "https://base-sepolia.g.alchemy.com/v2/YvaeQPIlbZdqJ-GiWv_NlryUvPp-ARXz";
const CHAIN_ID = 84532; // Base Sepolia

async function main() {

    const private_key = process.env.PRIVATE_KEY ? String(process.env.PRIVATE_KEY) : "";

    // ABI of the EthMultiVault contract (reduced)
    const abi = [
        {
            "type": "function",
            "name": "count",
            "inputs": [],
            "outputs": [
                {
                    "name": "",
                    "type": "uint256",
                    "internalType": "uint256"
                }
            ],
            "stateMutability": "view"
        },
        {
            "type": "function",
            "name": "getAtomCost",
            "inputs": [],
            "outputs": [
                {
                    "name": "",
                    "type": "uint256",
                    "internalType": "uint256"
                }
            ],
            "stateMutability": "view"
        },
        {
            "type": "function",
            "name": "createAtom",
            "inputs": [
                {
                    "name": "atomUri",
                    "type": "bytes",
                    "internalType": "bytes"
                }
            ],
            "outputs": [
                {
                    "name": "",
                    "type": "uint256",
                    "internalType": "uint256"
                }
            ],
            "stateMutability": "payable"
        },
        {
            "type": "function",
            "name": "deployAtomWallet",
            "inputs": [
                {
                    "name": "atomId",
                    "type": "uint256",
                    "internalType": "uint256"
                }
            ],
            "outputs": [
                {
                    "name": "",
                    "type": "address",
                    "internalType": "address"
                }
            ],
            "stateMutability": "nonpayable"
        },
    ];

    // Connect to the network
    let provider = new ethers.providers.JsonRpcProvider(API_URL, CHAIN_ID);

    // Address of the Transparent Upgradable Proxy
    let proxy = "0xb31C3A7f617ec14B0504D01cc7Caf702692064e3";

    // We connect to the Contract using a Provider, so we will only
    // have read-only access to the Contract
    let contract = new ethers.Contract(proxy, abi, provider);

    // Check the current vault counter
    let counter = await contract.count();
    console.log("counter:", counter.toNumber());

    // Get the current value
    let atomCost = await contract.getAtomCost();
    console.log("atomCost:", atomCost.toNumber());

    // Load the wallet to deploy the contract with
    let wallet = new ethers.Wallet(private_key, provider);

    // Create a new instance of the Contract with a Signer, which allows
    // update methods
    let contractWithSigner = contract.connect(wallet);

    let atomURI = ethers.utils.solidityPack(["string"], ["atom3"]);

    let tx = await contractWithSigner.createAtom(
        atomURI, {
        value: atomCost.toNumber(),
        gasPrice: ethers.utils.parseUnits("0.01", "gwei"),
    }
    );

    console.log("Tx hash:", tx.hash);

    // The operation is NOT complete yet; we must wait until it is mined
    await tx.wait();

    console.log("tx:", tx);

    let counter2 = await contract.count();
    console.log("counter2:", counter2.toNumber());

    let tx2 = await contractWithSigner.deployAtomWallet(
        ethers.utils.parseUnits("1"), {
        gasPrice: ethers.utils.parseUnits("0.01", "gwei"),
    }
    );

    await tx2.wait();

    console.log("tx2:", tx2);
}

main()
    .then(() => process.exit(0))
    .catch((e) => {
        console.error(e)
        process.exit(1)
    })
