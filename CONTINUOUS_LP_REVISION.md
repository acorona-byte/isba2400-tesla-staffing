# Continuous LP revision — November 21, 2026

This note accompanies the proposed update of `tesla-staffing-optimization.r`.
It follows Professor Najafi's direction to use **unrounded continuous LP costs**
for question G, consistent with the method used in (a)–(f).

## Required answers and extension benchmarks

| Model | Continuous LP minimum daily call-time cost | Notes |
|---|---:|---|
| Baseline (A/B) | $4,625.00 | Two language-specific pools; fractional staffing allowed |
| Limited English afternoon starts (C/D) | $4,665.00 | Same full-time CALL/OFF pattern, additional caps |
| Fully bilingual (E/F) | $4,525.00 | One pooled language-capable workforce |
| Bilingual wage premium (G) | **2.2099%** | ($4,625 / $4,525 - 1) × 100; round to **2.2%** |

The November 20 team meeting notes showed approximately $4,625.04, $4,665.01,
and $4,525.09 from Sherry's nonlinear solver. Small differences in the final cents
reflect solver tolerances; the same linear covering model can be solved exactly
to the values shown above by a linear-programming solver.

### Changes relative to the former integer figures

- Baseline: $5,100 → $4,625, a difference of $475.
- Restricted: $5,220 → $4,665, a difference of $555.
- Bilingual: $4,680 → $4,525, a difference of $155.
- Daily bilingual savings vs baseline: $420 → **$100** (2.16% of baseline).
- Daily bilingual savings vs restricted: $540 → **$140**.
- Question G break-even premium: 8.97% → **2.21%**.
- At 260 assumed weekdays: baseline-relative savings **$26,000/year**;
  restricted-relative savings **$36,400/year** (call-handling wages only).

### Demand-growth extension (same fixed mix, wages, productivity, and rules)

| Call demand increase | Minimum daily LP cost | FT agent-equivalents | PT agent-equivalents |
|---|---:|---:|---:|
| 0% | $4,625.00 | 32.0 | 4.6667 |
| 10% | $5,087.50 | 35.2 | 5.1333 |
| 20% | $5,550.00 | 38.4 | 5.6000 |
| 30% | $6,012.50 | 41.6 | 6.0667 |

These are **continuous capacity-equivalents**, not confirmed whole-person hires.
Linear scaling is expected in this particular continuous model because the
right-hand side of every demand constraint scales proportionally, while the
same staffing patterns, costs, and caps (for the baseline growth extension there
are no caps) remain fixed.

## Utilization and feasibility

The continuous optimum permits fractions of shifts. It models required
call-handling capacity under the case's deterministic two-hour blocks. The
reporting code now explicitly audits a naive nearest-integer schedule against
*every* language-specific and capped constraint. It does not treat rounded
counts as feasible automatically.

For the presentation, do **not** reuse the old integer-only assumptions such as
40 baseline hires, 37 bilingual hires, $420 daily savings, 9% premium, or the
old peak-utilization percentages. Recompute the utilization chart from the
current continuous solution, and describe it as *planned workload divided by
modeled call-handling capacity*; it is not observed employee utilization or
a forecast of wait times.

### Scope

- Preserve instructor-confirmed CALL → OFF → CALL → OFF full-time rotations.
- Preserve the case's 80/20 language-demand assumption, coverage rules, and
  call-time-only wage model.
- The continuous results answer the professor's analytic formulation. A
  separately validated integer schedule would still be necessary for actual
  staffing decisions.
- These figures were independently checked against an equivalent LP formulation.
  The updated R script itself has not yet been executed in the user's R
  environment; rerun it locally and inspect all generated tables and PNGs.
