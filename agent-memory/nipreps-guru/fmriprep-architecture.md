# fMRIPrep Architecture Deep Reference

## Config Singleton (`fmriprep/config.py`)

### Sections
- **environment**: Read-only runtime descriptors (cpu_count, exec_env, version, etc.)
- **execution**: Run-level settings (bids_dir, derivatives, output_dir, layout, etc.)
- **workflow**: Preprocessing graph configuration (anat_only, cifti_output, level, etc.)
- **nipype**: NiPype engine settings (nprocs, omp_nthreads, plugin, etc.)
- **seeds**: PRNG seeds (master, ants, numpy)
- **loggers**: Logging configuration (cli, workflow, interface, utils)

### Key Conditional Fields
- `workflow.level`: 'minimal' | 'resampling' | 'full' -- gates early returns in base.py
- `workflow.cifti_output`: None | '91k' | '170k' -- enables fsLR/grayordinates path
- `workflow.run_reconall`: bool -- enables FreeSurfer surfaces path
- `workflow.anat_only`: bool -- skips all BOLD processing
- `workflow.ignore`: list -- can contain 'fieldmaps', 'slicetiming', 'sbref', 'flair', 't2w'
- `workflow.force`: list -- can contain 'bbr', 'no-bbr', 'syn-sdc', 'fmap-jacobian'
- `workflow.bold2anat_init`: 'auto' | 't1w' | 't2w' | 'header'
- `execution.echo_idx`: int|None -- select specific echo for ME data
- `execution.me_output_echos`: bool -- output individual corrected echos
- `execution.derivatives`: dict of paths -- precomputed derivatives dirs

### Spaces System
- `init_spaces()` always adds MNI152NLin2009cAsym
- If cifti_output, also adds MNI152NLin6Asym with appropriate resolution (res-2 for 91k, res-1 for 170k)

## Fit/Transform Split in bold/base.py

### Level Gating (3 early return points)
1. `level == 'minimal'`: return after bold_fit_wf (line 273)
2. `level == 'resampling'`: return after bold_native_wf + native outputs (line 372)
3. `level == 'full'`: complete pipeline (confounds, carpetplot, std spaces, surfaces, CIFTI)

### bold_fit_wf Stages (5 stages, each skippable via precomputed)
1. HMC boldref generation (skip if `precomputed['hmc_boldref']`)
2. Motion correction / HMC (skip if `precomputed['transforms']['hmc']`)
3. Fieldmap registration (skip if `fieldmap_id` is None or `precomputed['transforms']['boldref2fmap']`)
4. Coreg boldref creation with SDC (skip if `precomputed['coreg_boldref']`)
5. BOLD-to-anat registration (skip if `precomputed['transforms']['boldref2anat']`)

### Buffer Pattern
Each stage writes to a "buffer" IdentityInterface node. Precomputed values are set directly on buffer inputs; computed values are connected from sub-workflows to buffers. This makes the skip pattern transparent to downstream consumers.

## Multi-echo Handling
- `bold_series` is a list sorted by EchoTime
- `multiecho = len(bold_series) > 1` (fit.py) or `> 2` (base.py, since ME needs 3+ echos)
- echo_index node uses iterables for ME, static `0` for SE
- join_echos JoinNode collects all echoes after per-echo STC+HMC+SDC resampling
- T2* combination via tedana's t2smap workflow (init_bold_t2s_wf)
- For ME: motion_xfm NOT passed to outputnode (prevents double-dipping)
- For ME: bold_minimal == bold_native (both are the combined time series)
- For SE: bold_minimal is STC-only; bold_native is STC+HMC+SDC resampled
- Downstream volumetric resamplers get `fieldmap_id=None` for ME (already corrected)

## Precomputed Derivatives System
- io_spec.json defines queries for baseline refs (hmc_boldref, coreg_boldref) and transforms (hmc, boldref2anat, boldref2fmap)
- fmap_spec.json defines queries for precomputed fieldmaps (fieldmap, coeffs, magnitude)
- collect_derivatives() uses BIDSLayout with nipreps.json config + custom patterns
- collect_fieldmaps() uses fmapids from the layout

## Surface/CIFTI Processing
- Requires: run_reconall=True
- FreeSurfer spaces: init_bold_surf_wf with mri_vol2surf (6-point cortical ribbon sampling)
- fsLR resampling: ribbon-constrained volume-to-surface, dilate 10mm, mask with cortex_mask, ADAP_BARY_AREA resample
- Grayordinates: combine fsLR surface data + MNI152NLin6Asym subcortical volume -> CIFTI2
- project_goodvoxels: HCP-style COV-based voxel exclusion mask

## Output Organization
- dismiss_echo(): removes echo entity for combined ME outputs
- BIDSURI tracks provenance (Sources field in sidecars)
- prepare_timing_parameters(): converts SliceTiming -> SliceTimingCorrected + StartTime/DelayTime/AcquisitionDuration
- DerivativesDataSink pattern used everywhere with source_file for entity extraction

## Testing Pattern
- mock_config() context manager: loads config.toml, creates temp dirs, initializes BIDSLayout from bundled ds000005
- Test data: ds000005 with sub-01 (T1w + 3 BOLD runs, mixedgamblestask)
- Tests can build workflows without execution via `with mock_config(): wf = init_*_wf(...)`
