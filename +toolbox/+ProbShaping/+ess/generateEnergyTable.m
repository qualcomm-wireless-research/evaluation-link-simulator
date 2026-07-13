function [mantissa_dec, exponent, max_energy_init] = generateEnergyTable(n_max, nuMb, alphabet_size, mantissa_bits)
%GENERATEENERGYTABLE Precompute the ESS arithmetic-coding energy table.
symbols = 1:2:2 * alphabet_size - 1;
symbol_energy = (symbols .^ 2 - 1) / 8;

prob = toolbox.ProbShaping.ess.mbDistribution(alphabet_size, nuMb,'Amplitude');

max_energy_init = symbols .^ 2 * prob * n_max;
max_residual_energy = floor((max_energy_init - n_max) / 8) + 1;

if symbol_energy(end) >= max_residual_energy
    symbol_energy = symbol_energy(symbol_energy < max_residual_energy);
end

count_table = zeros(n_max + 1, max_residual_energy);
quant_count_table = zeros(n_max + 1, max_residual_energy);
mantissa_dec = zeros(n_max + 1, max_residual_energy);
exponent = zeros(n_max + 1, max_residual_energy);

count_table(1, :) = 1;
quant_count_table(1, :) = 1;
mantissa_dec(1, :) = 1;

for n_value = 2:n_max + 1
    for residual_energy = 1:max_residual_energy
        residual_hypotheses = residual_energy - symbol_energy;
        valid_residuals = residual_hypotheses(residual_hypotheses >= 1);
        count_table(n_value, residual_energy) = sum(count_table(n_value - 1, valid_residuals));

        val = sum(quant_count_table(n_value - 1, valid_residuals));
        [~, dec_mantissa, exponent_value, reconstructed_num] = ...
            toolbox.ProbShaping.ess.dec2binFloat(val, mantissa_bits);

        mantissa_dec(n_value, residual_energy) = dec_mantissa;
        exponent(n_value, residual_energy) = exponent_value;
        quant_count_table(n_value, residual_energy) = reconstructed_num;
    end
end

mantissa_dec = mantissa_dec .* 2 ^ (mantissa_bits - 1);
end