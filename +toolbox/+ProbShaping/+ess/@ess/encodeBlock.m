function out = encodeBlock(obj, block_length, max_energy, input_bits)
% Incremental-window encoder: extends the comparison window per
% branch only to that branch's own predecessor exponent (no
% downshifting), and never explicitly compares the last
% alphabet index — it wins by elimination. Operates on "infinite" precision,
% no finite-precision quantization involved.  


alphabet_size = obj.effectiveAlphabetSize;
mantissa_bits = obj.nMantissa;

input_length = length(input_bits);
input_bits = [0; input_bits(:); zeros(mantissa_bits, 1)];
mantissas = obj.energyTable{1};
exponents = obj.energyTable{2};

symbols = 1:2:alphabet_size * 2;
energy_steps = (symbols .^ 2 - 1) / 8;
out = zeros(block_length, 1);
residual_energy = max_energy;

for symbol_idx = 1:block_length
    row = block_length + 2 - symbol_idx;
    low_exponent = exponents(row, residual_energy);
    bit_start = input_length - low_exponent + 1;

    compare_value = 0;
    bit_end_prev = bit_start - 1;
    chosen = alphabet_size;

    for alphabet_idx = 1:alphabet_size - 1
        l_pred = residual_energy - energy_steps(alphabet_idx);
        upper_exponent = exponents(row - 1, l_pred);
        upper_mantissa = mantissas(row - 1, l_pred);

        bit_end_cur = input_length - upper_exponent + mantissa_bits + 1;
        delta = bit_end_cur - bit_end_prev;
        if delta > 0
            new_bits = input_bits(bit_end_prev + 1:bit_end_cur);
            compare_value = compare_value * 2 ^ delta + ...
                new_bits' * (2 .^ (delta - 1:-1:0))';
        end

        if compare_value < upper_mantissa
            chosen = alphabet_idx;
            break;
        end
        compare_value = compare_value - upper_mantissa;
        bit_end_prev = bit_end_cur;
    end

    out(symbol_idx) = chosen;
    residual_energy = residual_energy - energy_steps(chosen);

    input_bits(bit_start:bit_end_cur) = obj.integerToBits( ...
        compare_value, bit_end_cur - bit_start + 1);
end
end