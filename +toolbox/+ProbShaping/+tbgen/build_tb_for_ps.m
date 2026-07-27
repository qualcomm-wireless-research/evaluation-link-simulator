function [transport_block, source_bits] = build_tb_for_ps(shaping_info)
%BUILD_TB_FOR_PS Build the PS transport block.
%
% CRC insertion stays NR-owned (`nrDLSCH`).
% This helper extracts source_bits from the CRC-stripped transport block after decoding for deshaping

payload_len = shaping_info.payloadTransportBlockLength;
source_bits = randi([0 1], payload_len, 1, 'int8');
transport_block = [];
source_idx = 1;

for i_cb = 1:shaping_info.num_cb
    cb_plan = shaping_info.codeBlocks(i_cb);

    [data_bits_prior_shaping, source_idx] = take_bits( ...
        source_bits, source_idx, cb_plan.numInfoBits, payload_len, i_cb);
    [data_punctured_bits, source_idx] = take_bits( ...
        source_bits, source_idx, cb_plan.numPayloadPuncturedBits, payload_len, i_cb);
    [data_unshaped_before_bits, source_idx] = take_bits( ...
        source_bits, source_idx, cb_plan.numPayloadUnshapedBitsBeforeShaped, ...
        payload_len, i_cb);
    [data_unshaped_bits, source_idx] = take_bits( ...
        source_bits, source_idx, cb_plan.numPayloadUnshapedBitsAfterShaped, ...
        payload_len, i_cb);

    data_shaped_bits = int8(cb_plan.codecState.encode(data_bits_prior_shaping));

    data_shaped_bits = toolbox.ProbShaping.mapping.sbpm_deinterleave( ...
        data_shaped_bits, 4^shaping_info.num_shaped_bit_levels);

    transport_block = [transport_block; data_punctured_bits; data_unshaped_before_bits; ...
         data_shaped_bits; data_unshaped_bits];
end


end

function [bits, next_idx] = take_bits(source_bits, bit_idx, num_bits, payload_len, i_cb)
next_idx = bit_idx + num_bits;
if next_idx - 1 > payload_len
    error("toolbox:InvalidSourceBitCursor", ...
        "CB %d overran payload source bits (%d of %d).", ...
        i_cb, next_idx - 1, payload_len);
end
if num_bits == 0
    bits = zeros(0, 1, 'int8');
else
    bits = source_bits(bit_idx:(next_idx - 1));
end
end
