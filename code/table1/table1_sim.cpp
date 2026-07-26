#include <cmath>
#include <cstdlib>
#include <ctime>
#include <deque>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <string>

using namespace std;

// --- MODEL CONSTANTS ---
const int cc = 50; // maximum number of neurons allocated
int nActive = 25;  // number of active neurons (can be overridden via CLI)
const long double inf = 1e10; // a large number for infinity
const long double maxW = 0.0109;

// --- LIF PARAMETERS ---
const long double firThr = 1.0; // Firing threshold
const long double tDecay = 20;  // Stat decay time constnt
const long double R_M = 10.0;   // Membrane resistance (e.g., in MΩ)

// --- PLASTICITY PARAMETERS ---
const long double T2 = 10;      // Time constant of STDP
const long double TD = 5;       // Time constant for Latency Plasticity
const long double WLR = 5.0e-4; // weights' Learning rat for STDP
const long double LLR = 1.0e-3; // latencies Learning rat for LTDP

// --- For drawing output file ---
const double FIR = 1.5, REC = -0.75;
fstream ofs;

// --- GLOBAL VARIABLES ---
long double t = 0;              //  simulation time
long double w[cc][cc];          // Weight matrix
long double L[cc][cc];          // Latency matrix
deque<long double> Ev[cc][cc];  // Event queue: Ev[i][j] is a spike from i to j
deque<long double> pEv[cc][cc]; // History of previous spike arrivals
long double NSV[cc];            // Neuron State Voltage
long double LstChang[cc];       // Time of last change for each neuron
long double perturbedInCurrent[cc]; // External input equivalent current with perturbation
long double inputEqCurrent[cc];     // External input equivalent current

// Runtime parameters
int cc_runtime = 50; // actual number of neurons active in the run (25 + nBackground)
bool latency_plasticity_enabled = true; // Toggle latency plasticity updates

void fir(int &i);
void recive(int &i, int &j);
void save(int i, int j);
void inizilizeW();
void inizilizeL();
void initializeEvent();
void printW();
void printWW();
long double timToFire(int neuron_index, long double V_start);
void postRecvVolt(int postN, int preN);
long double getNextEvent(int &a, int &b);

// Find the next event for processing
long double getNextEvent(int &preN, int &postN) {
  long double tNe = inf; // time of next event
  for (int i = 0; i < cc_runtime; i++) {
    for (int j = 0; j < cc_runtime; j++) {
      if (Ev[i][j].empty())
        continue;
      if (Ev[i][j].front() < tNe) {
        tNe = Ev[i][j].front();
        preN = i;  // source of event
        postN = j; // destination of event
      }
    }
  }
  return tNe;
}

// Get time for a neuron to reach threshold from a given starting state voltage
long double timToFire(int index, long double V_start) {
  if (V_start >= firThr)
    return 0.0;

  long double time, V_ss;
  V_ss = perturbedInCurrent[index] * R_M;
  if (V_ss <= V_start)
    return -1.0;
  time = tDecay * log((V_ss - V_start) / (V_ss - firThr));
  return time;
}

// A neuron fires
void fir(int &i) {
  long double delta_t;
  long double delta_w;
  for (int s = 0; s < cc_runtime; s++) {
    if (s == i)
      continue;
    while ((!pEv[s][i].empty()) && pEv[i][i].front() > pEv[s][i].front()) {
      pEv[s][i].pop_front();
    }
  }
  if (i < nActive)
    perturbedInCurrent[i] = inputEqCurrent[i];
  else
    perturbedInCurrent[i] = inputEqCurrent[i] + (rand() % 6000) / 100000.0;

  for (int s = 0; s < cc_runtime; ++s) {
    if (s == i || pEv[s][i].empty())
      continue;

    delta_t = t - pEv[s][i].back();
    delta_w = WLR * exp(-delta_t / T2);
    w[i][s] = min(w[i][s] + delta_w, maxW);

    if (latency_plasticity_enabled) {
      long double latency_change = pEv[i][i].back() - pEv[s][i].back() - .15;
      L[i][s] += LLR * latency_change *
                 (std::exp(-(latency_change * latency_change) / (TD * TD)) / TD);
      L[i][s] = max((L[i][s]), (long double)0.01);
      L[i][s] = min((L[i][s]), (long double)80.01);

      latency_change = t - pEv[s][i].back() - .15;
      L[i][s] += LLR * latency_change *
                 (std::exp(-(latency_change * latency_change) / (TD * TD)) / TD);
      L[i][s] = max((L[i][s]), (long double)0.01);
      L[i][s] = min((L[i][s]), (long double)80.01);
    }
  }

  pEv[i][i].pop_front();
  pEv[i][i].push_back(t);
  Ev[i][i].pop_front();
  Ev[i][i].push_back(t + timToFire(i, 0.0));

  NSV[i] = 0.0;
  LstChang[i] = t;

  for (int s = 0; s < cc_runtime; s++) {
    if (s == i)
      continue;
    Ev[i][s].push_back(t + L[s][i]);
  }
}

void postRecvVolt(int postN, int preN) {
  long double V_ss;
  long double timeSinceRecv = t - LstChang[postN];
  V_ss = perturbedInCurrent[postN] * R_M;
  NSV[postN] = V_ss + (NSV[postN] - V_ss) * exp(-timeSinceRecv / tDecay);
  NSV[postN] += w[postN][preN];
}

void recive(int &preN, int &postN) {
  long double delta_t;
  long double delta_w;

  if (!pEv[postN][postN].empty()) {
    delta_t = t - pEv[postN][postN].back();
    delta_w = -WLR * exp(-delta_t / T2);
    w[postN][preN] = max((long double)0.0, w[postN][preN] + delta_w);
  }
  pEv[preN][postN].push_back(t);
  Ev[preN][postN].pop_front();

  if (NSV[postN] >= firThr)
    return;
  postRecvVolt(postN, preN);
  LstChang[postN] = t;
  long double TtF = timToFire(postN, NSV[postN]);

  if (TtF >= 0.0)
    Ev[postN][postN][0] = t + TtF + .15;
}

void inizilizeW() {
  for (int i = 0; i < cc; i++) {
    for (int j = 0; j < cc; j++) {
      if (i == j)
        w[i][j] = 0.0;
      else
        w[i][j] = (rand() % 300 / 1000.0) * maxW;
    }
  }
}

void inizilizeL() {
  for (int i = 0; i < cc; i++) {
    LstChang[i] = 0.0;
    NSV[i] = 0.0;

    if (i < nActive) {
      perturbedInCurrent[i] = inputEqCurrent[i] =
          (1.1 + ((rand() % 100) / 1000.0)) / R_M;
    } else {
      perturbedInCurrent[i] = inputEqCurrent[i] = (1.02 / R_M);
    }
    for (int j = 0; j < cc; j++) {
      Ev[i][j].clear();
      pEv[i][j].clear();
      if (i == j) {
        long double initial_period = timToFire(i, 0.0);
        if (initial_period > 0) {
          Ev[i][j].push_back((rand() % 1000) / 1000.0 * initial_period);
          pEv[i][j].push_back(-Ev[i][j].front());
        }
      } else {
        L[j][i] = ((rand() % 1000) / 1000.0) * tDecay * 2 + 0.01;
      }
    }
  }
}

int main(int argc, char *argv[]) {
  string mode = "latency_on";
  int nBackground = 25;
  if (argc > 1) {
    mode = argv[1];
  }
  if (argc == 3) {
    nBackground = atoi(argv[2]);
  } else if (argc > 3) {
    nActive = atoi(argv[2]);
    nBackground = atoi(argv[3]);
  }

  if (mode == "latency_off") {
    latency_plasticity_enabled = false;
    cout << "Running simulation with Latency Plasticity: OFF (STDP ON), nActive = "
         << nActive << ", nBackground = " << nBackground << endl;
  } else {
    latency_plasticity_enabled = true;
    cout << "Running simulation with Latency Plasticity: ON (STDP ON), nActive = "
         << nActive << ", nBackground = " << nBackground << endl;
  }

  cc_runtime = nActive + nBackground;
  if (cc_runtime > cc) {
    cout << "Error: cc_runtime (" << cc_runtime << ") exceeds maximum cc (" << cc << ")" << endl;
    return 1;
  }

  int i, j;
  srand(13579246); // Seed for reproducibility
  inizilizeW();
  inizilizeL();

  string outFilename = "table1_" + mode + "_bg" + to_string(nBackground) + ".neuron";
  string outPath = "../../results/table1/" + outFilename;
  ofs.open(outPath, std::ofstream::out | ios::binary);
  if (!ofs.is_open()) {
    cout << "Warning: Could not open " << outPath << ". Writing to local directory instead." << endl;
    ofs.open(outFilename, std::ofstream::out | ios::binary);
  }
  ofs.write((char *)&cc_runtime, sizeof(int));

  cout.setf(ios::fixed);
  cout.setf(ios::showpoint);
  cout.precision(4);
  printW();

  for (long q = 0; q <= 1000000000; q++) {
    t = getNextEvent(i, j);
    if (q > 990000000)
      save(i, j);
    if (q % 100000000 == 0) {
      cout << "Progress: " << q << " / 1000000000 events completed (t = " << t << " ms)" << endl;
    }
    if (i == j)
      fir(i);
    else
      recive(i, j);
  }

  printW();
  cout << "Simulation completed successfully at t = " << t << endl;
  ofs.close();
  _exit(0);
}

void printW() {
  cout << "\n--- Weights (W) || Latencies (L) ---\n";
  for (int y = 0; y < cc_runtime; y++) {
    for (int x = 0; x < cc_runtime; x++)
      cout << w[y][x] << " ";
    cout << "|| ";
    for (int x = 0; x < cc_runtime; x++)
      cout << L[y][x] << " ";
    cout << endl;
  }
}

void printWW() {
  for (int y = 0; y < cc_runtime; y++) {
    for (int x = 0; x < cc_runtime; x++)
      cout << w[y][x] << " ";
    cout << endl;
  }
}

void save(int i, int j) {
  double x = t, y;
  if (i == j) {
    ofs.write((char *)&x, sizeof(double));
    ofs.write((char *)&i, sizeof(int));
    ofs.write((char *)&j, sizeof(int));
    ofs.write((char *)&FIR, sizeof(double));
  } else {
    y = w[j][i] / maxW * -1;
    ofs.write((char *)&x, sizeof(double));
    ofs.write((char *)&i, sizeof(int));
    ofs.write((char *)&j, sizeof(int));
    ofs.write((char *)&y, sizeof(double));
  }
}
