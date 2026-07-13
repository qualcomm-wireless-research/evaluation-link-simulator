function weighted_llrs = apply_csi_weighting(dlsch_llrs, csi, bits_per_symbol)
%APPLYCSIWEIGHTING Apply CSI weighting to LLRs.

wrapped_input = ~iscell(dlsch_llrs);
if wrapped_input
    dlsch_llrs = {dlsch_llrs};
end

csi_per_codeword = nrLayerDemap(csi);
weighted_llrs = dlsch_llrs;

for cw_idx = 1:numel(weighted_llrs)
    csi_expanded = repmat(csi_per_codeword{cw_idx}.', bits_per_symbol, 1);
    weighted_llrs{cw_idx} = weighted_llrs{cw_idx} .* csi_expanded(:);
end

if wrapped_input
    weighted_llrs = weighted_llrs{1};
end
end
