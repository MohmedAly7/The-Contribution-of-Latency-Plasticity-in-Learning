import os
import sys
import math
import struct
import subprocess
import shutil
import concurrent.futures
from bisect import bisect_left, bisect_right

def load_neuron_data_custom(filepath, maxW_val=0.0109):
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"Data file not found: {filepath}")

    with open(filepath, 'rb') as f:
        header = f.read(4)
        if len(header) < 4:
            raise ValueError("Empty or corrupted file header")
        cc = struct.unpack('i', header)[0]

        firing_events = []
        reception_events = []

        record_struct = struct.Struct('d i i d')
        record_size = record_struct.size

        while True:
            chunk = f.read(record_size)
            if len(chunk) < record_size:
                break
            t, i, j, amp = record_struct.unpack(chunk)

            if i == j:
                firing_events.append((t, i))
            else:
                weight = -amp * maxW_val
                reception_events.append((t, i, j, weight))

    return cc, firing_events, reception_events

def run_analysis_local(filepath, n_active=25, maxW_val=0.0109):
    cc, firing_events, reception_events = load_neuron_data_custom(filepath, maxW_val)
    active_neurons = list(range(min(n_active, cc)))

    spike_times = {n: [] for n in active_neurons}
    for t_val, n in firing_events:
        if n in spike_times:
            spike_times[n].append(t_val)

    # 1. Spike-Time Jitter
    total_jitter = 0.0
    max_jitter = 0.0
    valid_pairs_count_C = 0

    for a in active_neurons:
        for b in active_neurons:
            if a >= b:
                continue

            times_a = spike_times[a]
            times_b = spike_times[b]
            if len(times_a) < 5 or len(times_b) < 5:
                continue

            diffs = []
            for ta in times_a:
                idx_start = bisect_left(times_b, ta - 50.0)
                idx_end = bisect_right(times_b, ta + 50.0)
                for tb in times_b[idx_start:idx_end]:
                    diffs.append(tb - ta)

            if not diffs:
                continue

            num_bins = 100
            bins = [0] * num_bins
            for d in diffs:
                bin_idx = int((d + 50.0) // 1.0)
                if 0 <= bin_idx < num_bins:
                    bins[bin_idx] += 1

            max_count = max(bins)
            if max_count == 0:
                continue

            peak_bin_idx = bins.index(max_count)
            peak_delay = -50.0 + peak_bin_idx * 1.0 + 0.5
            peak_window_diffs = [d for d in diffs if abs(d - peak_delay) <= 5.0]

            if len(peak_window_diffs) >= 3:
                mean_diff = sum(peak_window_diffs) / len(peak_window_diffs)
                var_diff = sum((x - mean_diff) ** 2 for x in peak_window_diffs) / (len(peak_window_diffs) - 1)
                jitter = math.sqrt(var_diff)
                
                T_a = (times_a[-1] - times_a[0]) / (len(times_a) - 1) if len(times_a) > 1 else 1.0
                T_b = (times_b[-1] - times_b[0]) / (len(times_b) - 1) if len(times_b) > 1 else 1.0
                T_avg = (T_a + T_b) / 2.0
                jitter_pct = (jitter / T_avg) * 100.0 if T_avg > 0 else 0.0
                
                total_jitter += jitter_pct
                max_jitter = max(max_jitter, jitter_pct)
                valid_pairs_count_C += 1

    avg_jitter = total_jitter / valid_pairs_count_C if valid_pairs_count_C > 0 else 0.0

    # 2. Synaptic Weight Matrix & Latencies
    W = [[0.0] * cc for _ in range(cc)]
    for t_val, pre, post, weight in reception_events:
        W[post][pre] = max(0.0, min(weight, maxW_val))

    firings_map = {n: [] for n in range(cc)}
    for t_val, n in firing_events:
        firings_map[n].append(t_val)
    last_reception = {}
    for t_val, pre, post, _ in reception_events:
        last_reception[(pre, post)] = t_val

    L = [[0.0] * cc for _ in range(cc)]
    for pre in range(cc):
        for post in range(cc):
            if pre == post:
                continue
            t_rec = last_reception.get((pre, post))
            if t_rec is None:
                continue
            pre_firings = firings_map[pre]
            t_fire = None
            for tf in reversed(pre_firings):
                if tf < t_rec:
                    t_fire = tf
                    break
            if t_fire is not None:
                L[post][pre] = t_rec - t_fire

    # 3. Presynaptic Arrival Coincidence Index
    coincidence_index = 0.0
    arrivals_by_post = {n: [] for n in range(cc)}
    for t_val, pre, post, _ in reception_events:
        arrivals_by_post[post].append(t_val)

    active_firings = [ev for ev in firing_events if ev[1] in active_neurons]
    if active_firings:
        total_coincidences = 0
        for t_fire, post_n in active_firings:
            arrs = arrivals_by_post[post_n]
            idx_end = bisect_right(arrs, t_fire)
            idx_start = bisect_left(arrs, t_fire - 2.0)
            total_coincidences += (idx_end - idx_start)
        coincidence_index = total_coincidences / len(active_firings)

    # 4. Polychronous Group Search (PNG Count & Max Cascade)
    png_count = 0
    max_length = 0.0
    strong_weight_threshold = 0.784 * maxW_val
    coincidence_window_G = 2.0
    refractory_offset = 0.15

    for idx_i, i in enumerate(active_neurons):
        for idx_j, j in enumerate(active_neurons):
            if i >= j:
                continue

            for delta_t in [x * 0.5 for x in range(161)]:
                spike_times_G = {i: 0.0, j: float(delta_t)}
                fired = [i, j]
                changed = True
                while changed:
                    changed = False
                    for k in active_neurons:
                        if k in spike_times_G:
                            continue
                        arrivals = []
                        for pre in fired:
                            if W[k][pre] >= strong_weight_threshold:
                                t_arr = spike_times_G[pre] + L[k][pre]
                                arrivals.append(t_arr)
                        if len(arrivals) < 2:
                            continue
                        arrivals.sort()
                        triggered = False
                        t_fire = None
                        for idx in range(1, len(arrivals)):
                            if arrivals[idx] - arrivals[idx-1] <= coincidence_window_G:
                                triggered = True
                                t_fire = arrivals[idx] + refractory_offset
                                break
                        if triggered:
                            spike_times_G[k] = t_fire
                            fired.append(k)
                            changed = True
                if len(fired) >= 5:
                    png_count += 1
                    duration = max(spike_times_G.values()) - min(spike_times_G.values())
                    max_length = max(max_length, duration)

    return {
        "png_count": png_count,
        "max_length": max_length,
        "coincidence_index": coincidence_index,
        "avg_jitter": avg_jitter
    }

def get_maxW_from_cpp():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    cpp_path = os.path.join(script_dir, "table1_sim.cpp")
    if os.path.exists(cpp_path):
        with open(cpp_path, "r", encoding="utf-8") as f:
            for line in f:
                if "maxW =" in line and "const" in line:
                    parts = line.split("=")
                    if len(parts) > 1:
                        val_str = parts[1].replace(";", "").strip().split("//")[0].strip()
                        try:
                            return float(val_str)
                        except Exception:
                            pass
    return 0.0109

def locate_data_file(filename, custom_dir=None):
    search_dirs = []
    if custom_dir:
        search_dirs.append(custom_dir)

    script_dir = os.path.dirname(os.path.abspath(__file__))
    search_dirs.extend([
        os.path.abspath(os.path.join(script_dir, "../../results/table1")),
        os.path.abspath(os.path.join(script_dir, "../../data/table1")),
        os.path.abspath(os.path.join(script_dir, "../../data/table")),
        script_dir,
        os.getcwd()
    ])

    for d in search_dirs:
        path = os.path.join(d, filename)
        if os.path.exists(path) and os.path.getsize(path) > 0:
            return path
    return None

def compile_simulation_binary():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    cpp_file = os.path.join(script_dir, "table1_sim.cpp")
    exe_file = os.path.join(script_dir, "table1_sim.exe")

    if not os.path.exists(cpp_file):
        raise FileNotFoundError(f"Source file table1_sim.cpp not found at {cpp_file}")

    cmd = ["g++", "-O2", "-o", exe_file, cpp_file]
    print(f"-> Compiling C++ simulation: {' '.join(cmd)}", flush=True)
    subprocess.run(cmd, check=True, cwd=script_dir)
    return exe_file

def run_single_simulation(mode, bg):
    script_dir = os.path.dirname(os.path.abspath(__file__))
    exe_file = os.path.join(script_dir, "table1_sim.exe")
    out_filename = f"table1_{mode}_bg{bg}.neuron"

    cmd = [exe_file, mode, "25", str(bg)]
    print(f"-> [Parallel Sim] Starting mode={mode}, nBackground={bg}...", flush=True)

    proc = subprocess.run(cmd, cwd=script_dir, capture_output=True, text=True)

    filepath = locate_data_file(out_filename)
    if not filepath or not os.path.exists(filepath):
        alt_filename = f"figure8_1_{mode}_bg{bg}.neuron"
        filepath = locate_data_file(alt_filename)
        
    if not filepath or not os.path.exists(filepath):
        raise FileNotFoundError(f"Simulation failed for mode={mode}, bg={bg}. Stderr: {proc.stderr}")
        
    print(f"-> [Parallel Sim] Completed mode={mode}, nBackground={bg}.", flush=True)
    return mode, bg, filepath

def generate_table1(data_dir=None, force_sim=False):
    if "--force-sim" in sys.argv or "force" in sys.argv or "sim" in sys.argv:
        force_sim = True

    backgrounds = [0, 10, 25]
    modes = ["latency_on", "latency_off"]
    maxW_val = get_maxW_from_cpp()
    print(f"-> Using dynamic maxW = {maxW_val} (parsed from table1_sim.cpp)", flush=True)

    script_dir = os.path.dirname(os.path.abspath(__file__))
    data_target_dir = os.path.abspath(os.path.join(script_dir, "../../results/table1"))
    os.makedirs(data_target_dir, exist_ok=True)

    results = {bg: {} for bg in backgrounds}

    print("=" * 80)
    print("       GENERATING TABLE 1 FOR MPAPER (PARALLEL SIMULATIONS)")
    print("=" * 80)

    configs_to_run = []
    filepaths = {}

    for bg in backgrounds:
        for mode in modes:
            if force_sim:
                configs_to_run.append((mode, bg))
                continue
            fn = f"table1_{mode}_bg{bg}.neuron"
            fp = locate_data_file(fn, data_dir)
            if not fp:
                alt = f"figure8_1_{mode}_bg{bg}.neuron"
                fp = locate_data_file(alt, data_dir)
            
            if fp:
                filepaths[(mode, bg)] = fp
            else:
                configs_to_run.append((mode, bg))

    if configs_to_run:
        print(f"\n-> Launching {len(configs_to_run)} simulation(s) in PARALLEL...", flush=True)
        compile_simulation_binary()
        
        with concurrent.futures.ProcessPoolExecutor() as executor:
            futures = {executor.submit(run_single_simulation, m, b): (m, b) for m, b in configs_to_run}
            for future in concurrent.futures.as_completed(futures):
                m, b = futures[future]
                try:
                    res_m, res_b, fp = future.result()
                    filepaths[(res_m, res_b)] = fp
                    dest_file = os.path.join(data_target_dir, f"table1_{res_m}_bg{res_b}.neuron")
                    if os.path.abspath(fp) != os.path.abspath(dest_file):
                        import time
                        for _ in range(5):
                            try:
                                shutil.copy2(fp, dest_file)
                                break
                            except PermissionError:
                                time.sleep(0.5)
                    print(f"-> Saved data file to {dest_file}", flush=True)
                except Exception as e:
                    print(f"Error in parallel simulation for mode={m}, bg={b}: {e}", flush=True)
                    sys.exit(1)
    else:
        print("\n-> All simulation data files found! Skipping C++ execution.", flush=True)

    for bg in backgrounds:
        for mode in modes:
            fp = filepaths.get((mode, bg))
            if not fp or not os.path.exists(fp):
                raise FileNotFoundError(f"Missing data file for mode={mode}, bg={bg}")

            print(f"-> Processing metrics for {os.path.basename(fp)}...", flush=True)
            res = run_analysis_local(fp, n_active=25, maxW_val=maxW_val)

            results[bg][mode] = {
                "pg_count": res["png_count"],
                "m_cascade": res["max_length"],
                "s_coincidence": res["coincidence_index"],
                "s_jitter": res["avg_jitter"]
            }

    md_output = """# Table 1: Comparative Metrics (from MProject.pdf)

Comparative metrics between STDP-only (`STDP only`) and STDP + Latency plasticity (`With Latency Plasticity`) networks under varying background noise.
"""
    for bg in backgrounds:
        lon = results[bg]["latency_on"]
        loff = results[bg]["latency_off"]
        md_output += f"""
### {bg} Background Noise Neurons

| Network Metric / Statistic | With Latency Plasticity | STDP only |
| :--- | :---: | :---: |
| Polychronous Group Count (PG-Count) | {lon['pg_count']} | {loff['pg_count']} |
| Maximum Activation Cascade in ms (M-Cascade) | {lon['m_cascade']:.4f} | {loff['m_cascade']:.4f} |
| Spike Arrival Coincidence Index (S-Coincidence) | {lon['s_coincidence']:.4f} | {loff['s_coincidence']:.4f} |
| Average Pairwise Jitter % (S-Jitter) | {lon['s_jitter']:.4f}% | {loff['s_jitter']:.4f}% |
"""

    tex_output = r"""\begin{table}[htbp]
\centering
\caption{Comparative metrics between STDP-only and STDP + Latency Plasticity networks across noise conditions.}
\label{tab:table1_comparative_metrics}
\begin{tabular}{lrr}
\hline
\textbf{Metric / Noise Condition} & \textbf{With Latency Plasticity} & \textbf{STDP only} \\
\hline
"""
    for bg in backgrounds:
        lon = results[bg]["latency_on"]
        loff = results[bg]["latency_off"]
        tex_output += f"\\multicolumn{{3}}{{l}}{{\\textbf{{{bg} Background Noise Neurons}}}} \\\\\n"
        tex_output += f"PG-Count & {lon['pg_count']} & {loff['pg_count']} \\\\\n"
        tex_output += f"M-Cascade (ms) & {lon['m_cascade']:.4f} & {loff['m_cascade']:.4f} \\\\\n"
        tex_output += f"S-Coincidence & {lon['s_coincidence']:.4f} & {loff['s_coincidence']:.4f} \\\\\n"
        tex_output += f"S-Jitter (\\%) & {lon['s_jitter']:.4f}\\% & {loff['s_jitter']:.4f}\\% \\\\\n"
        tex_output += "\\hline\n"
    tex_output += r"""\end{tabular}
\end{table}
"""

    print("\n" + md_output)

    out_md_paths = [
        os.path.join(script_dir, "paper_table1_output.md"),
        os.path.join(data_target_dir, "paper_table1_output.md")
    ]
    out_tex_paths = [
        os.path.join(script_dir, "paper_table1_output.tex"),
        os.path.join(data_target_dir, "paper_table1_output.tex")
    ]

    for p in out_md_paths:
        with open(p, "w", encoding="utf-8") as f:
            f.write(md_output)

    for p in out_tex_paths:
        with open(p, "w", encoding="utf-8") as f:
            f.write(tex_output)

    print("=" * 80)
    print("Table 1 output files generated successfully:")
    for p in out_md_paths:
        print(f"  Markdown: {p}")
    for p in out_tex_paths:
        print(f"  LaTeX:    {p}")
    print("=" * 80)

if __name__ == "__main__":
    custom_dir = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("-") else None
    generate_table1(custom_dir)
