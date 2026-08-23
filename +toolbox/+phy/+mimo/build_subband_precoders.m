function [p_freq, subband_info] = build_subband_precoders(h_grid, opts)
%BUILDSUBBANDPRECODERS Per-PRG SVD precoders from a comb-sparse channel covariance.
%   [P_FREQ, SUBBAND_INFO] = BUILDSUBBANDPRECODERS(H_GRID, OPTS) computes a
%   closed-loop precoder for each precoding RB group (PRG) from the
%   antenna-domain channel estimate H_GRID (size [nsc, nsym, nrx, ntx]).
%
%   This models the CSI a periodic SRS/CSI-RS report actually carries: sparse
%   in time (a single OFDM snapshot symbol) and frequency (a comb of every Nth
%   subcarrier), coarse in granularity (one precoder per PRG). Within each PRG
%   the channel covariance R = sum(H'H) is accumulated over the sounded tones of
%   the snapshot symbol, and the top NUM_LAYERS eigen-directions of R (its
%   dominant right singular vectors) form the transmit precoder. Aggregating the
%   Hermitian covariance -- rather than averaging H, whose per-subcarrier phases
%   would partially cancel -- is what makes the wideband-within-PRG beamformer
%   well-conditioned.
%
%   OPTS fields:
%       numLayers    - number of layers (top eigen-directions kept)
%       subbandSize  - PRBs per PRG
%       numScPerPrb  - subcarriers per PRB (12 in NR)
%       combSize     - SRS frequency comb; sound every combSize-th SC (1 = all)
%       combOffset   - first sounded SC within the comb (0-based)
%       csiSymbol    - OFDM-symbol index used as the CSI snapshot (1-based)
%
%   Each PRG precoder is normalized so the total transmit power per RE is
%   tr(P'P) = 1 (orthonormal columns scaled by 1/sqrt(numLayers)), matching the
%   wideband convention in build_mimo_info.m.
%
%   P_FREQ is returned expanded per subcarrier with size [ntx, numLayers, nsc]
%   and is constant across OFDM symbols. SUBBAND_INFO records the PRG partition.

num_subcarriers = size(h_grid, 1);
num_symbols = size(h_grid, 2);
num_receive_antennas = size(h_grid, 3);
num_transmit_antennas = size(h_grid, 4);

num_layers = opts.numLayers;
if num_transmit_antennas < num_layers
    error("toolbox:InvalidClosedLoopRank", ...
        "Closed-loop precoding requires num_transmit_antennas >= num_layers.");
end

sc_per_prg = opts.subbandSize * opts.numScPerPrb;
comb_size = opts.combSize;
comb_offset = opts.combOffset;

% Single-symbol CSI snapshot (clamp to the available symbols).
csi_symbol = min(max(opts.csiSymbol, 1), num_symbols);

% Comb mask over all subcarriers: true on the sounded tones only.
sc_idx = (0:num_subcarriers - 1).';
comb_mask = mod(sc_idx, comb_size) == mod(comb_offset, comb_size);

prg_starts = 1:sc_per_prg:num_subcarriers;
num_prgs = numel(prg_starts);

p_freq = zeros(num_transmit_antennas, num_layers, num_subcarriers, class(h_grid));
subband_edges = zeros(num_prgs, 2);

for prg_idx = 1:num_prgs
    sc0 = prg_starts(prg_idx);
    sc1 = min(sc0 + sc_per_prg - 1, num_subcarriers);
    subband_edges(prg_idx, :) = [sc0, sc1];

    % Sounded tones inside this PRG; fall back to all of them if the comb skips
    % the whole group (e.g. a narrow PRG versus a coarse comb).
    prg_tones = find(comb_mask(sc0:sc1)) + (sc0 - 1);
    if isempty(prg_tones)
        prg_tones = (sc0:sc1).';
    end

    % Accumulate R = sum(H'H) over the sounded tones of the snapshot symbol.
    % H_k is [nrx, ntx]; R is the [ntx, ntx] Hermitian channel covariance.
    cov = zeros(num_transmit_antennas, num_transmit_antennas, class(h_grid));
    for t = 1:numel(prg_tones)
        k = prg_tones(t);
        h_k = reshape(h_grid(k, csi_symbol, :, :), num_receive_antennas, num_transmit_antennas);
        cov = cov + (h_k' * h_k);
    end

    % Dominant eigen-directions of the covariance. svd of a Hermitian matrix
    % returns descending singular values, so the first num_layers right vectors
    % are the strongest directions.
    [~, ~, v] = svd(cov);
    precoder = v(:, 1:num_layers) / sqrt(num_layers);

    p_freq(:, :, sc0:sc1) = repmat(precoder, 1, 1, sc1 - sc0 + 1);
end

subband_info = struct();
subband_info.subbandSize = opts.subbandSize;
subband_info.scPerPrg = sc_per_prg;
subband_info.numSubbands = num_prgs;
subband_info.subbandEdges = subband_edges;
subband_info.combSize = comb_size;
subband_info.combOffset = comb_offset;
subband_info.csiSymbol = csi_symbol;
end
