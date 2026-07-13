function [source_bits, info] = ps_descramble(mapped_bits, varargin)
%PS_DESCRAMBLE Apply selective descrambling and invert PS row routing.


[mapped_bits, Qm, shaped_bit_level, scrambling_sequence] = parse_inputs( ...
    mapped_bits, varargin{:});

shaped_mask = shaped_row_mask(numel(mapped_bits), Qm, shaped_bit_level);
descrambled_bits = mapped_bits;
if ~isempty(scrambling_sequence)
    descrambled_bits = descramble_unshaped_rows( ...
        descrambled_bits, scrambling_sequence, shaped_mask);
end

source_bits = inverse_route_rows(descrambled_bits, Qm, shaped_bit_level);
info = struct( ...
    "descrambledBits", descrambled_bits, ...
    "shapedMask", shaped_mask);
end

function y = inverse_route_rows(x, Qm, shaped_bit_level)
rows = reshape(x, Qm, []);
x_s = rows(3:(2 + 2 * shaped_bit_level), :);
x_p = [rows(1:2, :); rows((3 + 2 * shaped_bit_level):end, :)];
y = [x_s; x_p];
y = y(:);
end

function y = descramble_unshaped_rows(x, scrambling_sequence, shaped_mask)
scrambling_sequence = logical(scrambling_sequence(:));
if numel(scrambling_sequence) ~= numel(x)
    error("toolbox:InvalidPsScramblingSequence", ...
        "PS scrambling sequence length must match the mapped codeword length.");
end

scramble_mask = ~shaped_mask;
y = x(:);
if is_binary_vector(y)
    y(scramble_mask) = int8(xor(logical(y(scramble_mask)), ...
        scrambling_sequence(scramble_mask)));
else
    signs = ones(numel(y), 1);
    signs(scramble_mask) = 1 - 2 * double(scrambling_sequence(scramble_mask));
    y = y .* signs;
end
end

function mask = shaped_row_mask(G, Qm, shaped_bit_level)
rows = false(Qm, G / Qm);
rows(3:(2 + 2 * shaped_bit_level), :) = true;
mask = rows(:);
end

function tf = is_binary_vector(x)
tf = (isinteger(x) || islogical(x)) && all(x == 0 | x == 1);
end

function [mapped_bits, Qm, shaped_bit_level, scrambling_sequence] = parse_inputs( ...
    mapped_bits, varargin)
mapped_bits = mapped_bits(:);
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
            "PS demapper requires shapingInfo or E, shapedBits, Qm, shaped_bit_level.");
    end
    E = varargin{1};
    Qm = varargin{3};
    shaped_bit_level = varargin{4};
    if sum(E(:)) ~= numel(mapped_bits)
        error("toolbox:InvalidPsBitMapping", ...
            "Rate-matched CB lengths must sum to the demapper input length.");
    end
end

if mod(numel(mapped_bits), Qm) ~= 0
    error("toolbox:InvalidPsBitMapping", ...
        "PS demapper input length must be divisible by Qm.");
end
end
