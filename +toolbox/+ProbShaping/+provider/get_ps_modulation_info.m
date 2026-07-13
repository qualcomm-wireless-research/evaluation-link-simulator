function modulation_info = get_ps_modulation_info(modulation)
%GETPSMODULATIONINFO Get PS modulation metadata with caching.

persistent cached_infos
if isempty(cached_infos)
    cached_infos = struct();
end

% Accept either a modulation name (e.g. "256QAM") or a numeric bits-per-symbol
% value so callers that already hold bitsPerSymbol need not round-trip through
% a modulation-name string.
if isnumeric(modulation)
    bits_per_symbol = double(modulation);
    modulation_name = toolbox.phy.pdsch.bits_per_symbol(bits_per_symbol);
else
    modulation_name = char(string(modulation));
    bits_per_symbol = toolbox.phy.pdsch.bits_per_symbol(modulation_name);
end

key = matlab.lang.makeValidName(lower(modulation_name));
if isfield(cached_infos, key)
    modulation_info = cached_infos.(key);
    return;
end
num_amplitude_bits_per_dimension = bits_per_symbol / 2 - 1;
num_amplitude_levels = 2 ^ num_amplitude_bits_per_dimension;
real_bit_positions = 1:2:bits_per_symbol;
imag_bit_positions = 2:2:bits_per_symbol;

modulation_info = struct();
modulation_info.bitsPerSymbol = bits_per_symbol;
modulation_info.numAmplitudeBitsPerDimension = num_amplitude_bits_per_dimension;
modulation_info.numAmplitudeLevels = num_amplitude_levels;
modulation_info.amplitudes = 1:2:(2 * num_amplitude_levels - 1);
modulation_info.realBitPositions = real_bit_positions;
modulation_info.imagBitPositions = imag_bit_positions;
modulation_info.realAmplitudeBitPositions = real_bit_positions(2:end);
modulation_info.imagAmplitudeBitPositions = imag_bit_positions(2:end);
cached_infos.(key) = modulation_info;
end
