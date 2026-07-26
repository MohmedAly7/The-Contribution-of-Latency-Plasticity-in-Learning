import struct
import os

def load_neuron_data(filepath, maxW_val=0.0109):
    """
    Parses binary .neuron file and returns:
    - cc: total number of neurons
    - firing_events: list of (t, neuron_index)
    - reception_events: list of (t, pre_index, post_index, weight)
    """
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

def reconstruct_weights(cc, reception_events, maxW_val=0.0109):
    """
    Reconstructs final weight matrix W[post][pre] from reception events.
    """
    W = [[0.0] * cc for _ in range(cc)]
    for t, pre, post, weight in reception_events:
        W[post][pre] = max(0.0, min(weight, maxW_val))
    return W

def reconstruct_latencies(cc, firing_events, reception_events):
    """
    Reconstructs final latency matrix L[post][pre] (t_arrive - t_fire).
    """
    firings = {n: [] for n in range(cc)}
    for t, n in firing_events:
        firings[n].append(t)

    last_reception = {}
    for t, pre, post, _ in reception_events:
        last_reception[(pre, post)] = t

    L = [[0.0] * cc for _ in range(cc)]
    for pre in range(cc):
        for post in range(cc):
            if pre == post:
                continue
            t_rec = last_reception.get((pre, post))
            if t_rec is None:
                continue

            pre_firings = firings[pre]
            t_fire = None
            for tf in reversed(pre_firings):
                if tf < t_rec:
                    t_fire = tf
                    break

            if t_fire is not None:
                L[post][pre] = t_rec - t_fire
    return L
