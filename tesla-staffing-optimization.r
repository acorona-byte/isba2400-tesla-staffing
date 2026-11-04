# =============================================================================
# ISBA 2400 - Mathematics for Business Analytics
# Tesla Case Project
# Driving Innovations: Optimization of Staffing at Tesla
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
cat("TESLA STAFFING CASE\n")
cat("RAW DEMAND DATA\n")
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
cat("DEMAND BY LANGUAGE\n")
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

# The optimization model will choose these staffing quantities so that:
#
#   1. Customer demand is fully covered
#   2. Scheduling rules are satisfied
#   3. Language requirements are satisfied
#   4. Total labor cost is minimized

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

# Therefore, part-time agents cannot be used to satisfy Spanish-language
# demand in the baseline model


# ----- Restricted-start scenario -----

# These limits apply only to the later restricted-start scenario:
#
# No more than one qualified English-speaking full-time agent
# may begin work at 1 PM.

max_english_ft_start_1pm <- 1

# No more than one qualified English-speaking full-time agent
# may begin work at 3 PM.

max_english_ft_start_3pm <- 1

# The actual mathematical constraints will be added after the staffing
# coverage matrix and decision variables have been constructed



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

# When the staffing coverage matrix is constructed, each staffing
# pattern will also be assigned its corresponding call-handling cost.

# These costs will then be used in the objective function to determine
# the lowest-cost feasible staffing plan.



# -----------------------------------------------------------------------------
# 8. OBJECTIVE FUNCTION
# -----------------------------------------------------------------------------
#
# Minimize total salary expense associated with call-handling time
# while satisfying all demand, language, and scheduling constraints.
# -----------------------------------------------------------------------------

# Objective:
#
#   Minimize Total Call-Handling Labor Cost as:
#
#   Total Cost = Sum of (Staffing Option Cost x Number of Employees Assigned)
#
# Subject to:
#
#   English capacity  >= English demand
#   Spanish capacity  >= Spanish demand
#   Full-time scheduling rules
#   Part-time scheduling rules
#   Shift-start restrictions
#   Nonnegative integer staffing levels
#
# The actual mathematical objective function will be created after the
# staffing coverage matrix, staffing costs, and decision variables
# have been constructed.


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



# ----- 9A. Build Staffing Options -----

# Give the five permitted full-time start periods readable names.

# The numbers correspond to the demand blocks:

#   Block 1 = 7 AM
#   Block 2 = 9 AM
#   Block 3 = 11 AM
#   Block 4 = 1 PM
#   Block 5 = 3 PM

ft_start_names <- c(
  "7AM",
  "9AM",
  "11AM",
  "1PM",
  "3PM"
)

# Define the two valid full-time call patterns.

# 1 = employee is handling calls
# 0 = employee is performing other duties

ft_pattern_a <- c(1, 0, 1, 0)

ft_pattern_b <- c(0, 1, 0, 1)

# Define the one valid part-time call pattern

pt_pattern <- c(1, 1)



# ----- 9B. Build Coverage Matrix -----

# The coverage matrix shows which two-hour demand periods are covered
# by each valid staffing option.

# 1 = employee is handling calls during that period
# 0 = employee is not handling calls during that period

# Columns correspond to:

#   1 = 7 AM - 9 AM
#   2 = 9 AM - 11 AM
#   3 = 11 AM - 1 PM
#   4 = 1 PM - 3 PM
#   5 = 3 PM - 5 PM
#   6 = 5 PM - 7 PM
#   7 = 7 PM - 9 PM

coverage_matrix <- rbind(

    # Full-time agents starting at 7 AM
    ft_7am_a = c(1, 0, 1, 0, 0, 0, 0),
    ft_7am_b = c(0, 1, 0, 1, 0, 0, 0),

    # Full-time agents starting at 9 AM
    ft_9am_a = c(0, 1, 0, 1, 0, 0, 0),
    ft_9am_b = c(0, 0, 1, 0, 1, 0, 0),

    # Full-time agents starting at 11 AM
    ft_11am_a = c(0, 0, 1, 0, 1, 0, 0),
    ft_11am_b = c(0, 0, 0, 1, 0, 1, 0),

    # Full-time agents starting at 1 PM
    ft_1pm_a = c(0, 0, 0, 1, 0, 1, 0),
    ft_1pm_b = c(0, 0, 0, 0, 1, 0, 1),

    # Full-time agents starting at 3 PM
    ft_3pm_a = c(0, 0, 0, 0, 1, 0,1),

    # Pattern B also handles calls from 9 PM - 11 PM.
    # That period is outside the demand horizon for this case.
    # therefore, only the 5 PM - 7 PM call block appears here.
    ft_3pm_b = c(0, 0, 0, 0, 0, 1, 0),

    # Part-time agents
    pt_3pm = c(0, 0, 0, 0, 1, 1, 0),
    pt_5pm = c(0, 0, 0, 0, 0, 1, 1)

)

# Give the matrix columns readable names using the time periods
# that are already stored in the demand data.

colnames(coverage_matrix) <- demand$time_block

# Print the matrix so that we can verify the schedule

cat("\n============================================================\n")
cat("STAFFING COVERAGE MATRIX\n")
cat("============================================================\n\n")

print(coverage_matrix)

# ----- 9C. Assign Cost to Each Staffing Option -----

# Each staffing option is assigned the salary cost associated with
# the periods during which that employee is handling calls.

# Each two- hour call block before 5 PM costs:

# 2 hours x $30 = $60

# Each two-hour call block after 5 PM costs:calls_per_block

# 2 hours x $45 = $90



cost_per_option <- c(

  # Full-time agents starting at 7 AM
  ft_7am_a = 2 * wage_before_5pm + 2 * wage_before_5pm,
  ft_7am_b = 2 * wage_before_5pm + 2 * wage_before_5pm,

  # Full-time agents starting at 9 AM
  ft_9am_a = 2 * wage_before_5pm + 2 * wage_before_5pm,
  ft_9am_b = 2 * wage_before_5pm + 2 * wage_before_5pm,

    # Full-time agents starting at 11 AM
  ft_11am_a = 2 * wage_before_5pm + 2 * wage_before_5pm,
  ft_11am_b = 2 * wage_before_5pm + 2 * wage_after_5pm,

  # Full-time agents starting at 1 PM
  ft_1pm_a = 2 * wage_before_5pm + 2 * wage_after_5pm,
  ft_1pm_b = 2 * wage_before_5pm + 2 * wage_after_5pm,

  # Full-time agents starting at 3 PM
  ft_3pm_a = 2 * wage_before_5pm + 2 * wage_after_5pm,
  ft_3pm_b = 2 * wage_after_5pm + 2 * wage_after_5pm,

  # Part-time agents
  pt_3pm = 2 * wage_before_5pm + 2 * wage_after_5pm,
  pt_5pm = 2 * wage_after_5pm + 2 * wage_after_5pm

)

# Print each staffing option and its associated cost.

cat("\n============================================================\n")
cat("COST PER STAFFING OPTION\n")
cat("============================================================\n\n")

print(cost_per_option)



# ----- 9D. Define Baseline Decision Variables -----




# ----- 9E. Solve Baseline Optmization Model -----




# ----- 9F. Validate Baseline Solution -----








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
