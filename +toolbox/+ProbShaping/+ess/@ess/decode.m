function data_bits_out = decode(obj, shaped_bit_labels)
%DECODE ESS shaping decoder inverting obj.encode.
%
%   Consumes the length-(constLenPerCodeword * numShapedBitLevels)
%   bit-label stream produced by encode(data_bits) and returns the
%   length-numBitsPerCodeword info bits fed into that encode call.

shaped_bit_labels = int8(shaped_bit_labels(:));
shaped_bit_level = obj.numShapedBitLevels;
num_symbols = obj.constLenPerCodeword;
expected_len = num_symbols * shaped_bit_level;

if numel(shaped_bit_labels) ~= expected_len
    error("toolbox:InvalidEssInputLength", ...
        "ESS decode expected %d input bits for this CB, got %d.", ...
        expected_len, numel(shaped_bit_labels));
end

% Invert encode's real/imag row-pair stacking and transpose-flatten
% to recover the per-symbol bit-label matrix (N x L).
pair = reshape(shaped_bit_labels, 2, []);
unstacked = [pair(1, :), pair(2, :)];
bit_label_matrix = reshape(unstacked, shaped_bit_level, num_symbols).';

% Invert obj.bitLabel via a 2^L LUT keyed by MSB-first bit integer.
weights = 2 .^ ((shaped_bit_level - 1):-1:0).';
label_ints = double(obj.bitLabel) * weights;
inv_bit_label = zeros(2 ^ shaped_bit_level, 1);
inv_bit_label(label_ints + 1) = (1:size(obj.bitLabel, 1)).';
symbol_ints = double(bit_label_matrix) * weights;
symbols_in = inv_bit_label(symbol_ints + 1);

data_bits_out = zeros(obj.numBitsPerCodeword, 1, 'int8');
read_idx = 1;
write_idx = 1;
for block_idx = 1:(obj.nShapedBlocks - obj.numResidualBlock)
    symbol_range = read_idx:(read_idx + obj.nMax - 1);
    current_bits = obj.decodeBlock( ...
        obj.nMax, obj.maxEnergyReg, symbols_in(symbol_range));
    output_range = write_idx:(write_idx + obj.nShaperBitsReg - 1);
    data_bits_out(output_range) = int8(current_bits);
    read_idx = read_idx + obj.nMax;
    write_idx = write_idx + obj.nShaperBitsReg;
end

for idx = 1:obj.numResidualBlock
    symbol_range = read_idx:(read_idx + obj.nLast - 1);
    current_bits = obj.decodeBlock( ...
        obj.nLast, obj.maxEnergyLast, symbols_in(symbol_range));
    output_range = write_idx:(write_idx + obj.nShaperBitsLast - 1);
    data_bits_out(output_range) = int8(current_bits);
    read_idx = read_idx + obj.nLast;
    write_idx = write_idx + obj.nShaperBitsLast;
end
end