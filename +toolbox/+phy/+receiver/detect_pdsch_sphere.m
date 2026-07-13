function llr_out = detect_pdsch_sphere(pdsch_rx, pdsch_hest, n_var, sphere_decoder_obj)
%DETECTPDSCHSPHERE Perform PDSCH detection using pre-initialized sphere decoder.
%
%   [LLR_OUT, CSI] = DETECTPDSCHSPHERE(PDSCH_RX, PDSCH_HEST, N_VAR, SPHERE_DECODER_OBJ)
%   performs sphere decoding on PDSCH symbols using a pre-initialized
%   comm.SphereDecoder object. Returns soft LLRs directly.
%
%   Inputs:
%       pdsch_rx           - Received PDSCH symbols (num_re x num_rx)
%       pdsch_hest         - Channel estimates (num_re x num_rx x num_layers)
%       n_var              - Noise variance (scalar)
%       sphere_decoder_obj - Pre-initialized sphere decoder structure with fields:
%                            .decoder - comm.SphereDecoder object
%                            .constellation - NR constellation
%                            .bitTable - Binary bit mapping
%                            .bitsPerSymbol - Bits per symbol
%                            .algorithm - 'full' or 'radius'
%                            .configuredRadius - Configured radius value
%
%   Outputs:
%       llr_out - Soft LLRs (num_re x num_layers x bits_per_symbol)
%       csi     - Channel state information (num_re x num_layers)
%
%   Note: This function uses a pre-initialized comm.SphereDecoder for efficiency.
%   The sphere decoder expects: y = H*x + n, where:
%     y: received signal (num_rx x 1)
%     H: channel matrix (num_rx x num_layers)
%     x: transmitted symbols (num_layers x 1)

% Extract sphere decoder components
sphere_decoder = sphere_decoder_obj.decoder;


% Get dimensions
num_re = size(pdsch_rx,1);
num_rx = size(pdsch_rx, 2);

if ismatrix(pdsch_hest)
    if size(pdsch_hest, 1) ~= num_re
        error("toolbox:InvalidSphereChannelShape", ...
            "Expected channel estimates with %d resource elements, got %d.", ...
            num_re, size(pdsch_hest, 1));
    end
    pdsch_hest = reshape(pdsch_hest, num_re, num_rx, []);
end

num_layers = size(pdsch_hest, 3);

if size(pdsch_hest, 1) ~= num_re || size(pdsch_hest, 2) ~= num_rx
    error("toolbox:InvalidSphereChannelShape", ...
        "Expected channel estimates %d-by-%d-by-%d for sphere decoding, got %d-by-%d-by-%d.", ...
        num_re, num_rx, num_layers, size(pdsch_hest, 1), size(pdsch_hest, 2), size(pdsch_hest, 3));
end

% Initialize outputs
% llr_out = zeros(num_re, num_layers, sphere_decoder_obj.bitsPerSymbol);

% expects RXSYMBOLS as num_re-by-num_rx and CHAN as num_re-by-num_layers-by-num_rx.
% complex(...) is required because comm.SphereDecoder rejects purely real CHAN,
% which can occur after PS preprocessing or identity/AWGN channels.
chan = complex(permute(pdsch_hest, [1, 3, 2]) / sqrt(n_var));
llrs = -1 * sphere_decoder(pdsch_rx / sqrt(n_var), chan);
llr_out = permute(reshape(llrs, ...
    sphere_decoder_obj.bitsPerSymbol, num_re, num_layers), [2, 3, 1]);

end
