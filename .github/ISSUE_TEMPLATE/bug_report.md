---
name: Bug report
about: Report a simulator issue or unexpected result
title: ''
labels: bug
assignees: ''

---

**Describe the bug**
A clear and concise description of the issue.

**Simulation settings**
- Entry point: `run_scenario("scenario_awgn")` / `run_scenario("scenario_mimo")` / `run_scenario("scenario_simo")` / `toolbox.runSimulation` / other:
- `chain_modes`:
- `mcs_list`:
- `snr_db`:
- `cfg.receiver.channelEstimation`:
- `cfg.receiver.demapper`:
- Other changed settings:

**To Reproduce**
Steps or MATLAB commands to reproduce the behavior:

```matlab
% Paste the smallest reproducing commands or USER SETTINGS block here.
```

**Expected behavior**
A clear and concise description of what you expected to happen.

**Actual behavior**
Include error messages, stack traces, unexpected BLER/throughput behavior, or output-file details.

**Environment**
- OS:
- MATLAB release:
- 5G Toolbox available/version:
- MEX compiler, if relevant:
- CPU/GPU or other relevant hardware:

**Artifacts**
Attach or summarize relevant `results/<output_root>/<timestamp>/` files (`awgn_summary.csv`, `awgn_workspace.mat`, figures, logs, or `.mat` files) when helpful.

**Additional context**
Add any other context about the problem here.
