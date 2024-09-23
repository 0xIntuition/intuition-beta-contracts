const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");
const dotenv = require("dotenv");
const QuickChart = require("quickchart-js");

dotenv.config();

const allowedCurves = [
  "linear",
  // "catmullRom",
  "cubic",
  "exponential",
  "logarithmic",
  // "logarithmicStepCurve",
  "polynomial",
  "powerFunction",
  "quadratic",
  "skewed",
  "sqrt",
  "steppedCurve",
  "twoStepLinear",
];

const normalizeCurveName = (curve) => {
  if (typeof curve !== "string") {
    throw new TypeError("Input must be a string");
  }

  if (curve === "sqrt") {
    return "Square Root";
  }

  return (
    curve
      // Insert space before capital letters
      .replace(/([A-Z])/g, " $1")
      // Trim leading/trailing spaces
      .trim()
      // Replace multiple spaces with a single space
      .replace(/\s+/g, " ")
      // Capitalize each word
      .replace(/\b\w+/g, function (word) {
        return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
      })
  );
};

const curveContractAddresses = {
  linear: "0x1A6950807E33d5bC9975067e6D6b5Ea4cD661665",
  // catmullRom: "",
  cubic: "0xcc17634445F2aB1Ba3533f93eb0B19C8C3b7f99d",
  exponential: "0xBD635f0D71d1E9F581f78fcbB10c9ce11bf4c737",
  logarithmic: "0x7B4a74fF52b51EbE798ee8DAbF6f41cd50841041",
  // logarithmicStepCurve: "",
  polynomial: "0x31fb33E92cAb0ECAc10625DcdFd1Da1aE3eDD92E",
  powerFunction: "0x5613417B7EecE3e64edBBe8335Be781920bDA7E7",
  quadratic: "0x9E81c3F775c3Cbe4E38B397Fe2747b6B98eA78B0",
  skewed: "0xcA9a233baC48699335417F9593269e3465cE809f",
  sqrt: "0xE63cE927c5C164DBa0954005f644dBD9137F858d",
  steppedCurve: "0xB4b8E16F9c2D8F3f7dfBC594630dfdd64F38A15c",
  twoStepLinear: "0x226e51476FEf4A13EcCafb7231353a1bDB673a7B",
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

const generateSameValueArray = (value, count) => {
  return Array.from({ length: count }, () => value);
};

const generateRandomBytes = (length) => {
  return ethers.hexlify(ethers.randomBytes(length));
};

const rpcUrl =
  "https://base-sepolia.g.alchemy.com/v2/M4nJgUt8qQiwH9FklBw3o5fAv80gdj1O";

// Other options:
// https://base-sepolia.blockpi.network/v1/rpc/public
// "https://base-sepolia-rpc.publicnode.com";
// https://sepolia.base.org

const provider = new ethers.JsonRpcProvider(rpcUrl);
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

const linearCurveContract = new ethers.Contract(
  curveContractAddresses.linear,
  ethMultiVaultAbi,
  wallet
);

// const catmullRomCurveContract = new ethers.Contract(
//   curveContractAddresses.catmullRom,
//   ethMultiVaultAbi,
//   wallet
// );

const cubicCurveContract = new ethers.Contract(
  curveContractAddresses.cubic,
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

// const logarithmicStepCurveContract = new ethers.Contract(
//   curveContractAddresses.logarithmicStepCurve,
//   ethMultiVaultAbi,
//   wallet
// );

const polynomialCurveContract = new ethers.Contract(
  curveContractAddresses.polynomial,
  ethMultiVaultAbi,
  wallet
);

const powerFunctionCurveContract = new ethers.Contract(
  curveContractAddresses.powerFunction,
  ethMultiVaultAbi,
  wallet
);

const quadraticCurveContract = new ethers.Contract(
  curveContractAddresses.quadratic,
  ethMultiVaultAbi,
  wallet
);

const skewedCurveContract = new ethers.Contract(
  curveContractAddresses.skewed,
  ethMultiVaultAbi,
  wallet
);

const sqrtCurveContract = new ethers.Contract(
  curveContractAddresses.sqrt,
  ethMultiVaultAbi,
  wallet
);

const steppedCurveContract = new ethers.Contract(
  curveContractAddresses.steppedCurve,
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
  // catmullRom: catmullRomCurveContract,
  cubic: cubicCurveContract,
  exponential: exponentialCurveContract,
  logarithmic: logarithmicCurveContract,
  // logarithmicStepCurve: logarithmicStepCurveContract,
  polynomial: polynomialCurveContract,
  powerFunction: powerFunctionCurveContract,
  quadratic: quadraticCurveContract,
  skewed: skewedCurveContract,
  sqrt: sqrtCurveContract,
  steppedCurve: steppedCurveContract,
  twoStepLinear: twoStepLinearCurveContract,
};

// Function to generate the plot and save it as an HTML file
const generateHTMLPlot = async (data, curve, timestamp, htmlPath) => {
  const assets = data.assets;
  const shares = data.shares;

  // Prepare the HTML content
  const title = `${normalizeCurveName(curve)} Curve Visualization`;

  const htmlContent = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>${title}</title>
  <!-- Include Plotly.js via CDN -->
  <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
</head>
<body>

<div id="plot" style="width:100%;max-width:700px;height:500px;"></div>

<script>
  // Data arrays
  const assets = ${JSON.stringify(assets.map(Number))};
  const shares = ${JSON.stringify(shares.map(Number))};

  // Define the trace
  const trace = {
    x: assets,
    y: shares,
    mode: 'lines+markers',
    type: 'scatter',
    name: '${curve.charAt(0).toUpperCase() + curve.slice(1)} Curve'
  };

  // Calculate max values for axis scaling
  const maxAssets = Math.max.apply(null, assets) * 1.05; // 5% padding
  const maxShares = Math.max.apply(null, shares) * 1.05; // 5% padding

  // Define the layout with axis ranges
  const layout = {
    title: '${title}',
    xaxis: {
      title: 'Assets',
      range: [0, maxAssets]
    },
    yaxis: {
      title: 'Shares',
      range: [0, maxShares]
    }
  };

  // Create the plot
  Plotly.newPlot('plot', [trace], layout);
</script>

</body>
</html>
  `;

  // Save the HTML content to a file
  fs.writeFileSync(
    path.join(htmlPath, `${curve}-${timestamp}.html`),
    htmlContent
  );
};

// Function to generate the plot and save it as an image in PNG format
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

// Function to visualize all curves in a single HTML file
const generateCombinedHTMLPlot = (allData, outputPath) => {
  const title = "Curve Comparison";

  // Prepare the HTML content
  const htmlContent = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>${title}</title>
  <!-- Include Plotly.js via CDN -->
  <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
</head>
<body>

<div id="plot-all" style="width:100%;max-width:900px;height:600px;"></div>
<script>
  const data = [];

  ${allData
    .map((curveData, index) => {
      const { curve, data } = curveData;
      const assets = data.assets.map(Number);
      const shares = data.shares.map(Number);
      const title = `${normalizeCurveName(curve)} Curve`;

      return `
  // Data for ${curve}
  const trace_${index} = {
    x: ${JSON.stringify(assets)},
    y: ${JSON.stringify(shares)},
    mode: 'lines+markers',
    type: 'scatter',
    name: '${title}'
  };
  data.push(trace_${index});
`;
    })
    .join("\n")}

  // Calculate global max values for axis scaling
  const maxAssets = Math.max.apply(null, [].concat(${allData
    .map((_, index) => `data[${index}].x`)
    .join(", ")})) * 1.05;
  const maxShares = Math.max.apply(null, [].concat(${allData
    .map((_, index) => `data[${index}].y`)
    .join(", ")})) * 1.05;

  // Define the layout with axis ranges
  const layout = {
    title: '${title}',
    xaxis: {
      title: 'Assets',
      range: [0, maxAssets]
    },
    yaxis: {
      title: 'Shares',
      range: [0, maxShares]
    }
  };

  // Create the combined plot
  Plotly.newPlot('plot-all', data, layout);
</script>

</body>
</html>
  `;

  // Save the HTML content to a file
  fs.writeFileSync(outputPath, htmlContent);
};

module.exports = {
  allowedCurves,
  generateSameValueArray,
  generateRandomNumbers,
  generateRandomBytes,
  curveContracts,
  wallet,
  generatePlot,
  generateHTMLPlot,
  generateCombinedHTMLPlot,
  normalizeCurveName,
};
