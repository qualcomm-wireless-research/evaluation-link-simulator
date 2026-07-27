function [symbols, info] = new_pdsch(carrier, pdsch, codeword_bits, shaping_info)
%NEWPDSCH Shared NR/PS PDSCH scrambling, modulation, and layer mapping.

if nargin < 4 || isempty(shaping_info)
    shaping_info = struct('enabled', false);
end

codeword_bits = int8(codeword_bits(:));
is_ps_path = isfield(shaping_info, 'enabled') && logical(shaping_info.enabled);
if is_ps_path
    [scrambled_bits, info] = toolbox.ProbShaping.mapping.ps_scramble( ...
        codeword_bits, shaping_info);
    mapped_bits = info.mappedBits;
    info.sourceBits = codeword_bits;
else
    mapped_bits = codeword_bits;
    scrambling_sequence = toolbox.phy.pdsch.get_pdsch_scrambling_sequence( ...
        carrier, pdsch, numel(mapped_bits), false);
    scrambled_bits = int8(xor(logical(mapped_bits), scrambling_sequence));
    info = struct();
    info.sourceBits = zeros(0, 1, 'int8');
end

% QAM mapping & layer mapping
modulated_symbols = nrSymbolModulate(scrambled_bits, pdsch.Modulation);
symbols = nrLayerMap(modulated_symbols, pdsch.NumLayers);

avg_energy = mean(mean(abs(symbols) .^ 2));

% Debug probe: shaped 2-bit groups after QAM modulation and layer mapping.

% PS power scaling
info.psPowerScaling = 1.0;

if is_ps_path %% perform PS power scaling to normalize Tx power
    if isfield(shaping_info, 'txScaling')
        tx_scaling = lower(string(shaping_info.txScaling));
    else
        tx_scaling = "empirical"; %%default txScaling mode
    end

    switch char(tx_scaling)
        case 'empirical'
            target_energy = 1.0;
            info.psPowerScaling = target_energy / avg_energy;
        case 'lut'
            info.psPowerScaling = shaping_info.psPowerScaling;
        otherwise
            error("toolbox:InvalidPsTxScaling", ...
                "Unsupported shaping.txScaling '%s'.", tx_scaling);
    end
    symbols = sqrt(info.psPowerScaling) * symbols;
    
end
info.averageSymbolEnergy = mean(mean(abs(symbols) .^ 2));
info.mappedBits = mapped_bits;
info.scrambledBits = scrambled_bits;
end
