const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");
const {
  allowedCurves,
  generateSameValueArray,
  generateRandomBytes,
  curveContracts,
  wallet,
  generatePlot,
  generateHTMLPlot,
} = require("./utils.js");

// Define paths globally to make them accessible in both main and the conditional block
const jsonPath = "_playground/experiments/json/";
const imagePath = "_playground/experiments/images/";
const htmlPath = "_playground/experiments/html/";

const main = async (curveParam, numberOfDepositsParam) => {
  try {
    const curve = curveParam || process.argv[2] || "linear";
    const numberOfDeposits =
      parseInt(numberOfDepositsParam) || parseInt(process.argv[3]) || 10;

    if (!allowedCurves.includes(curve)) {
      throw new Error(
        `Invalid curve parameter: ${curve}. Allowed curves: ${allowedCurves.join(
          ", "
        )}`
      );
    }

    const shares = [];
    const assets = [];

    shares.push(0);
    assets.push(0);

    const contract = curveContracts[curve];

    const atomCost = await contract.getAtomCost();

    const createAtomTx = await contract.createAtom(generateRandomBytes(32), {
      value: atomCost,
    });

    await createAtomTx.wait(1);
    console.log("✅ Atom created successfully!");

    const atomId = await contract.count();
    console.log(`ℹ️  Current atom ID: ${atomId}`);

    const depositValues = generateSameValueArray(0.1, numberOfDeposits);

    const vaultStateBefore = await contract.vaults(atomId);

    assets.push(parseFloat(ethers.formatEther(vaultStateBefore[0])));
    shares.push(parseFloat(ethers.formatEther(vaultStateBefore[1])));

    for (let i = 0; i < depositValues.length; i++) {
      const depositAtomTx = await contract.depositAtom(wallet.address, atomId, {
        value: ethers.parseEther(depositValues[i].toString()),
      });
      await depositAtomTx.wait(1);
      console.log(`✅ Deposit #${i + 1} successful!`);

      const vaultState = await contract.vaults(atomId);

      assets.push(parseFloat(ethers.formatEther(vaultState[0])));
      shares.push(parseFloat(ethers.formatEther(vaultState[1])));
    }

    // Redeem all shares to recycle ETH
    const vaultStateForUser = await contract.getVaultStateForUser(
      atomId,
      wallet.address
    );
    const redeemAtomTx = await contract.redeemAtom(
      vaultStateForUser[0],
      wallet.address,
      atomId
    );
    await redeemAtomTx.wait(1);
    console.log("✅ All atom shares redeemed successfully!");

    // Create the data object
    const data = {
      assets,
      shares,
    };

    const timestamp = Date.now();

    // Save JSON data to file
    fs.writeFileSync(
      path.join(jsonPath, `${curve}-${timestamp}.json`),
      JSON.stringify(data, null, 2)
    );

    console.log("✅ JSON file generated successfully!");

    // Return necessary variables for plotting
    return { data, curve, timestamp };
  } catch (error) {
    console.error(error);
    process.exit(1);
  }
};

// Check if the script is being run directly or required as a module
if (require.main === module) {
  (async () => {
    const { data, curve, timestamp } = await main();

    // Generate plots only when run directly
    await generatePlot(data, curve, timestamp, imagePath);
    await generateHTMLPlot(data, curve, timestamp, htmlPath);

    console.log("✅ HTML & PNG files generated successfully!");
    process.exit(0);
  })();
} else {
  module.exports = main;
}
