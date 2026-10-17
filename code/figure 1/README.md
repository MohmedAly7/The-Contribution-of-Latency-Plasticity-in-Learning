# Figure 1: Single Neuron Dynamics and LIF Model Validation

## Overview
This folder contains the simulation and visualization scripts for **Figure 1**, which establishes the baseline behavior of the Leaky Integrate-and-Fire (LIF) neuron model used throughout this study. It demonstrates the membrane potential dynamics and Inter-Spike Interval (Firing period) distributions under stochastic input.

## Model Description
The simulation uses a standard LIF model defined by:
- **Membrane Capacitance ($C_m$):** 1500 pF
- **Membrane Resistance ($R_m$):** 100 MΩ
- **Resting Potential ($V_{rest}$):** -70 mV
- **Threshold ($V_{th}$):** -55 mV
- **Reset Potential ($V_{reset}$):** -70 mV

The neuron is driven by a Poisson pulse train with a target average current of 280 pA, consisting of 2.2 nA pulses of 0.2 ms duration.

## Files
- `figure1.m`: MATLAB script to simulate the LIF neuron, generate input currents, and plot the membrane potential (Panel A), input current (Panel B), and Firing period histogram (Panel C).

## Instructions
1. Open MATLAB.
2. Run `figure1.m`.
3. The script will generate a three-panel figure showing the temporal evolution of the membrane potential and the resulting firing statistics.

## Expected Results
- **Panel A:** Stochastic fluctuations in membrane potential with clearly defined spikes and resets.
- **Panel B:** The corresponding Poisson-distributed input current pulses.
- **Panel C:** A narrow, bell-shaped (Gaussian-like) firing period histogram centered around ~120 ms, demonstrating that the LIF neuron integrates high-rate Poisson input (~636.4 Hz) to produce a nearly periodic firing output.
