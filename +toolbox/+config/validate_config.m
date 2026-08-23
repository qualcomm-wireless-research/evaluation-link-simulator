function validate_config(cfg)
%VALIDATECONFIG Validate simulation configuration parameters.

mu = log2(cfg.carrier.subcarrierSpacingKHz / 15);
if abs(mu - round(mu)) > 1e-9
    error("toolbox:InvalidSCS", "Subcarrier spacing must be 15 * 2^mu kHz.");
end

if cfg.simulation.numTransportBlocks <= 0
    error("toolbox:InvalidSimulation", "numTransportBlocks must be positive.");
end

if cfg.simulation.maxNumTransmissions < 1 ...
        || mod(cfg.simulation.maxNumTransmissions, 1) ~= 0
    error("toolbox:InvalidMaxNumTransmissions", ...
        "maxNumTransmissions must be a positive integer.");
end

if cfg.simulation.warmupSlots < 0 || mod(cfg.simulation.warmupSlots, 1) ~= 0
    error("toolbox:InvalidWarmupSlots", ...
        "simulation.warmupSlots must be a nonnegative integer.");
end

fse = cfg.simulation.amc;
if logical(fse.enabled)
    if fse.warmupBlocks < 1 || mod(fse.warmupBlocks, 1) ~= 0
        error("toolbox:InvalidAmcWarmup", ...
            "simulation.amc.warmupBlocks must be a positive integer.");
    end
    precoding_mode_fse = lower(char(string(cfg.mimo.precodingMode)));
    if strcmp(precoding_mode_fse, 'none')
        error("toolbox:IncompatibleAmcPrecoding", ...
            "AMC requires precodingMode 'openloop' or 'closedloop', not 'none'.");
    end
    if cfg.pdsch.numLayers < 3
        error("toolbox:IncompatibleAmcRank", ...
            "AMC requires pdsch.numLayers >= 3 (got %d); the layer-spread " + ...
            "metric is degenerate at lower rank.", cfg.pdsch.numLayers);
    end
    % apply_rank_adaptation runs AFTER this validator and can lower numLayers,
    % rewrite mcsIndex and clear shaping.enabled -- invalidating every guard in
    % this block. Require it off rather than re-validating afterwards.
    if cfg.mimo.rankAdaptation
        error("toolbox:IncompatibleAmcRankAdaptation", ...
            "AMC requires mimo.rankAdaptation = false; rank adaptation can " + ...
            "change numLayers, mcsIndex and shaping.enabled underneath the " + ...
            "AMC guards.");
    end
    % The table is decided after retransmission bookkeeping is fixed, so a
    % retransmission would be reported on the baseline table but sent on the
    % switched one.
    if cfg.simulation.maxNumTransmissions > 1
        error("toolbox:IncompatibleAmcHarq", ...
            "AMC requires HARQ disabled (simulation.maxNumTransmissions == 1, " + ...
            "got %d).", cfg.simulation.maxNumTransmissions);
    end
    valid_selectors = {'condition_number'};
    if isfield(fse, 'selector')
        selector = lower(char(string(fse.selector)));
        if ~ismember(selector, valid_selectors)
            error("toolbox:InvalidAmcSelector", ...
                "simulation.amc.selector must be one of: %s.", ...
                strjoin(valid_selectors, ', '));
        end
        % Candidate tables must belong to the active path: ps_* when shaping is
        % on, qam* when off.
        shaping_on = isfield(cfg, 'shaping') && isfield(cfg.shaping, 'enabled') ...
            && logical(cfg.shaping.enabled);
        if shaping_on
            operating_field = 'shaping.mcsTable';
        else
            operating_field = 'pdsch.mcsTable';
        end
        is_ps_table = @(t) startsWith(lower(strtrim(string(t))), "ps_");
        is_uniform_table = @(t) startsWith(lower(strtrim(string(t))), "qam");
        % Derived via toolbox.amc.candidate_tables -- the same call amc.configure
        % makes, so the validated menu cannot drift from the one that runs.
        if isempty(fse.highMcsTable)
            error("toolbox:InvalidAmcHighMcsTable", ...
                ['simulation.amc.highMcsTable must name at least one MCS ', ...
                 'table to enable AMC (it is [] by default). The candidate ', ...
                 'menu is derived as [<operating table>, highMcsTable...], so ', ...
                 'only the aggressive end is configured -- the robust end is ', ...
                 'the table the sim transmits on (%s).\n', ...
                 'Uniform: pdsch.mcsTable = "qam256", highMcsTable = "qam1024". ', ...
                 'PS: shaping.mcsTable = "ps_mcs_table2", highMcsTable = ', ...
                 '"ps_mcs_table3".'], ...
                 operating_field);
        end
        cand_tables = toolbox.amc.candidate_tables(cfg, shaping_on);
        if shaping_on
            if ~all(arrayfun(is_ps_table, cand_tables))
                error("toolbox:IncompatibleAmcSelector", ...
                    ['the AMC candidate menu must be all ', ...
                     'probabilistic-shaping tables (ps_*) when shaping.enabled ', ...
                     '= true; derived menu [shaping.mcsTable, highMcsTable...] ', ...
                     'is: %s.'], strjoin(cellstr(cand_tables), ', '));
            end
        else
            if ~all(arrayfun(is_uniform_table, cand_tables))
                error("toolbox:IncompatibleAmcSelector", ...
                    ['the AMC candidate menu must be all ', ...
                     'uniform-QAM tables (qam*) when shaping.enabled = false; ', ...
                     'derived menu [pdsch.mcsTable, highMcsTable...] is: %s.'], ...
                    strjoin(cellstr(cand_tables), ', '));
            end
        end
        % The path checks are prefix-only, so a typo like "ps_mcs_tabel3" passes
        % them; resolve each candidate here rather than failing mid-warmup.
        for ti = 1:numel(cand_tables)
            try
                toolbox.getMcsInfo(cfg.pdsch.mcsIndex, cand_tables(ti));
            catch ME
                error("toolbox:InvalidAmcCandidateTable", ...
                    ['AMC candidate table "%s" ', ...
                     'is not a resolvable MCS table (%s).'], ...
                    cand_tables(ti), ME.message);
            end
        end
        % Relative tol 1e-3: the shipped SpEff-preserving tables agree only to
        % tabulation rounding (worst ~9e-05 relative) while a genuine SpEff
        % difference is >1%. An exact comparison would reject qam256 -> qam1024,
        % the pair the mechanism is built on.
        speff_rel_tol = 1e-3;
        ref_row = toolbox.getMcsInfo(cfg.pdsch.mcsIndex, cand_tables(1));
        ref_speff = ref_row.spectralEfficiency;
        for ti = 2:numel(cand_tables)
            cand_row = toolbox.getMcsInfo(cfg.pdsch.mcsIndex, cand_tables(ti));
            cand_speff = cand_row.spectralEfficiency;
            if abs(cand_speff - ref_speff) > speff_rel_tol * max(abs(ref_speff), realmin)
                base_msg = ['every simulation.amc.highMcsTable entry must carry ', ...
                    'the SAME spectral efficiency as the operating table at the ', ...
                    'operating MCS index (%d), so the AMC switch preserves SpEff ', ...
                    'and TBS. Operating table %s = "%s" is %.4f bits/symbol but ', ...
                    'highMcsTable entry %d ("%s") is %.4f -- a %.1f%% change, ', ...
                    'which would alter TBSize_bits and invalidate any comparison ', ...
                    'against a matched no-AMC baseline.\n'];
                if ~shaping_on && strcmpi(strtrim(char(cand_tables(1))), 'qam64')
                    fix_msg = ['"qam64" has NO SpEff-preserving companion table, ', ...
                        'so it cannot be an AMC operating table. Set ', ...
                        'pdsch.mcsTable = "qam256" and highMcsTable = "qam1024": ', ...
                        'qam1024 is qam256 with every row bumped one modulation ', ...
                        'order and the code rate rescaled, so SpEff is identical ', ...
                        'row-for-row.'];
                else
                    fix_msg = ['Use a companion table that is SpEff-preserving ', ...
                        'row-for-row at this MCS index (uniform: pdsch.mcsTable ', ...
                        '= "qam256", highMcsTable = "qam1024"; PS: ', ...
                        'shaping.mcsTable = "ps_mcs_table2", highMcsTable = ', ...
                        '"ps_mcs_table3").'];
                end
                error("toolbox:AmcHighMcsTableSpEffMismatch", ...
                    [base_msg, fix_msg], ...
                    cfg.pdsch.mcsIndex, operating_field, ...
                    cand_tables(1), ref_speff, ti - 1, cand_tables(ti), cand_speff, ...
                    100 * abs(cand_speff - ref_speff) / max(abs(ref_speff), realmin));
            end
        end
        % Fixed-SpEff AMC exists to hold the payload TBS constant across the
        % table switch, and on the PS path only TBS matching delivers that. The
        % shipped nu_MB columns are not mutually consistent: table3's column is
        % the TBS-matched value but table2's is not, so reading nu straight from
        % the table moves the payload across the switch. Measured at MCS 19, 3
        % layers, 8 PRB -- matchUniformTbs off: 19704 -> 18942 bits (-3.9%);
        % matchUniformTbs on: 18942 -> 18948 (+0.03%, inside
        % tbsMatchToleranceFraction). A moved payload silently invalidates the
        % comparison against the matched no-AMC baseline while every results
        % column still looks plausible. The isfield guard lets partial structs
        % from direct callers skip the rule.
        if shaping_on ...
                && isfield(cfg.shaping, 'matchUniformTbs') ...
                && ~logical(cfg.shaping.matchUniformTbs)
            error("toolbox:IncompatibleAmcTbsMatch", ...
                ['AMC on the PS path requires shaping.matchUniformTbs = true ', ...
                 '(with shaping.uniformMcsTable naming the uniform anchor) so ', ...
                 'nu is SOLVED per candidate table and the payload TBS is ', ...
                 'preserved across the switch. With matchUniformTbs = false, nu ', ...
                 'is read from each table''s nu_MB column, and the shipped ', ...
                 'columns do not agree with each other: switching ', ...
                 '"%s" -> "%s" at MCS %d moves the payload by several percent, ', ...
                 'which breaks the fixed-spectral-efficiency invariant AMC ', ...
                 'exists to hold and invalidates any comparison against a ', ...
                 'matched no-AMC baseline.'], ...
                cand_tables(1), cand_tables(end), cfg.pdsch.mcsIndex);
        end
        if strcmp(selector, 'condition_number')
            % isfinite is load-bearing: the gate is `condition_number_db <=
            % threshold -> none`, so a NaN threshold makes that false and falls
            % through to tableSwitch, pinning the aggressive table with no warning.
            % NaN also passes isreal/isscalar/"< 0"; +-Inf disables/pins it too.
            if ~isscalar(fse.conditionNumberThresholdDb) || ...
                    ~isreal(fse.conditionNumberThresholdDb) || ...
                    ~isfinite(fse.conditionNumberThresholdDb) || ...
                    fse.conditionNumberThresholdDb < 0
                error("toolbox:InvalidAmcConditionNumberThreshold", ...
                    ['simulation.amc.conditionNumberThresholdDb must be ', ...
                     'a finite nonnegative real scalar (dB).']);
            end
        end
    end
    % PRG averaging domain for the per-layer effective SNR the selector consumes.
    if isfield(fse, 'prgAveragingDomain')
        valid_domains = {'capacity'};  % one-element enum (see selector knob)
        if ~ismember(lower(char(string(fse.prgAveragingDomain))), valid_domains)
            error("toolbox:InvalidAmcPrgAveragingDomain", ...
                "simulation.amc.prgAveragingDomain must be ""capacity"" (the only supported domain).");
        end
    end
    if isfield(fse, 'timeAveragingDomain')
        valid_time_domains = {'db', 'capacity'};
        if ~ismember(lower(char(string(fse.timeAveragingDomain))), valid_time_domains)
            error("toolbox:InvalidAmcTimeAveragingDomain", ...
                "simulation.amc.timeAveragingDomain must be ""db"" or ""capacity"".");
        end
    end
end

if cfg.simulation.nErrors < 0 || mod(cfg.simulation.nErrors, 1) ~= 0
    error("toolbox:InvalidNErrors", ...
        "simulation.nErrors must be a nonnegative integer (0 disables the low-SNR early exit).");
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
if ~ismember(precoding_mode, {'none', 'openloop', 'closedloop'})
    error("toolbox:InvalidPrecodingMode", ...
        "Unsupported mimo.precodingMode '%s'.", cfg.mimo.precodingMode);
end

if strcmp(precoding_mode, 'none') ...
        && cfg.mimo.numTransmitAntennas ~= cfg.pdsch.numLayers
    error("toolbox:InvalidIdentityPrecoding", ...
        "With precodingMode = 'none', numTransmitAntennas must equal numLayers.");
end

if strcmp(precoding_mode, 'closedloop')
    if ~isfield(cfg.mimo, 'closedLoop')
        error("toolbox:InvalidClosedLoop", ...
            "precodingMode = 'closedloop' requires the mimo.closedLoop settings.");
    end
    cl = cfg.mimo.closedLoop;

    if ~ismember(lower(string(cl.method)), "svd")
        error("toolbox:UnsupportedClosedLoopMethod", ...
            "mimo.closedLoop.method must be 'svd'.");
    end

    if cl.subbandSize < 1 || mod(cl.subbandSize, 1) ~= 0
        error("toolbox:InvalidClosedLoopSubband", ...
            "mimo.closedLoop.subbandSize must be a positive integer (PRBs per PRG).");
    end

    if cl.periodicitySlots < 1 || mod(cl.periodicitySlots, 1) ~= 0
        error("toolbox:InvalidClosedLoopPeriodicity", ...
            "mimo.closedLoop.periodicitySlots must be a positive integer.");
    end

    if cl.processingDelaySlots < 0 || mod(cl.processingDelaySlots, 1) ~= 0
        error("toolbox:InvalidClosedLoopDelay", ...
            "mimo.closedLoop.processingDelaySlots must be a nonnegative integer.");
    end

    if cl.combSize < 1 || mod(cl.combSize, 1) ~= 0
        error("toolbox:InvalidClosedLoopCombSize", ...
            "mimo.closedLoop.combSize must be a positive integer.");
    end

    if cl.combOffset < 0 || mod(cl.combOffset, 1) ~= 0
        error("toolbox:InvalidClosedLoopCombOffset", ...
            "mimo.closedLoop.combOffset must be a nonnegative integer.");
    end

    if cl.csiSymbol < 1 || mod(cl.csiSymbol, 1) ~= 0
        error("toolbox:InvalidClosedLoopCsiSymbol", ...
            "mimo.closedLoop.csiSymbol must be a positive integer (1-based).");
    end
end

if isempty(cfg.pdsch.prbSet)
    error("toolbox:InvalidPRBSet", "PRB allocation must not be empty.");
end

if any(cfg.pdsch.prbSet < 0) || any(cfg.pdsch.prbSet >= cfg.carrier.nSizeGrid)
    error("toolbox:InvalidPRBSet", ...
        "PRB allocation must stay within the configured carrier grid.");
end

if any(cfg.pdsch.rv < 0) || any(cfg.pdsch.rv > 3) || any(mod(cfg.pdsch.rv, 1) ~= 0)
    error("toolbox:InvalidRV", "rv must contain integers between 0 and 3.");
end

if numel(cfg.pdsch.rv) < cfg.simulation.maxNumTransmissions
    error("toolbox:RvSequenceTooShort", ...
        "pdsch.rv must have at least maxNumTransmissions entries.");
end

if cfg.channel.numReceiveAntennas < 1
    error("toolbox:InvalidRxAntennas", "numReceiveAntennas must be positive.");
end

if cfg.channel.maximumDopplerHz < 0
    error("toolbox:InvalidDoppler", "maximumDopplerHz must be nonnegative.");
end

if lower(string(cfg.channel.model)) == "awgn"
    if cfg.mimo.numTransmitAntennas ~= 1 ...
            || cfg.channel.numReceiveAntennas ~= 1 ...
            || cfg.pdsch.numLayers ~= 1
        error("toolbox:UnsupportedAwgnMimoConfig", ...
            "channel.model = 'awgn' only supports 1 transmit antenna, " + ...
            "1 receive antenna, and 1 PDSCH layer.");
    end
end

if lower(string(cfg.channel.model)) == "cdl"
    if ~ismember(string(cfg.channel.delayProfile), ["CDL-A", "CDL-B", "CDL-C", "CDL-D", "CDL-E"])
        error("toolbox:InvalidDelayProfile", ...
            "Delay profile must be 'CDL-A', 'CDL-B', 'CDL-C', 'CDL-D', or 'CDL-E'");
    end
    if ~cfg.channel.swapTransmitAndReceive
        if prod(cfg.channel.transmitAntennaArray.size) / prod(cfg.channel.analogBF.arraySize) ~= cfg.mimo.numTransmitAntennas
            error("toolbox:InvalidCDLTxAntennas", ...
                "prod(transmitAntennaArray.size) / prod(analogBF.arraySize) must equal numTransmitAntennas");
        end
        if prod(cfg.channel.receiveAntennaArray.size) ~= cfg.channel.numReceiveAntennas
            error("toolbox:InvalidCDLRxAntennas", ...
                "prod(receiveAntennaArray.size) must equal numReceiveAntennas.");
        end
    else
        if prod(cfg.channel.receiveAntennaArray.size) ~= cfg.mimo.numTransmitAntennas
            error("toolbox:InvalidCDLULTxAntennas", ...
                "If swapTransmitAndReceive = true, prod(receiveAntennaArray.size) must equal numTransmitAntennas.");
        end
        if prod(cfg.channel.transmitAntennaArray.size) / prod(cfg.channel.analogBF.arraySize) ~= cfg.channel.numReceiveAntennas
            error("toolbox:InvalidCDLULRxAntennas", ...
                "If swapTransmitAndReceive = true, prod(transmitAntennaArray.size) / prod(analogBF.arraySize) must equal numReceiveAntennas.");
        end
    end
end

if ~ismember(string(cfg.channel.filter), ["td", "fd"])
    error("toolbox:InvalidDelayProfile", ...
        "Channel filter must be 'td' or 'fd'");
end

if ~ismember(lower(string(cfg.receiver.channelEstimation)), ["perfect"])
    error("toolbox:UnsupportedChannelEstimation", ...
        "channelEstimation must be 'perfect'.");
end

if ~ismember(lower(string(cfg.receiver.demapper)), ["mmse", "sphere", "fast_sphere"])
    error("toolbox:UnsupportedDemapper", ...
        "Demapper must be 'mmse', 'sphere', or 'fast_sphere'.");
end

% Fast-sphere decoder settings (only consumed when demapper = "fast_sphere",
% but always populated by defaultConfig so validated unconditionally).
if cfg.receiver.fastSphereNCand < 1 || mod(cfg.receiver.fastSphereNCand, 1) ~= 0
    error("toolbox:InvalidFastSphereNCand", ...
        "receiver.fastSphereNCand must be a positive integer.");
end

if cfg.receiver.fastSphereMaxList < 1 || mod(cfg.receiver.fastSphereMaxList, 1) ~= 0
    error("toolbox:InvalidFastSphereMaxList", ...
        "receiver.fastSphereMaxList must be a positive integer.");
end

if cfg.receiver.maxLdpcIterations < 1
    error("toolbox:InvalidDecoder", ...
        "maxLdpcIterations must be at least 1.");
end

% LLR clip limit (applied after the sphere/fast-sphere demappers). Must be
% a positive real scalar; Inf disables clipping.
if isfield(cfg.receiver, 'llrClipLimit')
    A = cfg.receiver.llrClipLimit;
    if ~isscalar(A) || ~isreal(A) || isnan(A) || A <= 0
        error("toolbox:InvalidLlrClipLimit", ...
            "receiver.llrClipLimit must be a positive real scalar (Inf disables clipping).");
    end
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
        && ~ismember(lower(string(cfg.shaping.mode)), ["ess", "ecc"])
    error("toolbox:UnsupportedShapingMode", ...
        "The active PS path supports shaping.mode = 'ess' or 'ecc' only.");
end

tx_scaling = lower(string(cfg.shaping.txScaling));
if ~ismember(tx_scaling, ["empirical", "lut"])
    error("toolbox:UnsupportedPsTxScaling", ...
        "shaping.txScaling must be 'empirical' or 'lut'.");
end

if strcmpi(string(cfg.shaping.mode), "ecc") && strcmpi(tx_scaling, "lut")
    error("toolbox:UnsupportedPsTxScaling", ...
        "shaping.txScaling = 'lut' is only supported for shaping.mode = 'ess'.");
end

if cfg.shaping.ess.nMax < 1 || mod(cfg.shaping.ess.nMax, 1) ~= 0
    error("toolbox:InvalidEssNMax", ...
        "shaping.ess.nMax must be a positive integer.");
end

if cfg.shaping.ess.nMantissa < 1 || mod(cfg.shaping.ess.nMantissa, 1) ~= 0
    error("toolbox:InvalidEssMantissa", ...
        "shaping.ess.nMantissa must be a positive integer.");
end

if cfg.shaping.ecc.nMax < 1 || mod(cfg.shaping.ecc.nMax, 1) ~= 0
    error("toolbox:InvalidEccNMax", ...
        "shaping.ecc.nMax must be a positive integer.");
end

if cfg.shaping.ecc.listSize < 1 || mod(cfg.shaping.ecc.listSize, 1) ~= 0
    error("toolbox:InvalidEccListSize", ...
        "shaping.ecc.listSize must be a positive integer.");
end
end
