function tbl = get_rank_mcs_table()
%GET_RANK_MCS_TABLE Rank adaptation lookup tables.
%
%   TBL = GET_RANK_MCS_TABLE() returns a struct keyed by
%   "x<numTx>x<numRx>_<delayProfile>". Each entry has:
%     - min_mcs_rank4: minimum MCS for rank 4 (below -> reduce to rank 3)
%     - min_mcs_rank3: minimum MCS for rank 3 (below -> reduce to rank 2)
%
%   Target MCS is selected as the maximum total spectral efficiency that
%   does not exceed the original total. Uniform adaptation applies to
%   QAM256 only. PS underflow switches to the QAM256 table.

tbl = struct();

% === 32x4 CDL-A ===
s = struct();
s.min_mcs_rank4 = 18;
s.min_mcs_rank3 = 18;
tbl.x32x4_CDL_A = s;

% === 32x4 CDL-B ===
s = struct();
s.min_mcs_rank4 = 10;
s.min_mcs_rank3 = 8;
tbl.x32x4_CDL_B = s;

% === 32x4 CDL-C ===
s = struct();
s.min_mcs_rank4 = 12;
s.min_mcs_rank3 = 6;
tbl.x32x4_CDL_C = s;

% === 4x4 CDL-A ===
s = struct();
s.min_mcs_rank4 = 20;
s.min_mcs_rank3 = 19;
tbl.x4x4_CDL_A = s;

% === 4x4 CDL-B ===
s = struct();
s.min_mcs_rank4 = 22;
s.min_mcs_rank3 = 8;
tbl.x4x4_CDL_B = s;

% === 4x4 CDL-C ===
s = struct();
s.min_mcs_rank4 = 21;
s.min_mcs_rank3 = 8;
tbl.x4x4_CDL_C = s;

end
