function match = match_ess_nu_to_uniform_tbs(cfg, varargin)
%MATCHESSNUTOUNIFORMTBS Find ESS nu_MB that matches uniform-QAM TBS.
%
% match = toolbox.ProbShaping.provider.match_ess_nu_to_uniform_tbs(cfg) uses the PDSCH
% allocation in cfg and searches cfg.shaping.nu so that the ESS payload TBS
% is close to the uniform-QAM TBS for the same MCS index.

cfg = toolbox.defaultConfig(cfg);

parser = inputParser;
parser.addParameter('UniformMcsTable', cfg.pdsch.mcsTable);
parser.addParameter('PsMcsTable', cfg.shaping.mcsTable);
parser.addParameter('Levels', cfg.shaping.numShapedAmplitudeBitLevelsPerDimension);
parser.addParameter('ToleranceFraction', 0.01);
parser.addParameter('NuLower', 0.0);
parser.addParameter('NuUpper', NaN);
parser.addParameter('MaxNu', 10.0);
parser.addParameter('MaxIterations', 24);
parser.parse(varargin{:});
opts = parser.Results;

requested_shaped_bit_level = opts.Levels;
if requested_shaped_bit_level < 1
    error("toolbox:InvalidShapingLevels", ...
        "ESS TBS matching requires at least one shaped amplitude bit level.");
end

[uniform_mcs_info, uniform_carrier, uniform_pdsch, uniform_pdsch_info, uniform_tbs] = ...
    computeUniformSizing(cfg, opts.UniformMcsTable);
[ps_mcs_info, ps_carrier, ps_pdsch, ps_pdsch_info, ps_chain_tbs] = ...
    computePsChainSizing(cfg, opts.PsMcsTable, requested_shaped_bit_level);
mod_info = toolbox.ProbShaping.provider.get_ps_modulation_info(ps_pdsch.Modulation);
shaped_bit_level = min(requested_shaped_bit_level, mod_info.numAmplitudeBitsPerDimension);

target_tbs = uniform_tbs;
target_tolerance_bits = max(1, opts.ToleranceFraction * target_tbs);

evaluations = struct( ...
    'nu', {}, ...
    'psPayloadTbs', {}, ...
    'psChainTbs', {}, ...
    'rateLoss', {}, ...
    'signedDifferenceBits', {}, ...
    'relativeDifference', {}, ...
    'metTolerance', {});

    function addEvaluation(evaluation)
        evaluations(end + 1) = evaluation; %#ok<AGROW>
    end

    function evaluation = evaluateNu(nu)
        ps_cfg = cfg;
        ps_cfg.shaping.enabled = true;
        ps_cfg.shaping.mode = "ess";
        ps_cfg.shaping.mcsTable = opts.PsMcsTable;
        ps_cfg.shaping.useMcsTableNu = false;
        ps_cfg.shaping.nu = nu;
        ps_cfg.shaping.numShapedAmplitudeBitLevelsPerDimension = requested_shaped_bit_level;

        try
            shaping_info = toolbox.ProbShaping.tbgen.init( ...
                ps_cfg, ps_carrier, ps_pdsch, ps_mcs_info, ps_pdsch_info, ps_chain_tbs);
            ps_payload_tbs = shaping_info.payloadTransportBlockLength;
        catch err
            if ismember(string(err.identifier), ...
                    ["toolbox:ShapingPayloadTooSmall", ...
                    "toolbox:ShapingAllocationTooSmall"])
                ps_payload_tbs = 0;
            else
                rethrow(err);
            end
        end

        signed_difference_bits = ps_payload_tbs - target_tbs;
        relative_difference = abs(signed_difference_bits) / target_tbs;
        evaluation = struct( ...
            'nu', nu, ...
            'psPayloadTbs', ps_payload_tbs, ...
            'psChainTbs', ps_chain_tbs, ...
            'rateLoss', ps_chain_tbs - ps_payload_tbs, ...
            'signedDifferenceBits', signed_difference_bits, ...
            'relativeDifference', relative_difference, ...
            'metTolerance', abs(signed_difference_bits) <= target_tolerance_bits);
    end

lower_nu = opts.NuLower;
lower_eval = evaluateNu(lower_nu);
addEvaluation(lower_eval);

table_nu = ps_mcs_info.nu_MB;
if isfinite(table_nu) && table_nu >= opts.NuLower && table_nu <= opts.MaxNu
    addEvaluation(evaluateNu(table_nu));
end

if isfinite(opts.NuUpper)
    upper_nu = opts.NuUpper;
else
    if isfinite(table_nu) && table_nu > lower_nu
        upper_nu = min(opts.MaxNu, max(2 * table_nu, 1e-3));
    else
        upper_nu = min(opts.MaxNu, 0.1);
    end
end

upper_eval = evaluateNu(upper_nu);
addEvaluation(upper_eval);

while upper_eval.signedDifferenceBits > 0 && upper_nu < opts.MaxNu
    lower_nu = upper_nu;
    upper_nu = min(opts.MaxNu, max(2 * upper_nu, upper_nu + 1e-3));
    upper_eval = evaluateNu(upper_nu);
    addEvaluation(upper_eval);
end

if lower_eval.signedDifferenceBits >= 0 && upper_eval.signedDifferenceBits <= 0
    low = lower_nu;
    high = upper_nu;
    for iter = 1:opts.MaxIterations
        mid = (low + high) / 2;
        mid_eval = evaluateNu(mid);
        addEvaluation(mid_eval);
        if mid_eval.signedDifferenceBits >= 0
            low = mid;
        else
            high = mid;
        end
    end
end

evaluations_table = struct2table(evaluations);
[~, best_idx] = min(evaluations_table.relativeDifference);
best = table2struct(evaluations_table(best_idx, :));

match = struct();
match.nu = best.nu;
match.targetTbs = target_tbs;
match.psPayloadTbs = best.psPayloadTbs;
match.psChainTbs = best.psChainTbs;
match.rateLoss = best.rateLoss;
match.signedDifferenceBits = best.signedDifferenceBits;
match.relativeDifference = best.relativeDifference;
match.metTolerance = best.metTolerance;
match.toleranceFraction = opts.ToleranceFraction;
match.max_shaped_bit_level = requested_shaped_bit_level;
match.shaped_bit_level = shaped_bit_level;
match.uniformMcsTable = string(opts.UniformMcsTable);
match.psMcsTable = string(opts.PsMcsTable);
match.uniformMcsInfo = uniform_mcs_info;
match.psMcsInfo = ps_mcs_info;
match.uniformModulation = string(uniform_pdsch.Modulation);
match.psModulation = string(ps_pdsch.Modulation);
match.numPrbs = numel(ps_pdsch.PRBSet);
match.nrePerPrb = uniform_pdsch_info.NREPerPRB;
match.evaluations = sortrows(evaluations_table, 'nu');
end

function [mcs_info, carrier, pdsch, pdsch_info, tbs] = ...
    computeUniformSizing(cfg, uniform_mcs_table)

uniform_cfg = cfg;
uniform_cfg.pdsch.mcsTable = uniform_mcs_table;
uniform_cfg.shaping.enabled = false;
uniform_cfg.shaping.numShapedAmplitudeBitLevelsPerDimension = 0;

mcs_info = toolbox.getMcsInfo(uniform_cfg.pdsch.mcsIndex, uniform_mcs_table);
[carrier, pdsch] = toolbox.phy.pdsch.build_link_objects(uniform_cfg, mcs_info);
[~, pdsch_info] = nrPDSCHIndices(carrier, pdsch);
tbs = nrTBS( ...
    pdsch.Modulation, ...
    pdsch.NumLayers, ...
    numel(pdsch.PRBSet), ...
    pdsch_info.NREPerPRB, ...
    mcs_info.targetCodeRate, ...
    0);
end

function [mcs_info, carrier, pdsch, pdsch_info, tbs] = ...
    computePsChainSizing(cfg, ps_mcs_table, shaped_bit_level)

ps_cfg = cfg;
ps_cfg.shaping.enabled = true;
ps_cfg.shaping.mode = "ess";
ps_cfg.shaping.mcsTable = ps_mcs_table;
ps_cfg.shaping.useMcsTableNu = false;
ps_cfg.shaping.numShapedAmplitudeBitLevelsPerDimension = shaped_bit_level;

mcs_info = toolbox.getMcsInfo(ps_cfg.pdsch.mcsIndex, ps_mcs_table);
[carrier, pdsch] = toolbox.phy.pdsch.build_link_objects(ps_cfg, mcs_info);
[~, pdsch_info] = nrPDSCHIndices(carrier, pdsch);
tbs = nrTBS( ...
    pdsch.Modulation, ...
    pdsch.NumLayers, ...
    numel(pdsch.PRBSet), ...
    pdsch_info.NREPerPRB, ...
    mcs_info.targetCodeRate, ...
    0);
end
