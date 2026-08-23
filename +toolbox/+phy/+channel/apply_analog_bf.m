function y = apply_analog_bf(x, analog_bf, tx_dim, cfg)
%APPLY_ANALOG_BF Apply analog BF to channel, e.g., H * W, and signal, e.g., W * s.

M = cfg.channel.transmitAntennaArray.size(1);
N = cfg.channel.transmitAntennaArray.size(2);
P = cfg.channel.transmitAntennaArray.size(3);
Mg = cfg.channel.transmitAntennaArray.size(4);
Ng = cfg.channel.transmitAntennaArray.size(5);
m = cfg.channel.analogBF.arraySize(1);
n = cfg.channel.analogBF.arraySize(2);

size_x = size(x);
if size_x(tx_dim) == M * N * P * Mg * Ng
    size_x_reshape = [size_x(1 : tx_dim - 1), m, M / m, n, N / n, P, Mg, Ng, size_x(tx_dim + 1 : end)];
else
    size_x_reshape = [size_x(1 : tx_dim - 1), 1, M / m, 1, N / n, P, Mg, Ng, size_x(tx_dim + 1 : end)];
end
size_analog_bf_reshape = [ones(1, tx_dim - 1), m, 1, n];

x_reshape = reshape(x, size_x_reshape);
analog_bf_reshape = reshape(analog_bf, size_analog_bf_reshape);

if size_x(tx_dim) == M * N * P * Mg * Ng
    y_reshape = sum(x_reshape .* analog_bf_reshape, [tx_dim, tx_dim + 2]);
    y = reshape(y_reshape, [size_x(1 : tx_dim - 1), size_x(tx_dim) / m / n, size_x(tx_dim + 1 : end)]);
else
    y_reshape = x_reshape .* analog_bf_reshape;
    y = reshape(y_reshape, [size_x(1 : tx_dim - 1), size_x(tx_dim) * m * n, size_x(tx_dim + 1 : end)]);
end
end
