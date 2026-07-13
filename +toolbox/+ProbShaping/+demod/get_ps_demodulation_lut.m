function [constellation, bit_labels, zero_masks, one_masks] = get_ps_demodulation_lut(modulation)
%GETPSDEMODULATIONLUT Get PS demodulation lookup table with caching.

persistent cached_luts
if isempty(cached_luts)
    cached_luts = struct();
end

key = matlab.lang.makeValidName(lower(char(string(modulation))));
if isfield(cached_luts, key)
    lut = cached_luts.(key);
    constellation = lut.constellation;
    bit_labels = lut.bitLabels;
    zero_masks = lut.zeroMasks;
    one_masks = lut.oneMasks;
    return;
end

bits_per_symbol = toolbox.phy.pdsch.bits_per_symbol(modulation);

bit_patterns = int8(dec2bin(0:(2 ^ bits_per_symbol - 1), bits_per_symbol) - '0');
mod_input_bits = reshape(bit_patterns.', [], 1);
constellation = nrSymbolModulate(mod_input_bits, modulation);
constellation = constellation(:);
bit_labels = logical(bit_patterns);
zero_masks = cell(1, bits_per_symbol);
one_masks = cell(1, bits_per_symbol);

for bit_idx = 1:bits_per_symbol
    zero_masks{bit_idx} = ~bit_labels(:, bit_idx);
    one_masks{bit_idx} = bit_labels(:, bit_idx);
end

lut = struct();
lut.constellation = constellation;
lut.bitLabels = bit_labels;
lut.zeroMasks = zero_masks;
lut.oneMasks = one_masks;
cached_luts.(key) = lut;
end
