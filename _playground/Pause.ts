import { ethers } from "ethers";
import { TxBuilder } from "@morpho-labs/gnosis-tx-builder";
import fs from "fs";

const PROXY_ADDRESS = "0x0000000000000000000000000000000000000000"; // Transparent Upgradable Proxy
const CHAIN_ID = 84532; // Base Sepolia (84532), Base Mainnet (8453)
const PAUSE_FILENAME = "./_playground/Pause.json";
const UNPAUSE_FILENAME = "./_playground/Unpause.json";

// Generate the json files for pause and UNPAUSE methods to use
// on Safe.Global Transaction Builder
// > ts-node Pause.ts
async function main() {
  // -----------------------------------------------------------------
  //
  //                               Pause
  //
  // -----------------------------------------------------------------
  const pauseTransaction = [
    {
      to: PROXY_ADDRESS,
      value: ethers.utils.parseEther("0").toString(),
      contractMethod: {
        name: "pause",
        inputs: [],
        outputs: [],
        payable: false,
      },
      contractInputsValues: {},
    },
  ];

  const pauseTx = TxBuilder.batch(PROXY_ADDRESS, pauseTransaction, {
    chainId: CHAIN_ID,
    name: "pause",
    description: "Pause the contract",
  });

  fs.writeFileSync(PAUSE_FILENAME, JSON.stringify(pauseTx, null, 2));
  console.log("File for pause:", PAUSE_FILENAME);

  // -----------------------------------------------------------------
  //
  //                               Unpause
  //
  // -----------------------------------------------------------------
  const unpauseTransaction = [
    {
      to: PROXY_ADDRESS,
      value: ethers.utils.parseEther("0").toString(),
      contractMethod: {
        name: "unpause",
        inputs: [],
        outputs: [],
        payable: false,
      },
      contractInputsValues: {},
    },
  ];

  const unpauseTx = TxBuilder.batch(PROXY_ADDRESS, unpauseTransaction, {
    chainId: CHAIN_ID,
    name: "unpause",
    description: "Unpause the contract",
  });

  fs.writeFileSync(UNPAUSE_FILENAME, JSON.stringify(unpauseTx, null, 2));
  console.log("File for pause:", UNPAUSE_FILENAME);
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e)
    process.exit(1)
  })
