function validate_config(cfg)
%VALIDATECONFIG Validate simulation configuration parameters.

mu = log2(cfg.carrier.subcarrierSpacingKHz / 15);
if abs(mu - round(mu)) > 1e-9
    error("toolbox:InvalidSCS", "Subcarrier spacing must be 15 * 2^mu kHz.");
end

if cfg.simulation.numTransportBlocks <= 0
    error("toolbox:InvalidSimulation", "numTransportBlocks must be positive.");
end

if cfg.pdsch.numLayers < 1 || cfg.pdsch.numLayers > 4
    error("toolbox:InvalidLayers", ...
        "This baseline supports 1 to 4 layers (single codeword) only.");
end

if cfg.mimo.numTransmitAntennas < 1 ...
        || mod(cfg.mimo.numTransmitAntennas, 1) ~= 0
    error("toolbox:InvalidTxAntennas", ...
        "mimo.numTransmitAntennas must be a positive integer.");
end

if cfg.mimo.numTransmitAntennas < cfg.pdsch.numLayers
    error("toolbox:InvalidMIMORank", ...
        "numTransmitAntennas must be at least the number of layers.");
end

precoding_mode = lower(char(string(cfg.mimo.precodingMode)));
if ~ismember(precoding_mode, {'none', 'openloop'})
    error("toolbox:InvalidPrecodingMode", ...
        "Unsupported mimo.precodingMode '%s'.", cfg.mimo.precodingMode);
end

if strcmp(precoding_mode, 'none') ...
        && cfg.mimo.numTransmitAntennas ~= cfg.pdsch.numLayers
    error("toolbox:InvalidIdentityPrecoding", ...
        "With precodingMode = 'none', numTransmitAntennas must equal numLayers.");
end

if isempty(cfg.pdsch.prbSet)
    error("toolbox:InvalidPRBSet", "PRB allocation must not be empty.");
end

if any(cfg.pdsch.prbSet < 0) || any(cfg.pdsch.prbSet >= cfg.carrier.nSizeGrid)
    error("toolbox:InvalidPRBSet", ...
        "PRB allocation must stay within the configured carrier grid.");
end

if cfg.pdsch.rv < 0 || cfg.pdsch.rv > 3 || mod(cfg.pdsch.rv, 1) ~= 0
    error("toolbox:InvalidRV", "rv must be an integer between 0 and 3.");
end

if cfg.channel.numReceiveAntennas < 1
    error("toolbox:InvalidRxAntennas", "numReceiveAntennas must be positive.");
end

if cfg.channel.maximumDopplerHz < 0
    error("toolbox:InvalidDoppler", "maximumDopplerHz must be nonnegative.");
end

if ~ismember(lower(string(cfg.receiver.channelEstimation)), ["perfect"])
    error("toolbox:UnsupportedChannelEstimation", ...
        "channelEstimation must be 'perfect'.");
end

if ~ismember(lower(string(cfg.receiver.demapper)), ["mmse", "sphere"])
    error("toolbox:UnsupportedDemapper", ...
        "Demapper must be 'mmse' or 'sphere'.");
end

if cfg.receiver.maxLdpcIterations < 1
    error("toolbox:InvalidDecoder", ...
        "maxLdpcIterations must be at least 1.");
end

if cfg.shaping.nu < 0
    error("toolbox:InvalidShapingNu", "shaping.nu must be nonnegative.");
end

shaped_bit_level = cfg.shaping.numShapedAmplitudeBitLevelsPerDimension;
if mod(shaped_bit_level, 1) ~= 0 || shaped_bit_level < 0 || shaped_bit_level > 2
    error("toolbox:InvalidShapingLevels", ...
        "numShapedAmplitudeBitLevelsPerDimension must be 0, 1, or 2.");
end

% shaping.enabled is the single source of truth for PS. When PS is enabled the
% shaping depth must select at least one amplitude bit level; otherwise the
% config is invalid rather than silently degrading to uniform.
if isfield(cfg.shaping, 'enabled') && logical(cfg.shaping.enabled) ...
        && shaped_bit_level <= 0
    error("toolbox:InvalidShapingLevels", ...
        "Invalid value: shaping.enabled = true requires " + ...
        "numShapedAmplitudeBitLevelsPerDimension >= 1.");
end

if cfg.shaping.maxSupportedCodeBlocks < 1 ...
        || mod(cfg.shaping.maxSupportedCodeBlocks, 1) ~= 0
    error("toolbox:InvalidShapingCodeBlocks", ...
        "shaping.maxSupportedCodeBlocks must be a positive integer.");
end

if isfield(cfg.shaping, 'enabled') && logical(cfg.shaping.enabled) ...
        && ~strcmpi(char(string(cfg.shaping.mode)), 'ess')
    error("toolbox:UnsupportedShapingMode", ...
        "The active PS path supports shaping.mode = 'ess' only.");
end

tx_scaling = lower(string(cfg.shaping.txScaling));
if ~ismember(tx_scaling, ["empirical", "lut"])
    error("toolbox:UnsupportedPsTxScaling", ...
        "shaping.txScaling must be 'empirical' or 'lut'.");
end

if cfg.shaping.ess.nMax < 1 || mod(cfg.shaping.ess.nMax, 1) ~= 0
    error("toolbox:InvalidEssNMax", ...
        "shaping.ess.nMax must be a positive integer.");
end

if cfg.shaping.ess.nMantissa < 1 || mod(cfg.shaping.ess.nMantissa, 1) ~= 0
    error("toolbox:InvalidEssMantissa", ...
        "shaping.ess.nMantissa must be a positive integer.");
end
end
