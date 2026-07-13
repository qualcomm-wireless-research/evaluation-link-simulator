function obj = initialize(obj, modulation, energy_table, nuMb, const_len_per_codeword, shaped_bit_level, n_max, n_mantissa)
%INITIALIZE Initialize ESS state for one NR code block shaping allocation.

obj.constLenPerCodeword = const_len_per_codeword;
obj.numShapedBitLevels = shaped_bit_level;
obj.nMax = n_max;
obj.nMantissa = n_mantissa;
obj.energyTable=energy_table;


bits_per_symbol = toolbox.phy.pdsch.bits_per_symbol(modulation);
qam_size = 2 ^ bits_per_symbol;
num_amplitude_levels = 2 ^ (bits_per_symbol / 2 - 1);

if obj.numShapedBitLevels < 1 || obj.numShapedBitLevels > log2(num_amplitude_levels)
    error("toolbox:InvalidEssShapingLevels", ...
        "ESS supports 1 to %d shaped amplitude bit level(s) for %s.", ...
        log2(num_amplitude_levels), modulation);
end


num_unshaped_bit_levels = log2(qam_size) / 2 - 1 - obj.numShapedBitLevels;
obj.constellation = 1:2:2*2^obj.numShapedBitLevels;
obj.nuMb = nuMb * 4 ^ num_unshaped_bit_levels;
obj.effectiveAlphabetSize = length(obj.constellation);

obj.nShapedBlocks = ceil(const_len_per_codeword / n_max);
obj.nLast = mod(const_len_per_codeword, n_max);


obj.prob = toolbox.ProbShaping.ess.mbDistribution(obj.effectiveAlphabetSize, obj.nuMb, 'Amplitude').';

[obj.nShaperBitsReg,obj.maxEnergyReg] = obj.compute_num_info(obj.nMax);

obj.numResidualBlock=0;
if obj.nLast>0 && obj.nShapedBlocks>=2
    n_total_last=obj.nMax+obj.nLast;
    assert(mod(n_total_last,2)==0, 'ESS segmentation_method=1 requires residual #shaped symbols to be even.');
    obj.nLast=n_total_last/2;
    obj.numResidualBlock=2;
    [obj.nShaperBitsLast,obj.maxEnergyLast] = obj.compute_num_info(obj.nLast);
elseif obj.nLast>0
    obj.numResidualBlock=1;
    [obj.nShaperBitsLast,obj.maxEnergyLast] = obj.compute_num_info(obj.nLast);
end

obj.modulation = string(modulation);
obj.qamSize = qam_size;


obj.entropySource = -sum(obj.prob(obj.prob > 0) .* log2(obj.prob(obj.prob > 0)));
obj.numBitsPerCodeword = (obj.nShapedBlocks-obj.numResidualBlock) * obj.nShaperBitsReg + obj.numResidualBlock*obj.nShaperBitsLast;
obj.bitLabel = toolbox.ProbShaping.ess.ess.amplitudeGroupBitPatterns(shaped_bit_level);
end