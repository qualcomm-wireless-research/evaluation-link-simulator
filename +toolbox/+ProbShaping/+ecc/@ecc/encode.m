function data_bits_out = encode(obj, data_bits)
%ENCODE ECC (multi-level polar) shaping encoder returning amplitude bit labels.
data_bits = int8(data_bits(:).');
num_bits = obj.numBitsPerCodeword;

if numel(data_bits) ~= num_bits
    error("toolbox:InvalidEccInputLength", ...
        "ECC shaper expected %d input bits for this CB, got %d.", ...
        num_bits, numel(data_bits));
end

symbols_out = zeros(obj.constLenPerCodeword, 1);
write_idx = 1;
read_idx = 1;
for block_idx = 1:obj.nShapedBlocks-obj.numResidualBlock
    input_range = read_idx:(read_idx + sum(obj.nShaperBitsReg) - 1);
    current_symbols = obj.encodeBlock(obj.nMax, obj.list_size, double(data_bits(input_range)).', obj.nShaperBitsReg, obj.p_bit_cond_nMax);
    output_range = write_idx:(write_idx + obj.nMax - 1);
    symbols_out(output_range) = current_symbols;
    read_idx = read_idx + sum(obj.nShaperBitsReg);
    write_idx = write_idx + obj.nMax;
end

for idx = 1:obj.numResidualBlock
    input_range = read_idx:(read_idx + sum(obj.nShaperBitsLast) - 1);
    current_symbols = obj.encodeBlock(obj.nLast,  obj.list_size, double(data_bits(input_range)).', obj.nShaperBitsLast, obj.p_bit_cond_nLast);
    output_range = write_idx:(write_idx + obj.nLast - 1);
    symbols_out(output_range) = current_symbols;
    read_idx = read_idx + sum(obj.nShaperBitsLast);
    write_idx = write_idx + obj.nLast;
end

data_bits_out = obj.bitLabel(symbols_out(:), :);
data_bits_out = reshape(data_bits_out.', [], 1);
data_bits_out = [data_bits_out(1:end/2).'; data_bits_out(end/2 + 1:end).'];
data_bits_out = int8(reshape(data_bits_out, [], 1));
end
