function sphere_decoder_obj = initialize_sphere_decoder(modulation, sphere_algorithm, sphere_radius)
%INITIALIZESPHEREDECODER Initialize sphere decoder object for a simulation.
%
%   SPHERE_DECODER_OBJ = INITIALIZESPHEREDECODER(MODULATION, SPHERE_ALGORITHM, SPHERE_RADIUS)
%   creates and configures a comm.SphereDecoder object that can be reused
%   throughout a simulation.
%
%   Inputs:
%       modulation       - Modulation scheme ('QPSK', '16QAM', '64QAM', '256QAM', '1024QAM')
%       sphere_algorithm - 'full' for exact ML or 'radius' for constrained search
%       sphere_radius    - Initial search radius (empty = auto-determine per call)
%
%   Outputs:
%       sphere_decoder_obj - Configured comm.SphereDecoder object with:
%                            .decoder - The sphere decoder object
%                            .constellation - NR constellation
%                            .bitTable - Binary bit mapping table
%                            .bitsPerSymbol - Number of bits per symbol
%                            .M - Constellation size

% Determine constellation size and bits per symbol
switch upper(modulation)
    case 'QPSK'
        M = 4;
        bits_per_symbol = 2;
    case '16QAM'
        M = 16;
        bits_per_symbol = 4;
    case '64QAM'
        M = 64;
        bits_per_symbol = 6;
    case '256QAM'
        M = 256;
        bits_per_symbol = 8;
    case '1024QAM'
        M = 1024;
        bits_per_symbol = 10;
    otherwise
        error('toolbox:UnsupportedModulation', ...
            'Unsupported modulation: %s', modulation);
end

% Generate constellation using NR standard mapping
% This ensures bit-to-symbol mapping matches the NR transmitter
all_bits = de2bi(0:M-1, bits_per_symbol, 'left-msb').';
constellation = nrSymbolModulate(all_bits(:), modulation);
constellation = constellation(:);  % Ensure column vector

% Create bit table - binary matrix (M x bits_per_symbol)
% Each row contains the binary representation of the symbol index
bit_table = de2bi(0:M-1, bits_per_symbol, 'left-msb');

% Create sphere decoder object with SOFT decision for LLR output
decoder = comm.SphereDecoder('Constellation', constellation, ...
                             'BitTable', bit_table, ...
                             'DecisionType', 'Soft');

% Set initial radius for sphere search
if strcmpi(sphere_algorithm, 'full')
    decoder.InitialRadius = 'Infinity';  % Full sphere search (exact ML)
else
    % Radius-constrained search
    if ~isempty(sphere_radius)
        decoder.InitialRadius = sphere_radius;
    else
        decoder.InitialRadius = 'Infinity';  % Default to full search
    end
end

% Package everything into output structure
sphere_decoder_obj = struct();
sphere_decoder_obj.decoder = decoder;
sphere_decoder_obj.constellation = constellation;
sphere_decoder_obj.bitTable = bit_table;
sphere_decoder_obj.bitsPerSymbol = bits_per_symbol;
sphere_decoder_obj.M = M;
sphere_decoder_obj.algorithm = sphere_algorithm;
sphere_decoder_obj.configuredRadius = sphere_radius;

end
