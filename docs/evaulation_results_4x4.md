# PS vs Uniform QAM Performance Study: 4Tx4Rx

## 1. Evaulation methdology 

Link-level simulations are run with 40 random seeds, each simulating 200 slots. 

The BLER used in the SNR @ 10% BLER results (Section 2) is the average BLER across the random seeds.

For the throughput vs SNR plots in Section 3, at each SNR the throughput for a given seed is taken as the maximum achieved across all simulated (MCS, rank) at that SNR (i.e. the seed always picks its best MCS, rank combination), then averaged over seeds. This models a system that adapts both MCS and rank.

The matlab scenario files used to generate the evaulation results in this report can be found in ./tests/scenarios/3GPP_eval_scenarios. 

## 2. SNR @ 10% BLER vs MCS index

SNR (dB) at which the seed-averaged BLER crosses 10%. 

### CDL-A rank 2

![SNRvsMCS CDL-A rank 2](figs_4x4/001_SNRvsMCS_CDL-A_rank_2.png)

### CDL-A rank 3

![SNRvsMCS CDL-A rank 3](figs_4x4/002_SNRvsMCS_CDL-A_rank_3.png)

### CDL-A rank 4

![SNRvsMCS CDL-A rank 4](figs_4x4/003_SNRvsMCS_CDL-A_rank_4.png)

### CDL-C rank 3

![SNRvsMCS CDL-C rank 3](figs_4x4/004_SNRvsMCS_CDL-C_rank_3.png)

### CDL-C rank 4

![SNRvsMCS CDL-C rank 4](figs_4x4/005_SNRvsMCS_CDL-C_rank_4.png)


### CDL-B rank 4

![SNRvsMCS CDL-B rank 4 (closed-loop)](figs_4x4/006_SNRvsMCS_CDL-B_rank_4.png)

### TDL-A rank 4 open-loop (11 Hz Doppler, PS mcs_table1)

![SNRvsMCS TDL-A rank 4 open-loop (11 Hz Doppler, PS mcs_table1)](figs_4x4/007_SNRvsMCS_TDL-A_rank_4_open-loop.png)


## 3. Max-over-(MCS & rank) throughput vs SNR (seed-averaged)

For each seed and SNR, throughput is maximized over all available MCS and all ranks of the channel, then averaged over seeds. Models a system that adapts both MCS and rank. For CDL-A, the results are based on radaption over ranks 2,3,4; For CDL-B and TDL-A (open-loop), it has a single rank (i.e., rank 4). For CDL-C, adaptation is over rank 3 and rank 4.

### CDL-A (ranks 2, 3, 4)

![XR-TPUT CDL-A](figs_4x4/008_TPUT_CDL-A_with_inset.png)

### CDL-B (ranks 4)

![XR-TPUT CDL-B](figs_4x4/009_TUPT_CDL-B_with_inset.png)

### CDL-C (ranks 3, 4)

![XR-TPUT CDL-C](figs_4x4/010_TUPT_CDL-C_with_inset.png)

### TDL-A (open-loop, ranks 4)

![XR-TPUT TDL-A](figs_4x4/011_TPUT_TDL_A.png)
