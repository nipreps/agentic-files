# niworkflows Architecture Deep-Dive

## What niworkflows Is

niworkflows is the **shared building-block library** for the NiPreps ecosystem.
It is NOT a standalone BIDS-App. It provides:
- Nipype interfaces (BIDS I/O, image manipulation, ANTs wrappers, reportlets)
- Reusable sub-workflows (brain extraction, BOLD reference, EPI reference, normalization, coregistration)
- Engine extensions (LiterateWorkflow, MultiProcPlugin, workflow splicer)
- Utilities (BIDS querying, space tracking, image manipulation)
- Visualization (carpet plots, registration overlays, report builder)

Consumed by: fMRIPrep, sMRIPrep, dMRIPrep, ASLPrep, NiBabies, PETPrep, MRIQC, XCP-D

## Key Architectural Patterns

### 1. Interface Conventions
- Input spec: `_<Name>InputSpec(BaseInterfaceInputSpec)`
- Output spec: `_<Name>OutputSpec(TraitedSpec)`
- Interface: `Name(SimpleInterface)` with `_run_interface(self, runtime)`
- Report-capable variants use RPT mixin pattern in `interfaces/reportlets/`

### 2. Workflow Factory Functions
- All workflows: `init_<name>_wf(params) -> pe.Workflow`
- Use `LiterateWorkflow` (imported as `Workflow` from `niworkflows.engine`)
- `inputnode`/`outputnode` contract via `IdentityInterface`
- `# fmt: off/on` around `wf.connect()` blocks
- `__desc__` for methods boilerplate

### 3. BIDS Interfaces
- `DerivativesDataSink`: monolithic BIDS-Derivatives output writer (being refactored)
- `PrepareDerivative` + `SaveDerivative`: new split pattern for provenance injection
- `BIDSURI`: provenance tracking via `bids::` URI scheme (being upstreamed from fMRIPrep)
- Entity config in `niworkflows/data/nipreps.json`

### 4. Header-Fixing Philosophy
- ANTs operations often corrupt NIfTI headers (qform/sform mismatch)
- `interfaces/fixes.py` wraps ANTs interfaces: `FixHeaderRegistration`, `FixHeaderApplyTransforms`, `FixN4`
- Always use Fix* variants in workflows

### 5. Space Tracking (utils/spaces.py)
- `Reference` (attrs-based): template name + specs (cohort/resolution/density)
- `SpatialReferences`: collection with standard vs nonstandard distinction
- Hardcoded valid space list -- needs updating when TemplateFlow adds templates

### 6. Resource Loading
- `acres.Loader` pattern replaces pkg_resources
- `niworkflows.data.load` or `niworkflows.load_resource`

## Key File Paths

| Area | Path |
|---|---|
| BIDS interfaces | `niworkflows/interfaces/bids.py` |
| Entity config | `niworkflows/data/nipreps.json` |
| ANTs fix interfaces | `niworkflows/interfaces/fixes.py` |
| Space utilities | `niworkflows/utils/spaces.py` |
| BIDS querying | `niworkflows/utils/bids.py` |
| Brain extraction WF | `niworkflows/anat/ants.py` |
| BOLD reference WF | `niworkflows/func/util.py` |
| EPI reference WF | `niworkflows/workflows/epi/refmap.py` |
| Normalization interface | `niworkflows/interfaces/norm.py` |
| Report engine | `niworkflows/reports/core.py` |
| Carpet plots | `niworkflows/viz/plots.py` |
| Engine extensions | `niworkflows/engine/` |
| Coregistration WFs | `niworkflows/anat/coregistration.py` |
| Image utilities | `niworkflows/utils/images.py` |
| Connection helpers | `niworkflows/utils/connections.py` |

## Active Refactoring Efforts

### 1. Upstreaming from fMRIPrep (issues #854, #984-986, #1024-1028)
The biggest active effort: moving general-purpose code from fMRIPrep into niworkflows:
- BIDSURI interface (PR #1031 in progress)
- ConvertAffine interface
- Workbench interfaces (MetricDilate, MetricResample, VolumeToSurfaceMapping, etc.)
- Clip / Label2Mask math interfaces
- extract_entities / check_pipeline_version utilities
- check_deps / fmt_subjects_sessions misc utilities
- Full fmriprep.interfaces.bids module port planned

### 2. nipreps.json -> Schema-Driven Config (PR #1023)
Replacing hand-maintained `nipreps.json` entity config with auto-generation from
BIDS schema. Addresses entity ordering bugs (#1018) and missing PET metadata (#946).

### 3. NiReports Migration (#787, PR #789)
Visual elements being migrated to NiReports package. Shim imports with deprecation
warnings being added. Not yet complete.

### 4. Brain Extraction Overhaul (#531, #569, #576, #644, #648, #734, #928)
Long-running effort to:
- Unify brain extraction across human/infant/rodent
- Improve robustness (random ANTs initialization failures)
- Add detailed intermediate reports
- Replace ANTs ImageMaths with nibabel+numpy (#568)
- Fix N4 extreme value sensitivity (#928)

### 5. EPI Reference Workflow Evolution (#614, #615, #1000-1001)
- `init_epi_reference_wf` being enhanced (ITK transforms, rodent support via PR #971)
- `init_bold_reference_wf` to be adapted to use new EPI reference
- Premask workflow split-out (PR #1001) to fix antsAI random failures

### 6. Space System Enhancement (#881, #889, #997)
- Surface/volume space distinction for CIFTI (PR #883)
- nativemax/nativemin resolution support
- Custom resolution syntax (e.g., `res-1p5mm`)
- Register-based API for new spaces (#889)

## Known Bugs (Actionable)

| # | Title | Severity |
|---|---|---|
| 1029 | DerivativesDataSink byte order corruption on big-endian data | HIGH |
| 1021 | Orientation error in norm.py create_cfm (lesion mask) | MEDIUM |
| 1018 | Entity ordering wrong in nipreps.json (seg before desc) | MEDIUM |
| 1000 | antsAI random coregistration failure with sbrefs | HIGH |
| 928 | brain_extraction_wf N4 final affected by extreme values | MEDIUM |
| 862 | collect_data fails with filters for nonexistent suffixes | LOW |
| 804 | BIDSFreeSurferDir filesystem race | MEDIUM |
| 799 | Pandoc failures crash report compilation | LOW |
| 959 | np.False_ rejected by nipype Select (upstream numpy 2.3+) | MEDIUM |

## Technical Debt

| # | Title | Area |
|---|---|---|
| 787 | NiReports migration incomplete | visualization |
| 661 | Version pinning too strict | packaging |
| 696 | RegridToZooms excessive padding | images |
| 632 | nibabel.four_to_three memory inefficiency | images |
| 537 | Atropos single-threaded but claims cores | brain extraction |
| 536 | SpatialReferences opaque to Sentry | spaces |
| 526 | Test/distribution separation | packaging |
| 522 | Build vs install test separation | CI |
| 672 | CircleCI docker layer caching | CI |
| 671 | test_masks missing from CI | CI |

## Deprecations and Migration Paths

### In Progress
- **viz/plots.py, viz/utils.py**: Being migrated to NiReports (#787, PR #789)
- **nipreps.json**: Being replaced with schema-driven generation (PR #1023)
- **DerivativesDataSink monolithic interface**: Being split into PrepareDerivative + SaveDerivative

### Planned
- **nilearn.image.resample_img**: default changing to force_resample=True in nilearn 0.13 (#967)
- **numpy bool deprecation**: np.False_ no longer accepted as int (upstream nipype fix needed, #959)

## Relationship to Other NiPreps Tools

| Tool | Relationship |
|---|---|
| fMRIPrep | Primary consumer. Many interfaces being upstreamed FROM fMRIPrep. |
| sMRIPrep | Consumer. Imports anat workflows directly. |
| dMRIPrep | Consumer. Will need BIDSURI, workbench interfaces. |
| ASLPrep | Consumer. Drove #854 (upstream migration list). |
| NiBabies | Consumer. Needs workbench, CIFTI interfaces. |
| PETPrep | Consumer. Needs PET metadata in nipreps.json, SUIT space support. |
| MRIQC | Consumer. Needs PET normalization parameters. |
| XCP-D | Consumer. Hit DerivativesDataSink race condition (#856). |
| NiReports | Receiving migrated visualization code from niworkflows. |
| SDCFlows | Sibling. SDC interfaces separate; niworkflows provides complementary utilities. |
| NiTransforms | Upstream. ConvertAffine being upstreamed. |
| nirodents | Consumer. Brain extraction and N4 adaptations needed (#611). |
