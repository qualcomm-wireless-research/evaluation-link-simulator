function [mapped_bits, info] = ps_scramble(source_bits, varargin)
%PS_SCRAMBLE Apply PS row routing and selective scrambling.
%
%   Treats the nrDLSCH output as one codeword and applies the row
%   permutation before selective scrambling.

[source_bits, Qm, shaped_bit_level, scrambling_sequence] = parse_inputs( ...
    source_bits, varargin{:});

mapped_rows = route_rows(source_bits, Qm, shaped_bit_level);
shaped_mask = shaped_row_mask(numel(mapped_rows), Qm, shaped_bit_level);
mapped_bits = mapped_rows;

if ~isempty(scrambling_sequence)
    mapped_bits = scramble_unshaped_rows(mapped_bits, scrambling_sequence, shaped_mask);
end

info = struct( ...
    "mappedBits", mapped_rows, ...
    "scrambledBits", mapped_bits, ...
    "shapedMask", shaped_mask);
end

function y = route_rows(x, Qm, shaped_bit_level)
num_symbols = numel(x) / Qm;
rows = reshape(x, Qm, num_symbols);
x_s = rows(1:(2 * shaped_bit_level), :);
x_p = rows((2 * shaped_bit_level + 1):end, :);
y = [x_p(1:2, :); x_s; x_p(3:end, :)];
y = y(:);
end

function y = scramble_unshaped_rows(x, scrambling_sequence, shaped_mask)
scrambling_sequence = logical(scrambling_sequence(:));
if numel(scrambling_sequence) ~= numel(x)
    error("toolbox:InvalidPsScramblingSequence", ...
        "PS scrambling sequence length must match the mapped codeword length.");
end

y = int8(x(:));
scramble_mask = ~shaped_mask;
y(scramble_mask) = int8(xor(logical(y(scramble_mask)), ...
    scrambling_sequence(scramble_mask)));
end

function mask = shaped_row_mask(G, Qm, shaped_bit_level)
rows = false(Qm, G / Qm);
rows(3:(2 + 2 * shaped_bit_level), :) = true;
mask = rows(:);
end


function [source_bits, Qm, shaped_bit_level, scrambling_sequence] = parse_inputs( ...
    source_bits, varargin)
source_bits = source_bits(:);
scrambling_sequence = [];

if numel(varargin) == 1 && isstruct(varargin{1})
    ps_info = varargin{1};
    Qm = ps_info.bitsPerSymbol;
    shaped_bit_level = ps_info.num_shaped_bit_levels;
    if isfield(ps_info, 'scramblingSequence')
        scrambling_sequence = ps_info.scramblingSequence(:);
    end
else
    if numel(varargin) < 4
        error("toolbox:InvalidPsBitMapping", ...
            "PS mapper requires shapingInfo or E, shapedBits, Qm, shaped_bit_level.");
    end
    E = varargin{1};
    Qm = varargin{3};
    shaped_bit_level = varargin{4};
    if sum(E(:)) ~= numel(source_bits)
        error("toolbox:InvalidPsBitMapping", ...
            "Rate-matched CB lengths must sum to the mapper input length.");
    end
end

if mod(numel(source_bits), Qm) ~= 0
    error("toolbox:InvalidPsBitMapping", ...
        "PS mapper input length must be divisible by Qm.");
end
end
