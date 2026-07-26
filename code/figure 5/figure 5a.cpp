#include <iostream>
#include <cmath>
#include <cstdlib>
#include <ctime>
#include <deque>
#include <fstream>
#include <iomanip>

using namespace std;

// --- MODEL CONSTANTS ---
const int cc = 10;              // number of neurons in the network
const int nActive = 5;          // number of active neurons
const long double inf  = 1e10;  // a large number for infinity
const long double maxW = .051;

// --- LIF PARAMETERS ---
const long double firThr = 1.0;  // Firing threshold
const long double tDecay = 20;   // Stat decay time constnt
const long double R_M = 10.0;         // Membrane resistance (e.g., in MΩ)

// --- PLASTICITY PARAMETERS ---
const long double T2 = 20;       // Time constant of STDP
const long double TD = 5;       // Time constant for Latency Plasticity
const long double WLR = 1.0e-4;   // weights' Learning rat for STDP
const long double LLR = 1.0e-2;   // latencies Learning rat for LTDP

// --- For drawing output file ---
const double FIR = 1.5, REC = -0.75;
fstream ofs;

// --- GLOBAL VARIABLES ---
long double t = 0;               //  simulation time
long double w[cc][cc];           // Weight matrix
long double L[cc][cc];           // Latency matrix
deque<long double> Ev[cc][cc];   // Event queue: Ev[i][j] is a spike from i to j
deque<long double> pEv[cc][cc];  // History of previous spike arrivals
long double NSV[cc];              // Neuron State Voltage
long double LstChang[cc];        // Time of last change for each neuron
long double perturbedInCurrent[cc]; // External input equivalent current with perturbation
long double inputEqCurrent[cc];    // External input equivalent current

void fir(int& i);
void recive(int& i, int& j);
void save(int i, int j);
void inizilizeW();
void inizilizeL();
void initializeEvent(); // initialize Event
void printW();
// Get time for a neuron to reach threshold from a given starting state voltage
long double timToFire(int neuron_index, long double V_start);
// get post-receive voltage
void postRecvVolt(int postN, int preN );
// Find the next event for processing
long double getNextEvent(int& a, int& b);
//-----------------------------------------

// Find the next event for processing
long double getNextEvent(int& preN, int& postN)
{
    long double tNe = inf; // time of next event
    for (int i = 0; i <cc; i++)
    {
        for (int j = 0; j < cc; j++)
        {
            if (Ev[i][j].empty()) continue;
            if (Ev[i][j].front() < tNe)
            {
                tNe = Ev[i][j].front();
                preN = i; // source of event
                postN= j; // destination of event
            }
        }
    }
    return tNe;
}

// Get time for a neuron to reach threshold from a given starting state voltage
long double timToFire(int index, long double V_start)
{
    if(V_start>=firThr) return 0.0;

    long double time, V_ss ;

    V_ss = perturbedInCurrent[index]*R_M ; //should be delleted
    if(V_ss<= V_start ) return -1.0;
    time = tDecay * log((V_ss - V_start) / (V_ss - firThr));
    return time;
}

// A neuron fires
void fir(int& i)
{
    long double delta_t;
    long double delta_w;
    for(int s=0; s<cc; s++)
    {
        if (s==i)   continue;
        /// to delete all previous event
        while ((!pEv[s][i].empty()) &&pEv[i][i].front()>pEv[s][i].front())
        {
            pEv[s][i].pop_front();
        }
    }
    if (i<nActive)
        perturbedInCurrent[i]=inputEqCurrent[i];//+(rand()%800 - 400)/8000000.0; /// almost zero noise
    else
        perturbedInCurrent[i]=inputEqCurrent[i]+(rand()%8000)/30000.0;
    // --- PLASTICITY  ---
    // When neuron 'i' (postsynaptic) fires, update weights and latencies
    // based on the arrival times of spikes from presynaptic neurons 's'.

    for (int s = 0; s < cc; ++s)
    {
        if (s == i || pEv[s][i].empty()) continue;

        // Get the arrival time of the most recent spike from neuron 's'
        delta_t = t - pEv[s][i].back();

        // STDP (Potentiation): If presynaptic spike arrived before postsynaptic fire.
        delta_w = WLR * exp(-delta_t / T2);
        w[i][s] = min(w[i][s] + delta_w, maxW);
//
        long double latency_change =  pEv[i][i].back()-pEv[s][i].back() -.15;
        L[i][s] +=  LLR*latency_change * (std::exp(-(latency_change * latency_change) / (TD * TD)) / TD) ;  /// latency plasticity
        L[i][s]=max((L[i][s]), (long double)0.01);  /// ensure latency is not negative
        L[i][s]=min((L[i][s]), (long double)80.01);  /// ensure latency is not negative




        latency_change =  t - pEv[s][i].back()  -.15;
        L[i][s] +=  LLR*latency_change * (std::exp(-(latency_change * latency_change) / (TD * TD)) / TD );  /// latency plasticity
        L[i][s]=max((L[i][s]), (long double)0.01);  /// ensure latency is not negative
        L[i][s]=min((L[i][s]), (long double)80.01);  /// ensure latency is not negative

    }

    // Update event quius
    pEv[i][i].pop_front();
    pEv[i][i].push_back(t);
    Ev[i][i].pop_front();
    Ev[i][i].push_back(t + timToFire(i,0.0));

    // --- FIRING LOGIC ---
    NSV[i] = 0.0;
    LstChang[i] = t;

    // Generate spikes (events) from neuron i to
    //the rest of the network
    for (int s = 0; s < cc; s++)
    {
        if (s == i) continue;
        Ev[i][s].push_back(t + L[s][i]); // Note: Latency is L[s][i] for spike from i->s
    }
}
// get post-receive voltage
void postRecvVolt(int postN, int preN )
{


    long double V_ss; //Steady-state voltage defines the RC circuit's theoretical solution,
    // but it's never reached  —neuron fires at 1.0 V.
    long double timeSinceRecv =t - LstChang[postN];

    V_ss = perturbedInCurrent[postN] * R_M;  // R_M represent the resistants of the RC model
    /// calculate the current internal state from last change
    NSV[postN] = V_ss + (NSV[postN] - V_ss) * exp(-timeSinceRecv / tDecay);
    NSV[postN] += w[postN][preN];
}

void recive(int& preN, int& postN) /// [j] receives a pulse from [i]
{
    long double delta_t;
    long double delta_w;

    // --- STDP DEPRESSION (LTD) LOGIC ---
    if (!pEv[postN][postN].empty())
    {
        delta_t = t - pEv[postN][postN].back(); // t_pre - t_post
        // presynaptic spike 'i' arrives after postsynaptic fire 'j', depress the synapse.
        delta_w = -WLR * exp(-delta_t / T2);
        w[postN][preN] = max((long double)0.0, w[postN][preN] + delta_w); // Ensure weight doesn't go below 0

    }
    // Record the arrival time for future plasticity calculations
    pEv[preN][postN].push_back(t);
    Ev[preN][postN].pop_front();

    if (NSV[postN]>=firThr) return ;
    postRecvVolt(postN,preN);    //to update the stat voltage postsynaptic neuron
    LstChang[postN] = t;
    /// calculate the new time after apply the input
    long double TtF = timToFire(postN, NSV[postN]);  // TtF -> time to fire


    if (TtF>=0.0)
        Ev[postN][postN][0]=t+TtF+.15;


}

// Initialize synaptic weights
void inizilizeW()
{
    for (int i = 0; i < cc; i++)
    {
        for (int j = 0; j < cc; j++)
        {
            if (i == j)
                w[i][j] = 0.0;
            else
                w[i][j] =(rand() % 300 / 1000.0)*maxW; // Small random weights
        }
    }
}

// Initialize neuron states, latencies, and currents
void inizilizeL()
{
    for (int i = 0; i < cc; i++)
    {

        LstChang[i] = 0.0;
        NSV[i] = 0.0;

        // Set different background currents for "active" vs "inactive" neurons
        if (i < nActive)
        {
            perturbedInCurrent[i] =inputEqCurrent[i] =(1.1+((rand()%120)/1000.0)) / R_M ; // Suprathreshold current for faster firing
        }
        else
        {
            perturbedInCurrent[i] =inputEqCurrent[i] =(1.02+((rand()%120)/1000.0)) / R_M ; // Weaker suprathreshold current for slower firing
            perturbedInCurrent[i] =inputEqCurrent[i] =(1.02 / R_M) ; // Weaker suprathreshold current for slower firing
        }
        for (int j = 0; j < cc; j++)
        {
            Ev[i][j].clear();
            pEv[i][j].clear();
            if (i == j)
            {
                // Kickstart the simulation with an initial firing event
                long double initial_period = timToFire(i,0.0);
                if(initial_period > 0)
                {
                    cout<<(rand() % 1000) / 1000.0 * initial_period<<endl;
                    Ev[i][j].push_back( (rand() % 1000) / 1000.0 * initial_period );
                    pEv[i][j].push_back(  -Ev[i][j].front());
                }
            }
            else
            {
                L[j][i] = ((rand() % 1000) / 1000.0)*tDecay*2 + 0.01; // Set random latencies
            }
        }
    }
}
void Reset()
{
        for (int i = 0; i < cc; i++)
    {

        LstChang[i] = 0.0;
        NSV[i] = 0.0;

        for (int j = 0; j < cc; j++)
        {
            Ev[i][j].clear();
            pEv[i][j].clear();
            if (i == j)
            {
                // Kickstart the simulation with an initial firing event
                long double initial_period = timToFire(i,0.0);
                if(initial_period > 0)
                {
                    cout<<(rand() % 1000) / 1000.0 * initial_period<<endl;
                    Ev[i][j].push_back(t+ (rand() % 1000) / 1000.0 * initial_period );
                    pEv[i][j].push_back( t -Ev[i][j].front());
                }
            }
            else
            {
                //L[j][i] = ((rand() % 1000) / 1000.0)*tDecay*2 + 0.01; // Set random latencies
                 Ev[i][j].clear();
                pEv[i][j].clear();
            }
        }
    }


}


// --- Main Program and Utility Functions ---
int main()
{
    int i, j;
    int ransead = time(NULL);
    srand(ransead);
    srand(1761044228);
    inizilizeW();
    inizilizeL();


    ofs.open("../../results/figure 5/figure5a.neuron", std::ofstream::out | ios::binary);
    ofs.write((char*)&cc, sizeof(int));

    cout.setf(ios::fixed);
    cout.setf(ios::showpoint);
    cout.precision(4);
    printW();

    // Main event loop
    for (long q = 0; q <= 40000000; q++)
    {
        //if(t/1000.0>1200) break;
        t = getNextEvent(i,j);
        if(q>39000000)
        save(i, j);
        if(q%2000000==0)cout<<q<<endl;
        if (i == j)
            fir(i);    // It's a firing event
        else
            recive(i, j); // It's a spike reception event
    }


    printW();



    cout << "\nRandom seed: " << ransead << endl;
    cout << "Simulation finished at t = " << t << endl;
    ofs.close();
    return 0;
}

// Print weights and latencies to console
void printW()
{
    cout << "\n--- Weights (W) || Latencies (L) ---\n";
    for(int y=0; y<cc; y++)
    {
        for (int x=0; x<cc; x++)
            cout << w[y][x] << " ";
        cout << "|| ";
        for (int x=0; x<cc; x++)
            cout << L[y][x] << " ";
        cout << endl;
    }
}

// Save firing events to a binary file for later visualization


void save (int i, int j)
{
    double x=t, y;
    {
        if(i==j)
        {
            ofs.write((char*)&x,sizeof(double));
            ofs.write((char*)&i,sizeof(int));
            ofs.write((char*)&j,sizeof(int));
            ofs.write((char*)&FIR,sizeof(double));
        }
        else
        {
            y= (w[j][i]/maxW*-.5)-.5;
            ofs.write((char*)&x,sizeof(double));
            ofs.write((char*)&i,sizeof(int));
            ofs.write((char*)&j,sizeof(int));
            ofs.write((char*)&y,sizeof(double));
        }

    }
}
