function sequence = get_pdsch_scrambling_sequence(carrier, pdsch, length, signed_output)
%GET_PDSCH_SCRAMBLING_SEQUENCE Shared NR PDSCH scrambling sequence generator.
%
%   SEQUENCE = GET_PDSCH_SCRAMBLING_SEQUENCE(CARRIER, PDSCH, LENGTH, SIGNED_OUTPUT)
%   returns the NR PDSCH PRBS used for codeword scrambling/descrambling.
%
%   When SIGNED_OUTPUT is true the sequence is returned as signed +/-1 doubles
%   (for LLR descrambling); otherwise it is returned as a logical bit vector
%   (for TX bit scrambling). The scrambling identity follows the NR rule:
%   NID when set on the PDSCH, otherwise the carrier cell ID.

if nargin < 4 || isempty(signed_output)
    signed_output = false;
end

if isempty(carrier)
    error("toolbox:MissingCarrier", ...
        "carrier is required for NR PDSCH (de)scrambling.");
end

scrambling_nid = carrier.NCellID;
if ~isempty(pdsch.NID)
    scrambling_nid = pdsch.NID(1);
end

if signed_output
    opts.MappingType = 'signed';
    opts.OutputDataType = 'double';
    sequence = nrPDSCHPRBS(scrambling_nid, pdsch.RNTI, 0, length, opts);
else
    sequence = logical(nrPDSCHPRBS(scrambling_nid, pdsch.RNTI, 0, length));
end
sequence = sequence(:);
end
