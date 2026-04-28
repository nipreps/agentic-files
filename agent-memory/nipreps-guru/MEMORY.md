# NiPreps Guru Memory

## NiPreps Framework Reference (www.nipreps.org) - see [nipreps-website.md](nipreps-website.md)

### Mission: "Analysis-grade data" — minimally preprocessed but safe to consume directly
### Three Layers: Infrastructure (NiPype, NiBabel, BIDS, NiTransforms, TemplateFlow) → Middleware (NiWorkflows, SDCFlows, NiReports) → End-user BIDS-Apps (fMRIPrep, dMRIPrep, MRIQC, PETPrep)
### Key Principles: Robustness, Ease of use, Glass-box transparency
### Anti-feature-creep: "paring knife, not Swiss army knife" — scope strictly limited to preprocessing
### CalVer: YY.MINOR.PATCH; bug-fix releases require derivatives+API+UI compatibility
### Licensing: Apache 2.0 default; CC0 for citation boilerplate and test data; MIT allowed for containers/wrappers
### Containerization: Docker (local/cloud) + Singularity/Apptainer (HPC); always `--cleanenv`; `-u $(id -u):$(id -g)`
### DataLad in containers: uid must match dataset installer; remove `:ro` for git-annex writes
### Governance: NSC (5 seats as of Aug 2025); liberal contribution model; .maint/MAINTAINERS.md + CONTRIBUTORS.md
### Coding: `init_<name>_wf()`, variables end `_wf`, PR prefixes ENH/FIX/TST/DOC/STY/REF/CI/MAINT
### Telemetry: fMRIPrep ~11,800 runs/week, ~66.2% success rate (Jan 2026)
### Recent: PETPrep first alpha (Aug 2025), NiFreeze ISMRM 2025 poster award, hackathons 2024+2025

## dMRIPrep Codebase State (2026-02-13)

### Architecture
- Follows fMRIPrep fit/transform pattern with `--level minimal|resampling|full`
- Base workflow at `dmriprep/workflows/base.py` delegates to SMRIPrep for anatomical
- DWI workflows in `dmriprep/workflows/dwi/` (base, fit, hmc, registration, resampling, outputs, eddy)
- NiFreeze interfaces at `dmriprep/interfaces/nifreeze.py` (NiFreezeEstimate, ExtractTransforms, RotateBVecs)
- Config system mirrors fMRIPrep's ToML singleton pattern
- I/O spec for precomputed derivatives in `dmriprep/data/io_spec.json` and `dmriprep/data/fmap_spec.json`

### Key Issues Found
- `ResampleDWISeries` in resampling.py has placeholder SDC: `# SDC would be applied here using sdcflows` (line ~390)
- NiFreeze interfaces assume API (`Estimator`, `DWI.motion_affines`, `DWI.eddy_xfms`) that may not match actual nifreeze
- `_write_motion_params` uses `transforms3d` which is not in deps
- Old eddy.py (FSL Eddy workflow) exists but is NOT connected to the new fit/transform architecture
- `BIDSSourceFile` references `self.inputs.bids_info['bold']` instead of `'dwi'` (line 108 of interfaces/bids.py)
- No `__init__.py` for `dmriprep/workflows/dwi/tests/`

### Test Coverage
- Very sparse: test_parser.py, test_version.py, test_vectors.py, test_bids.py, test_fit.py
- No integration/smoke tests for workflow construction
- No tests for interfaces (nifreeze, images, reports)

### User Preferences (oesteban)
- Owner/maintainer of the project
- Prefers pixi for environment management (linux-64), micromamba fallback for macOS

## fMRIPrep Architecture (2026-02-13) - see [fmriprep-architecture.md](fmriprep-architecture.md)

### Key Design Patterns
- **Workflow factory functions**: `init_*_wf()` return `pe.Workflow`, take config at build time
- **Fit/Transform split**: `init_bold_fit_wf` (estimation) vs `init_bold_native_wf`/`init_bold_volumetric_resample_wf`
- **Buffer nodes**: IdentityInterface nodes hold precomputed or computed values interchangeably
- **Staged skip pattern**: Each fit stage checks `precomputed` dict; if derivative exists, skip
- **Level gating**: `config.workflow.level` = minimal|resampling|full controls early returns
- **Config singleton**: `fmriprep.config` module with class-based sections, ToML serialization
- **DerivativesDataSink pattern**: Every output through BIDS-Derivatives compliant sinks
- **One-shot resampling**: `ResampleSeries` concatenates all transforms (HMC+SDC+coreg+normalization)

### Critical Conditional Branches in bold/fit.py
- 5 stages, each independently skippable via precomputed derivatives dict
- `workflow.ignore` list gates: STC (slicetiming), sbref, fieldmaps, flair, t2w
- `workflow.force` list gates: bbr/no-bbr, syn-sdc, fmap-jacobian
- `workflow.bold2anat_init`: auto resolves to t2w (if available) or t1w at subject level

### Multi-echo Critical Path
- echo_index.iterables drives per-echo processing
- join_echos JoinNode merges after per-echo STC+HMC+SDC
- ME: motion_xfm NOT passed downstream (prevents double resampling)
- ME: fieldmap_id=None for downstream volumetric resamplers
- Two-echo data explicitly rejected (RuntimeError in base.py)

## sMRIPrep Architecture (2026-02-14) - see [smriprep-architecture.md](smriprep-architecture.md)

### Role in NiPreps Ecosystem
- **Shared anatomical engine** for fMRIPrep, dMRIPrep, and other downstream *Preps
- fMRIPrep imports `init_anat_preproc_wf` / `init_anat_fit_wf` directly from `smriprep.workflows.anatomical`
- Located at `/Users/oesteban/workspace/smriprep`

### Key Design Differences from fMRIPrep
- **No config singleton**: All parameters passed as explicit kwargs to factory functions
- **No `--level` flag**: No fit/transform gating (always runs full pipeline)
- **Precomputed derivatives via `--derivatives`**: `collect_derivatives()` + `io_spec.json` queries populate `deriv_cache` dict
- **30+ workflow factory functions** across `anatomical.py`, `surfaces.py`, `outputs.py`, `fit/registration.py`

### 11-Stage Anatomical Pipeline (`init_anat_fit_wf`)
Each stage has a buffer node and is independently skippable via precomputed derivatives:
1. Template construction (multi-image longitudinal or single-image passthrough)
2. Brain extraction (SynthStrip/ANTs via NiWorkflows)
3. Tissue segmentation (FSL FAST)
4. Spatial normalization (ANTs via iterables over templates + JoinNode)
5. FreeSurfer surface reconstruction (autorecon1 + skull_strip_extern + parallel autorecon2/3)
6. Brain mask refinement (from FreeSurfer ribbon)
7. T2w-to-T1w coregistration (optional, when T2w available)
8. Surface format conversion (FreeSurfer to GIFTI) + morphometrics
9. Cortical ribbon mask generation
10. fsLR registration (SurfaceSphereProjectUnproject from fsaverage to fsLR)
11. MSM-Sulc (optional, Multimodal Surface Matching with sulcal depth)

### Downstream Consumer Contract
- **Anatomical derivatives**: preprocessed T1w/T2w, brain mask, tissue segmentation (dseg + tpms)
- **Spatial transforms**: anat2std_xfm / std2anat_xfm per template (via JoinNode lists)
- **Surface derivatives**: white/pial/midthickness/inflated per hemisphere (GIFTI), morphometrics (thickness, sulc, curv)
- **fsLR surfaces**: sphere.reg per hemisphere, CIFTI grayordinates (91k or 170k)
- **Cortical masks**: ROI files for cortex L/R, anat_ribbon volume mask

### CLI Key Arguments
- `--subject-anatomical-reference`: first-lex (default) | unbiased | sessionwise
- `--derivatives`: path(s) to precomputed BIDS-Derivatives
- `--skull-strip-mode`: auto | skip | force
- `--cifti-output`: 91k | 170k (enables CIFTI grayordinates)
- `--no-msm`: skip MSM-Sulc registration
- `--fs-no-reconall` / `--fs-no-resume`: control FreeSurfer execution

### Testing Patterns
- Parametric workflow construction tests in `test_anatomical.py`
- Uses `generate_bids_skeleton` for synthetic BIDS datasets
- Exhaustive precomputed derivatives combination test (all 2^N subsets)
- Conftest provides `bids_skeleton_factory` fixture

## fMRIPrep-rodents Architecture (2026-02-18) - see [fmriprep-rodents-architecture.md](fmriprep-rodents-architecture.md)

### What It Is
- Rodent fMRI preprocessing — standalone package (`fprodents`), NOT a fork of fMRIPrep
- T2w-primary contrast, Fischer344 default template, nirodents brain extraction
- Codebase resembles fMRIPrep circa 2020 — no fit/transform, no SDC, no surfaces

### Critical State
- Dependencies pinned 3+ years behind (niworkflows >=1.5.2 vs fMRIPrep's ~1.12+)
- No fit/transform split, no --level support, no one-shot resampling
- SDC not implemented (PR #55 stalled), HMC motion not connected to resampling
- CI/CD broken (CircleCI secrets expired)
- `patch/` directory is the rodent adaptation layer (interfaces, workflows, utils, reports)

### Roadmap 2026-2027
- **Goal 1**: Plugin architecture — fMRIPrep gains species-agnostic extension points,
  fMRIPrep-rodents becomes thin config/override layer
- **Goal 2**: Adopt fit/transform — buffer nodes, precomputed derivatives, --level
- 25 issues across 6 tiers (R-00 through R-24), 12-month plan

## nirodents State (2026-02-18) - see [nirodents-state.md](nirodents-state.md)

### What It Is
- Rodent-specific adapting layer, akin to niworkflows but for rodent pipelines
- Provides `init_rodent_brain_extraction_wf` — used by fMRIPrep-rodents and MRIQC-rodents
- CLI: `artsBrainExtraction`

### Critical Issues
- **No CI/CD** (#61), **no release since 0.2.8** (2021), mouse support broken (#63)
- Brain tissue segmentation never implemented (#3) — currently in fprodents patch/
- Must be revived before plugin architecture can work

## niworkflows State (2026-02-18) - see [niworkflows-architecture.md](niworkflows-architecture.md) and [niworkflows-roadmap.md](niworkflows-roadmap.md)

### What It Is
- Shared building-block library for NiPreps (interfaces, workflows, utilities, viz)
- NOT a BIDS-App; consumed by fMRIPrep, sMRIPrep, dMRIPrep, ASLPrep, NiBabies, PETPrep, MRIQC, XCP-D
- 86 open issues audited 2026-02-18

### Top Active Development Areas
1. **Upstreaming from fMRIPrep** (#854, #1024-1028): BIDSURI, ConvertAffine, Workbench, math interfaces, BIDS utils
2. **Schema-driven entity config** (PR #1023): replacing hand-maintained nipreps.json
3. **NiReports migration** (#787, PR #789): visual elements moving to NiReports
4. **Brain extraction robustness** (#928, #1000, PR #1001): N4 extreme values, antsAI random failures
5. **Space system enhancements** (#881, #889, #997): CIFTI surface+volume combos, custom resolutions

### Critical Bugs
- **#1029**: DerivativesDataSink byte order corruption on big-endian NIfTI (data integrity!)
- **#1000**: antsAI random coreg failure with sbrefs (PR #1001 fixes)
- **#1021**: norm.py create_cfm orientation error with lesion masks
- **#959**: numpy 2.3+ deprecation breaks nipype Select (upstream fix needed)

