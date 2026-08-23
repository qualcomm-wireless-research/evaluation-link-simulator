function cfg = defaultConfig(user_cfg)
%DEFAULTCONFIG Baseline configuration for fixed-MCS DL PDSCH BLER.
%
%   CFG = DEFAULTCONFIG() returns the full baseline configuration.
%   CFG = DEFAULTCONFIG(USER_CFG) returns the baseline with USER_CFG fields
%   deep-merged on top, so callers can pass a partial struct and have every
%   missing field filled with its default. This is the single source of truth
%   for configuration defaults.
%
%   Field-name convention: configuration leaf fields use lowerCamelCase
%   (e.g. nCellId, rnti, nId, numReceiveAntennas). These intentionally differ
%   from the MATLAB 5G Toolbox object properties (carrier.NCellID, pdsch.RNTI,
%   pdsch.NID), which use PascalCase; build_link_objects.m maps cfg fields onto
%   the NR objects.

cfg.simulation.snrDb = -6:2:18;
cfg.simulation.numTransportBlocks = 200;
cfg.simulation.rngSeed = 0;
cfg.simulation.verbose = true;
cfg.simulation.maxNumTransmissions = 1;   % HARQ transmissions, per TB (1 = no retransmission)
cfg.simulation.warmupSlots = 0;   % slots run before measurement start: channel evolves and closed-loop CSI reports/precoder selection run, but nothing is counted toward BLER/throughput
cfg.simulation.nErrors = 30;   % low-SNR early exit: if the first nErrors measured transport blocks all fail, declare BLER = 1 and move to the next SNR point (0 disables)

% AMC. Holds spectral efficiency constant and adapts only the modulation /
% code-rate split, by switching MCS TABLE at a fixed MCS index. Decided once per
% SNR point after a warmup phase, then held for that point; each point re-decides
% independently. Requires precodingMode open/closed-loop and rank > 1 to have a
% layer spread at all.
cfg.simulation.amc.enabled = false;
cfg.simulation.amc.warmupBlocks = 50;          % transport blocks used to measure per-layer SNR, per SNR point
cfg.simulation.amc.selector = "condition_number";       % only legal value

% The candidate menu is DERIVED, not listed: [<operating table>, highMcsTable...],
% so only the aggressive end is configured -- the robust end is whatever table the
% sim already transmits on. toolbox.amc.candidate_tables is the single derivation
% point; validate_config polices the result.
%   Uniform: pdsch.mcsTable = "qam256", highMcsTable = "qam1024". PS:
% shaping.mcsTable = "ps_mcs_table2", highMcsTable = "ps_mcs_table3". "qam64" has
% no SpEff-preserving companion and cannot be an AMC operating table.
cfg.simulation.amc.highMcsTable = [];   % aggressive end(s); scalar or vector; [] = unset, so enabling AMC errors

% Domain in which per-PRG per-layer MMSE SINR is reduced to one per-layer effective
% SNR. Orthogonal to the selector. "capacity" = mean log2(1+SINR_prg) over PRGs
% inverted back to dB, so a deep-faded PRG cannot be masked by a strong one.
cfg.simulation.amc.prgAveragingDomain = "capacity";  % only legal value

% Domain used to accumulate the already PRG-reduced per-layer SNR samples over
% AMC warmup time. "db" retains the legacy arithmetic dB mean; "capacity"
% averages log2(1+SINR) and converts that equivalent capacity back to dB.
cfg.simulation.amc.timeAveragingDomain = "capacity";

cfg.simulation.amc.conditionNumberThresholdDb = 16;      % L1-Lmin effective-SNR spread (dB) that triggers the table switch

cfg.carrier.nSizeGrid = 272;
cfg.carrier.subcarrierSpacingKHz = 30;
cfg.carrier.cyclicPrefix = 'normal';
cfg.carrier.nCellId = 1;

cfg.pdsch.mcsIndex = 10;
cfg.pdsch.mcsTable = "qam64";
cfg.pdsch.numLayers = 1;
cfg.pdsch.prbSet = 0:11;
cfg.pdsch.symbolAllocation = [0 14];
cfg.pdsch.mappingType = 'A';
cfg.pdsch.rnti = 1;
cfg.pdsch.nId = [];
cfg.pdsch.rv = [0 2 3 1];   % RV sequence for HARQ

cfg.pdsch.dmrs.configurationType = 1;
cfg.pdsch.dmrs.typeAPosition = 2;
cfg.pdsch.dmrs.length = 1;
cfg.pdsch.dmrs.additionalPosition = 0;
cfg.pdsch.dmrs.numCDMGroupsWithoutData = 2;

% TDL/CDL-common config
cfg.channel.model = "tdl";
cfg.channel.delayProfile = "TDL-C";
cfg.channel.delaySpread = 300e-9;
cfg.channel.maximumDopplerHz = 30;
cfg.channel.numReceiveAntennas = 2;
cfg.channel.normalizePathGains = true;
cfg.channel.normalizeOutputs = true;
cfg.channel.filter = "td"; % TD or FD channel filter

% CDL-specific config for channel (angle in GCS)
cfg.channel.carrierFrequency = 4e9; % Hz
cfg.channel.utDirectionOfTravel = [65; 90]; % [azimuth zenith] in degrees
cfg.channel.angleScaling = false;
cfg.channel.meanAngles = [0 0 0 0]; % [AoD AoA ZoD ZoA] in degrees
cfg.channel.transmitAntennaArray.size = [2 1 1 1 1]; % [M N P Mg Ng]
cfg.channel.transmitAntennaArray.elementSpacing = [0.5 0.5 1 1]; % [dV dH dgV dgH] in lambda
cfg.channel.transmitAntennaArray.polarizationAngles = [45 -45]; % degrees
cfg.channel.transmitAntennaArray.element = "38.901";
cfg.channel.transmitAntennaArray.polarizationModel = "Model-2";
cfg.channel.transmitArrayOrientation = [0; 10; 0]; % [bearing downtilt slant] in degrees
cfg.channel.receiveAntennaArray.size = [1 1 2 1 1];
cfg.channel.receiveAntennaArray.elementSpacing = [0.5 0.5 0.5 0.5];
cfg.channel.receiveAntennaArray.polarizationAngles = [0 90];
cfg.channel.receiveAntennaArray.element = "isotropic";
cfg.channel.receiveAntennaArray.polarizationModel = "Model-2";
cfg.channel.receiveArrayOrientation = [180; 0; 0];
cfg.channel.normalizeCDLChannel = false; % normalize antenna element/Tx analog BF gain
cfg.channel.numTimeSamples = 1000; % # time samples to compute scaling factor to normalize antenna element/Tx analog BF gain

% CDL-specific randomization config for channel (angle in GCS)
cfg.channel.randomizeUtDirectionOfTravel = false;
cfg.channel.randomUtDirectionOfTravel = [-180 180; 90 90]; % uniform random [azimuth zenith] lo/up in degrees
cfg.channel.randomizeMeanAngles = false;
cfg.channel.randomMeanAngles = [-60 60; -180 180; 97.2731 97.2731; 87.6845 87.6845]; % uniform random [AoD AoA ZoD ZoA] lo/up in degrees
cfg.channel.randomizeTransmitArrayOrientation = false;
cfg.channel.randomTransmitArrayOrientation = [0 0; 0 0; 0 0]; % uniform random [bearing downtilt slant] lo/up in degrees
cfg.channel.randomizeReceiveArrayOrientation = false;
cfg.channel.randomReceiveArrayOrientation = [-180 180; 0 0; 0 0];

% CDL-specific config for Tx analog BF (angle in GCS)
cfg.channel.analogBF.arraySize = [2 1]; % [m n], i.e., [Mp Np] (# chains) = [M N] (# AEs) ./ [m n]
cfg.channel.analogBF.direction = [0 100]; % [azimuth zenith] in degrees

% CDL-specific config Tx/Rx swap for UL, e.g., transmit/receiveAntennaArray, transmit/receiveArrayOrientation,
% departure/arrival angles in meanAngles, disable/enable Tx/Rx analog BF
cfg.channel.swapTransmitAndReceive = false;

cfg.receiver.channelEstimation = "perfect";
cfg.receiver.demapper = "mmse";              % Demapper: "mmse", "sphere", or "fast_sphere"
cfg.receiver.maxLdpcIterations = 20;
cfg.receiver.LDPCDecodingAlgorithm = 'Layered belief propagation'; %LBP decoder

% LLR magnitude clip applied after the sphere / fast-sphere tree-search
% decoders, capping soft LLRs to [-llrClipLimit, llrClipLimit] before LDPC
% decoding. At high SNR these reduced-complexity detectors can emit a few
% over-confident (and occasionally wrong-sign) LLRs whose magnitude grows
% ~1/n_var; clipping bounds their damage. Set to Inf to disable clipping.
cfg.receiver.llrClipLimit = 30;              % LLR clip magnitude A; LLRs capped to [-A, A] (Inf disables)


% Sphere decoder specific settings (only used when demapper = "sphere")
cfg.receiver.sphereAlgorithm = "full";       % "full" or "radius"
cfg.receiver.sphereRadius = [];              % Initial search radius for "radius" algorithm (empty = auto-determine)

% Fast-sphere decoder specific settings (only used when demapper = "fast_sphere")
cfg.receiver.fastSphereNCand = 8;            % Candidate list size per PAM level
cfg.receiver.fastSphereMaxList = 128;        % Max candidate list size for soft LLR computation
cfg.receiver.fastSphereUseQrAugmentation = true; % QR-augment with sqrt(N0)*I for MMSE regularisation (on by default)

cfg.mimo.precodingMode = "none";
cfg.mimo.numTransmitAntennas = 1;
cfg.mimo.openLoopPrecoder = "dft";
cfg.mimo.rankAdaptation = true;               % Closed-loop CDL adaptation for QAM256 and PS tables

% Closed-loop precoding (used when precodingMode = "closedloop"). The precoder
% is computed from genie CSI, per precoding RB group (PRG) via SVD of the
% comb-sparse, single-snapshot channel covariance R = sum(H'H), and reported
% back to the transmitter with a modeled periodicity and processing delay.
cfg.mimo.closedLoop.method = "svd";          % precoder computation: "svd"
cfg.mimo.closedLoop.subbandSize = 1;         % PRBs per precoding RB group (1 = per-PRB)
cfg.mimo.closedLoop.periodicitySlots = 1;    % CSI report period P (slots)
cfg.mimo.closedLoop.processingDelaySlots = 0;% feedback/processing delay D (slots)
cfg.mimo.closedLoop.warmupPrecoder = "dft";  % fallback before first valid report
cfg.mimo.closedLoop.combSize = 4;            % SRS frequency comb: sound every Nth SC (1 = all tones)
cfg.mimo.closedLoop.combOffset = 0;          % first sounded SC within the comb
cfg.mimo.closedLoop.csiSymbol = 1;           % OFDM symbol index used as the CSI snapshot (1-based)

cfg.shaping.enabled = false;
cfg.shaping.mode = "ess";
cfg.shaping.mcsTable = "ps_mcs_table1";
cfg.shaping.txScaling = "empirical";
cfg.shaping.nu = 0.0;
cfg.shaping.matchUniformTbs = false;
cfg.shaping.uniformMcsTable = "qam256";
cfg.shaping.tbsMatchToleranceFraction = 0.01;
cfg.shaping.tbsMatchMaxIterations = 24;
cfg.shaping.numShapedAmplitudeBitLevelsPerDimension = 0;
cfg.shaping.maxSupportedCodeBlocks = 1024;
cfg.shaping.ess.nMax = 128;
cfg.shaping.ess.nMantissa = 8;
cfg.shaping.ecc.nMax = 1024;
cfg.shaping.ecc.listSize = 1;

if nargin >= 1 && ~isempty(user_cfg)
    cfg = mergeConfig(cfg, user_cfg);
end

cfg.carrier.slotDurationMs = toolbox.phy.channel.get_slot_duration_ms(cfg.carrier.subcarrierSpacingKHz);
end

function base = mergeConfig(base, overlay)
%MERGECONFIG Deep-merge overlay struct fields onto base struct.

if ~isstruct(overlay)
    base = overlay;
    return;
end

fields = fieldnames(overlay);
for idx = 1:numel(fields)
    name = fields{idx};
    value = overlay.(name);
    if isfield(base, name) && isstruct(base.(name)) && isstruct(value) ...
            && isscalar(base.(name)) && isscalar(value)
        base.(name) = mergeConfig(base.(name), value);
    else
        base.(name) = value;
    end
end
end

