# nireports additions

## Extra criterion

**Minimal report as a CI artifact.** Any PR adding or changing a reportlet/figure must
have tests that write the figure where CI uploads it.

## How artifacts flow

- CircleCI sets `TEST_OUTPUT_DIR` and runs `store_artifacts` on it. GitHub Actions
  uploads nothing — artifacts appear only on the CircleCI job.
- Tests reach it through the `outdir` fixture (`nireports/conftest.py`), which is
  `None` locally unless `TEST_OUTPUT_DIR` is set:
  ```python
  if outdir is not None:
      fig.savefig(outdir / "name.svg", bbox_inches="tight")
  ```
  Use `outdir`, not `tmp_path`.

## Steps (run as step 8)

1. **Generate:** `TEST_OUTPUT_DIR=<scratchpad>/report pytest <test file>`.
2. **Look at every figure.** `rsvg-convert -w 1400 -b white f.svg -o f.png`, then Read
   each PNG. Check: duplicated decorations (one colorbar per shared scale), realistic
   simulated inputs (not saturated/clipped everywhere), sensible masks (no noise
   background), correct axis labels. Fix bad figures by fixing **test inputs**, not the
   plotting function's design.
3. **Deliver:** bundle the SVGs into one HTML page and send it with `SendUserFile`
   (`display: render`); send PNGs of the key figures (`display: attach`) for the PR
   description.

## Conventions seen here

- RNG: `rng = request.node.rng` (autouse fixture in `nireports/tests/conftest.py`).
- Figures: `constrained_layout=True`; scipy imports as `from scipy.ndimage import name`,
  imported lazily inside functions in `reportlets/`.
- Brain masks for test data: `nilearn.masking.compute_epi_mask`.
- Lint: `uvx ruff check` / `uvx ruff format --check`.
