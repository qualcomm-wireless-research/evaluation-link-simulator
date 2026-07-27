function obj = initialize(obj, modulation, nuMb, const_len_per_codeword, shaped_bit_level, n_max, list_size)
%INITIALIZE Initialize ECC (multi-level polar shaping) codec for one NR code block shaping allocation.

obj.constLenPerCodeword = const_len_per_codeword;
obj.numShapedBitLevels = shaped_bit_level;
obj.nMax = n_max;
obj.list_size = list_size;


bits_per_symbol = toolbox.phy.pdsch.bits_per_symbol(modulation);
qam_size = 2 ^ bits_per_symbol;
num_amplitude_levels = 2 ^ (bits_per_symbol / 2 - 1);

if obj.numShapedBitLevels < 1 || obj.numShapedBitLevels > log2(num_amplitude_levels)
    error("toolbox:InvalidEccShapingLevels", ...
        "ECC shaper supports 1 to %d shaped amplitude bit level(s) for %s.", ...
        log2(num_amplitude_levels), modulation);
end


num_unshaped_bit_levels = log2(qam_size) / 2 - 1 - obj.numShapedBitLevels;
obj.constellation = 1:2:2*2^obj.numShapedBitLevels;
obj.nuMb = nuMb * 4 ^ num_unshaped_bit_levels;
obj.effectiveAlphabetSize = length(obj.constellation);

obj.nShapedBlocks = ceil(const_len_per_codeword / n_max);
obj.nLast = mod(const_len_per_codeword, n_max);

obj.prob = toolbox.ProbShaping.ess.mbDistribution(obj.effectiveAlphabetSize, obj.nuMb, 'Amplitude').';

[obj.nShaperBitsReg, obj.p_bit_cond_nMax] = obj.compute_num_info(obj.nMax);

obj.numResidualBlock=0;
if obj.nLast>0 && obj.nShapedBlocks>=2
    n_total_last=obj.nMax+obj.nLast;
    assert(mod(n_total_last,2)==0, 'PS segmentation requires residual #shaped symbols to be even.');
    obj.nLast=n_total_last/2;
    obj.numResidualBlock=2;
    [obj.nShaperBitsLast, obj.p_bit_cond_nLast] = obj.compute_num_info(obj.nLast);
elseif obj.nLast>0
    obj.numResidualBlock=1;
    [obj.nShaperBitsLast, obj.p_bit_cond_nLast] = obj.compute_num_info(obj.nLast);
end

obj.modulation = string(modulation);
obj.qamSize = qam_size;


obj.entropySource = -sum(obj.prob(obj.prob > 0) .* log2(obj.prob(obj.prob > 0)));
obj.numBitsPerCodeword = (obj.nShapedBlocks-obj.numResidualBlock) * sum(obj.nShaperBitsReg) + obj.numResidualBlock*sum(obj.nShaperBitsLast);
obj.bitLabel = toolbox.ProbShaping.ecc.ecc.amplitudeGroupBitPatterns(shaped_bit_level);

end
