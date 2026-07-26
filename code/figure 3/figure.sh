#!/bin/bash
set -e

USE_PRE_RUN_DATA="${1:-0}"

mkdir -p "../../results/figure 3"

if [ "$USE_PRE_RUN_DATA" = "1" ]; then
    echo "USE_PRE_RUN_DATA is 1. Skipping compilation and execution of C++ code."
else
    g++ -O2 -o "figure 3a" "figure 3a.cpp"
    g++ -O2 -o "figure 3b " "figure 3b .cpp"
    g++ -O2 -o "figure 3c" "figure 3c.cpp"
    "./figure 3a"
    "./figure 3b "
    "./figure 3c"
fi

matlab -batch "USE_PRE_RUN_DATA=$USE_PRE_RUN_DATA; run('figure3.m')"
