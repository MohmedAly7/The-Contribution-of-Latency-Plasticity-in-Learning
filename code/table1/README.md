# Table 1: Comparative Network Metrics Generator

This directory contains the simulation and analysis pipeline to generate **Table 1** from the paper (`MProject.pdf`), titled:

> **Table 1: Comparative metrics between STDP-only and STDP + Latency plasticity networks under varying background noise.**

---

## 1. Paper Metrics Included in Table 1

Table 1 evaluates network performance across 3 background noise configurations (0, 10, and 25 noise neurons) under two plasticity regimes (**With Latency Plasticity** vs. **STDP only**):

1. **Polychronous Group Count (PG-Count)**:
   - Total number of structural polychronous neural groups (PNGs) discovered in the recurrent network.
2. **Maximum Activation Cascade in ms (M-Cascade)**:
   - Longest duration of sustained feedforward spike propagation cascade among identified PNGs.
3. **Spike Arrival Coincidence Index (S-Coincidence)**:
   - Average number of coincident presynaptic spike arrivals within a tight 2.0 ms arrival window preceding postsynaptic firings.
4. **Average Pairwise Jitter % (S-Jitter)**:
   - Average relative spike-timing displacement between active co-firing pairs as a percentage of average period.

---

## 2. Usage Instructions

### Quick Run (Generates Table 1 Output)
Run the python generator script from this directory:

```bash
python generate_paper_table1.py
```

### View Metric Definitions & Help
To view metric details and mathematical definitions in CLI:

```bash
python generate_paper_table1.py --help
```

### Specify Custom Data Directory
If pre-computed `.neuron` binary files are located in a custom folder, pass the folder path as an argument:

```bash
python generate_paper_table1.py "/path/to/data_folder"
```

---

## 3. Automatic Search & Simulation Workflow

1. **Data File Search**: The script automatically checks standard repository locations (`data/`, `results/table1/`, `../../results/figure 7b/`, `./`) for pre-computed simulation files (`table1_{mode}_bg{bg}.neuron` or `figure8_1_{mode}_bg{bg}.neuron`).
2. **Auto-Simulation**: If simulation files are missing, the script automatically compiles `table1_sim.cpp` using `g++` and runs the required simulations to generate fresh `.neuron` data files.
3. **Output Files**: Formatted results are exported to:
   - `paper_table1_output.md` (Markdown format)
   - `paper_table1_output.tex` (LaTeX format)
