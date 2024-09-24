# Instructions for Running the Share Price Formula Experiments

## Step 1: Install the Required Libraries

```bash
npm install
```

## Step 2: Set the Environment Variables

Create a `.env` file in the root directory and set the following environment variables:

```bash
PRIVATE_KEY=0x-your-private-key
BASE_SEPOLIA_RPC_URL=https://your-sepolia-rpc-url
```

**Note:** Make sure your wallet is funded with at least 3 or more Base Sepolia ETH.

## Step 3: Visualize Individual Share Price Formula

This script outputs a JSON file containing the number of shares and assets for each deposit, as well as the HTML file and a PNG file that visualizes the share price formula. Run the following command to visualize the individual share price formula:

```bash
npm run visualizeCurve curve_name number_of_deposits
```

**Parameters:**

`curve_name` - Name of the curve you want to visualize. Currently supported curves include the following:
 - linear
 - catmullRom (still debugging)
 - cubic
 - exponential
 - logarithmic
 - logarithmicStepCurve (still debugging)
 - polynomial
 - powerFunction
 - quadratic
 - skewed
 - sqrt
 - steppedCurve
 - twoStepLinear
- **Note:** If left empty, it defaults to linear.

`number_of_deposits` - Number of deposits to visualize the curve for. Each deposit will be represented by a point on the curve, and represents a 0.1 Base Sepolia ETH deposit into a newly created atom. **Note:** If left empty, it defaults to 10.

## Step 4: Visualize All Share Price Formulas in One Graph

This script outputs JSON files for each of the currently supported curves containing the number of shares and assets for each deposit, as well as the HTML file that visualizes all share price formulas in one graph. Run the following command to visualize all share price formulas in one graph:

```bash
npm run visualizeAll number_of_deposits
```

**Parameters:**

`number_of_deposits` - Number of deposits to visualize each curve for. Each deposit will be represented by a point on the curve, and represents a 0.1 Base Sepolia ETH deposit into a newly created atom. **Note:** If left empty, it also defaults to 10.

## Step 5: Take a Look at the Results

After running the above commands, you will find the following files in the `_playground/experiments` directory:

- Three folders, `html`, `json`, and `png`, containing the HTML, JSON, and PNG files, respectively

- If you've run the script to visualize an individual share price formula, these are the expected outputs:
  - `curveName-timestamp.json` - JSON file containing the number of shares and assets for each deposit.
  - `curveName-timestamp.html` - HTML file that visualizes the share price formula.
  - `curveName-timestamp.png` - PNG file that visualizes the share price formula.

- If you've run the script to visualize all share price formulas in one graph, these are the expected outputs:
  - In the `html/combined` folder, you can find `all-curves-timestamp.html` - HTML file that visualizes all share price formulas in one graph.
  - In the `json` folder, you can find all of the JSON files for each of the currently supported curves containing the number of shares and assets for each deposit.

**Note:** You can take a look at the generated HTML files in your browser to visualize the share price formulas by copying the full path to the HTML file and pasting it into your browser's address bar.

## Step 6: Clean Up

After you're done running the experiments, you can clean up the generated files by running the following command:

```bash
npm run cleanUp
```