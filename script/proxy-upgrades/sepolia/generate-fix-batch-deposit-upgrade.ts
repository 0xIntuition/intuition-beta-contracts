import { ethers } from "ethers";
import * as dotenv from "dotenv";
dotenv.config();

const BASE_SEPOLIA_RPC_URL = process.env.BASE_SEPOLIA_RPC_URL || "";
if (!BASE_SEPOLIA_RPC_URL) {
  throw new Error("Missing BASE_SEPOLIA_RPC_URL in .env");
}

/*
To run this:
pnpx tsx script/proxy-upgrades/generate-fix-batch-deposit-upgrade.ts
*/

async function main() {
  // Constants for the TimelockController and schedule parameters
  const timelockControllerAddress =
    "0xe6BE2A42cCAeB73909A79CC89299eBDA7bAa7Ea2"; // TimelockController contract address on Base sepolia
  const target = "0xD4436f981D2dcE0C074Eca869fdA1650227c7Efe"; // ProxyAdmin contract address on Base sepolia
  const value = 0;
  const predecessor =
    "0x0000000000000000000000000000000000000000000000000000000000000000";
  const salt =
    "0x0000000000000000000000000000000000000000000000000000000000000000";

  // Reinitialize calldata (can be left empty if no reinitialization call is needed)
  const reinitializeCalldata = process.argv[2]
    ? process.argv[2]
    : "0x"

  // To be replaced with actual values as needed
  const proxy = process.argv[3]
    ? process.argv[3]
    : "0x1A6950807E33d5bC9975067e6D6b5Ea4cD661665"; // EthMultiVault proxy contract address on Base sepolia
  const implementation = process.argv[4]
    ? process.argv[4]
    : "0x812D12A1f56B00722979F70cF05858d983FB1Cf7"; // Replace with the actual implementation address you want to upgrade to once it's deployed

  // Validate proxy and implementation addresses are provided and are valid
  if (!proxy || !implementation) {
    throw new Error("Proxy and implementation addresses must be provided.");
  }

  if (
    !ethers.utils.isAddress(proxy) ||
    !ethers.utils.isAddress(implementation)
  ) {
    throw new Error("Invalid proxy or implementation address.");
  }

  // Initialize the provider
  const provider = new ethers.providers.JsonRpcProvider(BASE_SEPOLIA_RPC_URL);

  // Fetch the minimum delay from the TimelockController contract
  const timelockABI = [
    "function getMinDelay() external view returns (uint256)",
  ];
  const timelockContract = new ethers.Contract(
    timelockControllerAddress,
    timelockABI,
    // @ts-ignore
    provider
  );
  const delay = await timelockContract.getMinDelay();

  // Generate the calldata for the upgradeAndCall function
  const proxyAdminABI = [
    "function upgradeAndCall(address proxy, address implementation, bytes data) external payable",
  ];
  const proxyAdminInterface = new ethers.utils.Interface(proxyAdminABI);
  const data = proxyAdminInterface.encodeFunctionData("upgradeAndCall", [
    proxy,
    implementation,
    reinitializeCalldata,
  ]);

  // Log the schedule parameters
  console.log("Schedule Parameters:\n");
  console.log(`Target: ${target}\n`);
  console.log(`Value: ${value}\n`);
  console.log(`Data: ${data}\n`);
  console.log(`Predecessor: ${predecessor}\n`);
  console.log(`Salt: ${salt}\n`);
  console.log(`Delay: ${delay}\n`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
