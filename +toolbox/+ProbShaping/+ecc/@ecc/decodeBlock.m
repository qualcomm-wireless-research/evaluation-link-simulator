function out = decodeBlock(obj, block_length, shaped_bits, n_info)
%DECODEBLOCK Multi-level polar shaping decoder for one DM block
%
%   Input:
%     block_length : E_s, the DM block length (= number of input symbols)
%     shaped_bits  : block_length x numShapedBitLevels int8, received
%                    per-level bit-label matrix (same layout encodeBlock's
%                    internal shaped_bits has before its symbol-index step)
%     n_info       : 1 x numShapedBitLevels, info-bit count per level (Ks)
%
%   Output:
%     out : sum(n_info) x 1, recovered message bits, level-major (same
%           startIdx/endIdx layout encodeBlock's input_bits used)

num_levels = obj.numShapedBitLevels;

endIdx   = cumsum(n_info);
startIdx = [1, endIdx(1:end-1) + 1];
out = zeros(endIdx(end), 1, 'int8');

for k = num_levels:-1:1
    k_b = n_info(k);
    E_s = block_length;
    k_s = E_s - k_b;

    F = toolbox.ProbShaping.ecc.polarConstruct(k_s, E_s, ceil(log2(E_s)));
    N = length(F);
    tx_mask = toolbox.ProbShaping.ecc.getTransmittedMask(N, k_s, E_s);
    info_pos = find(F == 1 & tx_mask);
    assert(length(info_pos) == k_b, ...
        "toolbox:EccInfoMismatch", ...
        "level %d: frozen&transmitted count %d ~= k_b %d", k, length(info_pos), k_b);

    % Step 1: inverse rate matching -> full-length mother codeword.
    c_rm   = double(shaped_bits(:, k));
    c_full = toolbox.ProbShaping.ecc.ecc.de_rate_match(c_rm, k_s, N);
    c_full = int8(mod(round(c_full), 2));

    % Step 2: invert the polar transform (involution over GF(2)).
    u_final_hat = toolbox.ProbShaping.ecc.polarTransform(c_full);

    % Step 3: message bits live at info_pos; shaping bits are discarded.
    out(startIdx(k):endIdx(k)) = int8(u_final_hat(info_pos));
end
end
