# nirodents Architecture and State Reference

## 1. What It Is
- Rodent-specific adapting layer, akin to niworkflows but for rodent pipelines
- Provides `init_rodent_brain_extraction_wf` — cornerstone of rodent brain extraction
- Used by both fMRIPrep-rodents and MRIQC-rodents
- CLI entry point: `artsBrainExtraction`
- Repository: https://github.com/nipreps/nirodents

## 2. Key Workflow

### `nirodents.workflows.brainextraction.init_rodent_brain_extraction_wf`
- Parameters: `template_id` (default Fischer344), `mri_scheme` (T1w/T2w)
- Uses ANTs-based brain extraction with rodent-tuned parameters
- Multiple refinement PRs: N4 improvements, clip function, bspline anisotropy scaling
- This is the primary consumer-facing API used by fMRIPrep-rodents

## 3. Critical Issues (verified 2026-02)

### No CI/CD (#61)
- CircleCI removed (PR #60), GitHub Actions never added
- No automated testing of any kind

### No Release Since Packaging Overhaul (#7)
- PEP 517 migration done (PR #60) but no release cut
- Last meaningful release: 0.2.8 (2021)
- setuptools-scm + PEP 517 build system now in place

### Brain Tissue Segmentation Never Implemented (#3)
- Open since 2020
- Currently handled downstream in fprodents `patch/workflows/anatomical.py` via FSL FAST
  with Fischer344 priors
- Should be migrated into nirodents to serve all consumers (fMRIPrep-rodents, MRIQC-rodents)

### Mouse Support Broken (#63)
- `init_rodent_brain_extraction_wf` fails with MouseIn template
- RuntimeError when trying to use mouse-specific templates
- Related issues: #43 (mouse brain masking requests), #62 (3D mouse brain extraction failures)

### Dead Code (#39)
- `gaussian_filter` utility is unused

## 4. User-Reported Issues
- #43: Mouse brain masking requests (recurring community ask)
- #46: artsBrainExtraction requires absolute paths (UX issue)
- #50: BIDS root detection fails for standalone files
- #62: 3D mouse brain extraction failures
- #63: MouseIn template RuntimeError
- #64: Docker issues on Apple Silicon

## 5. Packaging State (post-PR #60)
- Migrated to setuptools-scm + PEP 517
- Dependencies flexibilized (PR #59)
- Build system ready for release, but no release cut

## 6. What Needs to Happen (Roadmap R-16)

Priority order:
1. **Restore CI** via GitHub Actions — required for any reliable development
2. **Cut a new release** — unblock downstream consumers
3. **Ensure compatibility** with current niworkflows/sMRIPrep versions
4. **Migrate tissue segmentation** from fprodents into nirodents
5. **Fix MouseIn template support** — community has been asking since 2021
6. **Clean up dead code** (gaussian_filter, etc.)

## 7. Relationship to fMRIPrep-rodents Plugin Vision

In the plugin architecture roadmap:
- nirodents becomes the provider of rodent-specific brain extraction that plugs
  into fMRIPrep's species-agnostic extension points
- Tissue segmentation (currently in fprodents patch/) should migrate here
- nirodents must be healthy (CI, releases, tested) before fMRIPrep-rodents can
  reliably depend on it as a plugin component
