function ps_info = init(cfg, carrier, pdsch, mcs_info, pdsch_info, chain_tbs)
%INIT Initialize PS geometry and TB-generation metadata.

chain = nrDLSCHInfo(chain_tbs, mcs_info.targetCodeRate);
Qm = mcs_info.bitsPerSymbol;
G = pdsch_info.G;
prefix_len = 2 * chain.Zc;
pre_ldpc_len = chain.K - chain.F;
num_symbols = G / Qm;

ps_info = base_info(cfg, pdsch, mcs_info, Qm, chain, chain_tbs, pre_ldpc_len, prefix_len);
if ~ps_info.enabled
    return;
end

mod_info = toolbox.ProbShaping.provider.get_ps_modulation_info(pdsch.Modulation);
requested_shaped_bit_level = cfg.shaping.numShapedAmplitudeBitLevelsPerDimension;
shaped_bit_level = min(requested_shaped_bit_level, mod_info.numAmplitudeBitsPerDimension);
validate_ps_config(cfg, G, chain, Qm, shaped_bit_level, mod_info);

ps_info.max_num_shaped_bit_levels = requested_shaped_bit_level;
ps_info.num_shaped_bit_levels = shaped_bit_level;
E = rate_matched_lengths(chain, G, Qm, pdsch.NumLayers);
cb_labels = nrCodeBlockSegmentLDPC((1:(chain_tbs + chain.L)).', chain.BGN);
% payload_per_cb = count_payload_bits(cb_labels, pre_ldpc_len, chain.Lcb, chain_tbs);
payload_labels = cb_labels(1:(pre_ldpc_len - chain.Lcb), :);
payload_per_cb = sum(payload_labels >= 1 & payload_labels <= chain_tbs, 1).';


%%%build energy table for ESS%%%%
num_unshaped_bit_levels = mod_info.numAmplitudeBitsPerDimension - ps_info.num_shaped_bit_levels;

[mantissa_table, exponent_table] = toolbox.ProbShaping.ess.generateEnergyTable(...
    cfg.shaping.ess.nMax, ps_info.nu*4^num_unshaped_bit_levels, ...
    2.^(ps_info.num_shaped_bit_levels), cfg.shaping.ess.nMantissa+1);%%Note, the matissa table uses the format of 1xxxx, the first bit is redundant. 

ps_info.energyTable=cell(1,2);
ps_info.energyTable{1}=mantissa_table;
ps_info.energyTable{2}=exponent_table;

% generate per-CB parameters.
code_blocks = build_cb_plans( ...
    ps_info, cfg, cb_labels, chain_tbs, E, payload_per_cb, ...
    pre_ldpc_len, prefix_len, chain.Lcb);

payload_tbs = chain_tbs - sum([code_blocks.rateLoss]);

shaped_bits_per_cb = [code_blocks.numShapedBits].';
scrambling_seq = toolbox.phy.pdsch.get_pdsch_scrambling_sequence( ...
    carrier, pdsch, G, false);

ps_info.payloadTransportBlockLength = payload_tbs;
ps_info.numShapedBits = sum(shaped_bits_per_cb);
ps_info.numShapedSymbols = ps_info.numShapedBits / (2 * shaped_bit_level);
ps_info.numRateMatchedBitsPerCodeBlock = E;
ps_info.numShapedBitsPerCodeBlock = shaped_bits_per_cb;
ps_info.scramblingSequence = scrambling_seq;
ps_info.codeBlocks = code_blocks;
ps_info.nu_normalize = ps_info.nu * (2 / 3) * ((2 ^ Qm) - 1);
ps_info.psPowerScaling = 1.0;

if strcmp(ps_info.txScaling,'lut')  
    ps_info.psPowerScaling = toolbox.ProbShaping.ess.getTxScaling(2^ps_info.num_shaped_bit_levels,cfg.shaping.ess.nMax,size(exponent_table,2),num_unshaped_bit_levels);
end

ps_info.tbgen_probe = tbgen_probe(ps_info);

end

function ps_info = base_info(cfg, pdsch, mcs_info, Qm, chain, chain_tbs, pre_ldpc_len, prefix_len)
tx_scaling = lower(string(cfg.shaping.txScaling));

ps_info = struct( ...
    "enabled", logical(cfg.shaping.enabled), "mode", string(cfg.shaping.mode), ...
    "txScaling", tx_scaling, "mcsTable", string(mcs_info.table), ...
    "modulation", string(pdsch.Modulation), "bitsPerSymbol", Qm, ...
    "nu", cfg.shaping.nu, "measurementBasis", "tb_crc", ...
    "chainTransportBlockLength", chain_tbs, "payloadTransportBlockLength", chain_tbs, ...
    "preLdpcBlockLength", pre_ldpc_len, "prefixLength", prefix_len, ...
    "num_cb", chain.C, ...
    "numRateMatchedBitsPerCodeBlock", zeros(chain.C, 1), ...
    "numShapedBitsPerCodeBlock", zeros(chain.C, 1), ...
    "numShapedSymbols", 0, "numShapedBits", 0, ...
    "max_num_shaped_bit_levels", 0, "num_shaped_bit_levels", 0, ...
    "psPowerScaling", 1.0, ...
    "nu_normalize", 0.0);
end

function validate_ps_config(cfg, G, chain, Qm, shaped_bit_level, mod_info)
unsupported = ~strcmpi(char(cfg.shaping.mode), 'ess') ...
    || cfg.pdsch.rv ~= 0 ...
    || chain.C > cfg.shaping.maxSupportedCodeBlocks ...
    || mod(G, Qm) ~= 0 ...
    || shaped_bit_level < 1 ...
    || shaped_bit_level > mod_info.numAmplitudeBitsPerDimension;
if unsupported
    error("toolbox:InvalidPsConfiguration", ...
        "Unsupported PS configuration for ESS TB generation.");
end
end

% function payload_per_cb = count_payload_bits(labels, pre_ldpc_len, cb_crc_len, chain_tbs)
% payload_labels = labels(1:(pre_ldpc_len - cb_crc_len), :);
% payload_per_cb = sum(payload_labels >= 1 & payload_labels <= chain_tbs, 1).';
% end

function plans = build_cb_plans( ...
    ps_info, cfg, labels, chain_tbs, E, payload_per_cb, ...
    pre_ldpc_len, prefix_len, cb_crc_len)
plans = repmat(empty_plan(), numel(E), 1);
for i_cb = 1:numel(E)
    plans(i_cb) = plan_cb( ...
        ps_info, cfg, i_cb, E(i_cb), payload_per_cb(i_cb), ...
        pre_ldpc_len, prefix_len, cb_crc_len);
    plans(i_cb) = add_payload_accounting( ...
        plans(i_cb), labels(:, i_cb), pre_ldpc_len - cb_crc_len, ...
        prefix_len, chain_tbs);
end
end

function plan = empty_plan()
plan = struct( ...
    "index", 0, "numRateMatchedBits", 0, "numTbPayloadBits", 0, ...
    "numShapedBits", 0, "numShapedSymbols", 0, ...
    "rateLoss", 0, "codec", string(missing), "codecState", struct(), ...
    "essNumInfoBits", 0, "payloadTransportBlockStart", 0, ...
    "payloadTransportBlockEnd", 0, "numPayloadPuncturedBits", 0, ...
    "numPayloadUnshapedBitsBeforeShaped", 0, ...
    "numPayloadUnshapedBitsAfterShaped", 0, ...
    "numTransmittedSystematicBits", 0, "numUnshapedTransmittedBits", 0, ...
    "shapedPreLdpcStart", 0, "shapedPreLdpcEnd", 0);
end

function plan = plan_cb(ps_info, cfg, i_cb, Er, tb_payload_bits, pre_ldpc_len, prefix_len, cb_crc_len)
Qm = ps_info.bitsPerSymbol;
shaped_bit_level = ps_info.num_shaped_bit_levels;
num_symbols = floor(Er / Qm);
num_sign_bits = 2 * num_symbols;
num_tx_sys_bits = min(Er, pre_ldpc_len - prefix_len);
num_parity_bits = max(0, Er - num_tx_sys_bits);
unshaped_budget = num_sign_bits * (Qm / 2 - shaped_bit_level) - cb_crc_len;
ess_state = toolbox.ProbShaping.ess.ess( ...
    ps_info.modulation, ps_info.energyTable, ps_info.nu, num_sign_bits, shaped_bit_level, ...
    cfg.shaping.ess.nMax, cfg.shaping.ess.nMantissa);
num_shaped_bits = 2 * shaped_bit_level * num_symbols;
shaped_start = prefix_len + 1;
shaped_end = shaped_start + num_shaped_bits - 1;
if num_parity_bits > unshaped_budget ...
        || shaped_end > pre_ldpc_len - cb_crc_len ...
        || ess_state.numBitsPerCodeword > num_shaped_bits
    error("toolbox:InvalidPsPlanning", ...
        "PS geometry is infeasible for this configuration.");
end

plan = empty_plan();
plan.index = i_cb;
plan.numRateMatchedBits = Er;
plan.numTbPayloadBits = tb_payload_bits;
plan.numShapedBits = num_shaped_bits;
plan.numShapedSymbols = num_symbols;
plan.codec = "ess";
plan.codecState = ess_state;
plan.essNumInfoBits = ess_state.numBitsPerCodeword;
plan.rateLoss = num_shaped_bits - plan.essNumInfoBits;
plan.numTransmittedSystematicBits = num_tx_sys_bits;
plan.numUnshapedTransmittedBits = num_tx_sys_bits - num_shaped_bits;
plan.shapedPreLdpcStart = shaped_start;
plan.shapedPreLdpcEnd = shaped_end;
end

function plan = add_payload_accounting(plan, cb_labels, info_end, prefix_len, chain_tbs)
data_labels = cb_labels(1:info_end);
payload_labels = data_labels(data_labels >= 1 & data_labels <= chain_tbs);
if ~isempty(payload_labels)
    plan.payloadTransportBlockStart = payload_labels(1);
    plan.payloadTransportBlockEnd = payload_labels(end);
end

if plan.numShapedBits > 0
    shaped_rows = plan.shapedPreLdpcStart:plan.shapedPreLdpcEnd;
    before = (prefix_len + 1):(shaped_rows(1) - 1);
    after = (shaped_rows(end) + 1):info_end;
else
    before = (prefix_len + 1):info_end;
    after = zeros(1, 0);
end

plan.numPayloadPuncturedBits = count_payload(data_labels(1:prefix_len), chain_tbs);
plan.numPayloadUnshapedBitsBeforeShaped = count_payload(data_labels(before), chain_tbs);
plan.numPayloadUnshapedBitsAfterShaped = count_payload(data_labels(after), chain_tbs);
end

function n = count_payload(labels, chain_tbs)
n = nnz(labels >= 1 & labels <= chain_tbs);
end


function E = rate_matched_lengths(chain, G, Qm, num_layers)
QmNL = Qm * num_layers;
gamma = mod(G / QmNL, chain.C);
base = floor(G / (QmNL * chain.C));
E = QmNL * (base + ((1:chain.C).' > chain.C - gamma));
if sum(E) ~= G || any(E > chain.N - chain.F)
    error("toolbox:InvalidPsPlanning", "Unsupported PS rate-matching geometry.");
end
end

function probe = tbgen_probe(ps_info)
cb = ps_info.codeBlocks(:);
probe = struct( ...
    "num_cb", ps_info.num_cb, ...
    "tx_scaling", ps_info.txScaling, ...
    "max_num_shaped_bit_levels", ps_info.max_num_shaped_bit_levels, ...
    "num_shaped_bit_levels", ps_info.num_shaped_bit_levels, ...
    "chain_tbs", ps_info.chainTransportBlockLength, ...
    "payload_tbs", ps_info.payloadTransportBlockLength, "total_rate_loss", sum([cb.rateLoss]), ...
    "num_bits_toshape_per_cb", [cb.essNumInfoBits], ...
    "num_rate_matched_bits_per_cb", ps_info.numRateMatchedBitsPerCodeBlock(:).', ...
    "num_tb_payload_bits_per_cb", [cb.numTbPayloadBits], ...
    "num_shaped_bits_per_cb", ps_info.numShapedBitsPerCodeBlock(:).', ...
    "rate_loss_per_cb", [cb.rateLoss], ...
    "num_punctured_bits_per_cb", [cb.numPayloadPuncturedBits], ...
    "num_unshaped_bits_before_shaped_per_cb", [cb.numPayloadUnshapedBitsBeforeShaped], ...
    "num_unshaped_bits_after_shaped_per_cb", [cb.numPayloadUnshapedBitsAfterShaped]);
end
