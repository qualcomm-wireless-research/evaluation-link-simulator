function llr_out = detect_pdsch_fast_sphere(pdsch_rx, pdsch_hest, n_var, fast_sphere_decoder_obj)
%DETECTPDSCHFASTSPHERE Perform PDSCH detection using the MEX fast-sphere decoder.
%
%   LLR_OUT = DETECTPDSCHFASTSPHERE(PDSCH_RX, PDSCH_HEST, N_VAR, FAST_SPHERE_DECODER_OBJ)
%   runs fast_sphere_decoder once per resource element and
%   assembles soft LLRs into the same output contract as detect_pdsch_sphere.m.
%
%   Inputs:
%       pdsch_rx                - Received PDSCH symbols (num_re x num_rx)
%       pdsch_hest               - Channel estimates (num_re x num_rx x num_layers)
%       n_var                    - Noise variance (scalar)
%       fast_sphere_decoder_obj  - Struct from initialize_fast_sphere_decoder.m
%
%   Outputs:
%       llr_out - Soft LLRs (num_re x num_layers x bits_per_symbol)
%
%   Notes:
%   - H/y ARE pre-scaled by 1/sqrt(n_var), and N0=1.0 is passed to the MEX
%     instead of the raw noise variance. The MEX's tree-search distance metric
%     (squared residual) does NOT divide by N0 -- N0 only enters through the
%     MMSE regularizer and the fallback LLR clamp (lambdaML+2*N0). 
%     Do not pass raw n_var as the MEX's N0 argument.
%   - PS preprocessing is handled upstream in
%     toolbox.ProbShaping.demod.preprocess_demod_input; the MEX has no
%     shaping-prior parameters.

num_re = size(pdsch_rx, 1);
num_rx = size(pdsch_rx, 2);

if ismatrix(pdsch_hest)
    if size(pdsch_hest, 1) ~= num_re
        error("toolbox:InvalidFastSphereChannelShape", ...
            "Expected channel estimates with %d resource elements, got %d.", ...
            num_re, size(pdsch_hest, 1));
    end
    pdsch_hest = reshape(pdsch_hest, num_re, num_rx, []);
end

num_layers = size(pdsch_hest, 3);

if size(pdsch_hest, 1) ~= num_re || size(pdsch_hest, 2) ~= num_rx
    error("toolbox:InvalidFastSphereChannelShape", ...
        "Expected channel estimates %d-by-%d-by-%d for fast-sphere decoding, got %d-by-%d-by-%d.", ...
        num_re, num_rx, num_layers, size(pdsch_hest, 1), size(pdsch_hest, 2), size(pdsch_hest, 3));
end

bits_per_symbol = fast_sphere_decoder_obj.bitsPerSymbol;
llr_out = zeros(num_re, num_layers, bits_per_symbol);
inv_sqrt_n_var = 1 / sqrt(n_var);

for re_idx = 1:num_re
    h_re = complex(reshape(pdsch_hest(re_idx, :, :), num_rx, num_layers)) * inv_sqrt_n_var;
    y_re = complex(pdsch_rx(re_idx, :).') * inv_sqrt_n_var;

    llr_re = toolbox.phy.receiver.fastsphere.fast_sphere_decoder( ...
        h_re, y_re, fast_sphere_decoder_obj.moduTypes, 'soft', 1.0, ...
        fast_sphere_decoder_obj.nCand, fast_sphere_decoder_obj.maxList, ...
        fast_sphere_decoder_obj.useQrAugmentation);

    llr_out(re_idx, :, :) = permute( ...
        reshape(llr_re, bits_per_symbol, num_layers), [3, 2, 1]);
end

end
