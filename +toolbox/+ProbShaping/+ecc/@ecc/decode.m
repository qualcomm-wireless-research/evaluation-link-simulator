function data_bits_out = decode(obj, shaped_bit_labels)
%  DECODE Multi-level polar shaping decoder (ECC) inverting obj.encode
%
%   Consumes the length-(constLenPerCodeword * numShapedBitLevels)
%   bit-label stream produced by encode(data_bits) and returns the
%   length-numBitsPerCodeword info bits fed into that encode call.

shaped_bit_labels = int8(shaped_bit_labels(:));
shaped_bit_level = obj.numShapedBitLevels;
num_symbols = obj.constLenPerCodeword;
expected_len = num_symbols * shaped_bit_level;

if numel(shaped_bit_labels) ~= expected_len
    error("toolbox:InvalidEccInputLength", ...
        "ECC shaper decode expected %d input bits for this CB, got %d.", ...
        expected_len, numel(shaped_bit_labels));
end

pair = reshape(shaped_bit_labels, 2, []);
unstacked = [pair(1, :), pair(2, :)];
bit_label_matrix = reshape(unstacked, shaped_bit_level, num_symbols).';

data_bits_out = zeros(obj.numBitsPerCodeword, 1, 'int8');
read_idx = 1;
write_idx = 1;
for block_idx = 1:(obj.nShapedBlocks - obj.numResidualBlock)
    symbol_range = read_idx:(read_idx + obj.nMax - 1);
    current_bits = obj.decodeBlock( ...
        obj.nMax, bit_label_matrix(symbol_range, :), obj.nShaperBitsReg);
    output_range = write_idx:(write_idx + sum(obj.nShaperBitsReg) - 1);
    data_bits_out(output_range) = current_bits;
    read_idx = read_idx + obj.nMax;
    write_idx = write_idx + sum(obj.nShaperBitsReg);
end

for idx = 1:obj.numResidualBlock
    symbol_range = read_idx:(read_idx + obj.nLast - 1);
    current_bits = obj.decodeBlock( ...
        obj.nLast, bit_label_matrix(symbol_range, :), obj.nShaperBitsLast);
    output_range = write_idx:(write_idx + sum(obj.nShaperBitsLast) - 1);
    data_bits_out(output_range) = current_bits;
    read_idx = read_idx + obj.nLast;
    write_idx = write_idx + sum(obj.nShaperBitsLast);
end
end
