#!/bin/bash
set -e

# Default values
RUN_ALL=true
USE_PRE_RUN_DATA=0
FIGURES="1 2 3 4 5 6 7 7b table1"


# Check if either argument is "data"
if [ "$1" = "data" ] || [ "$2" = "data" ]; then
    USE_PRE_RUN_DATA=1
fi

# Check if the first argument is a figure number (not empty and not "data")
if [ -n "$1" ] && [ "$1" != "data" ]; then
    RUN_ALL=false
    FIGURES="$1"
fi


echo "======================================"
if [ "$USE_PRE_RUN_DATA" = "1" ]; then
    echo "MODE: Pre-run Data Mode (skipping C++ simulations, loading from /data/)"
else
    echo "MODE: Normal Simulation Mode (running C++ simulations, saving/loading from /results/)"
fi

if [ "$RUN_ALL" = "true" ]; then
    echo "TARGET: Running all figures (1-7, 7b)"
else
    echo "TARGET: Running only figure(s): $FIGURES"
fi
echo "======================================"

for FIG in $FIGURES; do
    echo "======================================"
    echo "Processing $FIG"
    echo "======================================"
    
    if [ "$FIG" = "table1" ]; then
        mkdir -p "../results/table1"
        cd "table1"
        if [ -f "table1.sh" ]; then
            bash table1.sh "$USE_PRE_RUN_DATA"
        fi
        cd ..
    else
        mkdir -p "../results/figure $FIG"
        cd "figure $FIG"
        if [ -f "figure.sh" ]; then
            bash figure.sh "$USE_PRE_RUN_DATA"
        else
            echo "WARNING: figure.sh not found in figure $FIG"
        fi
        cd ..
    fi
done


echo "Execution completed successfully!"
