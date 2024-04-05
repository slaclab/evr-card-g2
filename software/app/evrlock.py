import argparse
import numpy as np
import matplotlib.pyplot as plt

def main():
    
    parser = argparse.ArgumentParser(description='Timing analysis plots')
    parser.add_argument('--file', help='data file', default='evrlock.dat')
    parser.add_argument('--ps_per_step', help='pS per step', type=float, default=15.)
    parser.add_argument('--ps_per_clk' , help='pS per clk' , default=8.4e-3)
    parser.add_argument('--ps_per_ph'  , help='pS per ph'  , default=7.e6)
    args = parser.parse_args()

    index  = []
    clks   = []
    phase  = []
    phaseN = []
    valid  = []
    with open(args.file,"r") as f:
        for l in f.readlines():
            w = l.split()
            if len(w) >4:
                #index .append(float(w[0][:-1])*0.015*50) # ns
                index .append(float(w[0][:-1]))
                clks  .append(int(w[1]))
                # 27 bit integers
                def int27(u):
                    if (u & 1<<26):
                        u -= (1<<27)
                    return float(u)
                phase .append(int27(int(w[2]))/float(w[4]))
                phaseN.append(int27(int(w[3]))/float(w[4]))

    if False:
        phasefit  = np.polyfit(index[400:] ,phase[400:] ,1)
        phasenfit = np.polyfit(index[:2500],phaseN[:2500],1)
        clksfit   = np.polyfit(index[400:] ,clks[400:]  ,1)

        print(f'phasefit {phasefit}')
        print(f'phasenfit {phasenfit}')
        print(f'clksfit {clksfit}')

    aindex = np.array(index )*args.ps_per_step
    aph    = np.array(phase )*args.ps_per_ph
    aphN   = np.array(phaseN)*args.ps_per_ph
    aclks  = np.array(clks  )*args.ps_per_clk

    #  Result is
    #  phase(N)/index = -1.0718576e-4
    #  clks    /index = -0.08928598
    #  clks  = 119 MHz
    #  index = 15 ps/step; 750 ps/index
    plt.subplot(311)
    plt.plot(aindex,aph-np.mean(aph),aindex,aphN-np.mean(aphN))
    plt.grid()
    plt.subplot(312)
    plt.plot(aindex,aclks)
    plt.subplot(313)
    plt.hist(phase,bins='auto')
#    plt.plot(index,clks,index,phase)
    plt.show()


if __name__ == '__main__':
    main()
