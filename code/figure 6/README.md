# Figure 6 — Firing Period of a Five-Neuron Network with Active STDP and Fixed Propagation Latency

> **Fig. 6: Firing period of a five-neuron network with active STDP and fixed propagation latency.** In the absence of precise control over spike arrival times, the direction of STDP-induced modifications remains inconsistent. Consequently, neither robust synaptic efficacy nor coordinated alignment of spike arrivals emerges, thereby precluding the development of polychronous activity.

---

## Overview

This folder contains the C++ simulation and MATLAB visualisation script for **Figure 6**. The simulation models a five-neuron leaky integrate-and-fire (LIF) network with all-to-all excitatory connectivity and spike-timing-dependent plasticity (STDP) for weight updates. Crucially, **propagation latencies are fixed** throughout training — no latency plasticity is applied. This contrasts with later figures where latency plasticity is enabled.

The key result is that, without the ability to tune spike propagation delays, STDP alone is insufficient to coordinate spike arrival times. Weight modifications remain inconsistent across cycles, preventing the emergence of polychronous firing patterns.

---

## Files

| File | Role | Output |
|------|------|--------|
| `figure_6.cpp` | C++ event-driven LIF network simulation — trains for 40 M events with STDP only | `figure6.neuron` |
| `figure_6.m` | MATLAB Firing period line-plot viewer — reads `figure6.neuron` and plots firing period (Firing period) vs. time | Figure window |

> The `.neuron` file is binary; its format is described in the [Output File Format](#output-file-format) section below.

---

## How to Build and Run

### Requirements
- A C++ compiler supporting C++11 or later (`g++`)
- MATLAB (any recent version)

### Compile
```bash
g++ -O2 -o figure6 "figure_6.cpp"
```

> Using `-O2` or `-O3` is strongly recommended. Optimised builds can be **2–4× faster** than debug builds on a 40-million-event loop.

### Run
```bash
./figure6
```

The program prints:
- Weight/latency tables at the start and end of training
- Progress counters every 2,000,000 events
- Final simulation time and random seed

**Expected runtime:** several minutes to over an hour depending on hardware. The terminal output provides progress updates so you can monitor the run.

On completion the file `figure6.neuron` is written to the current directory.

> ⚠️ **The C++ simulation is computationally intensive.** The main training loop runs **40 million events**. Plan accordingly before running.

### Visualise in MATLAB
```matlab
run('figure_6.m')
```

`USE_STATIC = true` by default — no interactive input is needed. Set `USE_STATIC = false` to enable interactive mode where the user is prompted for file selection, page size, and page navigation.

---

## Model Description

### Network Structure

| Property | Value |
|----------|-------|
| Total neurons | 5 (`cc = 5`) |
| Active neurons (suprathreshold drive) | 5 (`nActive = 5`, indices 0–4) |
| Connectivity | All-to-all (excluding self) |

All five neurons receive constant suprathreshold input currents with small random perturbations, giving each neuron a slightly different intrinsic firing period.

### LIF Dynamics

Between events the membrane voltage decays as:

$$V(t) = V_{ss} + \bigl(V_0 - V_{ss}\bigr)\,e^{-(t-t_0)/\tau_m}, \qquad V_{ss} = I_{input} \cdot R_M$$

A spike is emitted when $V \geq V_{thr} = 1.0$, after which $V$ resets to 0. A refractory offset of 0.15 ms is added to the computed fire time.

### Plasticity Rules

**STDP (weight updates)** — applied at every firing event:
$$\Delta\omega = +\eta_w \cdot e^{-\Delta t / T_2} \quad \text{(potentiation, pre before post)}$$
$$\Delta\omega = -\eta_w \cdot e^{-\Delta t / T_2} \quad \text{(depression, post before pre)}$$

Weights are hard-clipped to $[0, \omega_{max}]$.

**Latency plasticity — disabled.** Propagation latencies are initialised randomly from $[0.01,\, \tau_m + 0.01]$ ms and remain fixed throughout the simulation. This is the defining condition of Figure 6: STDP acts on weights but has no mechanism to align spike arrival times.

### Key Parameters

| Parameter | Symbol | Value | Description |
|-----------|--------|-------|-------------|
| Network size | `cc` | 5 | Five-neuron LIF network |
| Active neurons | `nActive` | 5 | All neurons are active |
| Firing threshold | $V_{thr}$ | 1.0 | Normalised membrane voltage |
| Membrane time constant | $\tau_m$ | 20 ms | RC decay rate |
| Membrane resistance | $R_M$ | 10 MΩ | RC circuit resistance |
| STDP time constant | $T_2$ | 20 ms | Weight update window |
| Weight learning rate | $\eta_w$ | `1×10⁻⁴` | |
| Maximum weight | $\omega_{max}$ | 0.031 | Hard clip |
| Latency range | $L$ | [0.01, $\tau_m$ + 0.01] ms | Fixed, random initialisation |
| Simulation length | — | 40,000,000 events | Main training loop |


---

## Output File Format (`figure6.neuron`)

### Header (4 bytes)

| Bytes | Type | Value |
|-------|------|-------|
| 0–3 | `int32` | Number of neurons `cc` = 5 |

### Data records (24 bytes each)

Written by `save(i, j)` for every event during the simulation.

| Bytes | Type | Field | Notes |
|-------|------|-------|-------|
| 0–7 | `double` | Simulation time `t` (ms) | Absolute timestamp |
| 8–11 | `int32` | Pre-synaptic neuron index `i` (0-based) | |
| 12–15 | `int32` | Post-synaptic neuron index `j` (0-based) | |
| 16–23 | `double` | Amplitude value | `1.5` for a firing event (`i == j`); `−w[j][i] / maxW` for a synaptic reception |

---

## Visualisation Details (`figure_6.m`)

The MATLAB script supports two input modes controlled by the `USE_STATIC` flag:

| Mode | `USE_STATIC` | Behaviour |
|------|-------------|-----------|
| Static | `true` (default) | All parameters hardcoded — renders one figure and exits |
| Interactive | `false` | User is prompted for file, page size, and page number |

### Static Mode Defaults

| Parameter | Value |
|-----------|-------|
| File | `figure6.neuron` |
| Events per page | 40,000 (Firing period mode) |
| Hidden context pages | 0 |
| Page number | Last page (clamped to `totalPageNumber`) |

### Plot Description
- A single axes showing **Firing period (inter-spike interval) vs. time** for all 5 neurons.
- Each neuron is plotted as a coloured line; a legend identifies each neuron.
- If polychronization were emerging, the Firing period traces would converge to a common period. In this figure, the traces remain **disordered and non-convergent**, demonstrating that STDP alone (without latency plasticity) cannot produce coordinated firing.

---

## Reproducing Figure 6

1. Compile `figure_6.cpp` with optimisation (`-O2`) and run it. **Allow significant time for the 40-million-event training loop.**
2. Once `figure6.neuron` is written, open MATLAB in the same directory and run `figure_6.m`.
3. The default static mode displays the last page of Firing period data, showing the final firing period dynamics.
