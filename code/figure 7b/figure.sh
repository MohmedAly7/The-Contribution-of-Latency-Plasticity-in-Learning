#!/bin/bash
set -e

USE_PRE_RUN_DATA="${1:-0}"

# Create results directory if it doesn't exist
mkdir -p "../../results/figure 7b"

# Check if pre-run data is used
if [ "$USE_PRE_RUN_DATA" = "1" ]; then
    echo "USE_PRE_RUN_DATA is 1. Skipping C++ compilation and execution steps."
else
    # Compile the C++ simulation
    echo "Compiling figure 7b.cpp..."
    g++ -O2 -o figure7b "figure 7b.cpp"

    # Run the simulation
    echo "Running the C++ simulation..."
    ./figure7b
fi

# Run MATLAB script
echo "Running the MATLAB visualization..."
matlab -batch "USE_PRE_RUN_DATA=$USE_PRE_RUN_DATA; run('figure_7b.m')"

echo "Figure 7b processing complete."
