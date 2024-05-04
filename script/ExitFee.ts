import { ethers, parseEther } from "ethers";
import fs from "fs";
import { TxBuilder } from "@morpho-labs/gnosis-tx-builder";

// Chain id
const chainId = 84532; // Base Sepolia

// Address of the Transparent Upgradable Proxy
const proxy = "0x000..00";

// New exit fee (eg. 500 for 5%) for vault id
const vaultId = 0; // default
const exitFee = 500;

// Generate the json files for scheduling and executing the transactions
// on Safe.Global Transaction Builder
// > ts-node script/ExitFee.ts
async function main() {

  // ABI of the EthMultiVault contract (reduced)
  const abi = [
    {
      "type": "function",
      "name": "scheduleOperation",
      "inputs": [
        {
          "name": "operationId",
          "type": "bytes32",
          "internalType": "bytes32"
        },
        {
          "name": "data",
          "type": "bytes",
          "internalType": "bytes"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "setExitFee",
      "inputs": [
        {
          "name": "id",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "exitFee",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
    }
  ];

  // contract factory
  const EthMultiVault = new ethers.Contract(
    proxy,
    abi,
  );

  // -----------------------------------------------------------------
  //
  //                  Scheduling the operation
  // 
  // -----------------------------------------------------------------
  const scheduleOperationTransaction = [
    {
      to: proxy,
      value: parseEther("0").toString(),
      contractMethod: {
        name: "scheduleOperation",
        inputs: [
          {
            name: "operationId",
            internalType: "string",
            type: "bytes32",
          },
          {
            name: "data",
            internalType: "string",
            type: "bytes",
          },
        ],
        payable: true,    
      },
      contractInputsValues: {
        "operationId": ethers.keccak256(ethers.toUtf8Bytes("setExitFee")),
        "data": EthMultiVault.interface.encodeFunctionData("setExitFee", [vaultId, exitFee]),
      }
    },
  ];

  const scheduleTx = TxBuilder.batch(
    proxy, 
    scheduleOperationTransaction, 
    { 
      chainId: chainId, 
      name: "Schedule SetExitFee", 
      description: "Schedule a new exit fee" 
    }
  );
  
  const scheduleFile = "./script/ScheduleExitFee.json";
  fs.writeFileSync(scheduleFile, JSON.stringify(scheduleTx, null, 2));
  console.log("File for scheduling:", scheduleFile);

  // -----------------------------------------------------------------
  //
  //                       Executing
  // 
  // -----------------------------------------------------------------
  const execTransaction = [
    {
      to: proxy,
      value: parseEther("0").toString(),
      contractMethod: {
        name: "setExitFee",
        inputs: [
          {
            name: "id",
            internalType: "number",
            type: "uint256",
          },
          {
            name: "exitFee",
            internalType: "number",
            type: "uint256",
          },
        ],
        payable: true,    
      },
      contractInputsValues: {
        "id": String(vaultId),
        "exitFee": String(exitFee),
      }
    },
  ];

  const execTx = TxBuilder.batch(
    proxy, 
    execTransaction, 
    { 
      chainId: chainId, 
      name: "Exec SetExitFee", 
      description: "Exec a new exit fee" 
    }
  );
  
  const execFile = "./script/ExecExitFee.json";
  fs.writeFileSync(execFile, JSON.stringify(execTx, null, 2));  
  console.log("File for executing :", execFile);
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e)
    process.exit(1)
})
