function fast_sphere_decoder_obj = initialize_fast_sphere_decoder( ...
    modulation, num_layers, n_cand, max_list, use_qr_augmentation)
%INITIALIZEFASTSPHEREDECODER Initialize MEX fast-sphere decoder for a simulation.
%
%   FAST_SPHERE_DECODER_OBJ = INITIALIZEFASTSPHEREDECODER(MODULATION, NUM_LAYERS, ...
%   N_CAND, MAX_LIST) prepares the parameters needed to call the
%   vendored MEX decoder fast_sphere_decoder once per resource
%   element (see detect_pdsch_fast_sphere.m).
%
%   Inputs:
%       modulation  - Modulation scheme ('QPSK', '16QAM', '64QAM', '256QAM', '1024QAM')
%       num_layers  - Number of PDSCH layers (Nt seen by the MEX)
%       n_cand      - Candidate list size per PAM level
%       max_list    - Max candidate list size for soft LLR computation
%       use_qr_augmentation - Whether to use augmented QR (default: true)
%
%   Outputs:
%       fast_sphere_decoder_obj - struct with fields:
%                                 .moduTypes, .bitsPerSymbol, .nCand, .maxList

if nargin < 5 || isempty(use_qr_augmentation)
    use_qr_augmentation = true;
elseif ~isscalar(use_qr_augmentation) || ...
        (~islogical(use_qr_augmentation) && ~isnumeric(use_qr_augmentation))
    error('toolbox:InvalidQrAugmentation', ...
        'use_qr_augmentation must be a scalar logical or numeric value.');
else
    use_qr_augmentation = use_qr_augmentation ~= 0;
end

switch upper(modulation)
    case {'QPSK', '16QAM', '64QAM', '256QAM', '1024QAM'}
        % supported
    otherwise
        error('toolbox:UnsupportedModulation', ...
            'Unsupported modulation: %s', modulation);
end

% bits_per_symbol.m only covers 16/64/256/1024QAM; QPSK is handled here since
% it's a valid MEX modulation but outside that helper's supported set.
if strcmpi(modulation, 'QPSK')
    bits_per_symbol = 2;
else
    bits_per_symbol = toolbox.phy.pdsch.bits_per_symbol(modulation);
end

modu_types = repmat({lower(char(modulation))}, 1, num_layers);

% MEX files inside a +package folder resolve via their fully-qualified
% package name (toolbox.phy.receiver.fastsphere.<name>), same as .m
% functions -- no addpath needed. Verify it resolves before first use so a
% missing/incompatible MEX fails clearly here rather than deep in the RE loop.
if isempty(which('toolbox.phy.receiver.fastsphere.fast_sphere_decoder'))
    error('toolbox:MissingFastSphereMex', ...
        ['fast_sphere_decoder MEX file not found. ', ...
         'See %s for recompilation instructions.'], ...
        fullfile(fileparts(mfilename('fullpath')), '+fastsphere', 'MEX_src', 'README.md'));
end

fast_sphere_decoder_obj = struct();
fast_sphere_decoder_obj.moduTypes = modu_types;
fast_sphere_decoder_obj.bitsPerSymbol = bits_per_symbol;
fast_sphere_decoder_obj.nCand = n_cand;
fast_sphere_decoder_obj.maxList = max_list;
fast_sphere_decoder_obj.useQrAugmentation = use_qr_augmentation;

end
