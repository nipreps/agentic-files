# fMRIPrep-rodents Architecture Deep Reference

## 1. Package Identity
- Python package: `fprodents`, distribution: `fmriprep-rodents`, CLI: `fprodents`
- NOT a git fork of fMRIPrep — standalone package using NiPreps stack
- Does NOT import from `fmriprep` — uses niworkflows, smriprep, nirodents directly
- Repository: https://github.com/nipreps/fmriprep-rodents

## 2. Dependency Stack (as of master, 2026-02)
- niworkflows >= 1.5.2 (current fMRIPrep uses ~1.12+)
- smriprep >= 0.11.1 (current fMRIPrep uses ~0.16+)
- nirodents >= 0.2.7
- nipype >= 1.7.1
- templateflow ~= 0.7.1
- Build system: versioneer + setup.cfg (needs migration to hatch/setuptools-scm + pyproject.toml)

**Critical**: Dependencies are pinned 3+ years behind current NiPreps stack.

## 3. Key Architectural Differences from fMRIPrep

| Aspect | fMRIPrep | fMRIPrep-rodents |
|---|---|---|
| Primary anat contrast | T1w | T2w |
| Default template | MNI152NLin2009cAsym | Fischer344 |
| Brain extraction | ANTs (human priors) | nirodents (rodent-tuned ANTs) |
| Surface recon | FreeSurfer | Not supported |
| BOLD HMC | FSL MCFLIRT | AFNI 3dVolReg (but HMC actually from epi_reference_wf LTA) |
| BOLD-to-anat reg | BBR with FLIRT fallback | FLIRT only |
| SDC | SDCFlows | Not implemented (use_fieldwarp=False) |
| CIFTI output | Yes | No |
| Fit & transform | Yes (--level, --derivatives, buffer nodes) | No |

## 4. The patch/ Directory (rodent adaptation layer)

This is the core of what makes fMRIPrep-rodents different. It overrides/patches
fMRIPrep-era interfaces and workflows with rodent-specific implementations.

### patch/interfaces/__init__.py
- `BIDSDataGrabber`: T2w-centric data grabbing (vs T1w in fMRIPrep)
- `TemplateFlowSelect`: Fetches T2w template + mask (vs T1w)
- `RobustMNINormalization`: T2w reference image, Fischer344 special-case handling

### patch/workflows/anatomical.py
- Complete rodent anatomical pipeline
- Uses `nirodents.workflows.brainextraction.init_rodent_brain_extraction_wf` for brain extraction
- FSL FAST with Fischer344 priors for tissue segmentation (3-class)
- Label reordering: FAST outputs CSF=0,WM=1,GM=2 → remap to BIDS GM=1,WM=2,CSF=3

### patch/workflows/func.py
- Rodent BOLD reference workflow
- Uses nirodents brain extraction for BOLD brain masking (not BET)

### patch/utils/__init__.py
- `fix_multi_source_name()`: Handle multi-source file naming
- `get_template_specs()`: Rodent template specification handling
- `extract_entities()`: BIDS entity extraction utilities

### patch/reports/__init__.py
- T2w-centric report generation (all visualizations use T2w, not T1w)

## 5. Config Singleton
- `fprodents/config.py` mirrors fMRIPrep's pattern (class-based sections, TOML serialization)
- Key rodent defaults:
  - `skull_strip_template = "Fischer344"`
  - `skull_strip_t1w = "force"` (always strip, rodent images need it)
- `init_spaces()` always adds `Fischer344:res-native`

## 6. BOLD Workflow State
- `workflows/bold/base.py`: Monolithic `init_func_preproc_wf` — resembles fMRIPrep circa 2020
- No fit/transform split, no --level support, no one-shot resampling
- STC (3dTshift), registration (FLIRT), resampling, confounds, outputs all wired directly
- HMC is declared (AFNI 3dVolReg) but the motion transform is NOT connected to resampling

## 7. Known Issues from GitHub (verified 2026-02)

### fmriprep-rodents issues
- #27: FD calculation may be wrong for rodents (different head geometry)
- #34: Orientation convention issues with rodent data
- #51: API breakages from upstream niworkflows changes
- #55: SDC support PR (stalled/incomplete)

### Critical gaps
- No CI/CD running (CircleCI config exists but secrets expired)
- No fit/transform architecture
- SDC not implemented despite PR #55 existing
- HMC motion parameters not connected to resampling
- Dependencies severely outdated

## 8. Roadmap Vision (2026 Grant Application)

Two principal objectives:
1. **Plugin architecture**: Make fMRIPrep-rodents a thin configuration/override layer
   on fMRIPrep (surgery on fMRIPrep) rather than a parallel codebase
2. **Fit & transform**: Adopt the fit/transform architecture already in fMRIPrep

### What "plugin" means concretely
- fMRIPrep gains species-agnostic extension points (pluggable brain extraction,
  configurable registration, species-aware template handling)
- fMRIPrep-rodents becomes a configuration package that:
  - Registers rodent-specific brain extraction (nirodents)
  - Sets T2w as primary contrast
  - Configures rodent templates (Fischer344, etc.)
  - Overrides registration parameters for small-brain geometry
- The `patch/` directory gradually dissolves as fMRIPrep absorbs the extension points

### Key milestones (25 issues across 6 tiers, R-00 through R-24)
- Tier 0: Foundation (dep upgrade, benchmark dataset, deviations doc)
- Tier 1: Species abstraction (extension points in fMRIPrep)
- Tier 2: Fit/transform + SDC (BOLD refactor, rodent SDC, precomputed ingestion)
- Tier 3: Testing (regression harness, CI, construction tests)
- Tier 4: Documentation + nirodents revival
- Tier 5: Stretch goals (benchmarking, mouse support, project board)
