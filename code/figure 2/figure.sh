#!/usr/bin/env bash
set -e

# Run the MATLAB script
matlab -nodisplay -nosplash -nodesktop -r "run('figure2.m'); exit;"
