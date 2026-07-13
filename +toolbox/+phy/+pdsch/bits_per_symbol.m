function out = bits_per_symbol(modulation)
%BITS_PER_SYMBOL Convert between NR modulation name and bits per symbol.
%   OUT = BITS_PER_SYMBOL(MODULATION) accepts either a modulation name
%   ("16QAM"/"64QAM"/"256QAM"/"1024QAM") and returns the numeric bits per
%   symbol, or a numeric bits-per-symbol value and returns the modulation
%   name as a char row vector.

names = ["16QAM" "64QAM" "256QAM" "1024QAM"];
bps   = [4       6       8        10];

if isnumeric(modulation)
    idx = find(bps == double(modulation), 1);
    if isempty(idx)
        error("toolbox:UnsupportedShapingModulation", ...
            "Unsupported PS bits-per-symbol value %d.", modulation);
    end
    out = char(names(idx));
else
    idx = find(upper(string(modulation)) == names, 1);
    if isempty(idx)
        error("toolbox:UnsupportedShapingModulation", ...
            "Unsupported PS modulation %s.", modulation);
    end
    out = bps(idx);
end
end
