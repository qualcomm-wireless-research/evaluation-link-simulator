# Workflows and Actions

This folder contains workflows for maintaining the MATLAB link-level simulator repository.

Workflows:

1. `qcom-preflight-checks.yml` runs Qualcomm preflight checks, including repository linting, dependency review, copyright/license checks, commit-email checks, and Semgrep scanning through reusable Qualcomm workflows.
2. `stale-issues.yaml` periodically checks for stalled issues and pull requests. Stale items receive a comment so maintainers and contributors can confirm whether they are still active.

The simulator itself is exercised in MATLAB. Pull requests that change simulator behavior should document the MATLAB version, 5G Toolbox availability, `tests/scenarios/scenario_awgn.m` settings (`chain_modes`, `mcs_list`, `snr_db`), and representative result artifacts (e.g. `awgn_summary.csv`, `awgn_summary.png`) used for verification.
