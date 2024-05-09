import { ethers } from "ethers";
import { TxBuilder } from "@morpho-labs/gnosis-tx-builder";
import fs from "fs";

const PROXY_ADDRESS = "0x0000000000000000000000000000000000000000"; // Transparent Upgradable Proxy
const CHAIN_ID = 84532; // Base Sepolia (84532), Base Mainnet (8453)
const VAULT_ID = "0"; // default vault
const EXIT_FEE = "500"; // 5%
const SCHEDULE_FILENAME = "./_playground/ScheduleExitFee.json";
const EXEC_FILENAME = "./_playground/ExecExitFee.json";


// Generate the json files for scheduling and executing the transactions
// on Safe.Global Transaction Builder
// > ts-node ExitFee.ts
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
      "outputs": [],
      "stateMutability": "nonpayable"
    }
  ];

  // contract factory
  const EthMultiVault = new ethers.Contract(
    PROXY_ADDRESS,
    abi,
  );

  // -----------------------------------------------------------------
  //
  //                  Scheduling the operation
  // 
  // -----------------------------------------------------------------
  const scheduleOperationTransaction = [
    {
      to: PROXY_ADDRESS,
      value: ethers.utils.parseEther("0").toString(),
      contractMethod: {
        name: "scheduleOperation",
        inputs: [
          {
            name: "operationId",
            internalType: "bytes32",
            type: "bytes32",
          },
          {
            name: "data",
            internalType: "bytes",
            type: "bytes",
          },
        ],
        payable: true,
      },
      contractInputsValues: {
        "operationId": ethers.utils.keccak256(ethers.utils.toUtf8Bytes("setExitFee")),
        "data": EthMultiVault.interface.encodeFunctionData("setExitFee", [VAULT_ID, EXIT_FEE]),
      }
    },
  ];

  const scheduleTx = TxBuilder.batch(
    PROXY_ADDRESS,
    scheduleOperationTransaction,
    {
      chainId: CHAIN_ID,
      name: "Schedule SetExitFee",
      description: "Schedule a new exit fee"
    }
  );

  fs.writeFileSync(SCHEDULE_FILENAME, JSON.stringify(scheduleTx, null, 2));
  console.log("File for scheduling:", SCHEDULE_FILENAME);

  // -----------------------------------------------------------------
  //   
  //                  Executing
  //
  // -----------------------------------------------------------------
  const execTransaction = [
    {
      to: PROXY_ADDRESS,
      value: ethers.utils.parseEther("0").toString(),
      contractMethod: {
        name: "setExitFee",
        inputs: [
          {
            name: "id",
            internalType: "uint256",
            type: "uint256",
          },
          {
            name: "exitFee",
            internalType: "uint256",
            type: "uint256",
          },
        ],
        payable: true,
      },
      contractInputsValues: {
        "id": ethers.utils.parseEther(VAULT_ID).toString(),
        "exitFee": ethers.utils.parseEther(EXIT_FEE).toString(),
      }
    },
  ];

  const execTx = TxBuilder.batch(
    PROXY_ADDRESS,
    execTransaction,
    {
      chainId: CHAIN_ID,
      name: "Exec SetExitFee",
      description: "Exec a new exit fee"
    }
  );

  fs.writeFileSync(EXEC_FILENAME, JSON.stringify(execTx, null, 2));
  console.log("File for executing :", EXEC_FILENAME);
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e)
    process.exit(1)
  })
