# evaluation-link-simulator

MATLAB based link-level simulator for fixed-MCS BLER and throughput studies, comparing a standard 5G NR uniform-QAM chain against a probabilistic-shaping (PS) chain built around (a variation of) ESS (Enumerative Sphere Shaping).

## Supported Features

- Fixed-MCS DL PDSCH BLER and throughput versus SNR, for both AWGN and TDL fading channels.
- 5G NR uniform-QAM transmit/receive chain using MATLAB 5G Toolbox primitives (`nrDLSCH`, `nrPDSCH*`, `nrOFDMModulate`, `nrDLSCHDecoder`).
- ESS-based probabilistic-shaping (PS) chain: prestructured shaped transport blocks, scrambling modification, PS demod preprocessing, shared MMSE/sphere detector, modified descrambling before `nrDLSCHDecoder`.
- PS MCS tables (`ps_mcs_table1`, `ps_mcs_table2`), plus uniform tables `qam64`/`qam256`.
- Uniform-TBS matching: for each MCS with the coding rate determined from the MCS table, compute the MB parameter `nu` so PS payload TBS matches the uniform-QAM TBS for the same MCS (`shaping.matchUniformTbs`).
- TDL-A/B/C/D/E fading channel through `nrTDLChannel`, plus an AWGN channel mode with an identity/selecting spatial matrix.
- MMSE equalization through `nrEqualizeMMSE`, or sphere detection through `comm.SphereDecoder` (`receiver.demapper = "sphere"`).
- Open-loop precoding for configurable Tx/Rx/layer counts with `dft`, `identity`, or `hadamard` precoder options; SIMO (no precoding) and open-loop MIMO presets.
- Single-codeword operation, up to 4 PDSCH layers.

## Requirements

- MATLAB R2023a or newer (for 1024QAM support).
- MATLAB 5G Toolbox.
- Communications Toolbox is required for the sphere-decoder receiver path (`comm.SphereDecoder`).

## Installation Instructions

1. Clone the repository (in a terminal / Git Bash):

   ```bash
   git clone git@github.com:qualcomm/evaluation-link-simulator.git
   cd evaluation-link-simulator
   ```

   Or over HTTPS:

   ```bash
   git clone https://github.com/qualcomm/evaluation-link-simulator.git
   cd evaluation-link-simulator
   ```
2. Launch MATLAB and change to the repository root, e.g.:

   ```matlab
   cd 'C:\path\to\evaluation-link-simulator'
   ```
3. Add the repository root to the MATLAB path so the `+toolbox` package is visible:

   ```matlab
   addpath(pwd)
   ```

   The `+toolbox`, `+config`, `+phy`, and `+ProbShaping` packages are resolved automatically from the root — do **not** `addpath(genpath(pwd))` the package (`+`) folders.
4. Verify the setup by running a driver script from the repository root:

   ```matlab
   run('tests/test_awgn.m')
   ```

   A results folder should appear under `results/`. If MATLAB reports an undefined `toolbox.runSimulation`, the repository root is not on the path — re-run step 3.

## Active Entry Points

- `tests/test_awgn.m`: interactive AWGN fixed-MCS sweep (uniform and/or PS chain modes). Edit the `USER SETTINGS` block at the top.
- `tests/test_mimo.m`: interactive TDL/open-loop MIMO sweep driver (uniform and/or PS chain modes).
- `tests/test_simo.m`: interactive TDL SIMO sweep driver (1 Tx, many Rx, single layer; uniform and/or PS chain modes).
- `toolbox.runSimulation(cfg)`: programmatic single-simulation API, used by all driver scripts.

Run either driver from MATLAB in the repository root:

```matlab
run('tests/test_awgn.m')
```

```matlab
run('tests/test_mimo.m')
```

```matlab
run('tests/test_simo.m')
```

Each script writes outputs to a timestamped folder under `results/`:

- a `*_summary.csv` table with per-SNR BLER, throughput, chain mode, MCS, MCS table, TBS, and shaping metadata.
- a `*_workspace.mat` with the summary table, all `results` structs, and the base config.
- a `*_summary.fig`/`.png` overlay figure with BLER (log-scale) and throughput subplots.

For programmatic use:

```matlab
cfg = toolbox.defaultConfig(struct('shaping', struct('enabled', true)));
results = toolbox.runSimulation(cfg);
disp(results.summaryTable)
```

## Main Parameters

Edit only the `USER SETTINGS` block in `tests/test_awgn.m` / `tests/test_mimo.m` / `tests/test_simo.m` for normal runs. Settings common to all three scripts (shown with representative defaults; see each script for the full list):

```matlab
chain_modes = ["uniform", "ps"];   % "uniform", "ps", or both
mcs_list = 20;                     % fixed-MCS points to sweep
snr_db = 16:0.5:20;                % SNR sweep grid, dB
num_transport_blocks = 100;        % TBs per SNR point
rng_seed = 42;                     % RNG seed for repeatable runs

num_tx_antennas = 1;
num_rx_antennas = 1;
num_pdsch_layers = 1;
prb_set = 0:7;                     % allocated PRBs
pdsch_symbol_allocation = [0 9];   % [startSymbol numSymbols]

uniform_mcs_table = "qam256";      % "qam64" or "qam256"
ps_mcs_table = "ps_mcs_table1";    % "ps_mcs_table1" or "ps_mcs_table2"
num_shaped_bit_level = 2;          % shaped amplitude bit levels per dimension
ps_tx_scaling = "lut";             % "empirical" or "lut"
match_ps_tbs_to_uniform = true;    % bisect ESS nu to match uniform TBS

receiver_demapper = "mmse";        % "mmse" or "sphere"
max_ldpc_iterations = 25;          % LDPC decoder iteration cap
ldpc_decoding_algorithm = "Layered belief propagation";
make_plots = true;                 % save overlay BLER/throughput figures
output_root = "results/awgn";      % output directory root
```

Per-script differences:

- `tests/test_awgn.m`: AWGN channel, single antenna (defaults `1x1`, 1 layer). No channel/precoding settings — the base config hardcodes the AWGN model.
- `tests/test_mimo.m`: TDL fading (hardcoded `channel.model = "tdl"`, `TDL-E` profile) with open-loop precoding (defaults `4x4`, 4 layers). Adds `tdl_delay_spread`, `maximum_doppler_hz`, and `open_loop_precoder` (`"dft"`, `"identity"`, `"hadamard"`); `output_root = "results/mimo"`.
- `tests/test_simo.m`: TDL fading (hardcoded `channel.model = "tdl"`, `TDL-A` profile), 1 Tx / many Rx / single layer with the identity open-loop precoder. Adds `tdl_delay_spread`, `maximum_doppler_hz`, and `open_loop_precoder`; `output_root = "results/mimo"`.

## TX Chain

Shared NR path (both chain modes):

```text
payload bits
-> nrDLSCH (TB/CB CRC, CB segmentation, LDPC, rate matching, SBPM interleaving)
-> new_pdsch.m: scramble/descramble for unform QAM. shared nrSymbolModulate, nrLayerMap
-> optional open-loop precoding (dft / identity / hadamard)
-> nrOFDMModulate
-> AWGN or nrTDLChannel + AWGN
```

PS adds, ahead of the shared path:

```text
source bits
-> prestructured transport block (build_tb_for_ps.m)
-> ESS encode (per code block, +toolbox/+ProbShaping/+ess)
-> multiplexing of shaped and unshaped bits
```

and inside `new_pdsch.m`: selective scrambling of shaped bits (`ps_scramble.m`) and PS power normalization (`empirical` measures per-TB symbol energy; `lut` uses a precomputed table via `getTxScaling.m`).

## RX Chain

Shared NR path (annotated with owner boundaries; `[PS]` marks PS-only steps, `[PS*]` marks steps that behave differently under PS):

```text
nrOFDMDemodulate                              ┐ upstream (runSimulation.m, shared)
-> channel estimation (perfect)               │
-> nrExtractResources                         ┘
── new_pdsch_decode.m ──────────────────────────────────────────────────────
-> [PS] preprocess_demod_input.m (Cholesky/QR (Y_eq, H_eq), PS-aware norm)
-> nrEqualizeMMSE (or comm.SphereDecoder)     ┐ shared demapper / LLR path
-> nrLayerDemap / nrSymbolDemodulate (soft LLRs)│
-> CSI weighting                              ┘
-> [PS*] descramble (uniform: full; PS: selective ps_descramble.m)
─────────────────────────────────────────────────────────────────────────────
-> nrDLSCHDecoder                             ┐ downstream (runSimulation.m, shared)
-> TB CRC BLER and throughput calculation     ┘
-> [PS] deshape_tb.m -> PS source bits (after decode)
```

Stages between the `new_pdsch_decode.m` markers are owned by that file. `[PS] preprocess_demod_input.m` runs only when `cfg.shaping.enabled` is true; the equalize/demap/LLR/CSI block is common code both chains execute; `[PS*] descramble` is a full descramble for uniform and a selective `ps_descramble.m` for PS. `nrOFDMDemodulate`/channel estimation/`nrExtractResources` (upstream) and `nrDLSCHDecoder`/metrics (downstream) live in `runSimulation.m` and are unconditionally shared.

## Uniform vs PS: Shared and Divergent Paths

Both chains run on the same standard NR spine. PS reuses the entire spine and only bolts narrow modules onto the ends: transport-block construction before `nrDLSCH` at TX, and demod preprocessing / TB recovery around the detector at RX. Everything in the center column is identical for both chains.

The two `new_pdsch*` files are the only shared-path files that branch internally on `cfg.shaping.enabled`; the annotations below show exactly which operations each one owns.

```mermaid
flowchart TB
    payload["payload bits"]
    src["<b>source bits</b><br/>ESS encode per CB (+ess)<br/>multiplex shaped / unshaped<br/>prestructured TB (build_tb_for_ps)"]

    dlsch["<b>nrDLSCH</b><br/>TB/CB CRC · CB seg · LDPC · rate match · SBPM interleave"]
    pdsch["<b>new_pdsch.m</b><br/>scramble → nrSymbolModulate → nrLayerMap<br/><i>[PS] selective ps_scramble + power scaling </i>"]
    ofdm["precoding · nrOFDMModulate"]
    chan["AWGN   or   nrTDLChannel + AWGN"]
    demod["nrOFDMDemodulate · channel est (perfect) · nrExtractResources"]
    decode["<b>new_pdsch_decode.m</b><br/><i>[PS] preprocess_demod_input </i><br/>nrEqualizeMMSE or comm.SphereDecoder<br/>nrLayerDemap · nrSymbolDemodulate <br/><i>descramble /  [PS] selective ps_descramble</i>"]
    ldpcdec["<b>nrDLSCHDecoder</b>"]
    deshape["<b>deshape_tb.m</b>  <i>[PS only]</i><br/>recover PS source bits"]
    metrics["<b>TB CRC → BLER / throughput</b>"]

    payload --> dlsch
    src --> dlsch
    dlsch --> pdsch --> ofdm --> chan --> demod --> decode --> ldpcdec
    ldpcdec --> metrics
    ldpcdec -.-> deshape

    classDef shared fill:#f3f4f6,stroke:#6b7280,stroke-width:1.5px,color:#111827;
    classDef uniform fill:#eff6ff,stroke:#1d4ed8,stroke-width:1.5px,color:#1e3a8a;
    classDef ps fill:#fff7ed,stroke:#b45309,stroke-width:1.5px,color:#7c2d12;
    classDef channel fill:#ecfdf5,stroke:#059669,stroke-width:1.5px,color:#065f46;

    class dlsch,pdsch,ofdm,demod,decode,ldpcdec,metrics shared;
    class payload uniform;
    class src,deshape ps;
    class chan channel;

    linkStyle 0 stroke:#1d4ed8,stroke-width:1.6px;
    linkStyle 1 stroke:#b45309,stroke-width:1.6px;
    linkStyle 9 stroke:#b45309,stroke-width:1.6px,stroke-dasharray:5 4;
```

**Legend:** grey = shared standard-NR path (identical for both chains) · blue = Uniform QAM only · orange = PS only (added around the spine) · green = channel · _italic `[PS]`_ = PS-specific step inside a shared file (`new_pdsch.m` / `new_pdsch_decode.m`). The solid edge from `nrDLSCHDecoder` (BLER / throughput) is shared by both chains; the dashed orange edge to `deshape_tb.m` is PS-only.

**What lives where:**

- `new_pdsch.m` (TX) owns **scramble → `nrSymbolModulate` → `nrLayerMap`**, plus PS power scaling. Precoding and OFDM modulation occur after `new_pdsch.m`, on the shared path. It branches on `cfg.shaping.enabled` only at the scramble step (full vs. selective `ps_scramble.m`) and the trailing power normalization (`empirical` per-TB energy vs. `lut`).
- `new_pdsch_decode.m` (RX) owns **[PS: `preprocess_demod_input.m`] → equalize/detect (`nrEqualizeMMSE` or sphere) → `nrLayerDemap` → `nrSymbolDemodulate` → descramble**. OFDM demodulation, channel estimation, and resource extraction happen *upstream* on the shared path. It branches on `cfg.shaping.enabled` at the preprocessing step (PS-only) and the descramble step (full vs. selective `ps_descramble.m`).

Everything else — `nrDLSCH` / LDPC / rate matching / CRC, precoding, OFDM, the channel, channel estimation, the detector and LLR path, and `nrDLSCHDecoder` — is identical for both chains. The only PS-only stages outside the two `new_pdsch*` files are `build_tb_for_ps.m` (before `nrDLSCH`) and `deshape_tb.m` (after `nrDLSCHDecoder`).

## MIMO Presets

- 1x1 / SIMO (`num_tx_antennas == num_pdsch_layers`): `mimo.precodingMode = "none"`, identity precoder. Supports uniform and PS.
- Open-loop MIMO (`num_tx_antennas > num_pdsch_layers`): `mimo.precodingMode = "openloop"` with `dft`, `identity`, or `hadamard` precoder selection via `open_loop_precoder`.

## Aligning TBS Between Uniform QAM and PS

This alignment exists mainly for **performance-comparison purposes**: a fair uniform-vs-PS BLER-vs-SNR or throughput comparison requires both chains to carry (as closely as possible) the **same number of information bits per transport block** at the **same coding rate**.

Both chains keep the coding rate fixed to the value from their MCS table. Instead, we adjust the Maxwell-Boltzmann shaping parameter `nu`:

- **Uniform QAM**: the TBS comes directly from `nrTBS` for the selected MCS. This is the reference payload size.
- **PS**: the PDSCH still carries a standard `nrDLSCH` transport block, but ESS amplitude shaping consumes part of it, so the user-visible **payload TBS** is smaller and depends on `nu` (heavier shaping → fewer payload bits).

When `match_ps_tbs_to_uniform = true` (`shaping.matchUniformTbs`), `+toolbox/+ProbShaping/+provider/match_ess_nu_to_uniform_tbs.m` searches `nu` for the PS payload TBS that comes **closest** to the uniform-QAM target for the same MCS. The match is approximate, not exact: `nu` is only sampled at a finite set of points and the PS payload TBS is itself quantized, so the two payloads generally differ by a small amount (typically within a ~1% tolerance, which the matcher reports). The chosen `nu` overrides the MCS-table `nu_MB` for the run (`shaping.useMcsTableNu = false`), so the PS chain delivers essentially the same information payload at the same coding rate as the uniform reference. Set `match_ps_tbs_to_uniform = false` to instead use the MCS table's fixed `nu_MB` directly (payload TBS then floats).

## Testing

The driver scripts double as the primary functional tests: each runs a full uniform and/or PS TX/channel/RX sweep end to end and writes a BLER/throughput summary you can inspect for regressions.

- `tests/test_awgn.m`: single-antenna (1 Tx / 1 Rx / 1 layer) fixed-MCS sweep over a waveform-domain AWGN channel. Runs the selected `chain_modes` (uniform and/or PS) across the `snr_db` grid and writes per-SNR BLER, throughput, and shaping metadata to `results/awgn/`. Use it to smoke-test the shared NR chain and PS additions without fading effects.
- `tests/test_mimo.m`: multi-antenna fixed-MCS sweep over a TDL fading channel (default 4 Tx / 4 Rx / 4 layers, TDL-A, open-loop precoding). Exercises the MIMO precoding path, TDL channel, and detector (`mmse` or `sphere`) in addition to the shared chain, writing results to `results/mimo/`. `tests/test_simo.m` is the SIMO variant (1 Tx, many Rx, single layer).
- `tests/test_ess_encode_decode_test.m`: standalone round-trip test for the `@ess` codec (`+toolbox/+ProbShaping/+ess`). Sweeps modulation (`16QAM`/`64QAM`/`256QAM`/`1024QAM`), Maxwell-Boltzmann `nu`, shaped-bit level, and code-block length, builds an energy table and `ess` codec per case, then runs 100 random `encode`/`decode` round trips per case and asserts `decode(encode(bits)) == bits`. Run directly from MATLAB (`run('tests/test_ess_encode_decode_test.m')`); it errors out with a failure count if any round trip mismatches, or prints a `PASS` summary otherwise.

## PS Extension Notes

Implemented PS pieces:

- PS MCS table lookup through `toolbox.getMcsInfo` (`ps_mcs_table1`, `ps_mcs_table2`); each MCS includes a Maxwell-Boltzmann parameter `nu_MB`.
- Per-CB ESS distribution matching and ESS encode/decode under `+toolbox/+ProbShaping/+ess` (energy-table DP in `generateEnergyTable.m`, `@ess` class for `encode`/`decode`).
- TB CRC, CB segmentation, CB CRC, LDPC, and rate matching shared via `nrDLSCH` / `nrDLSCHDecoder`.
- Modified scrambling for un-shaped bits (`+toolbox/+ProbShaping/+mapping`).
- PS-aware demod preprocessing before the shared detector (`+toolbox/+ProbShaping/+demod`).
- Power normalization for nonuniform shaped constellations, either measured per-TB (`empirical`) or from a precomputed LUT (`lut`).
- Uniform-TBS matching: bisects `nu_MB` so the PS payload TBS matches the uniform-QAM TBS for the same MCS (`match_ess_nu_to_uniform_tbs.m`).
- `deshape_tb.m` inverts `build_tb_for_ps.m` to recover PS source bits from a decoded transport block.

For a PS run, set:

```matlab
chain_modes = "ps";
ps_mcs_table = "ps_mcs_table1";
```

## Source Layout

- `tests/test_awgn.m`: AWGN fixed-MCS sweep driver (canonical entry point for AWGN studies).
- `tests/test_mimo.m`: TDL/open-loop MIMO sweep driver.
- `tests/test_simo.m`: TDL SIMO (1 Tx, many Rx, single layer) sweep driver.
- `tests/test_ess_encode_decode_test.m`: standalone ESS codec round-trip test (see Testing).
- `+toolbox/runSimulation.m`: core TX/channel/RX simulation loop; owns the per-SNR/per-TB run and metric aggregation.
- `+toolbox/defaultConfig.m`: baseline configuration.
- `+toolbox/getMcsInfo.m`: uniform (`qam64`, `qam256`) and PS (`ps_mcs_table1`, `ps_mcs_table2`) MCS tables.
- `+toolbox/resolveMcsInfo.m`: selects the active MCS table and effective shaping `nu` for uniform or PS runs.
- `+toolbox/+config/`: config validation (`validate_config.m`) and 5G Toolbox dependency check (`require_5g_toolbox.m`).
- `+toolbox/+phy/+pdsch/`: shared PDSCH build (`build_link_objects.m`), TX modulation (`new_pdsch.m`), RX demod/descramble (`new_pdsch_decode.m`), scrambling sequence and modulation-order utilities.
- `+toolbox/+phy/+mimo/`: MIMO info and DFT/identity/Hadamard precoder builders, resource-grid precoding, and channel-estimate precoder mapping.
- `+toolbox/+phy/+channel/`: AWGN/TDL channel creation, AWGN generation, receive-grid, and slot-timing helpers.
- `+toolbox/+phy/+receiver/`: Sphere-decoder detection and initialization.
- `+toolbox/+ProbShaping/+tbgen/`: PS shaping-plan initialization (`init.m`), prestructured TB construction (`build_tb_for_ps.m`), and TB deshaping (`deshape_tb.m`).
- `+toolbox/+ProbShaping/+ess/`: ESS energy-table generation, Maxwell-Boltzmann distribution, TX-scaling LUT, and the `@ess` encoder/decoder class.
- `+toolbox/+ProbShaping/+mapping/`: PS modified scramble/descramble.
- `+toolbox/+ProbShaping/+demod/`: PS demod preprocessing.
- `+toolbox/+ProbShaping/+provider/`: PS modulation information (`get_ps_modulation_info.m`) and ESS-`nu`-to-uniform-TBS matching (`match_ess_nu_to_uniform_tbs.m`).

## Branches

**main**: Primary development branch. Contributors should develop submissions based on this branch, and submit pull requests to this branch.

## Contributing

Development guidance is in [CONTRIBUTING.md](CONTRIBUTING.md).

## Getting in Contact

- [Report an Issue on GitHub](../../issues)
- [Open a Discussion on GitHub](../../discussions)

## License

evaluation-link-simulator is licensed under the [BSD-3-Clause-Clear License](https://spdx.org/licenses/BSD-3-Clause-Clear.html). See [LICENSE.txt](LICENSE.txt) for the full license text.
