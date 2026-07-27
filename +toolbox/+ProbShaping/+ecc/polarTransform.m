function c = polarTransform(u)
%POLARTRANSFORM Polar transform G_N via iterative butterfly (O(N log N))
%
%   Implements c = u * G_N (row-vector convention, matching nrPolarEncode)
%   using the same butterfly structure as the FFT but with XOR:
%
%
%   Input : u, N x 1 binary vector, N must be a power of 2
%   Output: c, N x 1 binary vector, same class as u

    N = length(u);
    n = log2(N);
    assert(floor(n) == n && N >= 2, 'polarTransform: N must be a power of 2 >= 2');

    c = u(:);
    for s = 0 : n-1
        step = 2^s;
        for i = 0 : 2*step : N-1          % start of each butterfly group
            top = (i+1) : (i+step);        % 1-based top-half indices
            c(top) = bitxor(c(top), c(top + step));
        end
    end
end
