classdef ecc
%ECC Multi-level polar shaping codec for one NR code block shaping allocation.

    properties (SetAccess = private)
        modulation
        qamSize

        nuMb                % MB Parameter
        constLenPerCodeword % CB Block size
        numShapedBitLevels  % number of shaped bit levels
        nMax                % Max DM length
        constellation
        prob
        entropySource
        effectiveAlphabetSize
        nShapedBlocks
        nShaperBitsReg
        nLast=0             
        nShaperBitsLast=0
        numBitsPerCodeword
        bitLabel
        numResidualBlock=0
        list_size
        p_bit_cond_nMax     % per shaping bit level, p1, for nMax case
        p_bit_cond_nLast    % per shaping bit level, p1, for nLast case
    end

    methods

        data_bits_out = encode(obj, data_bits)
        data_bits_out = decode(obj, shaped_bit_labels)
        obj = initialize(obj, modulation, nu, const_len_per_codeword, shaped_bit_level, n_max, list_size)


        function obj = ecc(modulation, nuMb, const_len_per_codeword, shaped_bit_level, n_max, list_size)
            if nargin == 0
                return;
            end
            obj = obj.initialize( ...
                modulation, nuMb, const_len_per_codeword, shaped_bit_level, n_max, list_size);
        end


        function [n_info, p_bit_cond] = compute_num_info(obj,n)
        %COMPUTE_NUM_INFO Per-shaped-bit-level polar shaping-bit counts (and conditional probs) for a shaper of block length n.
        %   Returns a 1 x numShapedBitLevels vector Ks (ordered MSB->LSB amplitude
        %   bit), where Ks(k) is the number of information bits the level-k
        %   polar shaper carries: Ks(k) = round(n * H(b_k | less-significant
        %   amplitude bits)). 
        %
        %   The optional second output p_bit_cond is a 1 x numShapedBitLevels cell
        %   array using the same level index convention as n_info (p_bit_cond{k}
        %   corresponds to n_info(k); k=1 = MSB amplitude bit, k=numShapedBitLevels
        %   = LSB amplitude bit). Entry k is a 1 x 2^(numShapedBitLevels-k) row
        %   vector of p(b_k = 1 | context), where the context index is
        %   bin2dec(less-significant amplitude bits)+1. These are the conditional
        %   probabilities used to form the polar LLR targets at encode time.
          assert(n<=obj.nMax);
          num_levels = obj.numShapedBitLevels;
          p = obj.prob(:);       % ascending positive-half MB dist, aligns with amplitude-group rows
          bits_amp = toolbox.ProbShaping.ecc.ecc.amplitudeGroupBitPatterns(num_levels);
          % bits_amp: 2^num_levels x num_levels, row = ascending amplitude group
          % (aligned with p's row order), column k = level-k bit (k=1 MSB ..
          % k=num_levels LSB), same NR-constellation labeling as obj.bitLabel.
          entropy = zeros(1, num_levels);
          p_bit_cond = cell(1, num_levels);
          for k = num_levels:-1:1
              if k == num_levels
                  % least-significant amplitude bit: unconditional
                  p_bit_cond{k} = sum(p(bits_amp(:,k) == 1));
                  entropy(k) = toolbox.ProbShaping.ecc.ecc.binaryEntropy( ...
                      p_bit_cond{k});
              else
                  % condition on the less-significant amplitude bits (cols k+1..end)
                  weights = 2 .^ (num_levels - k - 1 : -1 : 0).';
                  context_dec = double(bits_amp(:, k+1:end)) * weights;   % context value per group row
                  p_bit_cond{k} = zeros(1, 2^(num_levels-k));
                  for jj = 1:2^(num_levels-k)
                      context_mask = (context_dec == jj-1);     % groups with context value jj-1
                      context_prob = sum(p(context_mask));
                      if context_prob == 0
                          continue;
                      end
                      p1 = sum(p(context_mask & (bits_amp(:,k) == 1))) / context_prob;
                      p_bit_cond{k}(jj) = p1;
                      entropy(k) = entropy(k) + context_prob * ...
                          toolbox.ProbShaping.ecc.ecc.binaryEntropy(p1);
                  end
              end
          end
          n_info = round(n * entropy);   % 1 x num_levels vector of per-level info-bit counts (Ks)
        end


    end

    methods (Access = private)
        out = encodeBlock(obj, block_length, list_size, input_bits, n_info, p_bit_cond)
        out = decodeBlock(obj, block_length, shaped_bits, n_info)

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

        function h = binaryEntropy(p)
            if p <= 0 || p >= 1
                h = 0;
            else
                h = -p * log2(p) - (1 - p) * log2(1 - p);
            end
        end

        function out = rate_match(coded, k_s, E_s)
        %RATE_MATCH Polar rate matching (TS 38.212 Section 5.4.1), reduced to
        %   the two cases the shaping codec uses. The mother length
        %   N = numel(coded) always satisfies E_s <= N (polarConstruct forces
        %   N = 2^ceil(log2(E_s))), so no repetition case is needed.
            N = numel(coded);
            subblockInterleaverPattern = nr5g.internal.polar.subblockInterleaveMap(N);   % 0-based
            if k_s / E_s <= 7/16
                sel = (N - E_s + 1 : N)';    % puncturing: last E_s interleaved slots
            else
                sel = (1 : E_s)';            % shortening: first E_s interleaved slots
            end
            out = coded(subblockInterleaverPattern(sel) + 1);        % transmitted bits, interleaved order
        end

        function out = de_rate_match(in, k_s, mother_len)
        %   DE_RATE_MATCH Inverse of rate_match. 
            E_s = numel(in);
            subblockInterleaverPattern = nr5g.internal.polar.subblockInterleaveMap(mother_len);   % 0-based
            if k_s / E_s <= 7/16
                sel = (mother_len - E_s + 1 : mother_len)';    % punctured
                out = zeros(mother_len, 1, class(in));         % non-tx -> 0 LLR
            else
                sel = (1 : E_s)';                              % shortened
                out = 1e20 * ones(mother_len, 1, class(in));   % non-tx -> large LLR
            end
            out(subblockInterleaverPattern(sel) + 1) = in;           % received values to original positions
        end
    end
end
