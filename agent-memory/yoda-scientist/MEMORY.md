# Yoda Agent Memory

## User: oesteban (Oscar Esteban)
- Neuroimaging researcher, fMRIPrep developer
- Uses DataLad + git-annex heavily for YODA-compliant projects
- Primary HPC: HES-SO Calypso cluster
- Container runtimes: Docker (local), Apptainer (HPC)
- Python env manager: micromamba (env name: `datalad`)

## Project: abide_preproc
- Path: ~/workspace/abide_preproc
- ABIDE I+II preprocessing with fMRIPrep 25.2.4
- YODA superdataset with 5 subdatasets (abide1, abide2, abide-both, templateflow, derivatives/fmriprep-25.2)
- `inputs/abide-both` is a self-contained merged BIDS view (~2194 subjects) using annex key reuse + web URL registration
- Container images stored as OCI layout in git-annex (dhub: and .datalad/environments/)
- Subject ID scheme: sub-v{1,2}s{siteindex}x{orig}
- Branch `run/first-local` has calypso HPC scripts and one-test-subject.sh not yet merged to master

## DataLad YODA patterns observed
- `code/.gitattributes` with `* annex.largefiles=nothing` keeps all code in Git
- MD5E backend universally configured
- Derivatives subdataset has comprehensive .gitattributes via cfg_fmriprep.py procedure
- SLURM script uses clone-per-job pattern with branch-per-job in derivatives, push to GIN remote
- `datalad containers-run` for provenance tracking

## Common YODA audit findings for DataLad projects
- .gitignore often incomplete (missing .tmp/, __pycache__, etc.)
- CHANGELOG.md often empty placeholder
- No LICENSE at project root is common oversight
- Environment specification (environment.yml/requirements.txt) frequently missing
- CLAUDE.md can reference files on unmerged branches (stale documentation)
- Branch safety guards mentioned in docs but not always implemented in code
