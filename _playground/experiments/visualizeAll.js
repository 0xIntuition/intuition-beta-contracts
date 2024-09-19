const { exec } = require("child_process");

const curves = [
  "linear",
  "exponential",
  "logarithmic",
  "catmullRom",
  "twoStepLinear",
];
const numberOfDeposits = parseInt(process.argv[2]) || 10;

const runVisualization = (curve) => {
  return new Promise((resolve, reject) => {
    exec(
      `node _playground/experiments/visualizeCurve.js ${curve} ${numberOfDeposits}`,
      (error, stdout, stderr) => {
        if (error) {
          console.error(`Error running visualization for ${curve}:`, error);
          reject(error);
        } else {
          console.log(`Visualization for ${curve} completed.`);
          resolve();
        }
      }
    );
  });
};

const main = async () => {
  for (const curve of curves) {
    try {
      await runVisualization(curve);
    } catch (error) {
      console.error(`Failed to visualize ${curve}:`, error);
    }
  }
};

main();
