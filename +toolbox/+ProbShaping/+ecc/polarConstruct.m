function F = polarConstruct(k_s, E_s, nMax)
%POLARCONSTRUCT NR polar code frozen-bit mask with forced N=2^ceil(log2(E_s))
%
%   Bypasses the NR Rmin=1/8 restrictions in the standard N-selection formula. 
%   Always uses N = 2^ceil(log2(E_s)), clamped to
%   [2^5, 2^nMax]. Reliability ordering is taken from the 3GPP NR
%   sequence (38.212 Table 5.3.1.2-1).
%
%   Inputs:
%     k_s  : number of shaping (free / information) bits
%     E_s  : rate-matched output length
%     nMax : max log2(N), 9 (downlink) or 10 (uplink)
%
%   Output:
%     F : N x 1 int8, 1 = frozen, 0 = free (information/shaping)

    n = max(ceil(log2(E_s)), 5);
    n = min(n, nMax);
    N = 2^n;

    % 3GPP TS 38.212 Table 5.3.1.2-1: Q_Nmax reliability sequence, 0-based,
    % most reliable to least reliable (NR_seq.m stores it least->most, so
    % reverse it here).
    Q_N = toolbox.ProbShaping.ecc.NR_seq;
    Q_N = Q_N(end:-1:1);

    % Keep only positions < N (sub-sequence for this mother code length)
    Q_N = Q_N(Q_N < N);   % most->least reliable, 0-based, length N

    % Identify transmitted positions via sub-block interleave + rate matching.
    % Non-transmitted positions must always be frozen; free bits are chosen
    % only among transmitted positions.
    subblockInterleaverPattern = nr5g.internal.polar.subblockInterleaveMap(N);  % 0-based, length N
    if k_s / E_s <= 7/16
        sel = (N - E_s + 1 : N)';    % puncturing: last E_s interleaved slots
    else
        sel = (1 : E_s)';             % shortening: first E_s interleaved slots
    end
    tx_mask = false(N, 1);
    tx_mask(subblockInterleaverPattern(sel) + 1) = true;     % 1-based, true = transmitted

    % From the reliability ordering, keep only transmitted positions.
    % Assign the k_s most reliable transmitted positions as free (F=0).
    Q_tx = Q_N(tx_mask(Q_N + 1));    % transmitted positions, most->least reliable
    F = ones(N, 1, 'int8');
    free_idx = Q_tx(1:k_s) + 1;      % 1-based
    F(free_idx) = 0;
end
