# Contributing to evaluation-link-simulator

Hi there! We’re thrilled that you’d like to contribute to this MATLAB link-level simulator.

## Branching Strategy

Contributors should develop on branches based off of `main` and submit pull requests against `main`.

## Submitting a Pull Request

1. Please read our [code of conduct](CODE-OF-CONDUCT.md) and [license](LICENSE.txt).
1. Fork and clone the repository.

    ```bash
    git clone git@github.com:qualcomm/evaluation-link-simulator.git
    ```

1. Create a new branch based on `main`:

    ```bash
    git checkout -b <my-branch-name> main
    ```

1. Create an upstream `remote` to make it easier to keep your branches up-to-date:

    ```bash
    git remote add upstream git@github.com:qualcomm/evaluation-link-simulator.git
    ```

1. Make your changes and, where practical, verify them in MATLAB with 5G Toolbox.
1. Commit your changes using the [DCO](https://developercertificate.org/). You can attest to the DCO by committing with the **-s** or **--signoff** options or manually adding the `Signed-off-by` line:

    ```bash
    git commit -s -m "Really useful commit message"
    ```

1. Sync your topic branch with upstream `main`:

    ```bash
    git pull --rebase upstream main
    ```

1. Push to your fork.

    ```bash
    git push -u origin <my-branch-name>
    ```

1. Submit a pull request from your branch to `main`.

## MATLAB Verification

For simulator changes, include the smallest practical MATLAB run that exercises the change. Run the full entry point:

```matlab
run('tests/test_awgn.m')
```

or a reduced sweep by editing only the `USER SETTINGS` block in `tests/test_awgn.m`, for example:

```matlab
chain_modes = "uniform";
mcs_list = 10;
snr_db = 5:5:15;
num_transport_blocks = 20;
```

If your change touches PS functionality, also verify the PS path by setting `chain_modes = ["uniform", "ps"]` and documenting the MATLAB release and operating system used.

## Pull Request Guidelines

- Follow the existing MATLAB package layout and naming style.
- Keep normal run-time outputs under `results/`; do not commit generated result files or figures.
- Do not commit local `reference/`, `tools/`, or generated `docs/` artifacts unless they are intentionally part of the reviewed change.
- Keep changes focused; submit unrelated simulator, plotting, and documentation changes separately when possible.
- Update `README.md` when requirements, entry points, or generated outputs change.
- Write a clear commit message and include relevant run settings or result summaries in the pull request description.

## Security Analysis of Pull Requests

To maintain the security and integrity of this project, pull requests may be scanned using [Semgrep](https://github.com/semgrep/semgrep) or other static-analysis tools to detect insecure coding patterns and potential security flaws.

If any issues are flagged, contributors are expected to resolve them before the PR can be merged. By submitting a PR, you agree to participate in this process and help us keep the project secure for everyone.
