# sMRIPrep Architecture Deep Reference

## 1. Role in the NiPreps Ecosystem

sMRIPrep is the **shared anatomical preprocessing backbone** for the NiPreps family.
It processes T1w (and optionally T2w/FLAIR) structural MRI data into a canonical
anatomical reference space, FreeSurfer surfaces, and standard-space registrations.

### How downstream *Preps consume sMRIPrep

fMRIPrep, dMRIPrep, and other downstream tools do **not** call sMRIPrep as a
subprocess. Instead, they:

1. **Import the factory function directly**:
   ```python
   from smriprep.workflows.anatomical import init_anat_preproc_wf
   ```
   (fMRIPrep's `init_anat_fit_wf` in `fmriprep/workflows/anatomical.py` is its
   *own* wrapper that adds fMRIPrep-specific logic, but the core is sMRIPrep's.)

2. **Embed sMRIPrep's workflow** as a sub-workflow within their per-subject graph.

3. **Consume its outputnode contract** to feed functional/diffusion processing.

### The Anatomical Derivatives Contract

Downstream tools expect these outputs from `init_anat_preproc_wf.outputnode`:

| Field | Type | Description |
|---|---|---|
| `t1w_preproc` | NIfTI | Bias-corrected T1w reference (defines anat space) |
| `t1w_mask` | NIfTI | Binary brain mask |
| `t1w_dseg` | NIfTI | 3-class tissue segmentation (GM=1, WM=2, CSF=3) |
| `t1w_tpms` | list[NIfTI] | Tissue probability maps (GM, WM, CSF order) |
| `template` | list[str] | Template names registered to |
| `anat2std_xfm` | list[file] | Forward transforms (anat->standard), collated with template |
| `std2anat_xfm` | list[file] | Reverse transforms (standard->anat) |
| `subjects_dir` | path | FreeSurfer SUBJECTS_DIR |
| `subject_id` | str | FreeSurfer subject ID |
| `fsnative2t1w_xfm` | file | fsnative-to-T1w affine (ITK format) |
| `t1w_aseg` | NIfTI | FreeSurfer aseg in T1w space |
| `t1w_aparc` | NIfTI | FreeSurfer aparc+aseg in T1w space |
| `sphere_reg` | list[GIFTI] | L/R sphere.reg (fsaverage registration) |
| `sphere_reg_fsLR` | list[GIFTI] | L/R fsLR registration spheres |
| `anat_ribbon` | NIfTI | Cortical ribbon volumetric mask |

These fields are the **seam** between anatomical and modality-specific processing.

### Precomputed Derivatives System (`--derivatives`)

The `--derivatives` CLI flag (or `derivatives` parameter) accepts paths to
BIDS-Derivatives directories. For each directory:

1. `utils/bids.py:collect_derivatives()` is called
2. It loads `io_spec.json` which defines BIDS queries for:
   - **baseline**: `preproc` (T1w), `mask`, `dseg`, `tpms`, `t2w_preproc`
   - **transforms**: `forward` (from-T1w) and `reverse` (to-T1w) for each space
   - **surfaces**: `white`, `pial`, `midthickness`, `sphere`, `sphere_reg`,
     `sphere_reg_fsLR`, `sphere_reg_msm`, `cortex_mask`, `thickness`, `sulc`, `curv`
   - **masks**: `anat_ribbon`
3. Results populate a `deriv_cache` dict passed as `precomputed` to `init_anat_fit_wf`
4. Each stage in `init_anat_fit_wf` checks the dict and skips if derivatives exist

The `collect_derivatives()` function uses a `BIDSLayout` with `nipreps.json` config
and the custom patterns from `io_spec.json`.

## 2. Complete Workflow Architecture

### Top-Level DAG

```
init_smriprep_wf()
  |
  +-- BIDSFreeSurferDir (if freesurfer)
  |     Initializes FS subjects_dir with template subjects
  |
  +-- [per subject-session pair]:
        init_single_subject_wf()
          |
          +-- BIDSDataGrabber, BIDSInfo
          +-- SubjectSummary, AboutSummary (reports)
          +-- init_anat_preproc_wf()
                |
                +-- init_anat_fit_wf() [CORE]
                +-- init_template_iterator_wf() [space iteration]
                +-- init_ds_anat_volumes_wf() [standard space outputs]
                +-- [if freesurfer]:
                |     init_surface_derivatives_wf()
                |     init_ds_surfaces_wf() [inflated]
                |     init_ds_surface_metrics_wf() [curv]
                |     init_ds_fs_segs_wf() [aseg, aparc]
                +-- [if cifti_output]:
                      init_hcp_morphometrics_wf()
                      init_resample_surfaces_wf()
                      init_morph_grayords_wf()
                      init_ds_surfaces_wf() [fsLR surfaces]
                      init_ds_grayord_metrics_wf()
```

### init_anat_preproc_wf (anatomical.py)

This is the **compatibility wrapper** around `init_anat_fit_wf`. It:
1. Calls `init_anat_fit_wf` for the core processing
2. Creates `init_template_iterator_wf` + `init_ds_anat_volumes_wf` for
   writing standard-space volumetric derivatives
3. Conditionally adds surface derivative workflows and CIFTI outputs
4. Exposes the full outputnode contract to downstream consumers

### init_anat_fit_wf (anatomical.py, `@tag('anat.fit')`)

The core estimation workflow. Uses the **buffer node pattern** extensively.

#### Buffer Nodes (7 buffers)

| Buffer | Fields | Purpose |
|---|---|---|
| `sourcefile_buffer` | `source_files` | Validated input T1w list |
| `t1w_buffer` | `t1w_preproc`, `t1w_mask`, `t1w_brain`, `ants_seg` | Stage 2 results |
| `seg_buffer` | `t1w_dseg`, `t1w_tpms` | Stage 3 results |
| `template_buffer` | `in1`/`in2` (Merge) | Collated template names |
| `anat2std_buffer` | `in1`/`in2` (Merge) | Forward transforms |
| `std2anat_buffer` | `in1`/`in2` (Merge) | Reverse transforms |
| `fs2anat_buffer` | `fsnative2anat_xfm` | FreeSurfer registration |
| `refined_buffer` | `t1w_mask`, `t1w_brain` | Refined mask after FS |
| `surfaces_buffer` | `white`, `pial`, `midthickness`, `sphere`, `sphere_reg`, `thickness`, `sulc` | GIFTI surfaces |
| `fsLR_buffer` | `sphere_reg_fsLR` | fsLR registration |
| `msm_buffer` | `sphere_reg_msm` | MSM-Sulc registration |

#### Processing Stages (11 stages, each independently skippable)

**Stage 1: T1w Template Construction**
- Skip if: `t1w_preproc` in precomputed
- Sub-workflow: `init_anat_template_wf`
- Steps: Denoise (ANTs), Conform, N4 bias correction, multi-T1w merge
  (FreeSurfer `mri_robust_template` if >1 image)
- Output: Single T1w reference, realignment transforms
- Datasink: `init_ds_template_wf`

**Stage 2: Brain Extraction / INU Correction**
- Skip if: `t1w_mask` in precomputed
- 4 code paths based on (`have_mask`, `have_t1w`, `skull_strip_mode`):
  - `force` + no precomputed: `init_brain_extraction_wf` (ANTs BET)
  - `auto` with pre-stripped input: `init_n4_only_wf`
  - `skip` with precomputed T1w: binarize input
  - Precomputed mask: apply mask + optional N4
- Datasink: `init_ds_mask_wf`

**Stage 3: Tissue Segmentation**
- Skip if: `t1w_dseg` AND `t1w_tpms` in precomputed
- Tool: FSL FAST (3-class, no bias correction since already done)
- LUT remap: FAST order (CSF=0, WM=1, GM=2) -> BIDS order (GM=1, WM=2, CSF=3)
- Datasinks: `init_ds_dseg_wf`, `init_ds_tpms_wf`

**Stage 4: Spatial Normalization**
- Skip per-template if: `transforms[template]` has both forward+reverse
- Sub-workflow: `init_register_template_wf` (fit/registration.py)
- Uses `inputnode.iterables` over template list for parameterized execution
- ANTs `SpatialNormalization` with truncated intensity input
- Datasink: `init_ds_template_registration_wf`
- Merge buffers combine precomputed + newly computed transforms

**Stage 5: FreeSurfer Surface Reconstruction** (gated by `freesurfer=True`)
- Sub-workflow: `init_surface_recon_wf`
  - `autorecon1` -> `skull_strip_extern` -> `init_autorecon_resume_wf`
  - Creates midthickness surface from white+graymid
  - Computes `fsnative2t1w_xfm` via `RobustRegister`
- OR `fs_no_resume=True`: skip recon-all, just read existing FS directory
- Datasink: `init_ds_fs_registration_wf`

**Stage 6: Brain Mask Refinement**
- Skip if: `t1w_mask` in precomputed OR `freesurfer=False`
- Sub-workflow: `init_refinement_wf` -> `init_segs_to_native_wf` + `RefineBrainMask`
- Reconciles ANTs and FreeSurfer brain masks (Mindboggle method)

**Stage 7: T2w Template** (if T2w images provided and not precomputed)
- Creates T2w template analogous to Stage 1
- BBRegister (T2-to-fsnative), concatenate with fsnative2anat, resample to T1w
- Datasink: `ds_t2w_preproc`

**Stage 8: Surface Conversion**
- Skip per-surface if: precomputed surfaces found (len==2 per surface)
- Sub-workflows: `init_gifti_surfaces_wf`, `init_gifti_morphometrics_wf`
- Surfaces: white, pial, midthickness (anatomical, to-scanner coords)
- Spheres: sphere, sphere_reg (no transform applied)
- Metrics: thickness, sulc
- Datasinks: `init_ds_surfaces_wf`, `init_ds_surface_metrics_wf`

**Stage 8a: Cortical Ribbon Mask**
- Skip if: `anat_ribbon` in precomputed
- Sub-workflow: `init_anat_ribbon_wf`
- Creates volumetric ribbon from signed distance volumes of white+pial surfaces

**Stage 9: fsLR Registration**
- Skip if: `sphere_reg_fsLR` has 2 entries in precomputed
- Sub-workflow: `init_fsLR_reg_wf`
- Uses `SurfaceSphereProjectUnproject` with fsaverage atlas spheres

**Stage 10: MSM-Sulc** (gated by `msm_sulc=True`)
- Skip if: `sphere_reg_msm` has 2 entries in precomputed
- Sub-workflow: `init_msm_sulc_wf`
- Steps: affine regression, apply affine, modify sphere, invert sulc, MSM tool
- Configuration: `MSMSulcStrainFinalconf` (or `Sloppy` variant)

**Stage 11: Cortical Surface Mask**
- Skip if: `cortex_mask` has 2 entries in precomputed
- Sub-workflow: `init_cortex_masks_wf`
- Steps: abs(thickness) -> binarize -> fill holes -> remove islands

### Outputnode Fields (init_anat_fit_wf)

Primary derivatives: `t1w_preproc`, `t2w_preproc`, `t1w_mask`, `t1w_dseg`, `t1w_tpms`
Transforms: `anat2std_xfm`, `std2anat_xfm`, `fsnative2t1w_xfm`
Surfaces: `white`, `pial`, `midthickness`, `sphere`, `sphere_reg`, `thickness`, `sulc`
Registration spheres: `sphere_reg_fsLR`, `sphere_reg_msm`
Masks: `cortex_mask`, `anat_ribbon`
Metadata: `template`, `subjects_dir`, `subject_id`, `t1w_valid_list`

## 3. Interface Inventory

### `interfaces/__init__.py`
- `DerivativesDataSink`: Subclass of niworkflows' DDS with `out_path_base = 'smriprep'`

### `interfaces/freesurfer.py`
- `ReconAll`: Extended recon-all with `steps` input (individual FS steps), `hemi` input,
  and smart resume logic (checks output timestamps vs inputs)
- `MRIsConvertData`: Wraps `mris_convert` for scalar data (curv, thickness, sulc);
  auto-selects ?h.white surface from the same directory
- `MakeMidthickness`: Patched `MRIsExpand` that ensures hemisphere-labeled output names
  and adjusts OMP_NUM_THREADS to 1.5x requested (FreeSurfer underutilization fix)

### `interfaces/cifti.py`
- `GenerateDScalar`: Creates CIFTI-2 dscalar.nii from L/R GIFTI scalar surfaces
  Uses templateflow's fsLR nomedialwall parcellation for masking
  Outputs both the CIFTI file and a JSON metadata sidecar

### `interfaces/fsl.py`
- `FAST`: Patched FSL FAST that allows `bias_iters=0` (Range(low=0) vs original Range(low=1))

### `interfaces/gifti.py`
- `MetricMath`: Python (nibabel-based) equivalent of wb_command operations:
  - `invert`: multiply by -1 (for HCP sulc/curv convention)
  - `abs`: absolute value (for HCP thickness)
  - `bin`: binarize (>0) for ROI creation
  Sets AnatomicalStructurePrimary and map names per HCP convention

### `interfaces/msm.py`
- `MSM`: CommandLine interface wrapping the `msm` binary
  Inputs: in_mesh, reference_mesh, in_data, reference_data, config_file
  Outputs: warped_mesh (sphere.reg.surf.gii), downsampled_warped_mesh, warped_data

### `interfaces/reports.py`
- `SubjectSummary`: HTML reportlet with subject info (T1w count, spaces, FS status)
- `AboutSummary`: HTML reportlet with sMRIPrep version and command
- `FSSurfaceReport`: Generates brain+ribbon overlay visualization from FS outputs

### `interfaces/surf.py`
- `NormalizeSurf`: Removes FreeSurfer VolGeom metadata from GIFTI surfaces
  (required for Connectome Workbench compatibility), applies optional LTA/ITK transform,
  adds MidThickness metadata for graymid surfaces, fixes "Sphere" -> "Spherical" GeometricType
- `FixGiftiMetadata`: Lighter version that only fixes GeometricType
- `AggregateSurfaces`: Groups surface/morphometry files by type (white, pial, etc.) into L/R pairs
- `MakeRibbon`: Creates binary ribbon mask from white/pial signed distance volumes

### `interfaces/workbench.py`
- `CreateSignedDistanceVolume`: `wb_command -create-signed-distance-volume`
- `SurfaceAffineRegression`: `wb_command -surface-affine-regression`
- `SurfaceApplyAffine`: `wb_command -surface-apply-affine`
- `SurfaceApplyWarpfield`: `wb_command -surface-apply-warpfield`
- `SurfaceModifySphere`: `wb_command -surface-modify-sphere` (fix radius to 100)
- `SurfaceSphereProjectUnproject`: `wb_command -surface-sphere-project-unproject`
- `SurfaceResample`: `wb_command -surface-resample` (BARYCENTRIC or ADAP_BARY_AREA)

### `interfaces/templateflow.py`
- `TemplateFlowSelect`: Fetches T1w, brain mask, and optionally T2w from TemplateFlow
- `TemplateDesc`: Splits template string "MNI152:cohort-2" into name + spec dict
- `fetch_template_files()`: Standalone function used at build time to prefetch templates

## 4. Configuration and Conditional Branches

### CLI Configuration (cli/run.py)

sMRIPrep does NOT use a config singleton like fMRIPrep. All parameters are passed
as explicit keyword arguments through the workflow factory function chain:

```
CLI args (argparse) -> build_workflow() -> init_smriprep_wf() -> init_single_subject_wf() -> init_anat_preproc_wf() -> init_anat_fit_wf()
```

### Key CLI Arguments and Their Effects

| Argument | Values | Effect |
|---|---|---|
| `--skull-strip-mode` | `auto`/`skip`/`force` | Controls Stage 2 brain extraction path |
| `--fs-no-reconall` | flag | Sets `freesurfer=False`, skips Stages 5-11 |
| `--no-submm-recon` | flag | Sets `hires=False` in FreeSurfer |
| `--no-msm` | flag | Sets `msm_sulc=False`, skips Stage 10 |
| `--cifti-output` | `91k`/`170k`/False | Enables CIFTI grayordinate outputs |
| `--longitudinal` | flag (deprecated) | Maps to `--subject-anatomical-reference unbiased` |
| `--subject-anatomical-reference` | `first-lex`/`unbiased`/`sessionwise` | Controls template construction strategy |
| `--fs-no-resume` | flag | Import pre-existing FS without running recon-all |
| `--derivatives` | paths | Precomputed derivatives directories |
| `--output-spaces` | space specs | TemplateFlow-based output spaces |
| `--sloppy` | flag | Low-quality mode for testing |
| `--session-label` | sessions | Filter sessions to process |
| `--bids-filter-file` | JSON path | Custom BIDS query filters |

### subject_anatomical_reference Modes

- **`first-lex`** (default): Use first T1w in lexicographic order. Each subject
  gets one anatomical reference across all sessions.
- **`unbiased`**: Create an unbiased structural template from all T1w images
  (FreeSurfer `mri_robust_template`). Sets `longitudinal=True` internally.
  Increases runtime significantly.
- **`sessionwise`**: Process each session independently. Creates separate
  subject-session pairs in `subject_session_list`. Each session gets its own
  anatomical reference. Requires sessions to exist.

### Conditional Branches Summary

1. **Have precomputed T1w** (`t1w_preproc` in cache): Skip template construction
2. **Have precomputed mask** (`t1w_mask` in cache): Skip brain extraction
3. **skull_strip_mode=auto**: Check if images are already skull-stripped via edge voxel test
4. **Have precomputed dseg/tpms**: Skip FAST segmentation
5. **Per-template transform check**: Skip registration for templates with both forward+reverse
6. **freesurfer=False**: Early return after Stage 4 (no surfaces at all)
7. **have_mask + freesurfer**: Skip mask refinement (Stage 6)
8. **T2w images present**: Enable T2w template and pial refinement
9. **FLAIR images present**: Enable FLAIR-based pial refinement
10. **fs_no_resume=True**: Skip recon-all, just verify FS directory exists
11. **Per-surface precomputed check**: Skip GIFTI conversion for found surfaces
12. **msm_sulc=True**: Enable MSM-Sulc Stage 10
13. **cifti_output**: Enable HCP morphometrics + grayordinates output path

## 5. The Fit/Transform Paradigm in sMRIPrep

### Fit Stage = init_anat_fit_wf

Everything in `init_anat_fit_wf` is **estimation**:
- T1w reference construction
- Brain mask estimation
- Tissue segmentation
- Spatial normalization transforms
- FreeSurfer surface reconstruction
- Surface registration spheres (fsLR, MSM)
- Cortical masks and ribbon

All outputs go through DerivativesDataSink nodes, making them available as
precomputed inputs for subsequent runs.

### Transform Stage = init_anat_preproc_wf wrapper

The transform-like operations are:
- `init_template_iterator_wf` + `init_ds_anat_volumes_wf`: Resample T1w/mask/dseg/tpms
  to each requested standard space
- `init_surface_derivatives_wf`: Convert FS volumes (aseg, aparc) to T1w space
- `init_resample_surfaces_wf`: Resample surfaces to fsLR density
- `init_morph_grayords_wf`: Create CIFTI dscalar files

### Where Buffer Nodes Exist

Every stage in `init_anat_fit_wf` uses buffer nodes. The pattern is:
```python
# Check precomputed
if not have_X:
    # compute X
    workflow.connect([(compute_node, buffer, [('out', 'field')])])
    workflow.connect([(buffer, datasink, [('field', 'in_file')])])
    workflow.connect([(datasink, outputnode, [('out_file', 'field')])])
else:
    buffer.inputs.field = precomputed['X']
    workflow.connect([(buffer, outputnode, [('field', 'field')])])
```

For transforms, the `niu.Merge(2)` pattern is used:
- `in1` holds precomputed transforms (set at build time)
- `in2` holds newly computed transforms (connected at build time)
- `out` concatenates both lists

### Key Difference from fMRIPrep's Fit/Transform

sMRIPrep does NOT have `--level` gating (minimal/resampling/full). The entire
workflow always runs to completion. Level gating is a fMRIPrep concept for
BOLD processing.

However, the precomputed derivatives system achieves a similar effect: if all
anatomical derivatives exist, sMRIPrep effectively becomes a pass-through that
validates and re-sinks the precomputed files.

## 6. Testing Patterns

### Workflow Construction Tests (`workflows/tests/test_anatomical.py`)

- **Fixture**: `bids_root` creates a BIDS skeleton via `generate_bids_skeleton`
  with sub-01 (2 T1w runs, 1 T2w, 2 BOLD, fieldmaps)
- **Quiet logger fixture**: Suppresses nipype.workflow to ERROR level
- **`test_init_anat_preproc_wf`**: Parametrized over `freesurfer` x `cifti_output`
  Builds the workflow without execution
- **`test_anat_fit_wf`**: Parametrized over `msm_sulc` x `skull_strip_mode`
- **`test_anat_fit_precomputes`**: Exhaustive parametric test over 10 dimensions:
  t1w count, t2w count, skull_strip_mode, precomputed {t1w_preproc, t2w_preproc,
  t1w_mask, t1w_dseg, t1w_tpms, xfms, sphere_reg_msm}
  Validates that `generate_expanded_graph` succeeds (no unconnected nodes)

### Surface Tests (`workflows/tests/test_surfaces.py`)

- **`test_ribbon_workflow`**: Integration test requiring mris_convert, wb_command,
  and $SUBJECTS_DIR. Creates ribbon from fsaverage and compares to reference.
- **`test_select_seg`**: Unit test for segmentation file selection logic.

### Interface Tests

- `interfaces/tests/test_surf.py` exists for NormalizeSurf
- Doctest-based tests in interface modules (MSM, workbench commands, TemplateFlowSelect)
- `conftest.py` populates namespace for doctests

## 7. Key Differences: fMRIPrep's anat_fit_wf vs sMRIPrep's

### What fMRIPrep Adds/Changes

1. **Config singleton**: fMRIPrep reads from `config.workflow.*` and `config.execution.*`
   at build time. sMRIPrep passes all params as explicit kwargs.

2. **Level gating**: fMRIPrep has `--level minimal|resampling|full` which gates
   how far BOLD processing goes. sMRIPrep has no such concept.

3. **Anatomical reference selection**: fMRIPrep's `init_anat_fit_wf` supports
   `bold2anat_init` auto-selection (prefers T2w if available). sMRIPrep always
   uses T1w as reference.

4. **Integration with functional**: fMRIPrep's anatomical outputs feed directly into
   `init_bold_fit_wf` for BOLD-to-anat registration, BOLD confound extraction
   (using masks/segs), and surface sampling.

5. **Infant/special populations**: fMRIPrep has dedicated infant-specific anatomical
   processing paths. sMRIPrep's anatomical path is general-purpose.

### Interface Surface Between Codebases

fMRIPrep depends on sMRIPrep as a Python package. The key import points are:

```python
# Direct workflow import
from smriprep.workflows.anatomical import init_anat_preproc_wf

# Surface workflows
from smriprep.workflows.surfaces import (
    init_gifti_surfaces_wf,
    init_resample_surfaces_wf,
    init_morph_grayords_wf,
    ...
)

# Output workflows
from smriprep.workflows.outputs import (
    init_ds_surfaces_wf,
    init_ds_surface_metrics_wf,
    init_ds_grayord_metrics_wf,
    init_template_iterator_wf,
    ...
)

# Interfaces
from smriprep.interfaces import DerivativesDataSink
from smriprep.interfaces.surf import NormalizeSurf
from smriprep.interfaces.cifti import GenerateDScalar

# Utilities
from smriprep.utils.bids import collect_derivatives
```

## 8. Workflow Factory Function Inventory

### workflows/base.py
| Function | Returns | Purpose |
|---|---|---|
| `init_smriprep_wf()` | Workflow | Top-level: per-subject loop + FS dir |
| `init_single_subject_wf()` | Workflow | Per-subject: data grab + anat_preproc |

### workflows/anatomical.py
| Function | Returns | Purpose |
|---|---|---|
| `init_anat_preproc_wf()` | Workflow | Compatibility wrapper: fit + transform outputs |
| `init_anat_fit_wf()` | Workflow | Core 11-stage anatomical estimation |
| `init_anat_template_wf()` | Workflow | Multi-T1w/T2w template construction |

### workflows/surfaces.py
| Function | Returns | Purpose |
|---|---|---|
| `init_surface_recon_wf()` | Workflow | FreeSurfer recon-all orchestration |
| `init_autorecon_resume_wf()` | Workflow | Parallelized recon-all stages 2-3 |
| `init_refinement_wf()` | Workflow | ANTs+FS mask reconciliation |
| `init_surface_derivatives_wf()` | Workflow | FS->GIFTI: inflated, curv, aseg, aparc |
| `init_gifti_surfaces_wf()` | Workflow | FS surfaces -> GIFTI (with transform) |
| `init_gifti_morphometrics_wf()` | Workflow | FS morphometry -> GIFTI shape files |
| `init_hcp_morphometrics_wf()` | Workflow | FreeSurfer->HCP convention conversion |
| `init_cortex_masks_wf()` | Workflow | Cortical ROI from thickness |
| `init_fsLR_reg_wf()` | Workflow | fsaverage -> fsLR sphere projection |
| `init_msm_sulc_wf()` | Workflow | MSM sulcal depth registration |
| `init_anat_ribbon_wf()` | Workflow | Volumetric cortical ribbon mask |
| `init_resample_surfaces_wf()` | Workflow | Resample surfaces to template density |
| `init_morph_grayords_wf()` | Workflow | Morphometry -> CIFTI dscalar |
| `init_segs_to_native_wf()` | Workflow | FS segmentations to native anat space |

### workflows/outputs.py
| Function | Returns | Purpose |
|---|---|---|
| `init_anat_reports_wf()` | Workflow | QC reportlets (dseg, normalization, FS) |
| `init_ds_template_wf()` | Workflow | Save desc-preproc T1w/T2w |
| `init_ds_mask_wf()` | Workflow | Save brain/ribbon masks |
| `init_ds_dseg_wf()` | Workflow | Save discrete segmentation |
| `init_ds_tpms_wf()` | Workflow | Save tissue probability maps |
| `init_ds_template_registration_wf()` | Workflow | Save anat2std + std2anat xfms |
| `init_ds_fs_registration_wf()` | Workflow | Save fsnative2anat + inverse xfms |
| `init_ds_surfaces_wf()` | Workflow | Save GIFTI surfaces |
| `init_ds_surface_metrics_wf()` | Workflow | Save GIFTI metrics (.shape.gii) |
| `init_ds_grayord_metrics_wf()` | Workflow | Save CIFTI dscalar metrics |
| `init_ds_anat_volumes_wf()` | Workflow | Save standard-space volumes |
| `init_ds_fs_segs_wf()` | Workflow | Save aseg + aparc+aseg |
| `init_ds_surface_masks_wf()` | Workflow | Save surface masks (.label.gii) |
| `init_template_iterator_wf()` | Workflow | Iterate over output spaces |

### workflows/fit/registration.py
| Function | Returns | Purpose |
|---|---|---|
| `init_register_template_wf()` | Workflow | ANTs registration to standard templates |

## 9. Data Files

### `data/io_spec.json`
Defines BIDS queries for precomputed derivatives collection:
- `queries.baseline`: T1w preproc, mask, dseg, tpms, T2w preproc
- `queries.transforms`: forward (from-T1w) and reverse (to-T1w)
- `queries.surfaces`: 12 surface types (white, pial, midthickness, sphere, sphere_reg, sphere_reg_fsLR, sphere_reg_msm, cortex_mask, thickness, sulc, curv)
- `queries.masks`: anat_ribbon
- `patterns`: 5 BIDS filename patterns for layout configuration

### `data/atlases/`
Contains fsaverage and fsLR atlas files used for:
- fsLR sphere registration (project/unproject)
- MSM-Sulc reference data (refsulc, spherical_std)
- Atlas ROI masks for CIFTI generation

### `data/msm/`
- `MSMSulcStrainFinalconf`: Full MSM configuration
- `MSMSulcStrainSloppyconf`: Sloppy (fast) MSM configuration

### `data/itkIdentityTransform.txt`
Identity transform for single-image template (no realignment needed)

## 10. External Tool Dependencies

| Tool | Used By | Purpose |
|---|---|---|
| FreeSurfer recon-all | `init_surface_recon_wf` | Surface reconstruction |
| FreeSurfer mris_convert | `init_gifti_surfaces_wf` | FS surface -> GIFTI |
| FreeSurfer mris_expand | `MakeMidthickness` | Create midthickness surface |
| FreeSurfer mri_robust_template | `init_anat_template_wf` | Multi-T1w averaging |
| FreeSurfer bbregister | Stage 7 (T2w) | T2w-to-fsnative registration |
| FreeSurfer mri_vol2vol | `init_segs_to_native_wf` | Resample FS segs |
| ANTs N4BiasFieldCorrection | Stage 1 | Bias field correction |
| ANTs antsBrainExtraction | Stage 2 | Brain extraction |
| ANTs antsRegistration | Stage 4 | Spatial normalization |
| FSL FAST | Stage 3 | Tissue segmentation |
| FSL fslmaths (ApplyMask) | Stage 6 | Apply refined mask |
| wb_command (Workbench) | Stages 8-11, CIFTI | Surface operations |
| MSM | Stage 10 | Multimodal surface matching |
