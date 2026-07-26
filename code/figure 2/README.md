# Figure 2: Temporal Integration of Scattered vs. Clustered Inputs

## Overview
This folder contains the scripts for **Figure 2**, which investigates how the temporal arrangement of synaptic inputs (Scattered vs. Clustered) affects the firing probability and membrane potential of an LIF neuron. This figure highlights the importance of precise spike timing and temporal summation.

## Model Description
The simulation utilizes an LIF neuron with a membrane time constant ($\tau_m$) of 20 ms. Two distinct stimulus patterns are compared:
1.  **Scattered Input:** 5 pulses with a 15 ms Inter-Pulse Interval (IPI), representing temporally distributed activity.
2.  **Clustered Input:** 5 pulses with a 3 ms IPI, representing highly synchronous or "bursty" activity.

## Files
- `figure2.m`: MATLAB script to simulate the neuron's response to both patterns sequentially and visualize the comparative dynamics.

## Instructions
1. Open MATLAB.
2. Run `figure2.m`.
3. The script simulates a 150 ms window where both scattered and clustered inputs are applied.

## Expected Results
- The **Scattered Input** should show sub-threshold oscillations where the membrane potential decays significantly between pulses, failing to reach the threshold.
- The **Clustered Input** should demonstrate temporal summation, where successive pulses build upon the preceding ones, eventually triggering a spike.
- This result provides the motivation for Latency Plasticity: the ability of the system to tune delays to transform scattered inputs into clustered ones.
