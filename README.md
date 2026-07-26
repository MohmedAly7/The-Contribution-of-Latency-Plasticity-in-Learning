# The Contribution of Latency Plasticity in Learning

This repository contains the source code, simulation engine, and analysis scripts for the study: **"The Contribution of Latency Plasticity in Learning"**.

## Abstract
Spike-timing-dependent plasticity (STDP) potentiates synapses when presynaptic spikes precede postsynaptic ones; however, substantial synaptic modification depends on temporal coherence across repetitions. Polychronization, a neural phenomenon characterized by staggered yet rhythmic spike timing, provides this temporal consistency. This structured spiking pattern not only facilitates memory formation but also aligns spike arrival times, thereby protecting memory-encoding neurons from background interference. We propose that, within recurrent networks, polychronization can be achieved among input-activated neurons through parameter tuning. To this end, we introduce a plasticity rule that jointly modulates synaptic weights and propagation latencies. Using computational modeling, we demonstrate that this rule autonomously generates polychronous groups without supervision. Our findings bridge micro-scale STDP potentiation and systems-level learning by illustrating how cycle-by-cycle changes accumulate coherently to form a neuronal group that shares a common firing frequency. The firing activity of this group represents the activating input pattern. Critically, this process requires plasticity of propagation latencies.

## Code Ocean & Local Execution Guide

This repository is configured to run on **Code Ocean** and local environments in two execution modes:

### Mode 1: Pre-Run Data Mode (Fast Analysis)
Use pre-computed binary datasets stored in `data/table1/` to generate figures and metrics without running C++ simulations:
```bash
# Run all figures and tables using pre-run datasets
bash code/runfigures.sh data

# Or run Table 1 specifically:
cd code/table1
bash table1.sh data
```
- **Inputs:** Reads binary `.neuron` files from `data/table1/`.
- **Outputs:** Saves markdown (`paper_table1_output.md`) and LaTeX (`paper_table1_output.tex`) tables directly into `results/table1/`.

### Mode 2: Full C++ Simulation Mode (From Scratch)
Compile and execute the C++ simulation engine in parallel to generate new `.neuron` datasets from scratch and evaluate results:
```bash
# Run all C++ simulations and generate output tables
bash code/runfigures.sh

# Or run Table 1 C++ simulation pipeline specifically:
cd code/table1
bash table1.sh
```
- **Execution:** Compiles `table1_sim.cpp` with `g++ -O2` and runs 6 parallel simulation processes.
- **Outputs:** Saves newly generated `.neuron` files into `results/table1/`, then computes all 4 network metrics (PG-Count, M-Cascade, S-Coincidence, S-Jitter) and writes output tables to `results/table1/`.

---

## Repository Structure
The project is organized by the figures presented in the paper, each containing the necessary C++ and Python/MATLAB code:

- **[Figure 1](./code/figure%201/):** Neuronal response to random input spikes.
- **[Figure 2](./code/figure%202/):** Effect of aligned presynaptic spikes.
- **[Figure 3](./code/figure%203/):** Representation of neuron dynamics.
- **[Figure 4](./code/figure%204/):** Two-neuron network with reciprocal coupling.
- **[Figure 5](./code/figure%205/):** Effect of background spikes on timing.
- **[Figure 6](./code/figure%206/):** Firing period of a five-neuron network with active STDP and fixed propagation latency.
- **[Figure 7](./code/figure%207/):** Post-training firing periods of 10 neurons, only 5 of which are active.
- **[Figure 7b](./code/figure%207b/):** Firing periods of all 50 neurons.
- **[Table 1](./code/table1/):** Comparative metrics between STDP-only and STDP + Latency plasticity networks under varying background noise.

## Getting Started

### Prerequisites
- **C++ Compiler:** `g++` (C++11 or later) with `-O2` optimization support.
- **Python 3:** With standard built-in modules (`struct`, `bisect`, `concurrent.futures`, `shutil`, `os`, `sys`).

### Quick Start
Navigate to the `code/` directory and execute the run script:
```bash
cd code
bash runfigures.sh
```

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
