function [Y_eq, H_eq] = preprocess_demod_input(pdsch_rx, pdsch_hest, n_var, shaping_info)
% PREPROCESS_DEMOD_INPUT PS demod preprocessing returning
% the Cholesky-form (Y_eq, H_eq) used by downstream MMSE/sphere.
%
%   Inputs
%     pdsch_rx      n_tones x n_rx received PDSCH REs.
%     pdsch_hest    n_tones x n_rx x num_layers channel estimate (layer domain).
%     n_var         scalar effective noise variance.
%     shaping_info  struct with at least:
%                     .enabled           (logical)
%                     .nu_normalize      (ν̃ per-Qm scaling for the regulariser)
%                     .psPowerScaling    (per-TB TX power; tx_scale = sqrt(·))
%
%   Outputs (shape depends on layer count)
%     1 layer, 1 Rx : Y_eq, H_eq are n_tones x 1 (scalar per tone).
%     1 layer, N Rx : Y_eq, H_eq are n_tones x 1 (scalar per tone after MF
%                                                combining).
%     M layer       : Y_eq is n_tones x M; H_eq is n_tones x M x M, the per-tone
%                     upper-triangular Cholesky factor of
%                     Rhh = (tx_scale·H)^H (tx_scale·H) + diag(ν̃·n_var).
%
%   Conventions
%     - Operates in the unwhitened-noise domain (n_var carried explicitly). 
%     - When shaping is disabled, returns the inputs unchanged (Y_eq = pdsch_rx,
%       H_eq = pdsch_hest) so the uniform NR path can reuse the same entry.

if isempty(pdsch_rx)
    Y_eq = zeros(0, 1);
    H_eq = zeros(0, 1);
    return;
end

if ~isfield(shaping_info, 'enabled') || ~logical(shaping_info.enabled)
    Y_eq = pdsch_rx;
    H_eq = pdsch_hest;
    return;
end

if ndims(pdsch_hest) == 2
    pdsch_hest = reshape(pdsch_hest, size(pdsch_hest, 1), size(pdsch_hest, 2), 1);
end
[n_tones, n_rx, num_layers] = size(pdsch_hest);

tx_scale = sqrt(shaping_info.psPowerScaling);

scaledHest = tx_scale .* pdsch_hest;
nuRegularizer        = n_var * shaping_info.nu_normalize;

if num_layers == 1 && n_rx == 1
    H = scaledHest(:, 1, 1);
    chanEnergy = abs(H) .^ 2;
    beta_scaling = chanEnergy ./ (chanEnergy + nuRegularizer);
    Y_eq = sqrt(beta_scaling) .* pdsch_rx(:, 1);
    H_eq = H ./ sqrt(beta_scaling);
elseif num_layers == 1 && n_rx > 1
    H = scaledHest(:, :, 1);
    Rhh = sum(abs(H) .^ 2, 2) + nuRegularizer;
    H_eq = sqrt(Rhh);
    Y_eq = H_eq ./ Rhh .* sum(conj(H) .* pdsch_rx, 2);
else
    Rhh = zeros(n_tones, num_layers, num_layers);
    for i_rx = 1:n_rx
        for i_tx = 1:num_layers
            for j_tx = 1:num_layers
                Rhh(:, i_tx, j_tx) = Rhh(:, i_tx, j_tx) ...
                    + conj(scaledHest(:, i_rx, i_tx)) .* scaledHest(:, i_rx, j_tx);
            end
        end
    end
    for i_stream = 1:num_layers
        Rhh(:, i_stream, i_stream) = Rhh(:, i_stream, i_stream) + nuRegularizer;
    end
    H_eq = zeros(n_tones, num_layers, num_layers);
    Y_eq = zeros(n_tones, num_layers);
    for i_tone = 1:n_tones
        Rhh_t = reshape(Rhh(i_tone, :, :), num_layers, num_layers);
        Heq_t = chol(Rhh_t);
        H_eq(i_tone, :, :) = Heq_t;
        H_t = reshape(scaledHest(i_tone, :, :), n_rx, num_layers);
        rx_vec = pdsch_rx(i_tone, :).';
        Y_eq(i_tone, :) = (Heq_t * (Rhh_t \ (H_t' * rx_vec))).';
    end
end
end
