# niworkflows Issue Roadmap

86 open issues as of 2026-02-18. Grouped by theme with status and priority.

---

## 1. Upstreaming from fMRIPrep (HIGHEST PRIORITY)

The dominant active effort: centralizing general-purpose code in niworkflows.

| # | Title | Priority | Status |
|---|---|---|---|
| 1024 | Upstream BIDSURI interface | HIGH | PR #1031 by tsalo |
| 1025 | Upstream ConvertAffine interface | HIGH | Open, no PR |
| 1026 | Upstream Workbench interfaces | HIGH | Open, no PR |
| 1027 | Upstream Clip and Label2Mask | MEDIUM | Open, no PR |
| 1028 | Upstream extract_entities + check_pipeline_version | MEDIUM | Open, no PR |
| 985 | Bring new fMRIPrep BIDS interfaces | HIGH | Open, superseded by #1024 etc. |
| 986 | Bring check_pipeline_version | MEDIUM | Subset of #1028 |
| 984 | Bring fmriprep.utils.misc | LOW | Open, no PR |
| 854 | Migrate tools post fit-apply restructure | HIGH | Master tracking issue (tsalo) |

**Key dependency**: #854 is the master list. Issues #1024-1028 are itemized subtasks.
The list from #854 also includes workflows (bold volumetric resample, registration,
confounds, fsLR resampling, grayordinates) that are more complex to upstream.

---

## 2. BIDS Entity Configuration

| # | Title | Priority | Status |
|---|---|---|---|
| 1018 | Entity ordering bug (seg before desc) | MEDIUM | PR #1020 (bendhouseart) |
| 946 | Missing PET metadata in nipreps.json | MEDIUM | Open |
| 752 | Missing Resolution/Density metadata | LOW | Partial fix done |
| 969 | SUIT not in valid spaces list | LOW | Blocked on TemplateFlow |

**PR #1023** (astewartau): Replace nipreps.json with schema-driven config generation.
This would fix #1018 and #946 systematically. Major architectural change.

---

## 3. Space System Enhancements

| # | Title | Priority | Status |
|---|---|---|---|
| 881 | Surface/volume space distinction for CIFTI | HIGH | PR #883 (tsalo), complex |
| 889 | nativemax/nativemin resolution support | MEDIUM | Design discussed |
| 997 | Custom resolution syntax (1p5mm, 6x6x3mm) | MEDIUM | Proposal, no PR |
| 1002 | Target resolution input to GenerateSamplingReference | MEDIUM | PR #1003 (tsalo) |
| 536 | SpatialReferences opaque to Sentry | LOW | Open |

**Discussion**: #881 evolving toward using `+` in space entity (e.g.,
`space-dhcpAsym42+MNIInfant1`) rather than `volspace`/`volcohort` entities.

---

## 4. Brain Extraction Improvements

Long-running effort spanning ~6 years of issues.

| # | Title | Priority | Status |
|---|---|---|---|
| 531 | RFC: Brain extraction workflow (unify human/infant/rodent) | HIGH | Open |
| 644 | Conclude integration of utilities in brain extraction | HIGH | M1.4.0 |
| 928 | N4 final affected by extreme values | MEDIUM | Partial fix by effigies |
| 734 | Improve robustness (random ANTs failures) | MEDIUM | Open |
| 648 | Detailed brain extraction reports | MEDIUM | Open |
| 569 | Improve results when FoV cuts brain | LOW | Open |
| 576 | Choppy brain mask when skull out of FoV | LOW | Open |
| 568 | Simple nibabel+numpy interfaces replacing ANTs | MEDIUM | M1.4.0 |
| 611 | N4 nodes adaptation for rodents | MEDIUM | M1.4.0 |
| 194 | Fill-in AFNI skull-stripping mask | LOW | Open |

---

## 5. EPI/BOLD Reference Workflows

| # | Title | Priority | Status |
|---|---|---|---|
| 1000 | antsAI random coreg failure with sbrefs | HIGH | PR #1001 (premask split) |
| 615 | Adapt bold_reference_wf to use epi_reference_wf | MEDIUM | M1.4.0 |
| 614 | ITK-compatible transforms in epi_reference_wf | MEDIUM | M1.4.0 |
| 612 | Rename StructuralReference interface | LOW | Discussion |
| 579 | Save boldref brain-extract outputs | LOW | Open |

**PR #971** (effigies): Parameterize epi_reference_wf for rodent support.
**PR #1001** (effigies): Split premask workflow to fix antsAI failures.

---

## 6. Bugs (Active)

| # | Title | Severity | Status |
|---|---|---|---|
| 1029 | DerivativesDataSink byte order corruption | HIGH | Open, no PR |
| 1021 | norm.py create_cfm orientation error | MEDIUM | Open, no PR |
| 1000 | antsAI random coreg failure | HIGH | PR #1001 |
| 928 | N4 extreme value sensitivity | MEDIUM | Workaround |
| 862 | collect_data filter crash | LOW | Open |
| 856 | File read/write race in parallel | MEDIUM | Open |
| 804 | BIDSFreeSurferDir filesystem race | MEDIUM | M1.8.0 |
| 799 | Pandoc failure crashes reports | LOW | Open |
| 959 | np.False_ rejected by nipype Select | MEDIUM | Upstream fix needed |
| 627 | Compressed+uncompressed file collision | LOW | Open |

---

## 7. NiReports Migration

| # | Title | Priority | Status |
|---|---|---|---|
| 787 | Finalize migration of visual elements | HIGH | PR #789 (oesteban) |

This is a blocking migration. PR #789 adds shim imports with deprecation warnings.

---

## 8. Visualization / Reportlet Improvements

Many of these may belong in NiReports after migration completes.

| # | Title | Priority | Status |
|---|---|---|---|
| 665 | Overhaul carpet plots | MEDIUM | Open |
| 564 | Confound correlation plot improvements | LOW | M1.4.0 |
| 574 | Collapse ICA-AROMA reportlet | LOW | Open |
| 633 | Configurable FD threshold in report | LOW | Open |
| 450 | Group reports | MEDIUM | M1.4.0 |
| 412 | Fast interactive fmriplot (uPlot) | LOW | Open |
| 252 | JS-based volume scrolling | LOW | Open |
| 237 | Improve fMRIPlot look and feel | LOW | Open |
| 254 | fMRIPlot modality-agnostic | LOW | Open |
| 219 | Add GIFTRPT | LOW | Open |
| 213 | Animations CPU intensive | LOW | Open |
| 142 | Consider MozJPEG compression | LOW | Open |
| 84 | Crop coreg reports with mask | LOW | M1.4.0 |

---

## 9. PET Support (PETPrep / PETQC)

| # | Title | Priority | Status |
|---|---|---|---|
| 946 | Missing PET metadata in nipreps.json | MEDIUM | Open |
| 944 | Add PET-MNI ANTs registration JSON | MEDIUM | Open |
| 948 | Add petref-mni_registration JSON | MEDIUM | Open |
| 969 | SUIT space not in valid spaces | LOW | Blocked on TemplateFlow |

---

## 10. Gradient Nonlinearity Correction

| # | Title | Priority | Status |
|---|---|---|---|
| 894 | Alternative gradient nonlinearity workflow | MEDIUM | Discussion |

**PR #819** (bpinsard): gradunwarp base workflow. Open since Aug 2023.
Vendor restriction: gradient coil data CANNOT be shared publicly (confirmed by vendor).

---

## 11. LiterateWorkflow / Boilerplate

| # | Title | Priority | Status |
|---|---|---|---|
| 999 | Space-separate descriptions from visit_desc() | LOW | Open |
| 415 | Auto-generate acquisition boilerplate | LOW | M1.4.0 |
| 440 | Generalizable summary interfaces | LOW | M1.4.0 |

---

## 12. FreeSurfer Integration

| # | Title | Priority | Status |
|---|---|---|---|
| 963 | Collect longitudinal FS derivatives | MEDIUM | Open |
| 794 | Pre-run FS folder needs to be writable | LOW | LTS issue |

---

## 13. Other / Misc Enhancements

| # | Title | Priority | Status |
|---|---|---|---|
| 924 | Add tolerance to MatchHeader | LOW | Help wanted |
| 903 | OIDC trusted publishing for PyPI | MEDIUM | Open |
| 901 | pytest marks for CircleCI test selection | LOW | Open |
| 936 | Move generate_bids_skeleton to lighter package | LOW | Open |
| 967 | Upcoming nilearn resample_img change | LOW | Tracking |
| 311 | Synchronous temporal filter workflow | LOW | Open |
| 434 | Refactor CIFTI subcortical resampling | LOW | M1.4.0 |
| 515 | Propagate TR from BIDS to NIfTI | LOW | M1.4.0 |
| 632 | four_to_three memory efficiency | LOW | Open |
| 145 | Subcortical coregistration step | LOW | Open |
| 296 | Bring back hard-links for gzipped files | LOW | Open |

---

## 14. CI/CD and Packaging

| # | Title | Priority | Status |
|---|---|---|---|
| 903 | OIDC trusted publishing | MEDIUM | Open |
| 901 | pytest marks for CircleCI | LOW | Open |
| 672 | CircleCI docker layer caching | LOW | Open |
| 671 | Add test_masks back into CI | LOW | Open |
| 660 | Multiversion docs chooser broken on tag HEAD | LOW | Open |
| 768 | Intersphinx mistargeting URLs | LOW | Open |
| 661 | Ease installation version restrictions | LOW | Open |
| 526 | Separate distribution and tests | LOW | M1.4.0 |
| 522 | Separate build/install tests | LOW | M1.4.0 |
| 597 | Report generation tutorial/docs | LOW | Open |

---

## Milestone Summary

- **M1.4.0**: 20 issues assigned (most very old, from 2020-2021). This milestone is
  effectively stale; most items predate the fit/transform restructure.
- **M1.8.0**: 1 issue (#804 BIDSFreeSurferDir race)
- **M1.2.10**: 1 issue (#574 ICA-AROMA reportlet)
- **LTS 1.3.x**: 1 issue (#794 FS folder writable)
- **No milestone**: 63 issues

---

## Critical Path for Near-Term Development

1. **Fix #1029** (byte order corruption) -- data integrity bug
2. **Merge PR #1031** (BIDSURI upstream) -- unblocks dMRIPrep/NiBabies
3. **Merge PR #1023** (schema-driven config) or fix #1018 -- entity ordering
4. **Continue #854 upstream series** (#1025, #1026) -- workbench + ConvertAffine
5. **Merge PR #1001** (premask split) -- fixes antsAI failures (#1000)
6. **Complete PR #789** (NiReports migration) -- technical debt
