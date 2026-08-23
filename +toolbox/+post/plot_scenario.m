function plot_scenario(run_result)
%PLOT_SCENARIO Postprocess a launched scenario: plot BLER/throughput vs SNR.
%
%   PLOT_SCENARIO(RUN_RESULT) takes the struct returned by
%   toolbox.launchScenario and, unless RUN_RESULT.makePlots is false, saves
%   the overlay BLER/throughput figures via toolbox.post.plot_summary and,
%   when RUN_RESULT.plotSnrGain is true, also computes and plots the
%   PS-vs-uniform SNR gain via toolbox.post.plot_snr_gain.

if ~run_result.makePlots
    return;
end

toolbox.post.plot_summary(run_result.summaryRows, run_result.outputDir, run_result.scenarioPrefix);

if run_result.plotSnrGain
    gain_table = toolbox.post.plot_snr_gain(run_result.summaryRows, run_result.outputDir, run_result.scenarioPrefix);
    disp(gain_table);
end
end
