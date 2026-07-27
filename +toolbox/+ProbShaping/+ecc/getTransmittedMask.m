function tx_mask = getTransmittedMask(N, k_s, E_s)
%GETTRANSMITTEDMASK Boolean mask of length N: true = transmitted bit
%
%   After sub-block interleaving, rate matching selects E_s of N bits:
%     shortening (k_s/E_s > 7/16): take first E_s of interleaved word
%     puncturing (k_s/E_s <= 7/16): take last  E_s of interleaved word
%   The remaining N-E_s interleaved positions are non-transmitted.
%
%   This function returns the mask in the original (pre-interleave) mother-code bit order.
%
%   Input:
%     N   : mother code length (power of 2)
%     k_s : number of shaping (free) bits — used only for rate decision
%     E_s : rate-matched output length
%
%   Output:
%     tx_mask : N x 1 logical, true at positions that are transmitted

    subblockInterleaverPattern = nr5g.internal.polar.subblockInterleaveMap(N);  % 0-based, length N

    if k_s/E_s <= 7/16
        % puncturing: last E_s of interleaved word are transmitted
        sel = (N - E_s + 1 : N)';      % 1-based interleaved positions
    else
        % shortening: first E_s of interleaved word are transmitted
        sel = (1 : E_s)';
    end

    % Map back to original (pre-interleave) positions
    tx_mask = false(N, 1);
    tx_mask(subblockInterleaverPattern(sel) + 1) = true;   % convert 0-based to 1-based
end
