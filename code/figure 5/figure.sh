#!/bin/bash
set -e

USE_PRE_RUN_DATA="${1:-0}"

mkdir -p "../../results/figure 5"

if [ "$USE_PRE_RUN_DATA" = "1" ]; then
    echo "Using pre-run data. Skipping C++ compilation and execution."
else
    g++ -O2 -o "figure 5a" "figure 5a.cpp"
    "./figure 5a"
fi

matlab -batch "USE_PRE_RUN_DATA=$USE_PRE_RUN_DATA; run('figure5a.m')"
matlab -batch "USE_PRE_RUN_DATA=$USE_PRE_RUN_DATA; run('figure5b.m')"

