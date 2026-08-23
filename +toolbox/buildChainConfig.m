function cfg = buildChainConfig(cfg, chain_mode, chain_opts)
%BUILDCHAINCONFIG Apply chain-specific MCS table and shaping settings to CFG.
%
%   CFG = BUILDCHAINCONFIG(CFG, CHAIN_MODE, CHAIN_OPTS) configures CFG for one
%   sweep variant, given CHAIN_MODE in {"uniform", "ps", "ess", "ecc"} ("ps"
%   and "ess" are equivalent labels for the ESS-shaped PS chain). CHAIN_OPTS
%   is a struct with fields:
%     uniformMcsTable      - MCS table for the uniform chain (e.g. "qam256")
%     psMcsTable            - MCS table shared by the ESS/ECC PS chains
%     numShapedBitLevel     - shaped amplitude bit levels per dimension
%     txScaling             - PS TX power scaling for ESS: "empirical" or "lut"
%                             (ECC always forces "empirical")
%     matchPsTbsToUniform   - match PS payload TBS to the uniform chain
%

switch lower(string(chain_mode))
    case "uniform"
        cfg.pdsch.mcsTable = chain_opts.uniformMcsTable;
        cfg.shaping.enabled = false;
        cfg.shaping.numShapedAmplitudeBitLevelsPerDimension = 0;
    case {"ps", "ess"}
        cfg.pdsch.mcsTable = chain_opts.psMcsTable;
        cfg.shaping.enabled = true;
        cfg.shaping.mode = "ess";
        cfg.shaping.mcsTable = chain_opts.psMcsTable;
        cfg.shaping.numShapedAmplitudeBitLevelsPerDimension = chain_opts.numShapedBitLevel;
        cfg.shaping.txScaling = chain_opts.txScaling;
        cfg.shaping.matchUniformTbs = logical(chain_opts.matchPsTbsToUniform);
        cfg.shaping.uniformMcsTable = chain_opts.uniformMcsTable;
    case "ecc"
        cfg.pdsch.mcsTable = chain_opts.psMcsTable;
        cfg.shaping.enabled = true;
        cfg.shaping.mode = "ecc";
        cfg.shaping.mcsTable = chain_opts.psMcsTable;
        cfg.shaping.numShapedAmplitudeBitLevelsPerDimension = chain_opts.numShapedBitLevel;
        % ECC has no LUT scaling table -- validate_config.m requires
        % "empirical" whenever mode='ecc'.
        cfg.shaping.txScaling = "empirical";
        cfg.shaping.matchUniformTbs = logical(chain_opts.matchPsTbsToUniform);
        cfg.shaping.uniformMcsTable = chain_opts.uniformMcsTable;
    otherwise
        error("toolbox:UnknownChain", "Unsupported chain mode: %s", char(chain_mode));
end
end
