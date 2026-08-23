function subcarrier_indices = allocated_subcarrier_indices(pdsch_indices, num_subcarriers)
%ALLOCATED_SUBCARRIER_INDICES Recover scheduled subcarriers from PDSCH indices.
%
% PDSCH_INDICES are linear indices into an NR resource grid whose first
% dimension is frequency. The returned indices are the unique 1-based
% subcarrier rows occupied by PDSCH, independent of OFDM symbol and layer.

validateattributes(num_subcarriers, {'numeric'}, ...
    {'scalar', 'integer', 'positive', 'finite'}, mfilename, 'num_subcarriers');
if isempty(pdsch_indices)
    error('toolbox:amc:EmptyPdschIndices', ...
        'PDSCH indices must contain at least one scheduled resource element.');
end

pdsch_indices = double(pdsch_indices(:));
if any(~isfinite(pdsch_indices) | pdsch_indices < 1 | ...
        pdsch_indices ~= fix(pdsch_indices))
    error('toolbox:amc:InvalidPdschIndices', ...
        'PDSCH indices must be finite positive integers.');
end

subcarrier_indices = unique(mod(pdsch_indices - 1, double(num_subcarriers)) + 1);
subcarrier_indices = reshape(subcarrier_indices, 1, []);
end
