const path = require("path");
const { generateCombinedHTMLPlot, allowedCurves } = require("./utils.js");

const curves = allowedCurves;
const numberOfDeposits = parseInt(process.argv[2]) || 10;

const visualizeCurve = require("./visualizeCurve.js");

const main = async () => {
  try {
    const allData = [];

    for (const curve of curves) {
      try {
        const { data } = await visualizeCurve(curve, numberOfDeposits);
        allData.push({ curve, data });
        console.log(
          `✅ Visualization for the ${curve} curve completed successfully!\n`
        );
      } catch (error) {
        console.error(`❌ Failed to visualize the ${curve} curve: `, error);
      }
    }

    // Generate the combined HTML file
    const combinedHtmlPath = "_playground/experiments/html/combined/";

    const timestamp = Date.now();
    const htmlFileName = `all-curves-${timestamp}.html`;

    generateCombinedHTMLPlot(
      allData,
      path.join(combinedHtmlPath, htmlFileName)
    );

    console.log(`✅ Combined HTML file generated successfully!`);
  } catch (error) {
    console.error(`❌ Failed to generate the combined HTML file: `, error);
  }
};

main();
