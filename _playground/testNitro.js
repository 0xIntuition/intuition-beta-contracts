const { ethers } = require("ethers");

const ethMultiVaultAddress = "0x5e620CF46D831d461D4691b9357FbD3209a22994";
const ethMultiVaultAbi = [
  "function count() external view returns (uint256)",
  "function getAtomCost() external view returns (uint256)",
  "function createAtom(bytes atomUri) external payable returns (uint256)",
  "function depositAtom(address receiver, uint256 id) external payable returns (uint256)",
  "function redeemAtom(uint256 shares, address receiver, uint256 id) external returns (uint256)",
  "function paused() external view returns (bool)",
];

const wait = async (seconds) => {
  return new Promise((resolve) => setTimeout(resolve, seconds * 1000));
};

async function main() {
  try {
    const provider = new ethers.BrowserProvider(
      "https://base-sepolia.blockpi.network/v1/rpc/public"
    );

    const testAccount = new ethers.Wallet(process.env.TEST_ACCOUNT, provider);

    const ethMultiVault = new ethers.Contract(
      ethMultiVaultAddress,
      ethMultiVaultAbi,
      provider
    );

    const ethMultiVaultBalanceBefore = await provider.getBalance(
      ethMultiVault.address
    );

    const ethMultiVaultBalanceBeforeFormatted = ethers.utils.formatEther(
      ethMultiVaultBalanceBefore
    );

    console.log(
      `EthMultiVault balance before: ${ethMultiVaultBalanceBeforeFormatted} ETH`
    );

    // step 1: create atom

    const createAtomTx = await ethMultiVault
      .connect(testAccount)
      .createAtom("0xabcdef", {
        value: await ethMultiVault.getAtomCost(),
      });
    await createAtomTx.wait(1);
    console.log("Atom created");

    const count = await ethMultiVault.count();
    const atomId = parseInt(count);

    console.log(`Atom ID: ${atomId}`);

    // step 2: deposit 5 ETH

    const depositAtomTx = await ethMultiVault
      .connect(testAccount)
      .depositAtom(testAccount.address, atomId, {
        value: ethers.utils.parseEther("5"),
      });
    await depositAtomTx.wait(1);
    console.log("5 ETH deposited");

    const ethMultiVaultBalanceAfterDeposit = await provider.getBalance(
      ethMultiVault.address
    );
    const ethMultiVaultBalanceAfterDepositFormatted = ethers.utils.formatEther(
      ethMultiVaultBalanceAfterDeposit
    );

    console.log(
      `EthMultiVault balance after deposit: ${ethMultiVaultBalanceAfterDepositFormatted} ETH`
    );

    // step 3: redeem 1.5 ETH to trigger the TVL monitoring alert

    const redeemAtomTx1 = await ethMultiVault
      .connect(testAccount)
      .redeemAtom(ethers.utils.parseEther("1.5"), testAccount.address, atomId);
    await redeemAtomTx1.wait(1);
    await wait(90);
    console.log("1.5 ETH redeemed - TVL alert should be triggered");

    const ethMultiVaultBalanceAfterRedeem1 = await provider.getBalance(
      ethMultiVault.address
    );
    const ethMultiVaultBalanceAfterRedeem1Formatted = ethers.utils.formatEther(
      ethMultiVaultBalanceAfterRedeem1
    );

    console.log(
      `EthMultiVault balance after redeem 1: ${ethMultiVaultBalanceAfterRedeem1Formatted} ETH`
    );

    // step 4: redeem 3 ETH to trigger the contract pause in the nitro enclave

    const redeemAtomTx2 = await ethMultiVault
      .connect(testAccount)
      .redeemAtom(ethers.utils.parseEther("3"), testAccount.address, atomId);
    await redeemAtomTx2.wait(1);
    await wait(90);
    console.log("3 ETH redeemed - contract pause should be triggered");

    const ethMultiVaultBalanceAfterRedeem2 = await provider.getBalance(
      ethMultiVault.address
    );
    const ethMultiVaultBalanceAfterRedeem2Formatted = ethers.utils.formatEther(
      ethMultiVaultBalanceAfterRedeem2
    );

    console.log(
      `EthMultiVault balance after redeem 2: ${ethMultiVaultBalanceAfterRedeem2Formatted} ETH`
    );

    const paused = await ethMultiVault.paused();
    console.log(`Contract paused: ${paused}`);
  } catch (error) {
    console.error(error);
  }
}

main();
