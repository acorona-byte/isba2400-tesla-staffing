# =============================================================================
# ISBA 2400 - Mathematics for Business Analytics
# Tesla Case Project
# Driving Innovations: Optimization of Support Staffing at Tesla
#
# Team:
#   Abel
#   Sinhye
#   Yan
#
# Repository:
#   https://github.com/acorona-byte/isba2400-tesla-staffing
#
# Shared Google Drive:
#   https://drive.google.com/drive/folders/1Ue8ItARhiLrjcfRoBeJfpwv64fPKuWqD?usp=drive_link
#
# Purpose:
#   Develop and validate an R-based optimization model for the Tesla support
#   staffing case.
#
#   The model will determine the lowest-cost staffing plan capable of meeting
#   forecast customer-support demand while accounting for:
#
#     - Full-time and part-time staffing rules
#     - English- and Spanish-language demand
#     - Two-hour call-coverage periods
#     - Full-time call / non-call rotations
#     - Shift-start restrictions
#     - Wage differences before and after 5 P.M.
#     - Alternative bilingual-agent scenarios
#
# Modeling Approach:
#
#   CASE DATA
#       ↓
#   CASE PARAMETERS
#       ↓
#   MODELING ASSUMPTIONS
#       ↓
#   DERIVED DEMAND
#       ↓
#   DECISION VARIABLES
#       ↓
#   CONSTRAINTS
#       ↓
#   COST MINIMIZATION
#       ↓
#   VALIDATION AND BUSINESS INTERPRETATION
#
# Collaboration Notes:
#
#   - Keep raw case data separate from modeling assumptions.
#   - Clearly document any assumptions that are not explicitly stated
#     in the case.
#   - Add comments explaining major modeling decisions.
#   - Keep intermediate calculations readable so results can be
#     independently checked.
#   - Feel free to create a branch for larger changes before merging
#     into main.
#   - Reach out to the team if help is needed with GitHub, R, or
#     the optimization model.
#
# =============================================================================



# -----------------------------------------------------------------------------
# 1. LOAD RAW CASE DATA
# -----------------------------------------------------------------------------

# The CSV contains ONLY the call-volume forecast explicitly provided
# in the case.
#
# Expected file:
#   data/tesla_staffing_inputs.csv
#
# Expected columns:
#   block_id
#   time_block
#   start_hour
#   end_hour
#   calls_per_hour

data_path <- file.path("data", "tesla_staffing_inputs.csv")

demand <- read.csv(
  data_path,
  stringsAsFactors = FALSE
)

cat("\n============================================================\n")
cat("TESLA SUPPORT STAFFING CASE\n")
cat("RAW DEMAND DATA LOADED\n")
cat("============================================================\n\n")

print(demand)



# -----------------------------------------------------------------------------
# 2. CASE PARAMETERS
# -----------------------------------------------------------------------------
#
# These values are explicitly stated in the case.
# They are NOT modeling assumptions.
# -----------------------------------------------------------------------------

# Each forecast period is two hours.
hours_per_block <- 2

# Average call-handling capacity.
calls_per_agent_hour <- 6


# ----- Language demand -----

# The case states that 20% of calls come from non-English speakers.
non_english_share <- 0.20


# ----- Full-time agents -----

# Full-time agents work an 8-hour shift.
ft_shift_hours <- 8

# They spend half of the shift handling calls.
ft_call_hours <- 4

# They alternate every 2 hours between:
#   - handling calls
#   - other responsibilities
ft_rotation_hours <- 2

# Full-time agents may begin at:
#   7 AM, 9 AM, 11 AM, 1 PM, or 3 PM.
ft_start_blocks <- c(1, 2, 3, 4, 5)


# ----- Part-time agents -----

# Part-time agents work continuously on calls for 4 hours.
pt_shift_hours <- 4

# Part-time agents speak English only in the baseline case.
pt_start_blocks <- c(5, 6)   # 3 PM or 5 PM


# ----- Wage rates -----

wage_before_5pm <- 30
wage_after_5pm  <- 45



# -----------------------------------------------------------------------------
# 3. MODELING ASSUMPTIONS
# -----------------------------------------------------------------------------
#
# These items are NOT stated explicitly in the case.
# They are interpretations required to construct the optimization model.
# -----------------------------------------------------------------------------

# ASSUMPTION 1:
#
# The case states that 20% of calls are from non-English speakers
# and separately defines Spanish-speaking full-time agents.
#
# We therefore interpret the non-English demand as Spanish-language demand.

spanish_share <- non_english_share

english_share <- 1 - spanish_share


# ASSUMPTION 2:
#
# The case does not provide a different language mix for each time block.
# We therefore apply the 20% Spanish / 80% English mix uniformly
# across all forecast periods.


# Additional assumptions should be documented here before being introduced
# into the optimization model.



# -----------------------------------------------------------------------------
# 4. DERIVED DEMAND
# -----------------------------------------------------------------------------
#
# These values are CALCULATED from the raw case data and modeling assumptions.
# They are not stored as raw inputs in the CSV.
# -----------------------------------------------------------------------------

# Total calls within each two-hour period.
demand$calls_per_block <-
  demand$calls_per_hour * hours_per_block


# English-language demand.
demand$english_calls_per_hour <-
  demand$calls_per_hour * english_share


# Spanish-language demand.
demand$spanish_calls_per_hour <-
  demand$calls_per_hour * spanish_share


# English-language calls per two-hour block.
demand$english_calls_per_block <-
  demand$english_calls_per_hour * hours_per_block


# Spanish-language calls per two-hour block.
demand$spanish_calls_per_block <-
  demand$spanish_calls_per_hour * hours_per_block


cat("\n============================================================\n")
cat("DERIVED DEMAND BY LANGUAGE\n")
cat("============================================================\n\n")

print(
  demand[, c(
    "time_block",
    "calls_per_hour",
    "english_calls_per_hour",
    "spanish_calls_per_hour"
  )]
)



# -----------------------------------------------------------------------------
# 5. STAFFING PATTERNS / DECISION VARIABLES
# -----------------------------------------------------------------------------
#
# Full-time agents may follow one of two alternating patterns:
#
# Pattern A:
#
#   CALL → OFF → CALL → OFF
#
# Pattern B:
#
#   OFF → CALL → OFF → CALL
#
# Each pattern spans the employee's 8-hour shift.
#
# Part-time agents work:
#
#   CALL → CALL
#
# across two consecutive 2-hour periods.
#
# Decision variables will eventually represent the number of agents assigned
# to each permitted:
#
#   - start time
#   - language
#   - full-time call pattern
#   - part-time shift
#
# We will define these variables once the coverage matrix is constructed.



# -----------------------------------------------------------------------------
# 6. STAFFING CONSTRAINTS
# -----------------------------------------------------------------------------
#
# The optimization model must satisfy the following requirements.
# -----------------------------------------------------------------------------


# ----- Demand coverage -----

# English-speaking call capacity must meet or exceed English call demand
# in every two-hour period.

# Spanish-speaking call capacity must meet or exceed Spanish call demand
# in every two-hour period.


# ----- Full-time scheduling -----

# Full-time agents work an 8-hour shift.

# Full-time agents alternate every two hours between call duties
# and their other responsibilities.

# They may begin their shift either:
#
#   - handling calls
#   - performing other duties


# ----- Part-time scheduling -----

# Part-time agents handle calls continuously for four hours.

# In the baseline scenario, part-time agents speak English only.


# ----- Restricted-start scenario -----

# For the later scenario:
#
# No more than one qualified English-speaking full-time agent
# may begin work at 1 PM.

max_english_ft_start_1pm <- 1

# No more than one qualified English-speaking full-time agent
# may begin work at 3 PM.

max_english_ft_start_3pm <- 1



# -----------------------------------------------------------------------------
# 7. COST STRUCTURE
# -----------------------------------------------------------------------------
#
# The case asks us to consider ONLY salary expense for time spent
# handling calls.
#
# Therefore, an employee's cost depends on the specific periods
# during which that employee is actually assigned to call handling.
# -----------------------------------------------------------------------------

# Before 5 PM:
#
#   $30 per call-handling hour
#
# After 5 PM:
#
#   $45 per call-handling hour


# Example:
#
# A part-time agent starting at 3 PM handles calls from:
#
#   3 PM - 5 PM  -> 2 hours × $30 = $60
#   5 PM - 7 PM  -> 2 hours × $45 = $90
#
# Total relevant salary cost:
#
#   $150



# -----------------------------------------------------------------------------
# 8. OBJECTIVE FUNCTION
# -----------------------------------------------------------------------------
#
# Minimize total salary expense associated with call-handling time
# while satisfying all demand, language, and scheduling constraints.
# -----------------------------------------------------------------------------

# Objective:
#
#   Minimize Total Call-Handling Labor Cost
#
# Subject to:
#
#   English capacity  >= English demand
#   Spanish capacity  >= Spanish demand
#   Full-time scheduling rules
#   Part-time scheduling rules
#   Shift-start restrictions
#   Nonnegative integer staffing levels



# -----------------------------------------------------------------------------
# 9. SCENARIO A/B - BASELINE MODEL
# -----------------------------------------------------------------------------
#
# Questions:
#
#   A. What staffing levels minimize operating cost?
#
#   B. What is the resulting minimum operating cost?
#
# Baseline workforce:
#
#   - English-speaking full-time agents
#   - Spanish-speaking full-time agents
#   - English-speaking part-time agents
# -----------------------------------------------------------------------------



# -----------------------------------------------------------------------------
# 10. SCENARIO C/D - RESTRICTED FULL-TIME STARTS
# -----------------------------------------------------------------------------
#
# Additional constraints:
#
#   - Maximum 1 English FT agent starting at 1 PM
#   - Maximum 1 English FT agent starting at 3 PM
#
# Questions:
#
#   C. What staffing plan minimizes cost?
#
#   D. What is the resulting minimum cost?
# -----------------------------------------------------------------------------



# -----------------------------------------------------------------------------
# 11. SCENARIO E/F - BILINGUAL WORKFORCE
# -----------------------------------------------------------------------------
#
# Assume all agents are bilingual.
#
# Language-specific staffing constraints are therefore removed.
#
# Questions:
#
#   E. What FT/PT staffing plan minimizes operating cost?
#
#   F. What is the resulting minimum operating cost?
# -----------------------------------------------------------------------------



# -----------------------------------------------------------------------------
# 12. SCENARIO G - BILINGUAL WAGE PREMIUM
# -----------------------------------------------------------------------------
#
# Determine the maximum percentage wage premium Tesla could pay bilingual
# agents without increasing total operating cost above the monolingual
# staffing solution.
#
# Result should be reported as a percentage rounded to one decimal place.
# -----------------------------------------------------------------------------



# -----------------------------------------------------------------------------
# 13. VALIDATION
# -----------------------------------------------------------------------------
#
# Before accepting any optimization result, verify:
#
#   1. Every demand block is fully covered.
#
#   2. English demand is covered.
#
#   3. Spanish demand is covered.
#
#   4. Full-time rotation patterns are respected.
#
#   5. Part-time scheduling rules are respected.
#
#   6. Restricted-start limits are satisfied where applicable.
#
#   7. Staffing decisions are nonnegative integers.
#
#   8. Reported cost equals independently recalculated labor cost.
# -----------------------------------------------------------------------------



# -----------------------------------------------------------------------------
# 14. OUTPUT / REPORTING
# -----------------------------------------------------------------------------
#
# Produce readable outputs for the final report:
#
#   - Staffing by start time
#   - Staffing by agent type
#   - Demand versus available capacity by block
#   - Total operating cost
#   - Scenario comparison
#   - Bilingual wage-premium sensitivity
#
# These outputs can later be exported to tables and charts for the
# written report and presentation.
# -----------------------------------------------------------------------------
