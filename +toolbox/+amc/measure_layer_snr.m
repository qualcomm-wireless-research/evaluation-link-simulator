function layer_snr_db = measure_layer_snr( ...
        h_est_grid, n_var, geom, domain, allocated_sc)
%MEASURE_LAYER_SNR Per-layer effective SNR (dB) from per-PRG MMSE SINR.
%
%   LAYER_SNR_DB = MEASURE_LAYER_SNR(H_EST_GRID, N_VAR, GEOM, DOMAIN) returns
%   per-layer effective post-equalisation SNR in dB as a [nlayers, 1] column.

[nsc, nsym, nrx, nlayers] = size(h_est_grid);
if nargin < 5 || isempty(allocated_sc)
    allocated_sc = 1:nsc;
else
    allocated_sc = double(reshape(allocated_sc, 1, []));
    if any(~isfinite(allocated_sc) | allocated_sc < 1 | allocated_sc > nsc ...
            | allocated_sc ~= fix(allocated_sc)) ...
            || numel(unique(allocated_sc)) ~= numel(allocated_sc)
        error('toolbox:amc:InvalidAllocatedSubcarriers', ...
            'Allocated subcarriers must be unique integer indices in [1, %d].', nsc);
    end
    allocated_sc = sort(allocated_sc);
end

% CSI snapshot symbol, clamped into range (mirrors build_subband_precoders).
csi_sym = min(max(round(geom.csiSymbol), 1), nsym);

% Take the lower-middle allocated subcarrier in each absolute PRG. Keeping the
% absolute PRG labels prevents a sparse allocation from being repacked into
% artificial groups after unallocated subcarriers are removed.
sc_per_prg  = max(round(geom.scPerPrg), 1);
prg_labels = floor((allocated_sc - 1) / sc_per_prg);
active_prgs = unique(prg_labels, 'stable');
prg_mid_sc = zeros(1, numel(active_prgs));
for prg_index = 1:numel(active_prgs)
    members = allocated_sc(prg_labels == active_prgs(prg_index));
    prg_mid_sc(prg_index) = members(floor((numel(members) + 1) / 2));
end

% One SINR observation per active PRG, at that PRG's middle allocated tone.
sinr_per_prg = per_re_sinr_lin(h_est_grid, n_var, prg_mid_sc, csi_sym, nrx, nlayers);
% Collapse the sampled-subcarrier axis in the configured domain.
% toolbox.amc.reduce_prg_snr is the single source of truth for that reduction
% (and clamps/floors the logs), so the simulator and its tests cannot drift.
layer_snr_db = toolbox.amc.reduce_prg_snr(sinr_per_prg, domain);
end

function sinr_lin = per_re_sinr_lin(h_est_grid, n_var, sc_idx, csi_sym, nrx, nlayers)
%PER_RE_SINR_LIN Batched MMSE per-layer LINEAR SINR at the given tones.
%   Returns [nlayers, numel(sc_idx)]. Negatives (round-off only) are clamped to
%   zero so the result is a valid linear SINR for the reduction.

n_sample = numel(sc_idx);

% Gather the [nrx, nlayers] channel at each sampled tone -> pages.
% h_est_grid(sc_idx, csi_sym, :, :) is [n_sample,1,nrx,nlayers]; permute to
% [nrx, nlayers, n_sample] so that pages are subcarriers.
H_s = reshape(permute(h_est_grid(sc_idx, csi_sym, :, :), [3, 4, 1, 2]), ...
    nrx, nlayers, n_sample);

% Batch Gram matrix: G_all = H^H H, shape [nlayers, nlayers, n_sample].
G_all = pagemtimes(conj(permute(H_s, [2, 1, 3])), H_s);

% Add noise floor to each diagonal (in-place; avoids allocating a large eye).
for l = 1:nlayers
    G_all(l, l, :) = G_all(l, l, :) + n_var;
end

% Batch-invert all Gram matrices and extract diagonals.
G_inv = pageinv(G_all);                              % [nlayers, nlayers, n_sample]
G_inv_2d = reshape(G_inv, nlayers*nlayers, n_sample);% [nlayers^2, n_sample]
diag_idx = 1:(nlayers+1):(nlayers*nlayers);          % diagonal linear indices
G_inv_diag = G_inv_2d(diag_idx, :);                  % [nlayers, n_sample]
sinr_lin = 1 ./ (n_var * real(G_inv_diag)) - 1;      % [nlayers, n_sample]
sinr_lin = max(sinr_lin, 0);                         % clamp round-off negatives
end
