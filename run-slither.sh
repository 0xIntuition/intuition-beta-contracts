#!/bin/bash
# Activate virtual environment
source venv/bin/activate
# Ensure the project is built
forge build
# Run Slither analysis
slither .
