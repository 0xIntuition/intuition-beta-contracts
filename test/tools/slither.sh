#!/bin/bash

# Check if virtual environment directory exists
if [ ! -d "venv" ]; then
  echo "Virtual environment not found. Creating one..."
  python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Ensure the project is built
forge build

# Run Slither analysis
slither .
