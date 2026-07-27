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

cfg.carrier.nSizeGrid = 52;
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

cfg.channel.model = "tdl";
cfg.channel.delayProfile = "TDL-C";
cfg.channel.delaySpread = 300e-9;
cfg.channel.maximumDopplerHz = 30;
cfg.channel.numReceiveAntennas = 2;
cfg.channel.normalizePathGains = true;
cfg.channel.normalizeOutputs = true;

cfg.receiver.channelEstimation = "perfect";
cfg.receiver.demapper = "mmse";              % Demapper: "mmse" or "sphere"
cfg.receiver.maxLdpcIterations = 20;
cfg.receiver.LDPCDecodingAlgorithm = 'Layered belief propagation'; %LBP decoder


% Sphere decoder specific settings (only used when demapper = "sphere")
cfg.receiver.sphereAlgorithm = "full";       % "full" or "radius"
cfg.receiver.sphereRadius = [];              % Initial search radius for "radius" algorithm (empty = auto-determine)

cfg.mimo.precodingMode = "none";
cfg.mimo.numTransmitAntennas = 1;
cfg.mimo.openLoopPrecoder = "dft";

cfg.shaping.enabled = false;
cfg.shaping.mode = "ess";
cfg.shaping.mcsTable = "ps_mcs_table1";
cfg.shaping.useMcsTableNu = true;
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

