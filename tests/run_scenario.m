function run_result = run_scenario(scenario_file)
%RUN_SCENARIO Load, launch, and postprocess one named scenario.
%
%   RUN_RESULT = RUN_SCENARIO(SCENARIO_FILE) runs the scenario defined by
%   SCENARIO_FILE, the name of a zero-arg tests/scenarios/scenario_*.m
%   function (e.g. "scenario_awgn", "scenario_mimo_cdl"). Loads the scenario
%   parameters, launches the simulation sweep, and postprocesses the results
%   into BLER/throughput-vs-SNR plots.
%
%   Example:
%       run_scenario("scenario_awgn")

% Anchor to repo root (parent of tests/) so toolbox.* resolves and results/
% lands at the repo root regardless of the current working directory. Also
% add tests/scenarios/ (and its subfolders) so scenario_*.m resolves
% regardless of the caller's current directory.
tests_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(tests_dir);
addpath(repo_root);
addpath(genpath(fullfile(tests_dir, 'scenarios')));

params = feval(scenario_file);
scenario = toolbox.loadScenario(params, repo_root);
run_result = toolbox.launchScenario(scenario);
toolbox.post.plot_scenario(run_result);

disp(run_result.summaryRows);
fprintf("Saved %s outputs to %s\n", run_result.scenarioTitle, run_result.outputDir);
end
