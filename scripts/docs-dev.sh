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
forge doc

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
# First, check if architecture section already exists
if ! grep -q "architecture/overview.md" docs/src/SUMMARY.md; then
    # Add architecture section after Home but before src
    awk '
    /# Home/ { print; print "- [Architecture](architecture/overview.md)"; next }
    { print }
    ' docs/src/SUMMARY.md > docs/src/SUMMARY.md.tmp
    mv docs/src/SUMMARY.md.tmp docs/src/SUMMARY.md
fi

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
additional-js = ["mermaid.min.js"]
additional-css = ["book.css"]

[preprocessor.mermaid]
command = "mdbook-mermaid"
EOF

# Step 7: Copy Mermaid files
echo "Setting up Mermaid..."
mkdir -p docs/theme
curl -o docs/mermaid.min.js https://unpkg.com/mermaid@8.13.3/dist/mermaid.min.js
cat > docs/theme/head.hbs << EOF
<script>
    window.addEventListener('load', (event) => {
        mermaid.initialize({
            startOnLoad: true,
            theme: 'dark',
            securityLevel: 'loose',
            themeVariables: {
                darkMode: true
            }
        });
    });
</script>
EOF

# Step 8: Start development server
echo "Starting mdbook server..."
cd docs && mdbook serve --open 