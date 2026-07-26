#!/bin/bash
USE_PRE_RUN_DATA="${1:-0}"

# Create the results directory if it doesn't exist
mkdir -p "../../results/figure 6"

if [ "$USE_PRE_RUN_DATA" = "1" ]; then
    echo "Using pre-run data. Skipping C++ compilation and execution."
else
    # Compile the C++ code
    echo "Compiling figure_6.cpp..."
    g++ -O2 -o figure6 figure_6.cpp

    # Run the C++ simulation
    echo "Running the simulation..."
    ./figure6
fi

# Run the MATLAB visualization script
echo "Running MATLAB script..."
matlab -batch "USE_PRE_RUN_DATA=$USE_PRE_RUN_DATA; run('figure_6.m')"

echo "Done. Results saved to ../../results/figure 6/"
