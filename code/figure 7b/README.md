# Figure 7b — Firing Periods of All 50 Neurons

> **Fig. 7b: Firing periods of all 50 neurons.** The solid blue line indicates the firing period of the 25 active neurons following polychronization, whereas the gray lines correspond to the inactive neurons.

---

## Overview

This folder contains the C++ simulation and MATLAB visualisation script for **Figure 7b**. The simulation scales the network to fifty leaky integrate-and-fire (LIF) neurons with all-to-all excitatory connectivity, spike-timing-dependent plasticity (STDP) for weight updates, and **latency plasticity** for propagation delay adaptation. Twenty-five neurons are active (suprathreshold drive) and twenty-five are inactive (near-threshold, stochastic firing).

The simulation runs **200 million events** in total, but only the **last 10 million events** (`q > 190000000`) are recorded to `figure7b.neuron`. The first 190 million events are used exclusively for training (plasticity is active throughout) and are not saved, keeping the output file to a manageable size.

The key result is that, even at this larger network scale, the dual plasticity rule successfully produces polychronization among the 25 active neurons. Their firing periods converge to a common value (blue lines), while the 25 inactive neurons remain uncoordinated (gray lines) — demonstrating that the learning rule selectively entrains input-activated neurons without requiring supervision.

---

## Files

| File | Role | Output |
|------|------|--------|
| `figure 7b.cpp` | C++ event-driven LIF network — trains for 200 M events with STDP + latency plasticity | `figure7b.neuron` |
| `figure_7b.m` | MATLAB Firing period line-plot viewer — reads `figure7b.neuron` and plots firing period (Firing period) vs. time | Figure window |

> The `.neuron` file is binary; its format is described in the [Output File Format](#output-file-format) section below.

---

## How to Build and Run

### Requirements
- A C++ compiler supporting C++11 or later (`g++`)
- MATLAB (any recent version)

### Compile
```bash
g++ -O2 -o figure7b "figure 7b.cpp"
```

> Using `-O2` or `-O3` is strongly recommended. Optimised builds can be **2–4× faster** than debug builds on a 200-million-event loop.

### Run
```bash
./figure7b
```

The program prints:
- Initial random firing offsets for each neuron
- Weight/latency tables at the start and end of training
- Progress counters every 2,000,000 events
- Final simulation time and random seed

**Expected runtime:** this is the most computationally intensive simulation in the repository. The main training loop runs **200 million events** on a 50-neuron network. Expect **several hours** of runtime depending on hardware. The terminal output provides progress updates so you can monitor the run.

On completion the file `figure7b.neuron` is written to the current directory.

> ⚠️ **The C++ simulation is very computationally intensive.** The main training loop runs **200 million events** on a 50-neuron all-to-all network. This may take some time.

### Visualise in MATLAB
```matlab
run('figure_7b.m')
```

`USE_STATIC = true` by default — no interactive input is needed. Set `USE_STATIC = false` to enable interactive mode where the user is prompted for file selection, page size, and page navigation.

---

## Model Description

### Network Structure

| Property | Value |
|----------|-------|
| Total neurons | 50 (`cc = 50`) |
| Active neurons (suprathreshold drive) | 25 (`nActive = 25`, indices 0–24) |
| Inactive neurons (near-threshold + noise) | 25 (indices 25–49) |
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

### Key Parameters

| Parameter | Symbol | Value | Description |
|-----------|--------|-------|-------------|
| Network size | `cc` | 50 | Fifty-neuron LIF network |
| Active neurons | `nActive` | 25 | Indices 0–24 |
| Firing threshold | $V_{thr}$ | 1.0 | Normalised membrane voltage |
| Membrane time constant | $\tau_m$ | 20 ms | RC decay rate |
| STDP time constant | $T_2$ | 10 ms | Weight update window |
| Latency plasticity time constant | $T_D$ | 5 ms | Latency update window |
| Weight learning rate | $\eta_w$ | `1×10⁻⁴` | |
| Latency learning rate | $\eta_L$ | `1×10⁻²` | |
| Maximum weight | $\omega_{max}$ | 0.0109 | Hard clip |
| Latency range | $L$ | [0.01, 80.01] ms | Hard clip |
| Active neuron input current | $I_a$ | `(1.1 + rand×0.12) / R_M` | Suprathreshold |
| Inactive neuron input current | $I_i$ | `1.02 / R_M` | Near-threshold |
| Refractory offset | — | 0.15 ms | Added to computed fire time |
| Simulation length | — | 200,000,000 events | Main training loop |
| Recorded events | — | Last 10,000,000 (`q > 190000000`) | Only post-training events saved to file |

---

## Output File Format (`figure7b.neuron`)

### Header (4 bytes)

| Bytes | Type | Value |
|-------|------|-------|
| 0–3 | `int32` | Number of neurons `cc` = 50 |

### Data records (24 bytes each)

Written by `save(i, j)` for events in the last 10 million events of the simulation (`q > 190000000`).

| Bytes | Type | Field | Notes |
|-------|------|-------|-------|
| 0–7 | `double` | Simulation time `t` (ms) | Absolute timestamp |
| 8–11 | `int32` | Pre-synaptic neuron index `i` (0-based) | |
| 12–15 | `int32` | Post-synaptic neuron index `j` (0-based) | |
| 16–23 | `double` | Amplitude value | `1.5` for a firing event (`i == j`); `−w[j][i] / maxW` for a synaptic reception |

---

## Visualisation Details (`figure_7b.m`)

The MATLAB script supports two input modes controlled by the `USE_STATIC` flag:

| Mode | `USE_STATIC` | Behaviour |
|------|-------------|-----------|
| Static | `true` (default) | All parameters hardcoded — renders one figure and exits |
| Interactive | `false` | User is prompted for file, page size, and page number |

### Static Mode Defaults

| Parameter | Value |
|-----------|-------|
| File | `figure7b.neuron` |
| Events per page | 1,000 (Firing period mode) |
| Hidden context pages | 50 |
| Page number | 1,000 (clamped to last page) |

### Plot Description
- A single axes showing **Firing period (inter-spike interval) vs. time** for all 50 neurons.
- **Blue lines** represent the 25 active neurons (indices 1–25); **gray lines** represent the 25 inactive neurons (indices 26–50).
- A two-item legend distinguishes active from inactive neurons.
- Page start/end markers are drawn as dashed vertical lines.
- After training, the active neurons' Firing period traces converge to a common firing period, while the inactive neurons' traces remain scattered — the visual signature of selective polychronization.

---

## Reproducing Figure 7b

1. Compile `figure 7b.cpp` with optimisation (`-O2`) and run it. **Allow several hours for the 200-million-event training loop.**
2. Once `figure7b.neuron` is written, open MATLAB in the same directory and run `figure_7b.m`.
3. The default static mode displays the last page of Firing period data, showing the converged firing periods of the active neurons (blue) against the scattered periods of the inactive neurons (gray).
