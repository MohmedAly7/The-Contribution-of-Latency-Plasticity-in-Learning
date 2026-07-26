#!/bin/bash
# figure.sh for figure 4

USE_PRE_RUN_DATA="${1:-0}"

# Create results directory
mkdir -p "../../results/figure 4"

if [ "$USE_PRE_RUN_DATA" = "1" ]; then
    echo "Using pre-run data. Skipping C++ compilation and execution."
else
    # Compile and run C++ code
    g++ -O2 -o figure4 "figure_4_a&b.cpp"
    ./figure4
fi

# Run MATLAB scripts in batch mode
matlab -batch "USE_PRE_RUN_DATA=$USE_PRE_RUN_DATA; run('figure_4a.m')"
matlab -batch "USE_PRE_RUN_DATA=$USE_PRE_RUN_DATA; run('figure4b.m')"
