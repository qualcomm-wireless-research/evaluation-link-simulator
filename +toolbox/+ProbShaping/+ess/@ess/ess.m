classdef ess
%ESS ESS shaping codec for one NR code block shaping allocation.

    properties (SetAccess = private)
        modulation
        qamSize
   
        nuMb
        constLenPerCodeword
        numShapedBitLevels
        nMax
        nMantissa
        constellation
        prob
        entropySource
        effectiveAlphabetSize
        nShapedBlocks
        nShaperBitsReg
        energyTable
        maxEnergyReg
        nLast=0
        nShaperBitsLast=0
        maxEnergyLast=0
        numBitsPerCodeword
        bitLabel
        numResidualBlock=0
        
    end

    methods

        data_bits_out = encode(obj, data_bits)
        data_bits_out = decode(obj, shaped_bit_labels)
        obj = initialize(obj, modulation, energy_table, nuMb, const_len_per_codeword, shaped_bit_level, n_max, n_mantissa)


        function obj = ess(modulation, energy_table, nuMb, const_len_per_codeword, shaped_bit_level, n_max, n_mantissa)
            if nargin == 0
                return;
            end
            if nargin < 5 || isempty(n_max)
                n_max = 256;
            end
            if nargin < 6 || isempty(n_mantissa)
                n_mantissa = 8;
            end
            obj = obj.initialize( ...
                modulation, energy_table, nuMb, const_len_per_codeword, shaped_bit_level, n_max, n_mantissa);
        end


        function [n_info,Lmax] = compute_num_info(obj,n)
        %%n: blocklength of the shaper, v: MB parameter, A: number of amp levels
          assert(n<=obj.nMax);
          symb = 1:2:2*obj.effectiveAlphabetSize-1;
          Px = toolbox.ProbShaping.ess.mbDistribution(obj.effectiveAlphabetSize, obj.nuMb, 'Amplitude'); %%compute MB distribution on the positive half        
          E_max_init = symb.^2 * Px * n;
          
          Lmax = floor((E_max_init-n)/8)+1;
          n_info = obj.energyTable{2}(n+1,Lmax); %%directly read out the exponent from the Nc exponent table
        end


    end

    methods (Access = private)
        out = encodeBlock(obj, block_length, max_energy, input_bits)
        out = decodeBlock(obj, block_length, max_energy, symbols_in)

    end

    methods (Static, Access = private)
        function group_bit_patterns = amplitudeGroupBitPatterns( shaped_bit_level)
            effective_bits_per_symbol = 2 * (shaped_bit_level + 1);
            effective_modulation = toolbox.phy.pdsch.bits_per_symbol( ...
                effective_bits_per_symbol);
            [constellation, bit_labels] = toolbox.ProbShaping.demod.get_ps_demodulation_lut( ...
                effective_modulation);
            positive_levels = sort(unique(abs(real(constellation))));
            amplitude_bit_positions = 3:2:effective_bits_per_symbol;

            group_bit_patterns = zeros(2 ^ shaped_bit_level, shaped_bit_level, 'int8');
            for group_idx = 1:(2 ^ shaped_bit_level)
                symbol_idx = find(abs(abs(real(constellation)) - positive_levels(group_idx)) < 1e-12 ...
                    & real(constellation) > 0, 1);
                group_bit_patterns(group_idx, :) = int8( ...
                    bit_labels(symbol_idx, amplitude_bit_positions(1:shaped_bit_level)));
            end
        end

        function bits = integerToBits(value, num_bits)
            bits = zeros(num_bits, 1);
            for idx = num_bits:-1:1
                bits(idx) = mod(value, 2);
                value = floor(value / 2);
            end
        end
    end
end