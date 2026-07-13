function [binary_mantissa, dec_mantissa, exponent, reconstructed_num] = dec2binFloat(decimal_num, mantissa_bits)
%DEC2BINFLOAT Convert a decimal number to a fixed-mantissa binary floating-point form.
if mantissa_bits < 1
    error("toolbox:InvalidEssMantissa", "Mantissa bit count must be positive.");
end

if decimal_num < 0
    sign_char = '-';
    abs_num = abs(decimal_num);
else
    sign_char = '';
    abs_num = decimal_num;
end

if abs_num == 0
    binary_mantissa = '0';
    dec_mantissa = 0;
    exponent = 0;
    reconstructed_num = 0;
    return;
end

exponent = floor(log2(abs_num));
normalized_num = abs_num / (2 ^ exponent);
if normalized_num >= 2
    normalized_num = normalized_num / 2;
    exponent = exponent + 1;
elseif normalized_num < 1
    normalized_num = normalized_num * 2;
    exponent = exponent - 1;
end

mantissa_bin = '1.';
current_num = normalized_num - 1;
for idx = 1:(mantissa_bits - 1)
    current_num = current_num * 2;
    if current_num >= 1
        mantissa_bin = [mantissa_bin, '1']; %#ok<AGROW>
        current_num = current_num - 1;
    else
        mantissa_bin = [mantissa_bin, '0']; %#ok<AGROW>
    end
end

binary_mantissa = [sign_char, mantissa_bin];
point_index = strfind(binary_mantissa, '.');
dec_mantissa = str2double(binary_mantissa(1:point_index - 1)) ...
    + sum((binary_mantissa(point_index + 1:end) == '1') .* 2 .^ (-1:-1:-(mantissa_bits - 1)));
reconstructed_num = dec_mantissa * (2 ^ exponent) * (1 - 2 * (decimal_num < 0));
end