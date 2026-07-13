function TxScaling = getTxScaling(alphabet_size,nmax,E_target,num_unshaped_bits)

candidate_nmax=[64,96,128,192,256];

if ~ismember(nmax, candidate_nmax) 
    error('For ESS sizes other than 64,96,128,192,256, set txScaling to be empirical;');
    
elseif alphabet_size >4 
    error('For ESS with alphabet size >4, set txScaling to be empirical;');
else
    nmax_idx=find(nmax==candidate_nmax);
    file_path = which('toolbox.ProbShaping.ess.getTxScaling');
    [package_dir, ~, ~] = fileparts(file_path);
    mat_file_path = fullfile(package_dir, 'energy_LUT.mat');
end




switch alphabet_size
    case 2
        load(mat_file_path,'LUT_2ary');
        E_avg=LUT_2ary(nmax_idx,E_target);
        E_uniform=5;



    case 4
        load(mat_file_path,'LUT_4ary');
        E_avg=LUT_4ary(nmax_idx,E_target);
        E_uniform=21;

end

for idx=1:num_unshaped_bits
    E_avg=E_avg*4+1;
    E_uniform=E_uniform*4+1;
end

TxScaling=E_uniform/E_avg;

end


