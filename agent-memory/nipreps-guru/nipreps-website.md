# NiPreps Website Documentation Reference (www.nipreps.org)

Source: https://www.nipreps.org (mkdocs site from nipreps/nipreps.github.io, branch: mkdocs)
Last updated: 2026-02-18

---

## 1. Mission and Core Concepts

### Analysis-Grade Data
NiPreps **augment the scanner** to produce data *directly consumable* by analyses.
"Analysis-grade data" = by analogy with "sashimi-grade fish":
- **Minimally preprocessed**, but
- **Safe to consume** directly.

### Origin Story
NiPreps were conceived as a **generalization of fMRIPrep** across new modalities,
populations, cohorts, and species. fMRIPrep is the seed project.

### Telemetry (as of Jan 2026)
- fMRIPrep executed ~11,800 times/week
- ~7,800 successful completions (66.2% success rate)
- Success rate likely higher when discounting debug/dry runs

---

## 2. Framework Architecture (Three Layers)

### Layer 1: Software Infrastructure
- **NiPype**: workflow engine (DAGs, execution plugins)
- **NiBabel**: neuroimaging file I/O
- **BIDS** + **BIDS-Derivatives**: data structure standards
- **NiTransforms**: spatial transforms library
- **TemplateFlow**: programmatic access to neuroimaging templates/atlases

### Layer 2: Middleware
- **NiWorkflows**: shared building-block library (interfaces, workflows, utilities, viz)
- **SDCFlows**: susceptibility distortion correction workflows
- **NiReports**: visual report generation (migrating from NiWorkflows)
- **MRIQC Web-API**: crowdsourced image quality metrics
- **MRIQC-nets**: deep learning models for QC

### Layer 3: End-User Tools (BIDS-Apps)
- **fMRIPrep**: fMRI preprocessing (flagship)
- **dMRIPrep**: diffusion MRI preprocessing
- **sMRIPrep**: structural MRI preprocessing (also middleware — consumed by fMRIPrep)
- **MRIQC**: MRI quality control (pre-preprocessing QC)
- **PETPrep**: PET preprocessing (first alpha released Aug 2025)

### Early-Stage / Special-Population Projects
- **NiBabies**: infant imaging adaptations
- **NiRodents**: small animal imaging adaptations
- **NiFreeze**: dMRI motion estimation (won ISMRM 2025 poster award)

---

## 3. BIDS and BIDS-Apps

### What Is BIDS?
Brain Imaging Data Structure — standard for organizing/describing brain datasets.
Validity checked with BIDS-Validator. Resources: bids-starter-kit.

### What Is a BIDS-App?
A container image capturing a neuroimaging pipeline that takes a BIDS-formatted
dataset as input. Core properties:
- Standardized CLI: `<entrypoint> <bids_dataset> <output_path> <analysis_level>`
- Container-based (Docker for local/cloud, Singularity/Apptainer for HPC)
- Versioned, hosted on Docker Hub
- Decouples participant-level from group-level analysis

### Analysis Levels
- `participant`: per-subject processing (map step)
- `group`: aggregate across participants (reduce step)
- fMRIPrep only has `participant`; MRIQC has both

### BIDS-Derivatives
NiPreps outputs follow BIDS-Derivatives specification. Example tree:
```
derivatives/fmriprep/
├── dataset_description.json
├── sub-01.html
├── sub-01/
│   ├── anat/  (preprocessed T1w, masks, segmentations, transforms)
│   ├── figures/
│   └── func/  (preprocessed BOLD, confounds, masks)
```

---

## 4. Containerized Execution

### Docker Execution
- Pull: `docker pull nipreps/fmriprep:<version>`
- Lightweight wrapper: `fmriprep-docker` (auto-translates dirs to mount points)
- Key mount strategy:
  - `-v path/to/data:/data:ro` (input, read-only)
  - `-v path/to/output:/out` (output, read-write)
  - `-v path/to/work:/work` (scratch/intermediate, use `-w /work`)
- TemplateFlow cache mount: `-v path/to/tf-cache:/opt/templateflow` + `-e TEMPLATEFLOW_HOME=/opt/templateflow`
- **Run as user**: `-u $(id -u):$(id -g)` to avoid root-owned output files
- Resource limits: Docker default 2GB RAM may be insufficient for large datasets

### Singularity/Apptainer Execution
- Build: `singularity build /my_images/fmriprep-<ver>.simg docker://nipreps/fmriprep:<ver>`
- **Always use `--cleanenv`** to prevent host environment leaking into container
- Bind paths: `-B <host>:<container>[:<permissions>]`
- FreeSurfer license: `export SINGULARITYENV_FS_LICENSE=$HOME/.freesurfer.txt`
- TemplateFlow: `export SINGULARITYENV_TEMPLATEFLOW_HOME=/opt/templateflow`

### Common Singularity Issues
- **SSL errors**: Set `SINGULARITYENV_REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt`
- **No internet on compute nodes**: Pre-fetch templates with `templateflow get <template>`
- **Socket errors in parallel** (#1170): Use `--network none` (requires pre-fetched templates)
- **$HOME issues**: Use `--home $HOME` or `-B $HOME:/home/fmriprep --home /home/fmriprep`
- **Non-existent bind points**: Rebuild image with `docker2singularity -m "/gpfs /scratch /work ..."`

### TemplateFlow Race Conditions
When sharing TemplateFlow cache across parallel executions, pre-download all needed
templates to avoid download races: `templateflow get MNI152NLin2009cAsym`

### SLURM Integration
Job array pattern: one task per subject via `sbatch --array=1-N fmriprep.slurm`
(example script provided in docs/assets/fmriprep.slurm)

### YODA Best Practices
Mount `$PWD` into `$PWD` with `-w $PWD` for YODA-compliant execution.
Makes inside/outside filesystem trees homologous, simplifies orchestration.

---

## 5. DataLad Integration in Containers

### Docker + DataLad
Two requirements:
1. **uid match**: The container execution uid must match the uid that installed the DataLad dataset
   - Use `-u $(id -u):$(id -g)` in docker run
2. **Write permissions**: Remove `:ro` from input mount so DataLad/git-annex can write to `.git/annex/`

### Common Error: `Git refuses to operate in this repository`
Caused by Git 2.35.2+ safe.directory check when uid mismatch.
Fix: Set execution uid correctly (not by running `git config` inside transient container).

### Singularity + DataLad
- User namespace mappings may be needed (contact sysadmin)
- Since $HOME is usually auto-bound, `git config --global --add safe.directory <path>` may work
- Remove `:ro` from bind option for write access

---

## 6. Transparency Principles

### Glass-Box Philosophy (vs Black-Box)
From Esteban et al., 2019 (Nature Methods):
- Visual reports = QC checkpoints showing logical flow of preprocessing
- Citation boilerplate = auto-generated methods description with all tool versions and references
- Open-source since inception, development discussions accessible on GitHub
- Modular design enhances transparency and enables community contributions

### Visual Reports
Two purposes:
1. **Quality assessment**: identify and exclude poorly processed data
2. **Understanding the workflow**: learn why specific preprocessing steps were taken

### Citation Boilerplates
- Auto-generated from workflow introspection (computational graph traversal)
- Include all relevant articles, software versions, templates, atlases
- Provided in 3 formats: Markdown, LaTeX, HTML/plain-text
- Released under **CC0 license** — intended for verbatim copying into Methods sections
- Note to reviewers: requiring modifications serves no scientific purpose and reduces replicability

---

## 7. Community and Governance

### Governance Model
- **Liberal contribution model** (open to all)
- Some meritocracy structure for author ordering in publications
- **NiPreps Steering Committee (NSC)**: expanded from 3 to 5 members (Aug 2025)
  - New members: Eilidh MacNicol (rodent data), Guiomar Niso (EEG/MEG extension)

### Membership Levels
- **Developers**: actively drive the project (follow-up meetings, docs, design, code review, resources)
- **Contributors**: help in broad sense (code, docs, benchmarking, features, support, rigor)
- Listed in `.maint/MAINTAINERS.md` and `.maint/CONTRIBUTORS.md` respectively
- Former contributors: `.maint/FORMER.md`
- Auto-generated `.zenodo.json` from these files, sorted by git-line-summary contribution size

### Anti-Feature-Creep Stance
> "fMRIPrep should be a paring knife, not a Swiss army knife" — Satra

Key principles:
- Keep tools tightly within scope
- Ease-of-use: minimal knobs (like the scanner itself)
- When proposing features, answer: Is CLI affected? Does complexity increase?
  Is there a standard procedure? Is it data-dependent? Can it be done outside the NiPrep?

### Feature Proposal Process
1. Search for prior discussion on GitHub
2. Check alignment with project vision/scope and development roadmap
3. Post issue with clear rationale
4. Propose validation strategy (onus on requester)

---

## 8. Contributing Guidelines

### Three Driving Principles
1. **Robustness**: Adapt to input data regardless of scanner/parameters/fieldmaps
2. **Ease of use**: Minimal manual input thanks to BIDS
3. **Glass-box**: Visual reports for every subject; documentation explains the why

### Design Foundations
1. Only and fully support BIDS/BIDS-Derivatives
2. Fully compliant BIDS-Apps (UI, CI, testing, delivery)
3. Scope strictly limited to preprocessing
4. Analysis-agnostic outputs
5. Transparent documentation + individual visual reports
6. Community-driven; contributors always credited
7. Modular; reliant on AFNI, ANTs, FreeSurfer, FSL, NiLearn, DIPY; extensible via plugins

### Coding Style
- Workflow variables end in `_wf`
- Factory functions: `init_<basename>_wf(name='<basename>_wf')`
- Node names match variable names (aids debugging working directories)

### PR Prefixes
`ENH` (feature), `FIX` (bug), `TST` (test), `DOC` (docs), `STY` (style),
`REF` (refactor), `CI` (CI/CD), `MAINT`/`MNT` (maintenance), `WIP` (work-in-progress)

### Branch Naming
- `fix/<identifier>`: bugfixes
- `enh/<feature-name>`: new features
- `doc/<identifier>` or `docs/<identifier>`: documentation (skips full CI)

---

## 9. Versioning and Releases

### Calendar Versioning (CalVer)
Format: `YY.MINOR.PATCH` (adopted Jan 2020)
- First release of 2021: `21.0.0`
- Series: `YY.MINOR.x` (e.g., 20.0.x = 20.0.0, 20.0.1, ...)

### Feature Releases (minor bumps)
- Target `master` branch
- May include any code changes

### Bug-Fix Releases (patch bumps)
Four conditions:
1. Resolve one or more bugs
2. **Derivatives compatibility**: identical imaging outputs between patches (modulo rounding/nondeterminism)
3. **API compatibility**: workflow functions, inputnode/outputnode unchanged
4. **UI compatibility**: no substantial CLI changes

Acceptable in patches: improved tests, docs, Dockerfile updates (no dep version changes), wrapper improvements

### Maintenance Branches
- Created from feature release tag: `git checkout -b maint/YY.MINOR.x YY.MINOR.0`
- Bug-fixes target `maint/YY.MINOR.x`, then merge into `master`

### Long-Term Support (LTS)
- One LTS series maintained at all times (~1 year intervals)
- LTS manager tracks upstream breaking changes, backports fixes
- Dependencies should be pinned; packages archived for resilience

### Dependency Version Matrix (fMRIPrep)
| fMRIPrep | sMRIPrep | SDCflows | NiWorkflows |
|---|---|---|---|
| 23.1.x | ~=0.12.0 | ~=2.5.0 | ~=1.8.0 |
| 23.0.x | ~=0.11.0 | ~=2.4.0 | ~=1.7.6 |
| 22.1.x | ~=0.10.0 | ~=2.2.1 | ~=1.7.0 |
| 22.0.x | ~=0.9.2 | ~=2.1.1 | ~=1.6.3 |
| 21.0.x | ~=0.8.0 | ~=2.0.0 | ~=1.4.0 |
| 20.2.x | ~=0.7.0 | ~=1.3.1 | ~=1.3.0 |

`~=` is PEP 440 compatible release specifier: `~= 1.1.7` means `>= 1.1.7, == 1.1.*`

---

## 10. Licensing

### Default License: Apache 2.0
All NiPreps software under Apache 2.0 unless justified otherwise (e.g., copyleft dependency).

### Key Apache 2.0 Properties
- Permissive, non-copyleft
- Automatic patent license grant
- Must preserve attribution notices
- Must note file changes in derived works
- Contributions automatically Apache-licensed
- GPL-compatible

### Container Image Licensing
- May use MIT License for container images and Docker-wrappers
- Must include NOTICE file in container (at `/NOTICE`)
- Print NOTICE contents in CLI output and visual reports

### Data Licensing
Test data and datasets: **CC0** (Creative Commons Zero v1.0 Universal)

### Derived Works Expectations
**Statement of Changes** in modified files:
1. Note in header comment that file is modified, with approximate date and description
2. Add license notice if missing
3. Deleted files: keep header with deletion note
4. Include link to original file at specific commit

**Change descriptions should include**: bug corrections, performance improvements,
method replacements, license changes.

### Papers Using NiPreps
Not "Derived Works" (just reuse, not redistribution). Follow citation guidelines
and report the auto-generated citation boilerplate.

---

## 11. Developer Environment

### Docker-Based Development
- Base image: `nipreps/fmriprep:unstable` (tracks master) or `:latest` (tracks release)
- Patch working copy into container via `-v` mounts or `fmriprep-docker -f/-n/-p` flags
- Interactive mode: `fmriprep-docker --shell` or `docker run --entrypoint=bash`
- Rebuild: `docker build -t fmriprep --build-arg VERSION=$(python get_version.py) .`

### Code-Server (Experimental)
- `Dockerfile_devel` for VS Code in browser via code-server
- Build: `docker build -t fmriprep_devel -f Dockerfile_devel .`
- Run: `docker run -it -p 127.0.0.1:8445:8080 -v ${PWD}:/src/fmriprep fmriprep_devel`
- Access: http://127.0.0.1:8445

---

## 12. Educational Resources and Events

### Bootcamps
- **fMRIPrep Bootcamp Geneva 2024**: Multi-day training (BIDS, containers, HPC, fMRIPrep)

### Online Books
- **QC-Book**: ISMRM 2022 tutorial (https://www.nipreps.org/qc-book)
- **NiPreps Book**: dMRI processing tools, ISBI 2021 (https://www.nipreps.org/nipreps-book/)

### SOPs
- **SOPs-cookiecutter**: Template repo for version-controlled QC standard operating procedures

### Recent Events (2024-2025)
- PETPrep sprint (Aug 2025): 23 PRs merged, first alpha release
- NiPreps hackathon 2025 @ McGovern Institute: NiPost, fMRI infant/rodent extensions
- NiFreeze best poster (Methods) at ISMRM 2025 Diffusion Study Group
- NiPreps hackathon 2024 @ McGovern Institute: NiTransforms discussions
- Bi-monthly NiPreps Roundups (resumed Feb 2023)
