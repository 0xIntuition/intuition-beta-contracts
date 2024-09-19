const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");
const dotenv = require("dotenv");
const QuickChart = require("quickchart-js");

dotenv.config();

const curveContractAddresses = {
  linear: "0x1A6950807E33d5bC9975067e6D6b5Ea4cD661665",
  exponential: "0xD8a8653ceD32364DeB582c900Cc3FcD16c34d6D5",
  logarithmic: "0xD8a8653ceD32364DeB582c900Cc3FcD16c34d6D5",
  catmullRom: "0xD8a8653ceD32364DeB582c900Cc3FcD16c34d6D5",
  twoStepLinear: "0xD8a8653ceD32364DeB582c900Cc3FcD16c34d6D5",
};

const ethMultiVaultAbi = [
  "function count() external view returns (uint256)",
  "function getAtomCost() external view returns (uint256)",
  "function createAtom(bytes atomUri) external payable returns (uint256)",
  "function depositAtom(address receiver, uint256 id) external payable returns (uint256)",
  "function redeemAtom(uint256 shares, address receiver, uint256 id) external returns (uint256)",
  "function convertToShares(uint256 assets, uint256 id) external view returns (uint256)",
  "function convertToAssets(uint256 shares, uint256 id) external view returns (uint256)",
  "function currentSharePrice(uint256 id) external view returns (uint256)",
  "function vaults(uint256 vaultId) external view returns (uint256 totalAssets, uint256 totalShares)",
  "function getVaultStateForUser(uint256 vaultId, address receiver) external view returns (uint256 shares, uint256 totalUserAssets)",
];

const generateRandomNumber = (min, max) => {
  return Math.random() * (max - min) + min;
};

const generateRandomNumbers = (min, max, count) => {
  return Array.from({ length: count }, () => generateRandomNumber(min, max));
};

const generateRandomBytes = (length) => {
  return ethers.hexlify(ethers.randomBytes(length));
};

const rpcUrl = "https://base-sepolia-rpc.publicnode.com"; // "https://sepolia.base.org";
const provider = new ethers.JsonRpcProvider(rpcUrl);
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

const linearCurveContract = new ethers.Contract(
  curveContractAddresses.linear,
  ethMultiVaultAbi,
  wallet
);

const exponentialCurveContract = new ethers.Contract(
  curveContractAddresses.exponential,
  ethMultiVaultAbi,
  wallet
);

const logarithmicCurveContract = new ethers.Contract(
  curveContractAddresses.logarithmic,
  ethMultiVaultAbi,
  wallet
);

const catmullRomCurveContract = new ethers.Contract(
  curveContractAddresses.catmullRom,
  ethMultiVaultAbi,
  wallet
);

const twoStepLinearCurveContract = new ethers.Contract(
  curveContractAddresses.twoStepLinear,
  ethMultiVaultAbi,
  wallet
);

const curveContracts = {
  linear: linearCurveContract,
  exponential: exponentialCurveContract,
  logarithmic: logarithmicCurveContract,
  catmullRom: catmullRomCurveContract,
  twoStepLinear: twoStepLinearCurveContract,
};

// Function to generate the plot and save it as an image
const generatePlot = async (data, curve, timestamp, imagePath) => {
  const assets = data.assets;
  const shares = data.shares;

  // Prepare the data for QuickChart
  const chart = new QuickChart();
  chart.setConfig({
    type: "line",
    data: {
      labels: assets,
      datasets: [
        {
          label: `${curve.charAt(0).toUpperCase() + curve.slice(1)} Curve`,
          data: shares,
          fill: false,
          borderColor: "blue",
          pointBackgroundColor: "blue",
          pointBorderColor: "blue",
          pointRadius: 3,
          lineTension: 0,
        },
      ],
    },
    options: {
      title: {
        display: true,
        text: `${curve.charAt(0).toUpperCase() + curve.slice(1)} Curve`,
      },
      scales: {
        xAxes: [
          {
            scaleLabel: {
              display: true,
              labelString: "Assets",
            },
            ticks: {
              autoSkip: true,
              maxTicksLimit: 10,
            },
          },
        ],
        yAxes: [
          {
            scaleLabel: {
              display: true,
              labelString: "Shares",
            },
          },
        ],
      },
    },
  });
  chart.setWidth(800);
  chart.setHeight(600);
  chart.setBackgroundColor("white");

  // // Save the chart as an image
  // const imageBuffer = await chart.toBuffer();
  // fs.writeFileSync(
  //   path.join(imagePath, `${curve}-${timestamp}.png`),
  //   imageBuffer
  // );

  // Save the chart directly to a file
  await chart.toFile(path.join(imagePath, `${curve}-${timestamp}.png`));
};

module.exports = {
  generateRandomNumbers,
  generateRandomBytes,
  curveContracts,
  wallet,
  generatePlot,
};
