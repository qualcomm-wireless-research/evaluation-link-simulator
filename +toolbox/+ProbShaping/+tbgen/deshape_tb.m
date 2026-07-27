function source_bits = deshape_tb(transport_block, shaping_info)
%DESHAPE_TB Recover PS payload source bits from a decoded transport block.
%
% Inverts build_tb_for_ps: for each CB, slices the [punctured; unshaped_before;
% shaped; unshaped_after] region out of the TB, undoes the SBPM deinterleave,
% runs the PS codec's decode on the shaped bits, then reassembles source bits
% in the same order build_tb_for_ps consumed them:
%   [shaped_info; punctured; unshaped_before; unshaped_after]
% Concatenating over CBs yields the length-payloadTransportBlockLength vector
% that build_tb_for_ps started from.

if ~isfield(shaping_info, 'enabled') || ~logical(shaping_info.enabled)
    error("toolbox:DeshapeRequiresPs", ...
        "deshape_tb requires shaping_info.enabled = true.");
end

transport_block = int8(transport_block(:));
if numel(transport_block) ~= shaping_info.chainTransportBlockLength
    error("toolbox:InvalidTbLength", ...
        "TB length %d does not match chainTransportBlockLength %d.", ...
        numel(transport_block), shaping_info.chainTransportBlockLength);
end

qam_deinterleave = 4 ^ shaping_info.num_shaped_bit_levels;
source_bits = zeros(shaping_info.payloadTransportBlockLength, 1, 'int8');
tb_cursor = 1;
src_cursor = 1;

for i_cb = 1:shaping_info.num_cb
    cb_plan = shaping_info.codeBlocks(i_cb);

    [punctured_bits, tb_cursor] = take_bits( ...
        transport_block, tb_cursor, cb_plan.numPayloadPuncturedBits);
    [unshaped_before_bits, tb_cursor] = take_bits( ...
        transport_block, tb_cursor, cb_plan.numPayloadUnshapedBitsBeforeShaped);
    [shaped_bits, tb_cursor] = take_bits( ...
        transport_block, tb_cursor, cb_plan.numShapedBits);
    [unshaped_after_bits, tb_cursor] = take_bits( ...
        transport_block, tb_cursor, cb_plan.numPayloadUnshapedBitsAfterShaped);

    shaped_pre_deinterleave = toolbox.ProbShaping.mapping.sbpm_interleave( ...
        shaped_bits, qam_deinterleave);
    shaped_info_bits = int8(cb_plan.codecState.decode(shaped_pre_deinterleave));

    cb_source = [shaped_info_bits; punctured_bits; unshaped_before_bits; unshaped_after_bits];
    source_bits(src_cursor:(src_cursor + numel(cb_source) - 1)) = cb_source;
    src_cursor = src_cursor + numel(cb_source);
end

if tb_cursor - 1 ~= numel(transport_block)
    error("toolbox:DeshapeTbCursor", ...
        "Deshape consumed %d TB bits, expected %d.", ...
        tb_cursor - 1, numel(transport_block));
end
if src_cursor - 1 ~= numel(source_bits)
    error("toolbox:DeshapeSrcCursor", ...
        "Deshape produced %d source bits, expected %d.", ...
        src_cursor - 1, numel(source_bits));
end
end

function [bits, next_idx] = take_bits(tb, tb_idx, num_bits)
if num_bits == 0
    bits = zeros(0, 1, 'int8');
    next_idx = tb_idx;
    return;
end
next_idx = tb_idx + num_bits;
if next_idx - 1 > numel(tb)
    error("toolbox:DeshapeTbOverrun", ...
        "Deshape TB slice ran past end (need %d, have %d).", ...
        next_idx - 1, numel(tb));
end
bits = tb(tb_idx:(next_idx - 1));
end
