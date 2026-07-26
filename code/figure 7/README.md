# Figure 7 — Post-Training Firing Periods of 10 Neurons, Only 5 of Which Are Active

> **Fig. 7: Post-training firing periods of 10 neurons, only 5 of which are active.** From 0 to 1300 ms, the network sustains polychronization despite interference from inactive neurons. At 1300 ms, all event timings are reset to random values, disrupting the temporal pattern. With the input pattern still present, a recall phase starts, and the network reinstates polychronization within 200 ms.

---

## Overview

This folder contains the C++ simulation and MATLAB visualisation script for **Figure 7**. The simulation models a ten-neuron leaky integrate-and-fire (LIF) network with all-to-all excitatory connectivity, spike-timing-dependent plasticity (STDP) for weight updates, and **latency plasticity** for propagation delay adaptation. Five neurons are active (suprathreshold drive) and five are inactive (near-threshold, stochastic firing).

The simulation has two phases:

1. **Training phase** (40 million events): Both STDP and latency plasticity shape weights and delays. Only the last 1 million events are recorded to `figure7.neuron`.
2. **Recall phase** (40,000 events): After training, `Reset()` randomises all event timings while preserving the learned weights and latencies. The network must recover polychronization from the disrupted state using only the stored synaptic parameters. All events are recorded.

The key result is that the trained network sustains polychronization despite interference from inactive neurons, and can rapidly reinstate coordinated firing (~200 ms) after a complete temporal reset — demonstrating that the learned weights and latencies encode a robust memory trace.

---

## Files

| File | Role | Output |
|------|------|--------|
| `figure 7.cpp` | C++ event-driven LIF network — trains for 40 M events with STDP + latency plasticity, then resets and records recall | `figure7.neuron` |
| `figure_7.m` | MATLAB Firing period line-plot viewer — reads `figure7.neuron` and plots firing period (Firing period) vs. time | Figure window |

> The `.neuron` file is binary; its format is described in the [Output File Format](#output-file-format) section below.

---

## How to Build and Run

### Requirements
- A C++ compiler supporting C++11 or later (`g++`)
- MATLAB (any recent version)

### Compile
```bash
g++ -O2 -o figure7 "figure 7.cpp"
```

> Using `-O2` or `-O3` is strongly recommended. Optimised builds can be **2–4× faster** than debug builds on a 40-million-event loop.

### Run
```bash
./figure7
```

The program prints:
- Initial random firing offsets for each neuron
- Weight/latency tables at the start and end of training
- Progress counters every 2,000,000 events during training and every 200,000 events during the recall pass
- Final simulation time and random seed

**Expected runtime:** several minutes to over an hour depending on hardware. The terminal output provides progress updates so you can monitor the run.

On completion the file `figure7.neuron` is written to the current directory.

> ⚠️ **The C++ simulation is computationally intensive.** The main training loop runs **40 million events** followed by a recall phase of 40,000 events. This may take some time.

### Visualise in MATLAB
```matlab
run('figure_7.m')
```

`USE_STATIC = true` by default — no interactive input is needed. Set `USE_STATIC = false` to enable interactive mode where the user is prompted for file selection, page size, and page navigation.

---

## Model Description

### Network Structure

| Property | Value |
|----------|-------|
| Total neurons | 10 (`cc = 10`) |
| Active neurons (suprathreshold drive) | 5 (`nActive = 5`, indices 0–4) |
| Inactive neurons (near-threshold + noise) | 5 (indices 5–9) |
| Connectivity | All-to-all (excluding self) |

Active neurons receive constant suprathreshold input currents with small random perturbations. Inactive neurons receive a fixed near-threshold current (`1.02 / R_M`) and fire stochastically via additive noise, acting as background interference.

### LIF Dynamics

Between events the membrane voltage decays as:

$$V(t) = V_{ss} + \bigl(V_0 - V_{ss}\bigr)\,e^{-(t-t_0)/\tau_m}, \qquad V_{ss} = I_{input} \cdot R_M$$

A spike is emitted when $V \geq V_{thr} = 1.0$, after which $V$ resets to 0. A refractory offset of 0.15 ms is added to the computed fire time.

### Plasticity Rules

**STDP (weight updates)** — applied at every firing event:
$$\Delta\omega = +\eta_w \cdot e^{-\Delta t / T_2} \quad \text{(potentiation, pre before post)}$$
$$\Delta\omega = -\eta_w \cdot e^{-\Delta t / T_2} \quad \text{(depression, post before pre)}$$

Weights are hard-clipped to $[0, \omega_{max}]$.

**Latency plasticity** — applied at every firing event using a Gaussian-shaped update:
$$\Delta L = \eta_L \cdot \Delta t \cdot \frac{e^{-\Delta t^2 / T_D^2}}{T_D}$$

Two latency update terms are computed per presynaptic spike: one relative to the previous self-spike and one relative to the current firing time. Latencies are clipped to $[0.01, 80.01]$ ms.

### Simulation Phases

| Phase | Events | Recording | Plasticity | Description |
|-------|--------|-----------|------------|-------------|
| Training | 40,000,000 | Last 1 M only (`q > 39000000`) | STDP + Latency | Full learning with both weight and delay adaptation |
| Reset | — | — | — | `Reset()` randomises all event timings; weights and latencies are preserved |
| Recall | 40,000 | All events | STDP + Latency | Network recovers polychronization from disrupted temporal state |

### Key Parameters

| Parameter | Symbol | Value | Description |
|-----------|--------|-------|-------------|
| Network size | `cc` | 10 | Ten-neuron LIF network |
| Active neurons | `nActive` | 5 | Indices 0–4 |
| Firing threshold | $V_{thr}$ | 1.0 | Normalised membrane voltage |
| Membrane time constant | $\tau_m$ | 20 ms | RC decay rate |
| Membrane resistance | $R_M$ | 10 MΩ | RC circuit resistance |
| STDP time constant | $T_2$ | 20 ms | Weight update window |
| Latency plasticity time constant | $T_D$ | 5 ms | Latency update window |
| Weight learning rate | $\eta_w$ | `1×10⁻⁴` | |
| Latency learning rate | $\eta_L$ | `1×10⁻²` | |
| Maximum weight | $\omega_{max}$ | 0.051 | Hard clip |
| Latency range | $L$ | [0.01, 80.01] ms | Hard clip |
| Training events | — | 40,000,000 | Main training loop |
| Recall events | — | 40,000 | Post-reset recording |

---

## Output File Format (`figure7.neuron`)

### Header (4 bytes)

| Bytes | Type | Value |
|-------|------|-------|
| 0–3 | `int32` | Number of neurons `cc` = 10 |

### Data records (24 bytes each)

Written by `save(i, j)` for events in both the late training and recall phases.

| Bytes | Type | Field | Notes |
|-------|------|-------|-------|
| 0–7 | `double` | Simulation time `t` (ms) | Absolute timestamp |
| 8–11 | `int32` | Pre-synaptic neuron index `i` (0-based) | |
| 12–15 | `int32` | Post-synaptic neuron index `j` (0-based) | |
| 16–23 | `double` | Amplitude value | `1.5` for a firing event (`i == j`); `−w[j][i] / maxW` for a synaptic reception |

---

## Visualisation Details (`figure_7.m`)

The MATLAB script supports two input modes controlled by the `USE_STATIC` flag:

| Mode | `USE_STATIC` | Behaviour |
|------|-------------|-----------|
| Static | `true` (default) | All parameters hardcoded — renders one figure and exits |
| Interactive | `false` | User is prompted for file, page size, and page number |

### Static Mode Defaults

| Parameter | Value |
|-----------|-------|
| File | `figure7.neuron` |
| Events per page | 1,000 (Firing period mode) |
| Hidden context pages | 4 |
| Page number | 999 last page before reset |

### Plot Description
- A single axes showing **Firing period (inter-spike interval) vs. time** for all 10 neurons.
- Each neuron is plotted as a coloured line; a legend identifies each neuron.
- The plot reveals two distinct regions:
  - **0–1300 ms:** Sustained polychronization — the 5 active neurons converge to a common firing period despite interference from 5 inactive neurons.
  - **After 1300 ms:** The temporal reset disrupts all spike timings, producing a brief transient. Within ~200 ms, the network reinstates polychronization, demonstrating successful recall from learned weights and latencies.

---

## Reproducing Figure 7

1. Compile `figure 7.cpp` with optimisation (`-O2`) and run it. **Allow significant time for the 40-million-event training phase.**
2. Once `figure7.neuron` is written, open MATLAB in the same directory and run `figure_7.m`.
3. The default static mode displays the last page of Firing period data, showing both the sustained polychronization and the recall after temporal reset.
