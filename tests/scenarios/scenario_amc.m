function params = scenario_amc()
%SCENARIO_AMC AMC comparison over CDL-A 32x4 closed loop.
%   PARAMS = SCENARIO_AMC() returns the scenario parameters consumed by
%   toolbox.loadScenario. Two arms enable AMC; the three arms are
%     (a) uniform baseline, no AMC            qam256
%     (b) Uniform QAM AMC                     qam256 -> qam1024
%     (c) PS AMC                              ps_mcs_table2 -> ps_mcs_table3

%% USER SETTINGS
mcs_index = 19;                       % shared operating MCS index (>= 14; ps_mcs_table3 covers 14-27)
snr_db = 10:1:24;                      % SNR sweep grid in dB
num_transport_blocks = 200;           % MEASURED transport blocks per SNR point
rng_seed = 33;                        % single RNG seed for repeatable runs

% 32-TxRU x 4-Rx CDL-A geometry: transmit array [2,8,2,1,1] prod=32 AEs
% receive [1,2,2,1,1] prod=4.
num_tx_antennas = 32;                 % transmit antennas (TxRU)
num_rx_antennas = 4;                  % receive antennas
num_pdsch_layers = 3;                 % PDSCH layers (rank > 1 needed for a layer spread)
tx_array_size = [2 8 2 1 1];          % [M N P Mg Ng]
tx_array_element_spacing = [0.5 0.5 1 1];
tx_array_pol_angles = [-45 45];
analog_bf_array_size = [1 1];         
analog_bf_direction = [0 90];         % [azimuth zenith] in degrees
rx_array_size = [1 2 2 1 1];          % prod = 4
rx_array_element_spacing = [0.5 0.5 0.5 0.5];
rx_array_pol_angles = [0 90];

prb_set = 0:23;                        % allocated PRBs (0:23 = 24 RB)
pdsch_symbol_allocation = [0 12];      % [start symbol, num symbols] within the slot

cdl_delay_spread = 100e-9;            % CDL RMS delay spread in seconds
maximum_doppler_hz = 11;              % maximum Doppler shift in Hz
channel_filter = "fd";   
receiver_demapper = "fast_sphere";           

max_ldpc_iterations = 25;             % LDPC decoder iteration cap

uniform_mcs_table = "qam256";        
uniform_high_table = "qam1024";       
ps_static_table = "ps_mcs_table2";    
ps_high_table = "ps_mcs_table3";      
num_shaped_bit_level = 2;             % shaped amplitude bit levels per dimension
ps_tx_scaling = "lut";                % PS TX power scaling: "empirical" or "lut"

cl_subband_size = 4;                  % closed-loop PRG size (PRBs per group); also the AMC SINR measurement axis
cl_periodicity = 40;                   % CSI report periodicity (slots)
cl_delay = 8;                         % feedback/processing delay (slots); < warmup_blocks so valid warmup blocks remain

warmup_blocks = 50;                   
threshold_db = 18.0;           
prg_averaging_domain = "capacity";    

make_plots = true;                   
output_root = fullfile("results", "amc");  

%% SHARED CDL-A CLOSED-LOOP CONFIG

base_cfg.simulation.snrDb = snr_db;
base_cfg.simulation.numTransportBlocks = num_transport_blocks;
base_cfg.simulation.rngSeed = rng_seed;
base_cfg.simulation.warmupSlots = warmup_blocks;
base_cfg.simulation.nErrors = 100;

base_cfg.pdsch.numLayers = num_pdsch_layers;
base_cfg.pdsch.prbSet = prb_set;
base_cfg.pdsch.symbolAllocation = pdsch_symbol_allocation;
base_cfg.pdsch.rv = 0;               
base_cfg.pdsch.mcsIndex = mcs_index;

base_cfg.channel.model = "cdl";
base_cfg.channel.filter = channel_filter;
base_cfg.channel.delayProfile = "CDL-A";
base_cfg.channel.delaySpread = cdl_delay_spread;
base_cfg.channel.maximumDopplerHz = maximum_doppler_hz;
base_cfg.channel.numReceiveAntennas = num_rx_antennas;
base_cfg.channel.normalizePathGains = true;
base_cfg.channel.normalizeOutputs = true;
base_cfg.channel.normalizeCDLChannel = true;   % normalize antenna-element/analog-BF gain (launcher: 1)
base_cfg.channel.carrierFrequency = 4e9; % Hz
base_cfg.channel.utDirectionOfTravel = [65; 90]; % [azimuth zenith] in degrees
base_cfg.channel.angleScaling = true;          % required for meanAngles randomization to take effect (launcher: 1)
base_cfg.channel.meanAngles = [0 0 0 0];       % [AoD AoA ZoD ZoA] in degrees

% Transmit array:  32 TxRU, directional 38.901.
base_cfg.channel.transmitAntennaArray.size = tx_array_size; % [M N P Mg Ng]
base_cfg.channel.transmitAntennaArray.elementSpacing = tx_array_element_spacing; % [dV dH dgV dgH] in lambda
base_cfg.channel.transmitAntennaArray.polarizationAngles = tx_array_pol_angles; % degrees
base_cfg.channel.transmitAntennaArray.element = "38.901";
base_cfg.channel.transmitAntennaArray.polarizationModel = "Model-1"; % launcher: Model-1 (default is Model-2)
base_cfg.channel.transmitArrayOrientation = [0; 0; 0];  % [bearing downtilt slant]; launcher: no downtilt (default is [0;10;0])

% Receive array: 4 isotropic AEs.
base_cfg.channel.receiveAntennaArray.size = rx_array_size;
base_cfg.channel.receiveAntennaArray.elementSpacing = rx_array_element_spacing;
base_cfg.channel.receiveAntennaArray.polarizationAngles = rx_array_pol_angles;
base_cfg.channel.receiveAntennaArray.element = "isotropic";
base_cfg.channel.receiveAntennaArray.polarizationModel = "Model-1"; % launcher: Model-1 (default is Model-2)
base_cfg.channel.receiveArrayOrientation = [180; 0; 0];

% Per-seed CDL angle randomization.
base_cfg.channel.randomizeUtDirectionOfTravel = true;
base_cfg.channel.randomUtDirectionOfTravel = [-180 180; 90 90];
base_cfg.channel.randomizeMeanAngles = true;
base_cfg.channel.randomMeanAngles = [-60 60; -180 180; 97.2731 97.2731; 87.6845 87.6845];
base_cfg.channel.randomizeTransmitArrayOrientation = false;
base_cfg.channel.randomTransmitArrayOrientation = [0 0; 0 0; 0 0];
base_cfg.channel.randomizeReceiveArrayOrientation = true;
base_cfg.channel.randomReceiveArrayOrientation = [-180 180; 0 0; 0 0];

base_cfg.channel.analogBF.arraySize = analog_bf_array_size; % [m n] (# chains) = [M N] (# AEs) ./ [m n]
base_cfg.channel.analogBF.direction = analog_bf_direction; % [azimuth zenith] in degrees

base_cfg.receiver.channelEstimation = "perfect";
base_cfg.receiver.demapper = receiver_demapper;
base_cfg.receiver.maxLdpcIterations = max_ldpc_iterations;
base_cfg.receiver.fastSphereNCand = 32;   % candidates per PAM level (default 8 too small for 256QAM x 3 layers)
base_cfg.receiver.fastSphereMaxList = 128;

base_cfg.mimo.numTransmitAntennas = num_tx_antennas;
base_cfg.mimo.precodingMode = "closedloop";
base_cfg.mimo.closedLoop.method = "svd";
base_cfg.mimo.closedLoop.subbandSize = cl_subband_size;
base_cfg.mimo.closedLoop.periodicitySlots = cl_periodicity;
base_cfg.mimo.closedLoop.processingDelaySlots = cl_delay;
base_cfg.mimo.closedLoop.warmupPrecoder = "identity";
base_cfg.mimo.rankAdaptation = false;

%% BUILD SWEEP VARIANTS
variants = struct('label', {}, 'cfgOverlay', {});

% (a) uniform baseline, no AMC.
uni_cfg = base_cfg;
uni_cfg.pdsch.mcsTable = uniform_mcs_table;
uni_cfg.shaping.enabled = false;
uni_cfg.shaping.numShapedAmplitudeBitLevelsPerDimension = 0;
uni_cfg.simulation.amc.enabled = false;
variants(end + 1) = struct('label', "uniform", 'cfgOverlay', uni_cfg); 

% (b) Uniform QAM AMC (qam256 -> qam1024). Same chain as (a) plus the
% selector, so it is measurable as a gain over (a).
uni_amc_cfg = uni_cfg;
uni_amc_cfg.simulation.amc.enabled = true;
uni_amc_cfg.simulation.amc.warmupBlocks = warmup_blocks;
uni_amc_cfg.simulation.amc.selector = "condition_number";
uni_amc_cfg.simulation.amc.prgAveragingDomain = prg_averaging_domain;
uni_amc_cfg.simulation.amc.highMcsTable = uniform_high_table;
uni_amc_cfg.simulation.amc.conditionNumberThresholdDb = threshold_db;
variants(end + 1) = struct('label', "Uniform QAM AMC", 'cfgOverlay', uni_amc_cfg); 

% PS chain config, used only as the base for (c). 
ps_cfg = base_cfg;
ps_cfg.pdsch.mcsTable = ps_static_table;
ps_cfg.shaping.enabled = true;
ps_cfg.shaping.mode = "ess";
ps_cfg.shaping.mcsTable = ps_static_table;
ps_cfg.shaping.numShapedAmplitudeBitLevelsPerDimension = num_shaped_bit_level;
ps_cfg.shaping.txScaling = ps_tx_scaling;
ps_cfg.shaping.matchUniformTbs = true;
ps_cfg.shaping.uniformMcsTable = uniform_mcs_table;
ps_cfg.simulation.amc.enabled = false;

% (c) PS AMC.
ps_amc_cfg = ps_cfg;
ps_amc_cfg.simulation.amc.enabled = true;
ps_amc_cfg.simulation.amc.warmupBlocks = warmup_blocks;
ps_amc_cfg.simulation.amc.selector = "condition_number";
ps_amc_cfg.simulation.amc.prgAveragingDomain = prg_averaging_domain;
ps_amc_cfg.simulation.amc.highMcsTable = ps_high_table;
ps_amc_cfg.simulation.amc.conditionNumberThresholdDb = threshold_db;
variants(end + 1) = struct('label', "PS AMC", 'cfgOverlay', ps_amc_cfg);

%% SCENARIO METADATA
params = struct();
params.scenarioPrefix = "cdla_amc_32tx4rx_mcs" + string(mcs_index);
params.scenarioTitle = "CDL-A AMC 32x4 (MCS " + string(mcs_index) + ")";
params.outputRoot = output_root;
params.makePlots = make_plots;
params.plotSnrGain = false;   

params.variants = variants;
end
