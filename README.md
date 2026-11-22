# ISBA 2400 — Tesla Staffing Optimization

Welcome, Professor Najafi!

This repository is our team workspace for the **Tesla Support Staffing Optimization** case in ISBA 2400. We are using R to build, test, and validate the staffing model while keeping our assumptions, input data, and results organized in one place.

## Project Goal

Our goal is to determine the lowest-cost staffing plan that can meet forecasted support demand while accounting for:

- English- and Spanish-speaking support needs
- Full-time and part-time staffing rules
- Shift timing and availability constraints
- The potential use of bilingual agents

## Repository Contents

- `tesla-staffing-optimization.r` — main R model and analysis
- `data/tesla_staffing_inputs.csv` — case inputs used by the model
- `README.md` — project overview and notes
- `console_output.txt` — saved calculations and slide-order tables
- `slide_pngs/` — seven charts for the visual slides

## Running and using the deck outputs

From the repository root, install `lpSolve`, then run
`Rscript tesla-staffing-optimization.r`, or use this in RStudio:

```r
source("tesla-staffing-optimization.r")
```

`console_output.txt` contains the slide-order tables,
full-precision staffing and finance calculations, separate nearest-integer
staffing tables.
The `slide_pngs` subfolder contains only the seven charts for visual slides 6,
11, 13, 15, 16, 18 and 19. Running the script replaces the console output and
these charts. Validation checks are included in the script.

Finance uses fractional agent-equivalents throughout. For example,
`(32 / 6) * 120 = 640`: a `.00` cost is consistent with fractional staffing.
The LP costs are $4,625.00, $4,665.00 and $4,525.00.
Rounded staffing is for presentation;
the rounding audit identifies coverage shortfalls. The integer mixed-team
extension is separate from the continuous case answers.

We will continue updating the repository as we refine the model, validate the results, and prepare the final report.

Thanks for taking a look, and please feel free to reach out if you have any questions or feedback.

— Abel, Sinhye, and Yan
