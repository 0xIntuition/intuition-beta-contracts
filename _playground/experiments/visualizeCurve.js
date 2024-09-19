const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");
const {
  generateRandomNumbers,
  generateRandomBytes,
  curveContracts,
  wallet,
  generatePlot,
} = require("./utils.js");

const main = async () => {
  try {
    const curve = process.argv[2] || "linear";
    const numberOfDeposits = parseInt(process.argv[3]) || 10;

    const jsonPath = "_playground/experiments/json/";
    const imagePath = "_playground/experiments/images/";

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
    console.log(`Current atom ID: ${atomId}`);

    const depositValues = generateRandomNumbers(0.005, 0.1, numberOfDeposits);

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

    // Now generate the plot and save it as an image
    await generatePlot(data, curve, timestamp, imagePath);

    console.log("✅ Plot generated successfully!");

    process.exit(0);
  } catch (error) {
    console.error(error);
    process.exit(1);
  }
};

main();
