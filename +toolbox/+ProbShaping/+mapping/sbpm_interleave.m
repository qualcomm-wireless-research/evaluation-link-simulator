function y = sbpm_interleave(x, qam_size)
%SBPMINTERLEAVE SBPM rectangular interleaver for column vectors.

qam_bits = validateQamSize(qam_size);
x = x(:);
if mod(numel(x), qam_bits) ~= 0
    error("toolbox:InvalidSbpmLength", ...
        "SBPM input length %d must be divisible by %d bit(s)/symbol.", ...
        numel(x), qam_bits);
end

a = reshape(x, numel(x) / qam_bits, qam_bits).';
y = a(:);
end

function qam_bits = validateQamSize(qam_size)
qam_bits = round(log2(double(qam_size)));
if ~isscalar(qam_size) || qam_size <= 0 || 2 ^ qam_bits ~= double(qam_size)
    error("toolbox:InvalidSbpmQamSize", ...
        "SBPM qam_size must be a positive power of two.");
end
end
