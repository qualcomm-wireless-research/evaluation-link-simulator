function dlsch_llrs = new_pdsch_decode( ...
    carrier, pdsch, pdsch_rx, pdsch_hest, n_var, receiver_cfg, shaping_info)
%NEWPDSCHDECODE Shared NR/PS RX front-end and descrambling flow.
%
%   This function now owns the full per-TB RX path from extracted PDSCH REs
%   to decoder-domain LLRs:
%     1) Front-end symbols/LLR preparation:
%          - Uniform: local MMSE or sphere demapper.
%          - PS: PS-specific demod preprocessing, then the same demapper.
%     2) Shared mapped-domain LLR extraction.
%     3) Diverged descrambling:
%          - Uniform: full NR descrambling.
%          - PS: selective descrambling + PS bit demapping.
%
%   When PS is enabled, preprocessing adapts the received observations to the
%   PS demod model before the common demapper is called.

if nargin < 7 || isempty(shaping_info)
    shaping_info = struct('enabled', false);
end
is_ps_path = isfield(shaping_info, 'enabled') && logical(shaping_info.enabled);

% PS-specific preprocessing
if is_ps_path
    [pdsch_rx, pdsch_hest] = toolbox.ProbShaping.demod.preprocess_demod_input( ...
        pdsch_rx, pdsch_hest, n_var, shaping_info);
end

% demapping
switch lower(char(receiver_cfg.demapper))
    case 'mmse'
        [demod_input, csi] = nrEqualizeMMSE(pdsch_rx, pdsch_hest, n_var);
        [demod_input, csi] = normalize_mmse_demod_input( ...
            demod_input, csi, n_var);
        bits_per_symbol = toolbox.phy.pdsch.bits_per_symbol(pdsch.Modulation);
        layer_symbols = nrLayerDemap(demod_input);
        layer_symbols = layer_symbols{1}; % unwrap
        mapped_llrs = nrSymbolDemodulate(layer_symbols, pdsch.Modulation, n_var);
        mapped_llrs = toolbox.phy.receiver.apply_csi_weighting( ...
            mapped_llrs, csi, bits_per_symbol);

    case 'sphere'
        assert(isfield(receiver_cfg, 'sphereDecoderObj') ...
            && ~isempty(receiver_cfg.sphereDecoderObj), ...
            'toolbox:MissingSphereDecoder', ...
            ['Sphere decoder requires pre-initialized sphereDecoderObj ', ...
             'in receiver_cfg.']);

        demod_input = toolbox.phy.receiver.detect_pdsch_sphere( ...
            pdsch_rx, pdsch_hest, n_var, receiver_cfg.sphereDecoderObj);
        mapped_llrs = reshape(permute(demod_input, [3, 2, 1]), [], 1);

    otherwise
        error("toolbox:UnsupportedDemapper", ...
            "Unsupported demapper '%s'. Use 'mmse' or 'sphere'.", ...
            receiver_cfg.demapper);
end

% unscrambling. For PS, we use a scrambling mask to protect the shaped bits.
if is_ps_path
    dlsch_llrs = toolbox.ProbShaping.mapping.ps_descramble(mapped_llrs, shaping_info);
else
    signs = toolbox.phy.pdsch.get_pdsch_scrambling_sequence( ...
        carrier, pdsch, numel(mapped_llrs), true);
    dlsch_llrs = mapped_llrs .* signs;
end

% unwrap a single CW cell array into a LLR vector.
if iscell(dlsch_llrs) && numel(dlsch_llrs) == 1
    dlsch_llrs = dlsch_llrs{1};
end

end

function [demod_input, effective_csi] = normalize_mmse_demod_input( ...
    demod_input, csi, n_var)

csi = real(csi);
effective_csi = max(csi - n_var, 0);

mmse_gain = zeros(size(csi), 'like', csi);
valid_csi = csi > 0;
mmse_gain(valid_csi) = effective_csi(valid_csi) ./ csi(valid_csi);

normalized_input = zeros(size(demod_input), 'like', demod_input);
valid_gain = mmse_gain > 0;
normalized_input(valid_gain) = demod_input(valid_gain) ./ mmse_gain(valid_gain);
demod_input = normalized_input;

end
