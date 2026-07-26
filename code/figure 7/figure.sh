#!/bin/bash
set -e

USE_PRE_RUN_DATA="${1:-0}"

# Ensure the output directory exists
mkdir -p "../../results/figure 7"

if [ "$USE_PRE_RUN_DATA" = "1" ]; then
    echo "Using pre-run data. Skipping C++ compilation and execution."
else
    # Compile the C++ simulation
    g++ -O2 -o figure7 "figure 7.cpp"

    # Run the simulation
    ./figure7
fi

# Run the MATLAB script to process the output and save figures
matlab -batch "USE_PRE_RUN_DATA=$USE_PRE_RUN_DATA; run('figure_7.m')"

