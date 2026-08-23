% Anchor to repo root (parent of tests/) so toolbox.* resolves regardless of
% the current working directory.
repo_root = fileparts(fileparts(mfilename('fullpath')));
addpath(repo_root);

n_mantissa = 8;
n_max = 128;

cases = struct( ...
    "modulation", {}, "nu", {}, "shaped_bit_level", {}, ...
    "const_len_per_codeword", {}, "expected_residual_block", {});

modulations = ["16QAM", "64QAM", "256QAM", "1024QAM"];
nu_values = [0.2 0.1 0.05];
const_lens = struct("len", {1000,2000}, "rb", {2});  %%Shaped CB length

case_idx = 0;
for m = 1:numel(modulations)
    modulation = modulations(m);
    Qm = toolbox.phy.pdsch.bits_per_symbol(modulation);
    max_shaped_bit_level = Qm / 2 - 1;
    for shaped_bit_level = 1:min(max_shaped_bit_level,2)
        for nu = nu_values
            for c = 1:numel(const_lens)
                case_idx = case_idx + 1;
                cases(case_idx).modulation = modulation;
                cases(case_idx).nu = nu;
                cases(case_idx).shaped_bit_level = shaped_bit_level;
                cases(case_idx).const_len_per_codeword = const_lens(c).len;
                cases(case_idx).expected_residual_block = const_lens(c).rb;
            end
        end
    end
end

rng(0);
num_failed = 0;
num_cases=0;
for i = 1:numel(cases)
    tc = cases(i);
    Qm = toolbox.phy.pdsch.bits_per_symbol(tc.modulation);
    num_unshaped_bit_levels = Qm / 2 - 1 - tc.shaped_bit_level;
    alphabet_size = 2 ^ tc.shaped_bit_level;
    effective_nu = tc.nu * 4 ^ num_unshaped_bit_levels;

    [mantissa_table, exponent_table] = toolbox.ProbShaping.ess.generateEnergyTable( ...
        n_max, effective_nu, alphabet_size, n_mantissa + 1);
    energy_table = {mantissa_table, exponent_table};

    codec = toolbox.ProbShaping.ess.ess( ...
        tc.modulation, energy_table, tc.nu, tc.const_len_per_codeword, ...
        tc.shaped_bit_level, n_max, n_mantissa);

    assert(codec.numResidualBlock == tc.expected_residual_block, ...
        "Case %d: expected numResidualBlock=%d, got %d.", ...
        i, tc.expected_residual_block, codec.numResidualBlock);
    for idx=1:100
        info_bits = int8(randi([0 1], codec.numBitsPerCodeword, 1));
        shaped_bits = codec.encode(info_bits);
        recovered_bits = codec.decode(shaped_bits);
        num_cases=num_cases+1;

        if ~isequal(int8(recovered_bits(:)), info_bits(:))
            num_failed = num_failed + 1;
            fprintf( ...
                "FAIL case %d: modulation=%s nu=%g shaped_bit_level=%d const_len=%d numResidualBlock=%d\n", ...
                i, tc.modulation, tc.nu, tc.shaped_bit_level, tc.const_len_per_codeword, codec.numResidualBlock);
        end
    end
end

if num_failed == 0
    fprintf("PASS: all %d round-trip cases matched.\n", num_cases);
else
    error("toolbox:EssRoundTripFailed", "%d of %d round-trip cases failed.", num_failed, numel(cases));
end

