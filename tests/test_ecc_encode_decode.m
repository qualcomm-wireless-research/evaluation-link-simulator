% test_ecc_encode_decode.m
% Standalone round-trip test for the @ecc shaping codec, 
%
% For every (modulation, shaped_bit_level, nu, const_len_per_codeword) case it
% builds an @ecc codec, then check Round-trip:
% decode(encode(bits)) == bits, bit-exact.
%

repo_root = fileparts(fileparts(mfilename('fullpath')));
addpath(repo_root);

ecc_cfg = struct( ...
    "modulation", {}, "nu", {}, "shaped_bit_level", {}, "const_len_per_codeword", {},...
    "n_max", {}, "list_size", {});

modulations = ["16QAM", "64QAM", "256QAM", "1024QAM"]; % "16QAM", "64QAM", "256QAM", "1024QAM"
nu_values = [0.2 0.1 0.05]; % 0.2 0.1 0.05
const_lens = struct("len", {1000, 2000});  %%Shaped CB length

case_idx = 0;
for m = 1:numel(modulations)
    modulation = modulations(m);
    Qm = toolbox.phy.pdsch.bits_per_symbol(modulation);
    max_shaped_bit_level = Qm / 2 - 1;
    for shaped_bit_level = 2:min(max_shaped_bit_level, 2)
        for nu = nu_values
            for c = 1:numel(const_lens)
                case_idx = case_idx + 1;
                ecc_cfg(case_idx).modulation = modulation;
                ecc_cfg(case_idx).nu = nu;
                ecc_cfg(case_idx).shaped_bit_level = shaped_bit_level;
                ecc_cfg(case_idx).const_len_per_codeword = const_lens(c).len;
                ecc_cfg(case_idx).n_max = 1024;
                ecc_cfg(case_idx).list_size = 1;
            end
        end
    end
end



rng(0);
num_failed = 0;
num_cases = 0;
for i = 1:numel(ecc_cfg)
    tc = ecc_cfg(i);

    % Constructor signature: ecc(modulation, nu, const_len_per_codeword,
    % shaped_bit_level, n_max, list_size)
    codec = toolbox.ProbShaping.ecc.ecc( ...
        tc.modulation, tc.nu, tc.const_len_per_codeword, tc.shaped_bit_level, tc.n_max, tc.list_size);

    expected_shaped_len = tc.const_len_per_codeword * tc.shaped_bit_level;

    for idx = 1:100
        info_bits = int8(randi([0 1], codec.numBitsPerCodeword, 1));
        shaped_bits = codec.encode(info_bits);
        num_cases = num_cases + 1;

        if numel(shaped_bits) ~= expected_shaped_len
            num_failed = num_failed + 1;
            fprintf(["FAIL case %d (layout): modulation=%s nu=%g " ...
                "shaped_bit_level=%d const_len=%d expected %d shaped bits, got %d\n"], ...
                i, tc.modulation, tc.nu, tc.shaped_bit_level, ...
                tc.const_len_per_codeword, expected_shaped_len, numel(shaped_bits));
            continue;
        end

        recovered_bits = codec.decode(shaped_bits);
        if ~isequal(int8(recovered_bits(:)), info_bits(:))
            num_failed = num_failed + 1;
            fprintf(["FAIL case %d (round-trip): modulation=%s nu=%g " ...
                "shaped_bit_level=%d const_len=%d\n"], ...
                i, tc.modulation, tc.nu, tc.shaped_bit_level, tc.const_len_per_codeword);
        end
    end
end

if num_failed == 0
    fprintf("PASS: all %d ecc round-trip cases matched.\n", num_cases);
else
    error("toolbox:EccRoundTripFailed", ...
        "%d of %d ecc round-trip cases failed.", num_failed, num_cases);
end
