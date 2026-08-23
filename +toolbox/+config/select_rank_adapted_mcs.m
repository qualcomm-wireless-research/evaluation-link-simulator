function [selected_mcs, selected_table] = select_rank_adapted_mcs( ...
        original_total_speff, new_rank, mcs_table_name)
%SELECT_RANK_ADAPTED_MCS Maximize total spectral efficiency after switching.

[selected_mcs, has_feasible_mcs] = select_from_table( ...
    original_total_speff, new_rank, mcs_table_name);
selected_table = char(mcs_table_name);

if ~has_feasible_mcs
    if ~startsWith(string(mcs_table_name), "ps_")
        error("toolbox:NoFeasibleMCS", ...
            "No MCS in table %s has total spectral efficiency <= %.15g at rank %d.", ...
            mcs_table_name, original_total_speff, new_rank);
    end

    selected_table = 'qam256';
    [selected_mcs, has_feasible_mcs] = select_from_table( ...
        original_total_speff, new_rank, selected_table);
    if ~has_feasible_mcs
        error("toolbox:NoFeasibleMCS", ...
            "No MCS in table %s or qam256 has total spectral efficiency <= %.15g at rank %d.", ...
            mcs_table_name, original_total_speff, new_rank);
    end
end
end

function [selected_mcs, has_feasible_mcs] = select_from_table( ...
        original_total_speff, new_rank, mcs_table_name)
valid_mcs = zeros(1, 32);
valid_total_speff = zeros(1, 32);
num_valid_mcs = 0;

for candidate_mcs = 0:31
    try
        candidate_info = toolbox.getMcsInfo(candidate_mcs, mcs_table_name);
    catch exception
        if ismember(string(exception.identifier), ["toolbox:UnknownMCS", "toolbox:ReservedMCS"])
            continue;
        end
        rethrow(exception);
    end
    num_valid_mcs = num_valid_mcs + 1;
    valid_mcs(num_valid_mcs) = candidate_mcs;
    valid_total_speff(num_valid_mcs) = candidate_info.spectralEfficiency * new_rank;
end

valid_mcs = valid_mcs(1:num_valid_mcs);
valid_total_speff = valid_total_speff(1:num_valid_mcs);
feasible_positions = find(valid_total_speff <= original_total_speff);
has_feasible_mcs = ~isempty(feasible_positions);

if has_feasible_mcs
    [~, best_position] = max(valid_total_speff(feasible_positions));
    selected_mcs = valid_mcs(feasible_positions(best_position));
else
    selected_mcs = NaN;
end
end
