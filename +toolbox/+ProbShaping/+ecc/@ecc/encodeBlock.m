function out = encodeBlock(obj, block_length, list_size, input_bits, n_info, p_bit_cond)
%  ENCODEBLOCK Multi-level polar shaping encoder for one DM block (Option-B cover-code).
%
%   Runs one cover-code polar-shaping pass per amplitude-bit level,
%   LSB first (k = numShapedBitLevels down to 1), so each level's LLR target
%   can condition on the already-decided less-significant levels.
%
%   Input:
%     block_length : E_s, the DM block length (= number of output symbols)
%     list_size    : SCL list size passed to nr5g.internal.polar.decode
%     input_bits   : flat info-bit stream for this block, sum(n_info) long
%     n_info       : 1 x numShapedBitLevels, info-bit count per level (Ks)
%     p_bit_cond   : 1 x numShapedBitLevels cell, per-level conditional p(b=1)
%
%   Output:
%     out : block_length x 1, symbol-group index (1..effectiveAlphabetSize)

num_levels = obj.numShapedBitLevels;
input_bits = int8(input_bits(:));

endIdx   = cumsum(n_info);
startIdx = [1, endIdx(1:end-1) + 1];

shaped_bits = zeros(block_length, num_levels, 'int8');

for k = num_levels:-1:1
    k_b = n_info(k);
    bits_k = input_bits(startIdx(k):endIdx(k));

    E_s = block_length;
    k_s = E_s - k_b;

    F = toolbox.ProbShaping.ecc.polarConstruct(k_s, E_s, ceil(log2(E_s)));
    N = length(F);
    tx_mask = toolbox.ProbShaping.ecc.getTransmittedMask(N, k_s, E_s);
    info_pos = find(F == 1 & tx_mask);
    assert(length(info_pos) == k_b, ...
        "toolbox:EccInfoMismatch", ...
        "level %d: frozen&transmitted count %d ~= k_b %d", k, length(info_pos), k_b);

    % --- Step 1: Pre-encode information ------------------------------
    u_pre = zeros(N, 1, 'int8');
    u_pre(info_pos) = bits_k;
    c_pre = toolbox.ProbShaping.ecc.polarTransform(u_pre);
    c_1   = toolbox.ProbShaping.ecc.ecc.rate_match(c_pre, k_s, E_s);

    % --- Step 2: Conditional LLR target ------------------------------
    if k == num_levels
        p_target = log((1 - p_bit_cond{k}) / p_bit_cond{k});
    else
        weights  = 2 .^ (num_levels - k - 1 : -1 : 0).';
        context  = double(shaped_bits(:, k+1:end)) * weights;
        p_1_cond = p_bit_cond{k}(context + 1);
        p_1_cond = p_1_cond(:);
        p_target = log((1 - p_1_cond) ./ p_1_cond);
    end
    llr_masked = double(p_target) .* (1 - 2 * double(c_1));

    % --- Step 3: De-rate-match and SC-List decode ---------------------
    llr_full = toolbox.ProbShaping.ecc.ecc.de_rate_match(llr_masked, k_s, N);
    crcLen=0;
    padCRC=false;
    rnti=0;
    qPC=[];
    u_hat = nr5g.internal.polar.decode(llr_full, F, list_size, false,crcLen,padCRC,rnti,qPC);

    % --- Step 4: Encode cover code and rate-match ---------------------
    u_full = zeros(N, 1, 'int8');
    u_full(F == 0) = int8(u_hat);
    c_cover    = toolbox.ProbShaping.ecc.polarTransform(u_full);
    c_cover_rm = toolbox.ProbShaping.ecc.ecc.rate_match(c_cover, k_s, E_s);

    % --- Step 5: XOR ---------------------------------------------------
    shaped_bits(:, k) = bitxor(int8(c_1), int8(c_cover_rm));
end

% Invert obj.bitLabel to map each symbol's per-level bit pattern to its
% group index (same table-inversion pattern as decode.m's inv_bit_label).
weights = 2 .^ (num_levels-1:-1:0).';
label_ints = double(obj.bitLabel) * weights;
inv_bit_label = zeros(2 ^ num_levels, 1);
inv_bit_label(label_ints + 1) = (1:size(obj.bitLabel, 1)).';
symbol_ints = double(shaped_bits) * weights;
out = inv_bit_label(symbol_ints + 1);
end
