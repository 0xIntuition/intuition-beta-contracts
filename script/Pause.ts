import { ethers, parseEther } from "ethers";
import fs from "fs";
import { TxBuilder } from "@morpho-labs/gnosis-tx-builder";

// Chain id
const chainId = 84532; // Base Sepolia

// Address of the Transparent Upgradable Proxy
const proxy = "0x767A4d81Ebf73E01dCDD13F502df686B076FC61f";

// Generate the json files for pause and unpause methods to use
// on Safe.Global Transaction Builder
// > ts-node script/Pause.ts
async function main() {

  // ABI of the EthMultiVault contract (reduced)
  const abi = [
    {
        "type": "function",
        "name": "unpause",
        "inputs": [],
        "outputs": [],
        "stateMutability": "nonpayable"
      },
      {
        "type": "function",
        "name": "pause",
        "inputs": [],
        "outputs": [],
        "stateMutability": "nonpayable"
      },        
  ];

  // contract factory
  const EthMultiVault = new ethers.Contract(
    proxy,
    abi,
  );

  // -----------------------------------------------------------------
  //
  //                               Pause
  // 
  // -----------------------------------------------------------------
  const pauseTransaction = [
    {
      to: proxy,
      value: parseEther("0").toString(),
      contractMethod: {
        name: "pause",
        inputs: [],
        payable: true,    
      },
      contractInputsValues: {}
    },
  ];

  const pauseTx = TxBuilder.batch(
    proxy, 
    pauseTransaction, 
    { 
      chainId: chainId, 
      name: "pause", 
      description: "Pause the contract" 
    }
  );
  
  const pauseFile = "./script/Pause.json";
  fs.writeFileSync(pauseFile, JSON.stringify(pauseTx, null, 2));
  console.log("File for pause:", pauseFile);

  // -----------------------------------------------------------------
  //
  //                               Unpause
  // 
  // -----------------------------------------------------------------
  const unpauseTransaction = [
    {
      to: proxy,
      value: parseEther("0").toString(),
      contractMethod: {
        name: "unpause",
        inputs: [],
        payable: true,    
      },
      contractInputsValues: {}
    },
  ];

  const unpauseTx = TxBuilder.batch(
    proxy, 
    pauseTransaction, 
    { 
      chainId: chainId, 
      name: "unpause", 
      description: "Unpause the contract" 
    }
  );
  
  const unpauseFile = "./script/Unpause.json";
  fs.writeFileSync(unpauseFile, JSON.stringify(unpauseTx, null, 2));
  console.log("File for pause:", unpauseFile);
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e)
    process.exit(1)
})
