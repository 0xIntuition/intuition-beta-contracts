#!/usr/bin/env bash
set -e

# Check prerequisites
command -v forge >/dev/null 2>&1 || { echo "forge is required but not installed. See https://book.getfoundry.sh/getting-started/installation"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "node is required but not installed. See https://nodejs.org/"; exit 1; }
command -v cargo >/dev/null 2>&1 || { echo "cargo is required but not installed. See https://rustup.rs/"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is required but not installed"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required but not installed. See https://stedolan.github.io/jq/"; exit 1; }

# Install dependencies if needed
if ! command -v mdbook >/dev/null 2>&1; then
    echo "Installing mdbook..."
    cargo install mdbook
fi

if ! command -v mdbook-mermaid >/dev/null 2>&1; then
    echo "Installing mdbook-mermaid..."
    cargo install mdbook-mermaid
fi

if ! command -v mmdc >/dev/null 2>&1; then
    echo "Installing mermaid-cli..."
    npm install -g @mermaid-js/mermaid-cli
fi

# Step 1: Generate Forge documentation
echo "Generating Forge documentation..."
forge doc --build --markdown

# Step 2: Create architecture documentation directory
echo "Setting up architecture documentation..."
mkdir -p docs/src/architecture

# Step 3: Generate contract information JSON
echo "Generating contract information..."
mkdir -p docs/contracts
for contract in $(find src -name "*.sol"); do
    base=$(basename "$contract" .sol)
    echo "Processing $base..."
    
    # Get each piece of information and combine them using jq
    abi=$(forge inspect "$contract:$base" abi)
    devdoc=$(forge inspect "$contract:$base" devdoc)
    userdoc=$(forge inspect "$contract:$base" userdoc)
    storage=$(forge inspect "$contract:$base" storageLayout)
    
    # Combine them into a single JSON object
    echo "{
        \"abi\": $abi,
        \"devdoc\": $devdoc,
        \"userdoc\": $userdoc,
        \"storageLayout\": $storage
    }" | jq '.' > "docs/contracts/$base.json"
done

# Step 4: Generate contract diagrams
echo "Generating contract diagrams..."
python3 scripts/generate_diagrams.py

# Step 5: Update SUMMARY.md to include architecture
echo "Updating SUMMARY.md..."
{
    echo "# Summary"
    echo "- [Home](README.md)"
    echo "- [Architecture](architecture/overview.md)"
    echo "  - [EthMultiVault](architecture/EthMultiVault.md)"
    echo "  - [BondingCurveRegistry](architecture/BondingCurveRegistry.md)"
    echo "  - [BaseCurve](architecture/BaseCurve.md)"
    echo "  - [LinearCurve](architecture/LinearCurve.md)"
    echo "  - [ProgressiveCurve](architecture/ProgressiveCurve.md)"
    echo "  - [AtomWallet](architecture/AtomWallet.md)"
    echo "  - [Attestoor](architecture/Attestoor.md)"
    echo "  - [AttestoorFactory](architecture/AttestoorFactory.md)"
    echo "  - [CustomMulticall3](architecture/CustomMulticall3.md)"
    echo "# src"
    tail -n +3 docs/src/SUMMARY.md | grep -v "architecture/overview.md"
} > docs/src/SUMMARY.md.tmp
mv docs/src/SUMMARY.md.tmp docs/src/SUMMARY.md

# Step 6: Configure mdbook
echo "Configuring mdbook..."
cat > docs/book.toml << EOF
[book]
title = "Intuition Beta Contracts Documentation"
authors = ["Intuition Labs"]
language = "en"
multilingual = false
src = "src"

[output.html]
default-theme = "dark"
preferred-dark-theme = "ayu"
git-repository-url = "https://github.com/0xIntuition/intuition-beta-contracts"
additional-js = ["mermaid.min.js", "mermaid-init.js"]
additional-css = ["book.css"]

[preprocessor.mermaid]
command = "mdbook-mermaid"
EOF

# Step 7: Copy Mermaid files
echo "Setting up Mermaid..."
mkdir -p docs/theme
curl -o docs/mermaid.min.js https://cdn.jsdelivr.net/npm/mermaid@10.6.1/dist/mermaid.min.js
cat > docs/mermaid-init.js << EOF
window.addEventListener('load', (event) => {
    mermaid.initialize({
        startOnLoad: true,
        theme: 'dark',
        securityLevel: 'loose',
        themeVariables: {
            darkMode: true,
            xyChart: {
                backgroundColor: '#1f2937',
                titleColor: '#ffffff',
                gridColor: '#374151',
                xAxisLabelColor: '#9ca3af',
                yAxisLabelColor: '#9ca3af',
                plotColorPalette: '#6366f1'
            }
        },
        mindmap: {
            padding: 10,
            useMaxWidth: true
        }
    });
});
EOF

# Step 8: Generate curve data and graphs
echo "Generating curve data and graphs..."
python3 scripts/generate_curve_graphs.py

# Step 9: Start development server
echo "Starting mdbook server..."
cd docs && mdbook serve --open 