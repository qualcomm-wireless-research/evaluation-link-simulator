function out = decodeBlock(obj, block_length, max_energy, symbols_in)
% Incremental-window decoder, exact inverse of obj.encodeBlock:
% symbol index 1 (most probable branch) needs no accumulation at
% all, and other branches extend the comparison window only by
% the delta of new bits since the previous branch's window.

alphabet_size = obj.effectiveAlphabetSize;
mantissa_bits = obj.nMantissa;
mantissas = obj.energyTable{1};
exponents = obj.energyTable{2};

symbols = 1:2:alphabet_size * 2;
energy_steps = (symbols .^ 2 - 1) / 8;

residual_energy_max = max_energy;   % class stores Lmax (residual-energy index) directly
input_length = exponents(block_length + 1, residual_energy_max);
residual_energy = residual_energy_max - sum(energy_steps(symbols_in));

output_bits = zeros(input_length + 1 + mantissa_bits, 1);
for symbol_idx = 1:block_length
    current_symbol = symbols_in(block_length - symbol_idx + 1);
    row = symbol_idx;
    residual_energy = residual_energy + energy_steps(current_symbol);

    if current_symbol == 1
        continue;
    end

    low_exponent = exponents(row + 1, residual_energy);
    bit_start = input_length - low_exponent + 1;

    compare_value = 0;
    bit_end_prev = bit_start - 1;

    for alphabet_idx = 1:(current_symbol - 1)
        l_pred = residual_energy - energy_steps(alphabet_idx);
        if l_pred < 1
            continue;   % branch unreachable: insufficient energy
        end

        bit_end_cur = input_length - exponents(row, l_pred) + mantissa_bits + 1;

        delta = bit_end_cur - bit_end_prev;
        if delta > 0
            new_bits = output_bits(bit_end_prev + 1:bit_end_cur);
            compare_value = compare_value * 2 ^ delta + ...
                new_bits' * (2 .^ (delta - 1:-1:0))';
        end

        compare_value = compare_value + mantissas(row, l_pred);
        bit_end_prev = bit_end_cur;
    end

    output_bits(bit_start:bit_end_cur) = obj.integerToBits( ...
        compare_value, bit_end_cur - bit_start + 1);
end
out = output_bits(2:input_length + 1);
end