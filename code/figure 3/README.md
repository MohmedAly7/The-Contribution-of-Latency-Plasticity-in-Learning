# Figure 3 — Representation of Neuron Dynamics

> **Fig. 3: Representation of neuron dynamics.**
> **a.** The panel displays 11 superimposed firing cycles of $n_2$. The single red arrows indicate the overlapping firing times, while the spike arrivals from neuron $n_1$ are represented by the inner blue arrows. With synaptic weights $\omega_{12}$ and $\omega_{21}$ set to negligibly small values, the phase dispersion of spike arrival times remains uniform across all cycles. The axes represent continuous time $t$ and the period index $k$.     
> **b.** The introduction of a positive coupling strength $\omega_{21}$ (from neuron $n_1$ to neuron $n_2$) shortens the duration of firing period $p_2(k)$, thereby reducing the disparity between the firing periods of the two neurons. Approximately 20 cycles are required to accumulate a shift equivalent to one full firing period. As the arrival of an action potential from $n_2$ approaches the firing time of $n_1$, the magnitude of the cycle-to-cycle shift progressively decreases, and the arrival density increases. In the absence of STDP, this temporal pattern remains unchanged across successive cycles.
> **c.** The panel shows an overlay of 1,000 firing cycles of neuron $n_2$ under STDP-enabled conditions. Under these circumstances, gradual polychronization may emerge, consistent with Hebbian principles. The red arrow indicates the consolidated firing of $n_2$, whereas the blue arrows represent spike arrivals from $n_1$, transitioning from dispersed arrival in early training cycles (translucent blue) to consolidated arrivals after polychronization (solid blue).

---

## Overview

This folder contains three independent C++ simulations and one shared MATLAB visualisation script that together produce the three panels of Figure 3. Each panel isolates a different synaptic condition on the same two-neuron LIF network, enabling a controlled comparison of how coupling strength and STDP progressively shape the inter-neuron phase relationship — from uniform dispersion (panel **a**), through biased-but-unlocked dynamics (panel **b**), to full polychronization (panel **c**).

---

## Files

| File | Role | Output |
|------|------|--------|
| `figure_3a.cpp` | C++ simulation — **no coupling** (negligible weights) | `circle_figure3a.neuron` |        
| `figure_3b.cpp` | C++ simulation — **static unidirectional coupling**, no learning | `circle_figure3b.neuron` |
| `figure_3c.cpp` | C++ simulation — **STDP-enabled bidirectional coupling** | `circle_figure3c.neuron` |     
| `figure3.m` | MATLAB visualiser — reads all three files and renders panels a, b, c | Figure window |        

> The `.neuron` files are binary; their format is described in the [Output File Format](#output-file-format) section below.

---

## How to Build and Run

### Requirements
- A C++ compiler supporting C++11 or later (`g++`)
- MATLAB with the [`arrow`](https://www.mathworks.com/matlabcentral/fileexchange/278) function on the path      
- No other external libraries required

### Compile
```bash
g++ -O2 -o figure3a "figure_3a.cpp"
g++ -O2 -o figure3b "figure_3b.cpp"
g++ -O2 -o figure3c "figure_3c.cpp"
```

### Run (in any order)
```bash
./figure3a    # writes circle_figure3a.neuron
./figure3b    # writes circle_figure3b.neuron
./figure3c    # writes circle_figure3c.neuron
```

Each executable prints the weight/latency table at start and end, reports progress every 200,000 events, and outputs the final simulation time to `stdout`.

### Visualise in MATLAB
```matlab
run('figure3.m')
```

`USE_STATIC = true` by default — no interactive input needed. All three panels render in one figure window.   

---

## What Each Panel Shows

### Panel a — No Coupling (`figure_3a.cpp`)

Both synaptic weights are zero (`w[0][1] = 0`, `w[1][0] = 0`) and STDP is disabled (`WLR = 0`). With no interaction between them, the phase of $n_1$'s spike arrivals drifts uniformly around $n_2$'s cycle with each successive firing. Superimposing **11 firing cycles** (solid arrows) produces an evenly scattered distribution confirming statistical independence.

| Parameter | Value |
|-----------|-------|
| `maxW` | 0.00 — weights disabled |
| `WLR` | 0 — no STDP |
| $\omega_{12}$ / $\omega_{21}$ | 0 / 0 |
| Latency range | `[0.01, τ + 0.01]` ms, random |
| Random seed | `1759424374` |
| Cycles plotted | 11 (offset 1, opacity 1.0) |

### Panel b — Static Unidirectional Coupling (`figure_3b.cpp`)

A small positive weight is fixed from $n_1$ to $n_2$ (`w[1][0] = 0.0011`); the reverse synapse remains zero. STDP is still disabled. so each incoming spike from $n_1$ slightly shortens $p_2(k)$. This produces a non-uniform drift: arrival density increases as $n_1$'s spike time converges toward $n_2$'s firing time, and the per-cycle shift decreases accordingly. Without plasticity the pattern repeats stably but never locks. The diagram shows **≈ 20 cycles** (solid arrows) with progressively clustering arrivals that do not fully consolidate.

| Parameter | Value |
|-----------|-------|
| `maxW` | 0.06 |
| `WLR` | 0 — no STDP |
| $\omega_{12}$ / $\omega_{21}$ | 0 / 0.0011 (fixed) |
| Latency range | `[0.01, τ + 0.01]` ms, random |
| Random seed | `1777632710` |
| Cycles plotted | 19 (offset 2, opacity 1.0) |

### Panel c — STDP Learning (`figure_3c.cpp`)

Both synapses are now plastic (`WLR = 1 × 10⁻³`). Weights begin from small random values and are updated by STDP at every spike event. Over 60,000 events, Hebbian reinforcement gradually consolidates the phase relationship. Overlaying **1,000 firing cycles** at opacity 0.1 captures the full training trajectory in a single image: early cycles appear as dispersed translucent arrows; later cycles as tightly clustered, nearly solid arrows — the visual signature of emerging polychronization.

| Parameter | Value |
|-----------|-------|
| `maxW` | 0.01 |
| `WLR` | `1 × 10⁻³` — STDP active |
| Initial weights | Random, $< 0.3 \times \omega_{max}$ |
| Latency range | `[0.01, 2τ + 0.01]` ms, random |
| Random seed | `1777632710` |
| Cycles plotted | 1,000 (offset 1, opacity 0.1) |

---

## Shared Model Parameters

These values are identical across all three simulations.

| Parameter | Symbol | Value | Description |
|-----------|--------|-------|-------------|
| Network size | `cc` | 2 | Two-neuron LIF network |
| Firing threshold | $V_{thr}$ | 1.0 | Normalised membrane voltage |
| Membrane time constant | $\tau$ | 5 ms | Voltage decay rate |
| Membrane resistance | $R_M$ | 10 MΩ | RC circuit resistance |
| STDP time constant | $T_2$ | 10 ms | Temporal window for weight updates |
| Simulation length | — | 60,000 events | All panels |

### LIF Membrane Voltage

Between events the membrane voltage decays as:

$$V(t) = V_{ss} + \bigl(V_0 - V_{ss}\bigr)\,e^{-(t-t_0)/\tau}, \qquad V_{ss} = I_{input} \cdot R_M$$

A spike is emitted when $V \geq V_{thr} = 1.0$, after which $V$ resets to 0.

### STDP Update Rules

$$\Delta\omega = +\eta_w \cdot e^{-\Delta t / T_2} \quad \text{(pre before post — potentiation)}$$
$$\Delta\omega = -\eta_w \cdot e^{-\Delta t / T_2} \quad \text{(post before pre — depression)}$$

Weights are hard-clipped to $[0, \omega_{max}]$.

---

## Output File Format

All three `.neuron` files share the same binary layout.

### Header (4 bytes)

| Bytes | Type | Value |
|-------|------|-------|
| 0–3 | `int32` | Number of neurons `cc` = 2 |

### Data records (20 bytes each)

Written by `saveCircle(i)` at the moment neuron `i` fires.

| Bytes | Type | Field | Notes |
|-------|------|-------|-------|
| 0–3 | `int32` | Firing neuron index `i` (0-based) | Which neuron fired |
| 4–11 | `double` | $t - t^{(i)}_{\text{prev}}$ | Elapsed time since `i`'s own previous spike → period $T$ |
| 12–19 | `double` | $t - t^{(\neg i)}_{\text{arrival}}$ | Elapsed time since the other neuron's last spike arrived → phase index $k$; `−1` if no arrival in history |

Multiple records may be written per firing event when spike-history queues hold more than one entry.

---

## Visualisation Details (`figure3.m`)

The MATLAB script places all three panels in a single `1 × 3` figure. For each panel:

- A black circle (radius 3) represents one complete oscillation cycle of $n_2$.
- The **red/orange arrow** (fixed at 12 o'clock) marks $n_2$'s own consolidated firing time.
- Each **blue arrow** is placed at angle $\theta = 2\pi \cdot k / T$, encoding the phase of $n_1$'s spike arrival within $n_2$'s period.
- The arc labelled **t** (black) marks the continuous-time axis; the arc labelled **k** (blue) marks the discrete period-index axis.
- Letter labels **a**, **b**, **c** are placed below each panel via figure-level `annotation` calls.
- Each panel has its own `n2` / `n1` legend.

| Panel | Cycles shown | Arrow opacity | Visual purpose |
|-------|-------------|---------------|----------------|
| a | 11 | 1.0 (solid) | Uniform phase dispersion — independence |
| b | 19 | 1.0 (solid) | Non-uniform drift and density increase — static coupling |
| c | 1,000 | 0.1 (translucent → solid) | Full training trajectory — polychronization |

---

## Reproducing Figure 3

1. Compile and run all three C++ files in the same working directory.
2. Confirm that `circle_figure3a.neuron`, `circle_figure3b.neuron`, and `circle_figure3c.neuron` are present.   
3. Open MATLAB in that directory and run `figure3.m`.
