function scenario = loadScenario(params, repo_root)
%LOADSCENARIO Expand scenario parameters into ready-to-run configs.
%
%   SCENARIO = LOADSCENARIO(PARAMS, REPO_ROOT) takes the PARAMS struct
%   returned by one of the scenarios/scenario_*.m files and expands it into
%   SCENARIO.variants, a struct array of {label, cfg} pairs ready to pass to
%   toolbox.launchScenario.
%
%   PARAMS must provide either:
%     * params.variants  - struct array of {label, cfgOverlay}, one per sweep
%                           point, each a full defaultConfig-shaped overlay
%                           (used e.g. for a precoding/delay sweep); or
%     * params.baseCfg together with params.chainModes and params.mcsList,
%       plus params.chainOpts (see toolbox.buildChainConfig) - the common
%       case of sweeping chain mode x fixed-MCS point.
%
%   Common PARAMS fields (defaults filled in if missing):
%     scenarioPrefix   - output file stem (required)
%     scenarioTitle    - figure title (default: scenarioPrefix)
%     outputRoot       - output directory root, relative to REPO_ROOT
%     makePlots        - save BLER/throughput overlay figures (default true)
%     plotSnrGain      - also compute/plot the PS-vs-uniform SNR gain
%                        (default false)

if ~isfield(params, "scenarioTitle") || isempty(params.scenarioTitle)
    params.scenarioTitle = params.scenarioPrefix;
end
if ~isfield(params, "makePlots")
    params.makePlots = true;
end
if ~isfield(params, "plotSnrGain")
    params.plotSnrGain = false;
end

scenario = struct();
scenario.scenarioPrefix = params.scenarioPrefix;
scenario.scenarioTitle = params.scenarioTitle;
scenario.outputRoot = fullfile(repo_root, params.outputRoot);
scenario.makePlots = params.makePlots;
scenario.plotSnrGain = params.plotSnrGain;

if isfield(params, "variants") && ~isempty(params.variants)
    variants = struct("label", {}, "cfg", {});
    for idx = 1:numel(params.variants)
        variants(idx).label = params.variants(idx).label; %#ok<AGROW>
        variants(idx).cfg = toolbox.defaultConfig(params.variants(idx).cfgOverlay); %#ok<AGROW>
    end
else
    chain_modes = string(params.chainModes);
    mcs_list = params.mcsList(:).';
    variants = struct("label", {}, "cfg", {});
    idx = 0;
    for chain_mode = chain_modes
        for mcs_index = mcs_list
            idx = idx + 1;
            cfg = toolbox.defaultConfig(params.baseCfg);
            cfg.pdsch.mcsIndex = mcs_index;
            cfg = toolbox.buildChainConfig(cfg, chain_mode, params.chainOpts);
            variants(idx).label = chain_mode; %#ok<AGROW>
            variants(idx).cfg = cfg; %#ok<AGROW>
        end
    end
end

scenario.variants = variants;
end
