#!/bin/bash
set -e

ARG="${1:-}"
USE_PRE_RUN_DATA=0

if [ "$ARG" = "data" ] || [ "$ARG" = "1" ]; then
    USE_PRE_RUN_DATA=1
fi

mkdir -p "../../results/table1"

echo "======================================"
echo "Running Table 1 Pipeline (Code Ocean)"
echo "======================================"

if [ "$USE_PRE_RUN_DATA" = "1" ]; then
    echo "MODE: Pre-run Data Mode (reading from /data/table1, outputting to /results/table1)"
    python3 generate_paper_table1.py "../../data/table1"
else
    echo "MODE: C++ Simulation Mode (running C++ sim, saving & reading from /results/table1)"
    python3 generate_paper_table1.py force
fi

echo "Table 1 processing complete."
