# =============================================================================
# ISBA 2400 - Mathematics for Business Analytics
# Tesla Case Project
# Driving Innovations: Optimization of Staffing at Tesla
#
# Team:
#   Abel Corona
#   Sinhye Kim
#   Steven Smithwick
#   Yan Wu
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
#   The model will determine the lowest-cost staffing allocation capable of meeting
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



# =============================================================================
# REQUIRED PACKAGE
# =============================================================================
#
# This project uses lpSolve for continuous linear programming (fractional staffing).
#
# If lpSolve is not already installed, run this once in the R console:
#
# install.packages("lpSolve")
#
# The script will stop with a clear message if the package is missing.
# =============================================================================

if (!requireNamespace("lpSolve", quietly = TRUE)) {
  stop(
    "Package 'lpSolve' is required. Run install.packages('lpSolve') once."
  )
}



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

# Full-time agents always begin their shift handling calls.
# They then alternate every 2 hours between calls and other duties.

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

# ASSUMPTION 3 (Professor Najafi's direction):
#
# Staffing is modeled as CONTINUOUS (lpSolve all.int = FALSE). Fractional
# results are agent-equivalents. Daily costs, the break-even premium, cost
# per call, capacity and utilization all use the continuous solution.
# Staffing tables are then rounded to whole people per shift (13A).

# ASSUMPTION 4 (Professor Najafi's direction):
#
# Full-time agents always start their shift on calls, and nobody works
# after 9 PM. A full-timer therefore cannot start at 5 PM (their second
# call block would fall after 9 PM).

# ASSUMPTION 5:
#
# Bilingual agents work at full speed (6 calls/hour) in both languages and
# can switch queues block by block. Real language skills fall on a spectrum.

# ASSUMPTION 6:
#
# Only salary for time on calls counts as cost. Benefits, recruiting,
# training and off-call time are out of scope (also for annualized figures).

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
# Full-time agents may follow the alternating pattern:
#
# Pattern:
#
#   CALL → OFF → CALL → OFF
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

# Full-time agents work an 8-hour shift 
# and always begin their shift handling calls.

# Full-time agents alternate every two hours between call duties
# and their other responsibilities

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
# the lowest-cost feasible staffing allocation.



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
#   Nonnegative continuous staffing levels
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

# Define the full-time call patterns.

# 1 = employee is handling calls
# 0 = employee is performing other duties

ft_pattern <- c(1, 0, 1, 0)

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
    ft_7am = c(1, 0, 1, 0, 0, 0, 0),

    # Full-time agents starting at 9 AM
    ft_9am = c(0, 1, 0, 1, 0, 0, 0),

    # Full-time agents starting at 11 AM
    ft_11am = c(0, 0, 1, 0, 1, 0, 0),

    # Full-time agents starting at 1 PM
    ft_1pm = c(0, 0, 0, 1, 0, 1, 0),

    # Full-time agents starting at 3 PM
    ft_3pm = c(0, 0, 0, 0, 1, 0, 1),

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

# Each two-hour call block after 5 PM costs:

# 2 hours x $45 = $90

cost_per_option <- c(
  # Full-time agents starting at 7 AM
  ft_7am = 2 * wage_before_5pm + 2 * wage_before_5pm,

  # Full-time agents starting at 9 AM
  ft_9am = 2 * wage_before_5pm + 2 * wage_before_5pm,

    # Full-time agents starting at 11 AM
  ft_11am = 2 * wage_before_5pm + 2 * wage_before_5pm,

  # Full-time agents starting at 1 PM
  ft_1pm = 2 * wage_before_5pm + 2 * wage_after_5pm,

  # Full-time agents starting at 3 PM
  ft_3pm = 2 * wage_before_5pm + 2 * wage_after_5pm,

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

# The baseline model distinguishes full-time staffing by language.

# Each full-time staffing pattern can therefore be assigned to either:

#   - an English-speaking full-time agent
#   - a Spanish-speaking full-time agent

# Part-time agents are English-speaking only in the baseline scenario

# Identify the full-time staffing options.

ft_options <- rownames(coverage_matrix)[
  grepl("^ft_", rownames(coverage_matrix))
]

# Identify the part-time staffing options.
pt_options <- rownames(coverage_matrix)[
  grepl("^pt_", rownames(coverage_matrix))
]

# Create the English-speaking full-time decision variables.

english_ft_vars <- paste0(
  "eng_",
  ft_options
)

# Create the Spanish-speaking full-time decision variables.

spanish_ft_vars <- paste0(
  "spa_",
  ft_options
)

# Create the English-speaking part-time decision variables.

english_pt_vars <- paste0(
  "eng_",
  pt_options
)

# Combine all the baseline decision variables into one vector.

decision_names <- c(
  english_ft_vars,
  spanish_ft_vars,
  english_pt_vars
)

# Assign the corresponding staffing cost to each decision variable.

# English and Spanish full-time agents have the same schedule costs.
# Part-time agents use the part-time schedule costs.

baseline_costs <- c(
  cost_per_option[ft_options],
  cost_per_option[ft_options],
  cost_per_option[pt_options]
)

names(baseline_costs) <- decision_names

# Print the baseline decision variables and their costs.

cat("\n============================================================\n")
cat("BASELINE DECISION VARIABLES\n")
cat("============================================================\n\n")

print(
  data.frame(
    decision_variable = decision_names,
    cost = baseline_costs,
    row.names = NULL
  )
)



# ----- 9E. Solve Baseline Optmization Model -----

# Each active agent handles 6 calls per hour.
# Therefore, during a two-hour block, one active agent can handle:

agent_capacity_per_block <-
  calls_per_agent_hour * hours_per_block

# Build English Capacity Constraints

# English demand can be covered by:

#   - English-speaking full-time agents
#   - English-speaking part-time agents

english_ft_coverage <-
  t(coverage_matrix[ft_options, , drop = FALSE]) *
    agent_capacity_per_block

english_pt_coverage <- 
  t(coverage_matrix[pt_options, , drop = FALSE]) *
    agent_capacity_per_block

# Create zero columns for staffing groups that cannot serve
# a particular language

zero_ft <- matrix(
  0,
  nrow = nrow(demand),
  ncol = length(ft_options)
)

zero_pt <- matrix(
  0,
  nrow = nrow(demand),
  ncol = length(pt_options)
)

# Decision-variable order:

# English FT | Spanish FT | English PT

english_constraints <- cbind(
  english_ft_coverage,
  zero_ft,
  english_pt_coverage
)

# Build Spanish Capacity Constraints

# Spanish demand can only be covered by Spanish-speaking
# full-time agents in the baseline scenario.

spanish_ft_coverage <-
  t(coverage_matrix[ft_options, , drop = FALSE]) *
  agent_capacity_per_block

spanish_constraints <- cbind(
  zero_ft,
  spanish_ft_coverage,
  zero_pt
)

# Combine all demand constraints

# Seven English constraints + seven Spanish constraints
# gives fourteen total baseline demand constraints.

constraint_matrix <- rbind(
  english_constraints,
  spanish_constraints
)

colnames(constraint_matrix) <- decision_names

rownames(constraint_matrix) <- c(
  paste0("ENG_", demand$time_block),
  paste0("SPA_", demand$time_block)
)

# Every capacity constraint must meet or exceed demand.

constraint_directions <-
  rep(">=", nrow(constraint_matrix))


# Right-hand side of the constraints:
# required English calls followed by Spanish calls.

constraint_rhs <- c(
  demand$english_calls_per_block,
  demand$spanish_calls_per_block
)

# Solve the optimization model

baseline_model <- lpSolve::lp(
  direction = "min",
  objective.in = as.numeric(baseline_costs),
  const.mat = constraint_matrix,
  const.dir = constraint_directions,
  const.rhs = constraint_rhs,
  all.int = FALSE
)

# A status of 0 indicates that an optimal solution was found.

if(baseline_model$status != 0) {
  stop("Baseline optimization did not return an optimal solution.")
}

# Attatch readable names to the staffing solution.

baseline_solution <- baseline_model$solution

names(baseline_solution) <- decision_names

# Build a readable results table.

baseline_results <- data.frame(
  decision_variable = decision_names,
  agents = baseline_solution,
  cost_per_agent = as.numeric(baseline_costs),
  total_cost = baseline_solution * as.numeric(baseline_costs),
  row.names = NULL
)

cat("\n============================================================\n")
cat("BASELINE OPTIMAL STAFFING ALLOCATION\n")
cat("============================================================\n\n")

print(
  baseline_results[
    baseline_results$agents > 0,
  ]
)


cat(
  "\nMinimum baseline operating cost: $",
  format(
    round(baseline_model$objval, 2),
    nsmall = 2
  ),
  "\n",
  sep = ""
)



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
#   C. What staffing allocation minimizes cost?
#
#   D. What is the resulting minimum cost?
# -----------------------------------------------------------------------------

# ----- 10A. Build Restricted-Start Constraints -----

# Create a constraint for English-speaking full-time agents
# starting at 1 PM.
#
# Conceptually:
#
#   eng_ft_1pm <= 1

restricted_1pm <- rep(
  0,
  length(decision_names)
)

names(restricted_1pm) <- decision_names

restricted_1pm["eng_ft_1pm"] <- 1


# Create a constraint for English-speaking full-time agents
# starting at 3 PM.
#
# Conceptually:
#
#   eng_ft_3pm <= 1

restricted_3pm <- rep(
  0,
  length(decision_names)
)

names(restricted_3pm) <- decision_names

restricted_3pm["eng_ft_3pm"] <- 1


# ----- 10B. Add Restrictions to Baseline Constraints -----

# Keep all fourteen baseline demand constraints and add
# the two restricted-start constraints.

restricted_constraint_matrix <- rbind(
  constraint_matrix,
  restricted_1pm,
  restricted_3pm
)


rownames(restricted_constraint_matrix)[15:16] <- c(
  "MAX_ENG_FT_1PM",
  "MAX_ENG_FT_3PM"
)


# Baseline demand constraints use >=.
#
# The two new staffing limits use <=.

restricted_constraint_directions <- c(
  constraint_directions,
  "<=",
  "<="
)


# Add the maximum permitted staffing values to the
# right-hand side.

restricted_constraint_rhs <- c(
  constraint_rhs,
  max_english_ft_start_1pm,
  max_english_ft_start_3pm
)


# Verify the restricted model dimensions.
#
# 14 demand constraints + 2 staffing restrictions = 16 constraints.

stopifnot(
  nrow(restricted_constraint_matrix) == 16,
  ncol(restricted_constraint_matrix) == 12,
  length(restricted_constraint_directions) == 16,
  length(restricted_constraint_rhs) == 16
)


# ----- 10C. Solve Restricted-Start Model -----

restricted_model <- lpSolve::lp(
  direction = "min",
  objective.in = as.numeric(baseline_costs),
  const.mat = restricted_constraint_matrix,
  const.dir = restricted_constraint_directions,
  const.rhs = restricted_constraint_rhs,
  all.int = FALSE
)


# A status of 0 indicates that an optimal solution was found.

if (restricted_model$status != 0) {
  stop(
    "Restricted-start optimization did not return an optimal solution."
  )
}


# Attach readable names to the optimized staffing solution.

restricted_solution <- restricted_model$solution

names(restricted_solution) <- decision_names


# Build a readable staffing table.

restricted_results <- data.frame(
  decision_variable = decision_names,
  agents = restricted_solution,
  cost_per_agent = as.numeric(baseline_costs),
  total_cost =
    restricted_solution * as.numeric(baseline_costs),
  row.names = NULL
)


cat("\n============================================================\n")
cat("RESTRICTED-START OPTIMAL STAFFING ALLOCATION\n")
cat("============================================================\n\n")

print(
  restricted_results[
    restricted_results$agents > 0,
  ]
)


# ----- Question D: Minimum Operating Cost -----

cat(
  "\nMinimum restricted-start operating cost: $",
  format(
    round(restricted_model$objval, 2),
    nsmall = 2
  ),
  "\n",
  sep = ""
)



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
#   E. What FT/PT staffing allocation minimizes operating cost?
#
#   F. What is the resulting minimum operating cost?
# -----------------------------------------------------------------------------

# ----- 11A. Define Bilingual Decision Variables -----

# Because every agent is bilingual, separate English and Spanish
# staffing variables are no longer necessary.
#
# We now need only one decision variable for each valid
# full-time or part-time staffing option.

bilingual_decision_names <- paste0(
  "bil_",
  rownames(coverage_matrix)
)


# Each bilingual staffing option has the same schedule cost
# used in the previous scenarios.

bilingual_costs <- cost_per_option

names(bilingual_costs) <- bilingual_decision_names


cat("\n============================================================\n")
cat("BILINGUAL DECISION VARIABLES\n")
cat("============================================================\n\n")

print(
  data.frame(
    decision_variable = bilingual_decision_names,
    cost = bilingual_costs,
    row.names = NULL
  )
)


# ----- 11B. Build Bilingual Capacity Constraints -----

# Since all agents are bilingual, any active agent can handle
# any customer call.
#
# Therefore, language-specific demand constraints are removed.
#
# The model only needs:
#
#   Total Call Capacity >= Total Call Demand


bilingual_constraint_matrix <-
  t(coverage_matrix) * agent_capacity_per_block


colnames(bilingual_constraint_matrix) <-
  bilingual_decision_names


rownames(bilingual_constraint_matrix) <-
  demand$time_block


# Every capacity constraint must meet or exceed total demand.

bilingual_constraint_directions <-
  rep(">=", nrow(demand))


# Total demand for each two-hour period.

bilingual_constraint_rhs <-
  demand$calls_per_block


# Verify the model dimensions.
#
# Seven demand periods and seven staffing decisions.

stopifnot(
  nrow(bilingual_constraint_matrix) == 7,
  ncol(bilingual_constraint_matrix) == 7,
  length(bilingual_constraint_rhs) == 7
)


# ----- 11C. Solve Bilingual Optimization Model -----

bilingual_model <- lpSolve::lp(
  direction = "min",
  objective.in = as.numeric(bilingual_costs),
  const.mat = bilingual_constraint_matrix,
  const.dir = bilingual_constraint_directions,
  const.rhs = bilingual_constraint_rhs,
  all.int = FALSE
)


# A status of 0 indicates that an optimal solution was found.

if (bilingual_model$status != 0) {
  stop(
    "Bilingual optimization did not return an optimal solution."
  )
}


# Attach readable names to the staffing solution.

bilingual_solution <- bilingual_model$solution

names(bilingual_solution) <- bilingual_decision_names


# Build a readable results table.

bilingual_results <- data.frame(
  decision_variable = bilingual_decision_names,
  agents = bilingual_solution,
  cost_per_agent = as.numeric(bilingual_costs),
  total_cost =
    bilingual_solution * as.numeric(bilingual_costs),
  row.names = NULL
)


cat("\n============================================================\n")
cat("BILINGUAL OPTIMAL STAFFING ALLOCATION\n")
cat("============================================================\n\n")

print(
  bilingual_results[
    bilingual_results$agents > 0,
  ]
)


# ----- Question F: Minimum Operating Cost -----

cat(
  "\nMinimum bilingual operating cost: $",
  format(
    round(bilingual_model$objval, 2),
    nsmall = 2
  ),
  "\n",
  sep = ""
)



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

# The baseline model represents the monolingual workforce.

monolingual_cost <- baseline_model$objval


# The bilingual model represents the minimum operating cost when
# all agents are bilingual at the original wage rates.

bilingual_cost <- bilingual_model$objval


# Let p represent the maximum proportional wage premium.
#
# At the break-even point:
#
#   bilingual_cost * (1 + p) = monolingual_cost
#
# Therefore:
#
#   p = (monolingual_cost / bilingual_cost) - 1

max_bilingual_premium <-
  (monolingual_cost / bilingual_cost) - 1


# Convert the proportional premium to a percentage.

max_bilingual_premium_pct <-
  max_bilingual_premium * 100


cat("\n============================================================\n")
cat("BILINGUAL WAGE PREMIUM\n")
cat("============================================================\n\n")


cat(
  "Maximum bilingual wage premium: ",
  round(max_bilingual_premium_pct, 1),
  "%\n",
  sep = ""
)



# -----------------------------------------------------------------------------
# 13. EXTENSION H - DEMAND GROWTH SENSITIVITY
# -----------------------------------------------------------------------------
#
# This section tests how the optimal staffing allocation changes if customer-support
# demand increases while all staffing rules, language shares, productivity,
# and wage rates remain unchanged.
#
# Growth scenarios:
#
#   - Current demand
#   - +10%
#   - +20%
#   - +30%
#
# This is a sensitivity analysis, not a forecast.
# -----------------------------------------------------------------------------


# Define demand-growth scenarios.

growth_rates <- c(
  0.00,
  0.10,
  0.20,
  0.30
)


# Create an empty results table.

growth_results <- data.frame()

# Keep each continuous solution so staffing can be rounded shift by shift
# later (13A).

growth_solutions <- list()


# Solve the baseline staffing model for each growth scenario.

for (g in growth_rates) {

  # Increase English and Spanish demand proportionally.

  growth_english_demand <-
    demand$english_calls_per_block * (1 + g)

  growth_spanish_demand <-
    demand$spanish_calls_per_block * (1 + g)


  # Build the new right-hand side.

  growth_rhs <- c(
    growth_english_demand,
    growth_spanish_demand
  )


  # Solve the model using the same cost structure
  # and staffing constraints as the baseline.

  growth_model <- lpSolve::lp(
    direction = "min",
    objective.in = as.numeric(baseline_costs),
    const.mat = constraint_matrix,
    const.dir = constraint_directions,
    const.rhs = growth_rhs,
    all.int = FALSE
  )


  # Stop if any growth scenario is infeasible.

  if (growth_model$status != 0) {
    stop(
      paste(
        "Optimization failed for growth rate:",
        g
      )
    )
  }


  # Store the optimized staffing solution.

  growth_solution <- growth_model$solution

  names(growth_solution) <- decision_names

  growth_solutions[[length(growth_solutions) + 1]] <- growth_solution


  # Calculate FT and PT totals.

  growth_ft_total <-
    sum(
      growth_solution[
        c(
          english_ft_vars,
          spanish_ft_vars
        )
      ]
    )

  growth_pt_total <-
    sum(
      growth_solution[
        english_pt_vars
      ]
    )


  # Add scenario results to the summary table.

  growth_results <- rbind(
    growth_results,
    data.frame(
      demand_growth_pct =
        paste0(round(g * 100), "%"),

      full_time_agents =
        growth_ft_total,

      part_time_agents =
        growth_pt_total,

      total_agents =
        growth_ft_total +
        growth_pt_total,

      minimum_cost =
        growth_model$objval
    )
  )
}


cat("\n============================================================\n")
cat("DEMAND GROWTH SENSITIVITY\n")
cat("============================================================\n\n")

print(growth_results)



# =============================================================================



# -----------------------------------------------------------------------------
# 13A. ROUNDING RULE - WHOLE PEOPLE PER SHIFT
# -----------------------------------------------------------------------------
#
# The continuous LP returns fractional agent-equivalents (for example, 5.33
# English full-timers starting at 7 AM).
#
# Following the case and Professor Najafi's direction:
#
#   - COSTS, break-even premium, cost per call and every other dollar figure
#     use the CONTINUOUS (unrounded) LP solution.
#
#   - STAFFING TABLES (who to hire at each start time) are rounded to whole
#     people, shift by shift, to the nearest person (.5 rounds up).
#
# The rounded schedule is a hiring guide, not a new optimum. It leaves some
# blocks slightly short (see the rounding audit in 14T and the service-level
# extension in 13B), which is why its cost is never used.
#
# Note: R's round() uses "round half to even" (round(2.5) = 2), so we use an
# explicit half-up rule to match the deck.
# -----------------------------------------------------------------------------

round_half_up <- function(x) {
  floor(x + 0.5 + 1e-9)
}

baseline_rounded <- round_half_up(baseline_solution)
restricted_rounded <- round_half_up(restricted_solution)
bilingual_rounded <- round_half_up(bilingual_solution)

# Add rounded headcount to the demand-growth table (FT + PT, rounded shift
# by shift, the same way as the Scenario I staffing table).

growth_results$full_time_rounded <- NA_real_
growth_results$part_time_rounded <- NA_real_

for (i in seq_along(growth_rates)) {

  growth_rounded <- round_half_up(growth_solutions[[i]])

  growth_results$full_time_rounded[i] <-
    sum(growth_rounded[c(english_ft_vars, spanish_ft_vars)])

  growth_results$part_time_rounded[i] <-
    sum(growth_rounded[english_pt_vars])
}

cat("\n============================================================\n")
cat("ROUNDED STAFFING (WHOLE PEOPLE PER SHIFT)\n")
cat("============================================================\n\n")

print(
  data.frame(
    decision_variable = decision_names,
    baseline_continuous = round(baseline_solution, 3),
    baseline_rounded = baseline_rounded[decision_names],
    restricted_continuous = round(restricted_solution, 3),
    restricted_rounded = restricted_rounded[decision_names],
    row.names = NULL
  )
)

print(
  data.frame(
    decision_variable = bilingual_decision_names,
    bilingual_continuous = round(bilingual_solution, 3),
    bilingual_rounded = bilingual_rounded[bilingual_decision_names],
    row.names = NULL
  )
)



# -----------------------------------------------------------------------------
# 13B. EXTENSION I - SERVICE-LEVEL BUFFER (ROUNDED UTILIZATION)
# -----------------------------------------------------------------------------
#
# Question:
#
#   I. What does it cost to give the rounded schedule a buffer so that no
#      block runs above 100% utilization?
#
# Definition used in the deck (slide 19):
#
#   Utilization = required headcount / staffed headcount
#
#   required headcount = calls in the block / 12 calls per agent
#                        (the continuous LP requirement, e.g. 5.33)
#
#   staffed headcount  = rounded agents actually on calls in that block
#                        (e.g. 5)
#
#   5.33 / 5 = 106.7%  -> the block is over-utilized: 5 people are asked to
#                         do the work of 5.33.
#
# We focus on the ENGLISH queue of Scenario I (today's plan): it carries 80%
# of calls, and it is where rounding down leaves the most blocks short.
#
# The 85% line on the chart is a utilization TARGET (planning cushion), not
# a case constraint.
# -----------------------------------------------------------------------------

english_queue_vars <- c(english_ft_vars, english_pt_vars)
spanish_queue_vars <- spanish_ft_vars

# Agents on calls in each block = staffing x coverage pattern.

agents_on_calls <- function(staffing, vars) {
  patterns <- sub("^(eng|spa|bil)_", "", vars)
  as.numeric(staffing[vars] %*% coverage_matrix[patterns, , drop = FALSE])
}

english_required <- demand$english_calls_per_block / agent_capacity_per_block
spanish_required <- demand$spanish_calls_per_block / agent_capacity_per_block
total_required   <- demand$calls_per_block / agent_capacity_per_block

english_staffed_rounded <-
  agents_on_calls(baseline_rounded, english_queue_vars)

spanish_staffed_rounded <-
  agents_on_calls(baseline_rounded, spanish_queue_vars)

bilingual_staffed_rounded <-
  agents_on_calls(bilingual_rounded, bilingual_decision_names)

# Utilization by block (NA where nobody is staffed).

safe_util <- function(required, staffed) {
  ifelse(staffed > 0, 100 * required / staffed, NA_real_)
}

english_util_rounded   <- safe_util(english_required, english_staffed_rounded)
spanish_util_rounded   <- safe_util(spanish_required, spanish_staffed_rounded)
bilingual_util_rounded <- safe_util(total_required, bilingual_staffed_rounded)

# Comparison bar on slide 19: add ONE agent to each block on its own
# (a block-by-block what-if, not a schedule). 11 AM - 1 PM is skipped
# because it is already under 100%.

plus_one_blocks <- english_util_rounded > 100

english_util_plus_one <- ifelse(
  plus_one_blocks,
  100 * english_required / (english_staffed_rounded + 1),
  NA_real_
)

# A real schedule must add whole SHIFTS, not single blocks.
# Four extra English full-timers (7 AM, 9 AM, 1 PM, 3 PM) cover every
# over-utilized block:
#
#   7 AM FT -> 7-9 and 11-1
#   9 AM FT -> 9-11 and 1-3
#   1 PM FT -> 1-3 and 5-7
#   3 PM FT -> 3-5 and 7-9

buffer_hires <- c("eng_ft_7am", "eng_ft_9am", "eng_ft_1pm", "eng_ft_3pm")

buffer_rounded <- baseline_rounded
buffer_rounded[buffer_hires] <- buffer_rounded[buffer_hires] + 1

buffer_daily_cost <- sum(baseline_costs[buffer_hires])

english_staffed_buffer <- agents_on_calls(buffer_rounded, english_queue_vars)
english_util_buffer <- safe_util(english_required, english_staffed_buffer)

stopifnot(all(english_util_buffer < 100))

service_level_table <- data.frame(
  time_block = demand$time_block,
  english_required = english_required,
  english_staffed = english_staffed_rounded,
  english_util_pct = english_util_rounded,
  plus_one_util_pct = english_util_plus_one,
  buffer_staffed = english_staffed_buffer,
  buffer_util_pct = english_util_buffer,
  spanish_util_pct = spanish_util_rounded,
  bilingual_util_pct = bilingual_util_rounded
)

blocks_over_100_english   <- sum(english_util_rounded > 100, na.rm = TRUE)
blocks_over_100_bilingual <- sum(bilingual_util_rounded > 100, na.rm = TRUE)
restricted_staffed_rounded <-
  agents_on_calls(restricted_rounded, english_queue_vars)
blocks_over_100_restricted <-
  sum(safe_util(english_required, restricted_staffed_rounded) > 100,
      na.rm = TRUE)

cat("\n============================================================\n")
cat("EXTENSION I - SERVICE-LEVEL BUFFER (ROUNDED UTILIZATION)\n")
cat("============================================================\n\n")

print(
  data.frame(
    time_block = service_level_table$time_block,
    required = round(service_level_table$english_required, 2),
    staffed = service_level_table$english_staffed,
    today_pct = round(service_level_table$english_util_pct, 1),
    plus_one_pct = round(service_level_table$plus_one_util_pct, 1),
    with_4_hires_pct = round(service_level_table$buffer_util_pct, 1)
  ),
  row.names = FALSE
)

cat(
  "\nEnglish blocks over 100% (Scenario I, rounded): ",
  blocks_over_100_english, " of 7\n",
  "Buffer: 4 English FT hires (7 AM, 9 AM, 1 PM, 3 PM) = +$",
  format(buffer_daily_cost, nsmall = 2), "/day\n",
  "Bilingual peak when rounded the same way: ",
  round(max(bilingual_util_rounded, na.rm = TRUE), 1), "%\n",
  sep = ""
)



# -----------------------------------------------------------------------------
# 13C. EXTENSION - MIXED TEAM (A FEW BILINGUAL AGENTS)
# -----------------------------------------------------------------------------
#
# Why this section exists:
#
#   The continuous model says an all-bilingual team saves $100.00/day.
#   But Tesla hires whole people, and it does not need to convert everyone.
#   This extension asks: how many bilingual agents does it take to capture
#   the savings if the rest of the team stays English-only + Spanish-only?
#
# Model (whole-person, integer staffing):
#
#   E_t, S_t  English / Spanish full-timers starting at t   (integer)
#   B_t       bilingual full-timers starting at t           (integer)
#   P_k       English part-timers starting at k             (integer)
#   Q_k       bilingual part-timers starting at k           (integer)
#   y_b, z_b  bilingual agents assigned to the English / Spanish queue in
#             block b                                       (continuous)
#
#   minimize  sum c (E + S + P) + (1 + premium) * sum c (B + Q)
#
#   subject to, in every block b:
#     12 * (English agents on calls + y_b)  >= English calls
#     12 * (Spanish agents on calls + z_b)  >= Spanish calls
#     y_b + z_b <= bilingual agents on calls     (each bilingual agent
#                                                 serves one queue at a time,
#                                                 or splits their time)
#     total bilingual hires (B + Q) <= k
#
# Assumptions:
#
#   - Same shift rules, wages, 6 calls/hour and 80/20 split as Scenarios I-III.
#   - Bilingual agents work at full speed in either language.
#   - Whole-person costs are compared ONLY with other whole-person costs
#     (they are higher than the continuous LP costs because fractions of a
#     person can't be hired).
# -----------------------------------------------------------------------------

solve_mixed_team <- function(max_bilingual = Inf, premium = 0, demand_scale = 1) {

  ft <- ft_options
  pt <- pt_options
  n_blocks <- nrow(demand)

  var_names <- c(
    paste0("eng_", ft), paste0("spa_", ft), paste0("bil_", ft),
    paste0("eng_", pt), paste0("bil_", pt),
    paste0("y_", seq_len(n_blocks)), paste0("z_", seq_len(n_blocks))
  )

  obj <- c(
    cost_per_option[ft], cost_per_option[ft],
    cost_per_option[ft] * (1 + premium),
    cost_per_option[pt], cost_per_option[pt] * (1 + premium),
    rep(0, 2 * n_blocks)
  )

  cov_ft <- t(coverage_matrix[ft, , drop = FALSE])
  cov_pt <- t(coverage_matrix[pt, , drop = FALSE])
  zero_f <- matrix(0, n_blocks, length(ft))
  zero_p <- matrix(0, n_blocks, length(pt))
  eye    <- diag(n_blocks)
  zero_b <- matrix(0, n_blocks, n_blocks)

  english_rows <- cbind(cov_ft * 12, zero_f, zero_f, cov_pt * 12, zero_p,
                        eye * 12, zero_b)
  spanish_rows <- cbind(zero_f, cov_ft * 12, zero_f, zero_p, zero_p,
                        zero_b, eye * 12)
  bilingual_rows <- cbind(zero_f, zero_f, -cov_ft, zero_p, -cov_pt,
                          eye, eye)

  mat <- rbind(english_rows, spanish_rows, bilingual_rows)
  dir <- c(rep(">=", 2 * n_blocks), rep("<=", n_blocks))
  rhs <- c(demand$english_calls_per_block * demand_scale,
           demand$spanish_calls_per_block * demand_scale,
           rep(0, n_blocks))

  if (is.finite(max_bilingual)) {
    cap_row <- as.numeric(grepl("^bil_", var_names))
    mat <- rbind(mat, cap_row)
    dir <- c(dir, "<=")
    rhs <- c(rhs, max_bilingual)
  }

  integer_vars <- which(!grepl("^[yz]_", var_names))

  model <- lpSolve::lp(
    direction = "min",
    objective.in = as.numeric(obj),
    const.mat = mat,
    const.dir = dir,
    const.rhs = rhs,
    int.vec = integer_vars
  )

  if (model$status != 0) {
    stop("Mixed-team optimization did not return an optimal solution.")
  }

  solution <- round(model$solution, 6)
  names(solution) <- var_names

  list(
    cost = model$objval,
    solution = solution,
    bilingual_hires = sum(solution[grepl("^bil_", var_names)]),
    total_hires = sum(solution[!grepl("^[yz]_", var_names)])
  )
}

# Cost curve: 0, 1, 2, ... bilingual agents added.

mixed_team_k <- 0:6

mixed_team_curve <- data.frame(
  bilingual_agents = mixed_team_k,
  whole_person_cost = sapply(
    mixed_team_k,
    function(k) solve_mixed_team(max_bilingual = k)$cost
  )
)

mixed_separate_cost <-
  mixed_team_curve$whole_person_cost[mixed_team_curve$bilingual_agents == 0]

# Smallest number of bilingual agents that reaches the lowest cost.

mixed_best_cost <- min(mixed_team_curve$whole_person_cost)

mixed_needed_k <- min(
  mixed_team_curve$bilingual_agents[
    abs(mixed_team_curve$whole_person_cost - mixed_best_cost) < 1e-6
  ]
)

mixed_best <- solve_mixed_team(max_bilingual = mixed_needed_k)

mixed_daily_saving <- mixed_separate_cost - mixed_best$cost

mixed_bilingual_seats <-
  mixed_best$solution[grepl("^bil_", names(mixed_best$solution)) &
                        mixed_best$solution > 0]

# Premium room: how much more could those bilingual agents earn before the
# mixed team costs as much as today's whole-person schedule?
# (Bisection on a uniform bilingual premium, bilingual count unrestricted.)

premium_low <- 0
premium_high <- 3

for (iteration in 1:30) {
  premium_mid <- (premium_low + premium_high) / 2
  if (solve_mixed_team(premium = premium_mid)$cost < mixed_separate_cost - 1e-6) {
    premium_low <- premium_mid
  } else {
    premium_high <- premium_mid
  }
}

mixed_breakeven_premium_pct <- premium_low * 100

cat("\n============================================================\n")
cat("EXTENSION - MIXED TEAM (WHOLE-PERSON SCHEDULES)\n")
cat("============================================================\n\n")

print(mixed_team_curve, row.names = FALSE)

cat("\nBilingual seats in the lowest-cost mixed team:\n")
print(mixed_bilingual_seats)

cat(
  "\nWhole-person cost, English-only + Spanish-only: $",
  format(mixed_separate_cost, big.mark = ",", nsmall = 2), "\n",
  "Whole-person cost with ", mixed_needed_k, " bilingual agents: $",
  format(mixed_best$cost, big.mark = ",", nsmall = 2), "\n",
  "Daily saving: $", format(mixed_daily_saving, nsmall = 2), "\n",
  "Break-even premium for the bilingual agents: ~",
  round(mixed_breakeven_premium_pct), "%\n",
  sep = ""
)



# =============================================================================
# 14. SUMMARY OUTPUT
# =============================================================================
#
# Purpose:
#
#   Produce the tables, charts and summary calculations used in the
#   Tesla support-staffing recommendation deck, in deck order.
#
#   Every PNG is named by the deck slide it supports (e.g. 11_... = slide 11).
#   Appendix charts (A1_, A2_) back numbers that are quoted in the deck but
#   no longer have their own slide.
#
# Number rules (agreed with the team and Professor Najafi):
#
#   - Staffing tables show headcount ROUNDED to whole people, shift by shift.
#   - Daily costs, savings, cost per call, break-even premium, capacity and
#     utilization use the CONTINUOUS LP solution.
#   - Every dollar figure is shown with 2 decimals.
#   - Exception: the mixed-team extension (13C) and the service-level
#     extension (13B) are whole-person analyses by design, and are labeled
#     that way wherever they appear.
#
#   Required objects from prior sections:
#
#     demand, coverage_matrix, cost_per_option, agent_capacity_per_block
#     baseline_solution / baseline_costs / baseline_model
#     restricted_solution / restricted_model
#     bilingual_solution / bilingual_costs / bilingual_model
#     english_ft_vars, spanish_ft_vars, english_pt_vars
#     growth_results, growth_solutions
#     baseline_rounded, restricted_rounded, bilingual_rounded   (13A)
#     service_level_table, buffer_daily_cost                    (13B)
#     mixed_team_curve, mixed_best, mixed_breakeven_premium_pct (13C)
#
#   Output:
#
#     output/summary_output/png/*.png
#     output/summary_output/summary_output.txt
#
# =============================================================================



# -----------------------------------------------------------------------------
# 14A. OUTPUT FOLDERS
# -----------------------------------------------------------------------------

summary_output_dir <-
  file.path(
    "output",
    "summary_output"
  )

summary_png_dir <-
  file.path(
    summary_output_dir,
    "png"
  )

dir.create(
  summary_png_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

# Remove charts from earlier runs so the folder matches the current deck.

unlink(
  list.files(
    summary_png_dir,
    pattern = "\\.png$",
    full.names = TRUE
  )
)



# -----------------------------------------------------------------------------
# 14B. DECK COLOR PALETTE
# -----------------------------------------------------------------------------
#
# Deck conventions:
#
#   Scenario I   (English-only + Spanish-only)  dark gray
#   Scenario II  (English start limit)          mid gray
#   Scenario III (bilingual)                    red
#   Extra / comparison series                   light gray
#   Target lines (85% utilization target)       dashed text gray
#
#   Language charts (slides 6, 11, 13): English = dark, Spanish = red,
#   part-time = mid gray.
#
#   Slides 18 and 19 highlight the comparison series in red.
# -----------------------------------------------------------------------------

tesla_red          <- "#E31937"
tesla_dark         <- "#171A20"
tesla_dark_gray    <- "#393C41"
tesla_text_gray    <- "#5C5E62"
tesla_mid_gray     <- "#8E8E8E"
tesla_soft_gray    <- "#B8B9BB"
tesla_light_gray   <- "#DCDCDD"
tesla_lighter_gray <- "#E5E5E6"
tesla_background   <- "#F4F4F4"
tesla_white        <- "#FCFCFC"

scenario_colors <- c(
  II  = tesla_mid_gray,
  I   = tesla_dark_gray,
  III = tesla_red
)



# -----------------------------------------------------------------------------
# 14C. EXTERNAL HISTORICAL CONTEXT
# -----------------------------------------------------------------------------
#
# These values are NOT optimization inputs.
#
# They are included only to reproduce the historical / financial context used
# in the presentation (slides 4, 17 and 21).
#
# Values are stored in millions at full precision so the deck can show
# 2 decimals ($976.09M) and growth rates are computed, not typed.
#
# References:
#
# Tesla, Inc. (2019). Form 10-K for fiscal year 2018.
# U.S. Securities and Exchange Commission.
#   - Total revenues: $21,461.268M (2018), $11,758.751M (2017)
#   - Automotive sales revenue: $17,631.522M (2018), $8,534.752M (2017)
#   - Net loss attributable to common stockholders: $976.091M (2018)
#   - Quarterly data: Q3 2018 net income $311.516M, Q4 2018 $139.483M
#
# Tesla, Inc. (2019, January 2).
# Q4 2018 Vehicle Production & Deliveries.
# Form 8-K, Exhibit 99.1.
#
# Tesla, Inc. (2018, January 3).
# Q4 2017 Vehicle Production & Deliveries (103,122 total 2017 deliveries).
#
# Tesla, Inc. (2019, January 30).
# Fourth Quarter & Full Year 2018 Update.
#
# Paul Tan's Automotive News. (2019, January 31).
# Tesla ended 2018 with a net loss of USD976 million.
#
# TEAM NOTE: double-check the quarterly figures (Q3 / Q4) against the 10-K
# quarterly table before submission.
# -----------------------------------------------------------------------------

# ----- Historical context (slide 4) -----

model_3_deliveries_2018 <- 145846

total_revenue_2018_million <- 21461.268
total_revenue_2017_million <- 11758.751

net_loss_2018_million <- -976.091

q3_profit_2018_million <- 311.516
q4_profit_2018_million <- 139.483

# ----- Scale-context values (slide 17) -----

vehicle_deliveries_2017 <- 103122
vehicle_deliveries_2018 <- 245240

annualized_delivery_run_rate_start_2018 <- 120000
annualized_delivery_run_rate_end_2018 <- 350000

automotive_sales_revenue_2017_million <- 8534.752
automotive_sales_revenue_2018_million <- 17631.522

# ----- Presentation-only assumptions -----

# Weekdays per year used to annualize daily savings (slide 21).
weekdays_per_year <- 260

# Illustrative handling-rate improvement (slide 22).
improved_calls_per_agent_hour <- 7

# Utilization target used on slides 19 and 20. A planning cushion, not a
# case constraint.
utilization_target_pct <- 85



# -----------------------------------------------------------------------------
# 14D. HELPER FUNCTIONS
# -----------------------------------------------------------------------------

# Pull one named value from a solution vector.

solution_value <- function(
  solution,
  variable_name
) {

  value <-
    solution[
      variable_name
    ]

  if (
    length(value) == 0 ||
    is.na(value)
  ) {
    return(0)
  }

  as.numeric(value)
}

# Dollar format with 2 decimals: 4625 -> "$4,625.00", -100 -> "-$100.00".

money <- function(x) {
  paste0(
    ifelse(x < 0, "-$", "$"),
    formatC(abs(x), format = "f", digits = 2, big.mark = ",")
  )
}

# Percent format: pct(94.337) -> "94.3%".

pct <- function(x, digits = 1) {
  ifelse(
    is.na(x),
    "-",
    paste0(formatC(x, format = "f", digits = digits), "%")
  )
}

# Whole-number headcount for tables; zero shows as a dash (as in the deck).

headcount <- function(x) {
  ifelse(x == 0, "-", format(x, big.mark = ","))
}

# Open a deck-sized PNG (16:9).

open_png <- function(file_name) {
  png(
    filename = file.path(summary_png_dir, file_name),
    width = 1600,
    height = 900,
    res = 144,
    bg = tesla_background
  )
}

# Left-aligned chart title in the deck style.

chart_title <- function(title, subtitle = NULL) {
  title(
    main = title,
    adj = 0,
    line = if (is.null(subtitle)) 2.5 else 4.2,
    cex.main = 1.45,
    col.main = tesla_dark,
    font.main = 2
  )
  if (!is.null(subtitle)) {
    mtext(subtitle, side = 3, adj = 0, line = 2.7, cex = 0.85,
          col = tesla_text_gray)
  }
}

# Render a presentation-style table to PNG.

render_table_png <- function(
  table_data,
  file_name,
  title,
  column_widths = NULL,
  font_size = 10,
  note = NULL
) {

  open_png(file_name)

  grid::grid.newpage()

  grid::grid.text(
    title,
    x = grid::unit(0.03, "npc"),
    y = grid::unit(0.94, "npc"),
    just = c("left", "center"),
    gp = grid::gpar(
      col = tesla_dark,
      fontsize = 24,
      fontface = "bold"
    )
  )

  n_body_rows <- nrow(table_data)
  n_rows <- n_body_rows + 1
  n_cols <- ncol(table_data)

  if (is.null(column_widths)) {
    column_widths <- rep(1 / n_cols, n_cols)
  }

  column_widths <- column_widths / sum(column_widths)

  left <- 0.03
  right <- 0.97
  top <- 0.86
  bottom <- if (is.null(note)) 0.08 else 0.14

  x_edges <-
    left +
    c(0, cumsum(column_widths)) *
    (right - left)

  row_height <- min((top - bottom) / n_rows, 0.085)

  draw_cell <- function(x0, x1, y_mid, text, fill, color, face) {

    grid::grid.rect(
      x = grid::unit((x0 + x1) / 2, "npc"),
      y = grid::unit(y_mid, "npc"),
      width = grid::unit(x1 - x0, "npc"),
      height = grid::unit(row_height, "npc"),
      gp = grid::gpar(fill = fill, col = tesla_light_gray, lwd = 0.6)
    )

    # Wrap long text to roughly fit the column width.
    wrap_width <- max(8, floor((x1 - x0) * 1500 / (font_size * 0.62)))

    grid::grid.text(
      paste(strwrap(text, width = wrap_width), collapse = "\n"),
      x = grid::unit(x0 + 0.008, "npc"),
      y = grid::unit(y_mid, "npc"),
      just = c("left", "center"),
      gp = grid::gpar(col = color, fontsize = font_size, fontface = face)
    )
  }

  # Header row.

  for (column_index in seq_len(n_cols)) {
    draw_cell(
      x_edges[column_index],
      x_edges[column_index + 1],
      top - row_height / 2,
      names(table_data)[column_index],
      tesla_dark,
      tesla_white,
      "bold"
    )
  }

  # Body rows (alternating fill, as in the deck tables).

  for (row_index in seq_len(n_body_rows)) {

    row_mid <- top - row_height * row_index - row_height / 2

    fill_color <-
      if (row_index %% 2 == 1) tesla_white else tesla_lighter_gray

    for (column_index in seq_len(n_cols)) {
      draw_cell(
        x_edges[column_index],
        x_edges[column_index + 1],
        row_mid,
        as.character(table_data[row_index, column_index]),
        fill_color,
        tesla_dark,
        "plain"
      )
    }
  }

  if (!is.null(note)) {
    grid::grid.text(
      paste(strwrap(note, width = 150), collapse = "\n"),
      x = grid::unit(0.03, "npc"),
      y = grid::unit(0.06, "npc"),
      just = c("left", "center"),
      gp = grid::gpar(col = tesla_text_gray, fontsize = 9)
    )
  }

  dev.off()
}

# Render a horizontal cost chart (slides 11, 13 and 15).

render_horizontal_cost_chart <- function(
  labels,
  values,
  file_name,
  title,
  colors,
  value_labels = money(values),
  subtitle = NULL,
  note = NULL
) {

  open_png(file_name)

  par(
    mar = c(5, 16, 6, 4),
    bg = tesla_background,
    fg = tesla_dark,
    col.axis = tesla_text_gray,
    col.lab = tesla_text_gray
  )

  bars <-
    barplot(
      values,
      names.arg = labels,
      horiz = TRUE,
      las = 1,
      col = colors,
      border = NA,
      xlim = c(0, max(values) * 1.35),
      xlab = "Daily on-call cost ($)",
      cex.names = 1.0,
      axes = FALSE
    )

  axis(1, at = pretty(c(0, max(values))),
       labels = money(pretty(c(0, max(values)))), cex.axis = 0.8)

  text(
    x = values,
    y = bars,
    labels = value_labels,
    pos = 4,
    col = tesla_dark,
    font = 2,
    cex = 0.95
  )

  chart_title(title, subtitle)

  if (!is.null(note)) {
    mtext(note, side = 1, adj = 0, line = 3.8, cex = 0.7,
          col = tesla_text_gray)
  }

  dev.off()
}

# Render a vertical (optionally grouped) bar chart with labels ABOVE bars
# and an optional dashed target line drawn BEHIND the bars.
#
# values: vector (one series) or matrix (rows = series, cols = groups).

render_vertical_bar_chart <- function(
  values,
  group_labels,
  file_name,
  title,
  colors,
  value_labels,
  ylim,
  y_label = "",
  y_axis_labels = NULL,
  target_line = NA,
  target_label = NULL,
  legend_labels = NULL,
  subtitle = NULL,
  note = NULL,
  space = NULL
) {

  open_png(file_name)

  par(
    mar = c(5.5, 7.5, 7, 2),
    bg = tesla_background,
    fg = tesla_dark,
    col.axis = tesla_text_gray,
    col.lab = tesla_text_gray,
    xpd = FALSE
  )

  is_grouped <- is.matrix(values)

  # Draw an empty frame first so the target line sits behind the bars.

  bar_args <- list(
    height = values,
    beside = is_grouped,
    names.arg = group_labels,
    col = colors,
    border = NA,
    ylim = ylim,
    xpd = FALSE,
    axes = FALSE,
    ylab = "",
    cex.names = 0.9
  )

  if (!is.null(space)) bar_args$space <- space

  bar_positions <- do.call(barplot, c(bar_args, list(plot = TRUE)))

  if (!is.na(target_line)) {
    abline(h = target_line, lty = 2, lwd = 2, col = tesla_text_gray)
  }

  do.call(barplot, c(bar_args, list(add = TRUE)))

  y_ticks <- pretty(ylim)
  y_ticks <- y_ticks[y_ticks >= ylim[1] & y_ticks <= ylim[2]]

  axis(
    2,
    at = y_ticks,
    labels = if (is.null(y_axis_labels)) y_ticks else y_axis_labels(y_ticks),
    las = 1,
    cex.axis = 0.8
  )

  box(bty = "l", col = tesla_dark)

  mtext(y_label, side = 2, line = 6.2, col = tesla_text_gray, cex = 0.9)

  # Labels above bars (skip NA / empty labels).

  label_y <- pmax(as.numeric(values), ylim[1])
  keep <- !is.na(as.numeric(values)) & nzchar(as.character(value_labels))

  text(
    x = as.numeric(bar_positions)[keep],
    y = label_y[keep],
    labels = as.character(value_labels)[keep],
    pos = 3,
    col = tesla_dark,
    font = 2,
    cex = 0.75,
    xpd = TRUE
  )

  if (!is.null(legend_labels)) {

    legend_fill <- c(colors, if (!is.na(target_line)) NA)
    legend_border <- c(rep(NA, length(colors)), if (!is.na(target_line)) NA)
    legend_lty <- c(rep(NA, length(colors)), if (!is.na(target_line)) 2)

    legend(
      "topleft",
      inset = c(0, -0.075),
      legend = c(legend_labels, target_label),
      fill = legend_fill,
      border = legend_border,
      lty = legend_lty,
      col = c(rep(NA, length(colors)), tesla_text_gray),
      lwd = 2,
      bty = "n",
      horiz = TRUE,
      cex = 0.8,
      xpd = TRUE,
      seg.len = 1.5,
      x.intersp = 0.6,
      text.width = NA
    )
  }

  chart_title(title, subtitle)

  if (!is.null(note)) {
    mtext(note, side = 1, adj = 0, line = 4.3, cex = 0.7,
          col = tesla_text_gray)
  }

  dev.off()
}

# Staffing table by start time, rounded to whole people (slides 10, 12, 14).

build_staffing_table <- function(rounded, columns) {

  start_labels <- c("7 AM", "9 AM", "11 AM", "1 PM", "3 PM", "5 PM")
  start_keys   <- c("7am", "9am", "11am", "1pm", "3pm", "5pm")

  table_out <- data.frame(Start = c(start_labels, "Total"),
                          stringsAsFactors = FALSE)

  for (column_name in names(columns)) {

    prefix <- columns[[column_name]]
    values <- sapply(
      start_keys,
      function(key) solution_value(rounded, paste0(prefix, key))
    )

    table_out[[column_name]] <- c(headcount(values), sum(values))
  }

  table_out
}

# Agents on calls per block x 12 calls = capacity per block.

block_capacity <- function(staffing) {

  patterns <- sub("^(eng|spa|bil)_", "", names(staffing))

  as.numeric(staffing %*% coverage_matrix[patterns, , drop = FALSE]) *
    agent_capacity_per_block
}



# -----------------------------------------------------------------------------
# 14E. SUMMARY CALCULATIONS
# -----------------------------------------------------------------------------

# ----- Scenario costs (continuous LP) -----

baseline_cost <- baseline_model$objval
restricted_cost <- restricted_model$objval
bilingual_cost <- bilingual_model$objval

# ----- Scenario staffing totals: ROUNDED headcount (slides 2, 10, 12, 14) -----

baseline_ft_english <- sum(baseline_rounded[english_ft_vars])
baseline_ft_spanish <- sum(baseline_rounded[spanish_ft_vars])
baseline_pt_english <- sum(baseline_rounded[english_pt_vars])
baseline_ft_total <- baseline_ft_english + baseline_ft_spanish
baseline_total_agents <- baseline_ft_total + baseline_pt_english

restricted_ft_english <- sum(restricted_rounded[english_ft_vars])
restricted_ft_spanish <- sum(restricted_rounded[spanish_ft_vars])
restricted_pt_english <- sum(restricted_rounded[english_pt_vars])
restricted_ft_total <- restricted_ft_english + restricted_ft_spanish
restricted_total_agents <- restricted_ft_total + restricted_pt_english

bilingual_ft_total <-
  sum(bilingual_rounded[grepl("^bil_ft_", names(bilingual_rounded))])
bilingual_pt_total <-
  sum(bilingual_rounded[grepl("^bil_pt_", names(bilingual_rounded))])
bilingual_total_agents <- bilingual_ft_total + bilingual_pt_total

# ----- Agent-equivalents, capacity and utilization (continuous LP) -----
#
# Every hire is on calls for exactly two 2-hour blocks (FT: CALL-OFF-CALL-OFF,
# PT: CALL-CALL), so each agent-equivalent supplies 2 x 12 = 24 calls a day.
#
#   capacity     = sum of block capacity across the day
#   utilization  = calls / capacity
#   idle capacity = capacity - calls

daily_calls <- sum(demand$calls_per_block)

baseline_agent_equivalents <- sum(baseline_solution)
restricted_agent_equivalents <- sum(restricted_solution)
bilingual_agent_equivalents <- sum(bilingual_solution)

baseline_block_capacity <- block_capacity(baseline_solution)
restricted_block_capacity <- block_capacity(restricted_solution)
bilingual_block_capacity <- block_capacity(bilingual_solution)

daily_baseline_capacity <- sum(baseline_block_capacity)
daily_restricted_capacity <- sum(restricted_block_capacity)
daily_bilingual_capacity <- sum(bilingual_block_capacity)

baseline_utilization_pct <- 100 * daily_calls / daily_baseline_capacity
restricted_utilization_pct <- 100 * daily_calls / daily_restricted_capacity
bilingual_utilization_pct <- 100 * daily_calls / daily_bilingual_capacity

baseline_idle_capacity <- daily_baseline_capacity - daily_calls
restricted_idle_capacity <- daily_restricted_capacity - daily_calls
bilingual_idle_capacity <- daily_bilingual_capacity - daily_calls

idle_capacity_reduction <- baseline_idle_capacity - bilingual_idle_capacity
idle_agent_hours_removed <- idle_capacity_reduction / calls_per_agent_hour

baseline_on_call_hours <- daily_baseline_capacity / calls_per_agent_hour
bilingual_on_call_hours <- daily_bilingual_capacity / calls_per_agent_hour

# Per-block continuous utilization (appendix A1).

continuous_block_utilization <- data.frame(
  time_block = demand$time_block,
  II  = 100 * demand$calls_per_block / restricted_block_capacity,
  I   = 100 * demand$calls_per_block / baseline_block_capacity,
  III = 100 * demand$calls_per_block / bilingual_block_capacity
)

lowest_block_utilization <- sapply(
  continuous_block_utilization[, c("II", "I", "III")],
  min
)

# ----- Cost breakdowns (slides 11, 13, 15) -----

cost_breakdown <- function(solution, costs, groups) {
  sapply(groups, function(vars) sum(solution[vars] * costs[vars]))
}

baseline_breakdown <- cost_breakdown(
  baseline_solution, baseline_costs,
  list(english_ft = english_ft_vars,
       spanish_ft = spanish_ft_vars,
       english_pt = english_pt_vars)
)

restricted_breakdown <- cost_breakdown(
  restricted_solution, baseline_costs,
  list(english_ft = english_ft_vars,
       spanish_ft = spanish_ft_vars,
       english_pt = english_pt_vars)
)

bilingual_breakdown <- cost_breakdown(
  bilingual_solution, bilingual_costs,
  list(full_time = grep("^bil_ft_", names(bilingual_solution), value = TRUE),
       part_time = grep("^bil_pt_", names(bilingual_solution), value = TRUE))
)

baseline_share_pct <- 100 * baseline_breakdown / baseline_cost
restricted_share_pct <- 100 * restricted_breakdown / restricted_cost

# ----- Scenario savings -----

restricted_cost_increase <- restricted_cost - baseline_cost
restricted_cost_increase_pct <- (restricted_cost / baseline_cost - 1) * 100

bilingual_savings <- baseline_cost - bilingual_cost
bilingual_savings_pct <- (1 - bilingual_cost / baseline_cost) * 100

bilingual_savings_vs_restricted <- restricted_cost - bilingual_cost
bilingual_savings_vs_restricted_pct <-
  (1 - bilingual_cost / restricted_cost) * 100

# ----- Cost per call -----

baseline_cost_per_call <- baseline_cost / daily_calls
restricted_cost_per_call <- restricted_cost / daily_calls
bilingual_cost_per_call <- bilingual_cost / daily_calls

# ----- Bilingual wage premium (Question G) -----

max_bilingual_premium <- (baseline_cost / bilingual_cost) - 1
max_bilingual_premium_pct <- max_bilingual_premium * 100

premium_wage_before_5pm <- wage_before_5pm * (1 + max_bilingual_premium)
premium_wage_after_5pm <- wage_after_5pm * (1 + max_bilingual_premium)

# ----- Demand growth (Question H) -----

growth_results$calls_per_day <- round(daily_calls * (1 + growth_rates))
growth_results$cost_change_pct <-
  (growth_results$minimum_cost / baseline_cost - 1) * 100
growth_results$cost_per_call <-
  growth_results$minimum_cost / (daily_calls * (1 + growth_rates))

growth_30_cost <- growth_results$minimum_cost[growth_rates == 0.30]
growth_30_cost_change_pct <- growth_results$cost_change_pct[growth_rates == 0.30]

# ----- Annualized business case (slide 21) -----

annual_savings_vs_baseline <- bilingual_savings * weekdays_per_year
annual_savings_vs_restricted <- bilingual_savings_vs_restricted * weekdays_per_year
annual_savings_whole_person <- mixed_daily_saving * weekdays_per_year
cost_per_call_reduction_pct <-
  (1 - bilingual_cost_per_call / baseline_cost_per_call) * 100

# ----- Historical growth calculations (slides 4 and 17) -----

total_revenue_growth_pct <-
  (total_revenue_2018_million / total_revenue_2017_million - 1) * 100

vehicle_delivery_growth_pct <-
  (vehicle_deliveries_2018 / vehicle_deliveries_2017 - 1) * 100

delivery_run_rate_growth_pct <-
  (annualized_delivery_run_rate_end_2018 /
     annualized_delivery_run_rate_start_2018 - 1) * 100

automotive_revenue_growth_pct <-
  (automotive_sales_revenue_2018_million /
     automotive_sales_revenue_2017_million - 1) * 100

# ----- Efficiency lever (slide 22) -----

capacity_increase_pct <-
  (improved_calls_per_agent_hour / calls_per_agent_hour - 1) * 100



# -----------------------------------------------------------------------------
# 14F. ANSWER-KEY SUMMARY TABLE (SLIDE 2)
# -----------------------------------------------------------------------------

answer_key_table <- data.frame(
  Section = LETTERS[1:9],
  `What Alex asked` = c(
    "English-/Spanish-only hires by shift",
    "English-/Spanish-only minimum cost",
    "Hires with 1 PM / 3 PM English cap",
    "Minimum cost with the cap",
    "Hires if every agent is bilingual",
    "Bilingual minimum cost",
    "Max bilingual wage premium",
    "Cost if calls grow 10-30%",
    "Cost of a service-level buffer"
  ),
  `Our answer` = c(
    paste0(baseline_ft_total, " FT (", baseline_ft_english, " English, ",
           baseline_ft_spanish, " Spanish) + ", baseline_pt_english, " PT"),
    paste0(money(baseline_cost), " per day"),
    paste0(restricted_ft_total, " FT (", restricted_ft_english, " English, ",
           restricted_ft_spanish, " Spanish) + ", restricted_pt_english, " PT"),
    paste0(money(restricted_cost), " (+", money(restricted_cost_increase),
           ", +", pct(restricted_cost_increase_pct), ")"),
    paste0(bilingual_ft_total, " FT + ", bilingual_pt_total, " PT"),
    paste0(money(bilingual_cost), " (-", money(bilingual_savings),
           ", -", pct(bilingual_savings_pct), ")"),
    pct(max_bilingual_premium_pct),
    paste0("+30% calls: ", money(growth_30_cost), "/day (+",
           round(growth_30_cost_change_pct), "%)"),
    paste0("+4 hires, +", money(buffer_daily_cost),
           "/day: every block under 100%")
  ),
  Slide = c(10, 11, 12, 13, 14, 15, 16, 18, 19),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

render_table_png(
  answer_key_table,
  "02_answer_key_table.png",
  "Every answer at a glance",
  c(0.09, 0.36, 0.45, 0.10),
  11,
  note = "Staffing = rounded to whole people per shift. Costs = continuous LP solution."
)



# -----------------------------------------------------------------------------
# 14G. RECOMMENDATION METRICS (SLIDE 3)
# -----------------------------------------------------------------------------

recommendation_table <- data.frame(
  Metric = c(
    money(bilingual_cost),
    as.character(mixed_needed_k),
    pct(bilingual_utilization_pct),
    paste0("~", round(mixed_breakeven_premium_pct), "%")
  ),
  Meaning = c(
    "Daily cost with one bilingual team, the lowest of all three plans",
    "Bilingual agents capture the full saving in a whole-person schedule",
    paste0("Of capacity used, vs. ", pct(baseline_utilization_pct), " today"),
    "Premium those few agents can earn and still break even"
  ),
  Source = c(
    "Scenario III, continuous LP (11C)",
    "Mixed-team model, whole people (13C)",
    "Continuous LP capacity (14E)",
    "Mixed-team model, whole people (13C)"
  ),
  stringsAsFactors = FALSE
)

render_table_png(
  recommendation_table,
  "03_recommendation_metrics.png",
  "Add bilingual agents where queues are thin",
  c(0.18, 0.52, 0.30),
  12
)



# -----------------------------------------------------------------------------
# 14H. HISTORICAL FINANCIAL CONTEXT (SLIDE 4)
# -----------------------------------------------------------------------------

historical_context_table <- data.frame(
  Metric = c(
    "Model 3 deliveries",
    "Total revenue",
    "Revenue growth",
    "Net loss",
    "Q3 profit",
    "Q4 profit"
  ),
  Value = c(
    format(model_3_deliveries_2018, big.mark = ",", scientific = FALSE),
    paste0(money(total_revenue_2018_million / 1000), "B"),
    paste0("+", round(total_revenue_growth_pct), "%"),
    paste0(money(net_loss_2018_million), "M"),
    paste0(money(q3_profit_2018_million), "M"),
    paste0(money(q4_profit_2018_million), "M")
  ),
  Context = c(
    "2018, first full year of volume production",
    "2018",
    paste0("vs. ", money(total_revenue_2017_million / 1000), "B in 2017"),
    "2018 full year",
    "2018 Q3",
    "2018 Q4"
  ),
  stringsAsFactors = FALSE
)

render_table_png(
  historical_context_table,
  "04_2018_financial_context.png",
  "Selling more cars than ever, still losing money",
  c(0.35, 0.25, 0.40),
  12,
  note = "Sources: Tesla Q4 2018 deliveries release; Tesla Form 10-K FY2018; Paul Tan's Automotive News (Jan. 2019)."
)



# -----------------------------------------------------------------------------
# 14I. DEMAND PROFILE (SLIDE 6)
# -----------------------------------------------------------------------------

demand_matrix <- rbind(
  English = demand$english_calls_per_hour,
  Spanish = demand$spanish_calls_per_hour
)

short_block_labels <- c("7-9 AM", "9-11", "11-1 PM", "1-3", "3-5", "5-7", "7-9")

daily_english_calls <- sum(demand$english_calls_per_block)
daily_spanish_calls <- sum(demand$spanish_calls_per_block)
peak_to_low_ratio <- max(demand$calls_per_hour) / min(demand$calls_per_hour)

open_png("06_demand_profile.png")

par(mar = c(5.5, 5, 7, 2), bg = tesla_background,
    col.axis = tesla_text_gray, col.lab = tesla_text_gray)

demand_bars <- barplot(
  demand_matrix,
  names.arg = short_block_labels,
  col = c(tesla_dark_gray, tesla_red),
  border = NA,
  ylim = c(0, 110),
  axes = FALSE,
  ylab = "Average calls per hour"
)

axis(2, las = 1, cex.axis = 0.8)

text(demand_bars, demand$calls_per_hour, demand$calls_per_hour,
     pos = 3, font = 2, col = tesla_dark)

legend("topleft", inset = c(0, -0.075), xpd = TRUE, horiz = TRUE, bty = "n",
       fill = c(tesla_dark_gray, tesla_red), border = NA, cex = 0.85,
       legend = c(paste0("English - 80% - ", daily_english_calls, " calls"),
                  paste0("Spanish - 20% - ", daily_spanish_calls, " calls")))

chart_title(
  "Calls peak at 1-3 PM and fade after 5 PM",
  paste0(daily_calls, " calls every weekday, 7 AM to 9 PM. The peak is ",
         round(peak_to_low_ratio, 1), "x the quietest block.")
)

mtext("Average calls per hour by 2-hour block. 80/20 language split applied to every block.",
      side = 1, adj = 0, line = 4, cex = 0.7, col = tesla_text_gray)

dev.off()



# -----------------------------------------------------------------------------
# 14J. OPERATING-RULE TABLE (SLIDE 7)
# -----------------------------------------------------------------------------

rule_labels <- c(
  ft_7am = "FT start 7 AM", ft_9am = "FT start 9 AM", ft_11am = "FT start 11 AM",
  ft_1pm = "FT start 1 PM", ft_3pm = "FT start 3 PM",
  pt_3pm = "PT start 3 PM", pt_5pm = "PT start 5 PM"
)

operating_rules_table <- data.frame(
  `Hire option` = rule_labels[rownames(coverage_matrix)],
  stringsAsFactors = FALSE,
  check.names = FALSE
)

for (block_index in seq_len(nrow(demand))) {

  column_values <- sapply(rownames(coverage_matrix), function(option) {

    if (coverage_matrix[option, block_index] == 1) return("CALL")

    # A full-timer is OFF calls in the block right after each call block,
    # within their 8-hour shift.
    if (grepl("^ft_", option)) {
      first_block <- which(coverage_matrix[option, ] == 1)[1]
      if (block_index > first_block && block_index <= first_block + 3) {
        return("OFF")
      }
    }

    ""
  })

  operating_rules_table[[short_block_labels[block_index]]] <- column_values
}

operating_rules_table$Cost <- money(cost_per_option[rownames(coverage_matrix)])

render_table_png(
  operating_rules_table,
  "07_operating_rules_table.png",
  "Each hire covers a fixed set of blocks",
  c(0.20, rep(0.09, 7), 0.13),
  10,
  note = paste0("Each agent handles ", agent_capacity_per_block,
                " calls per 2-hour block. A block on calls costs ",
                money(2 * wage_before_5pm), " before 5 PM and ",
                money(2 * wage_after_5pm), " after 5 PM. Only time on calls counts.")
)



# -----------------------------------------------------------------------------
# 14K. MODEL-SYMBOL TABLES (SLIDES 8-9)
# -----------------------------------------------------------------------------

objective_symbols_table <- data.frame(
  Symbol = c("Z", "T", "K", "E, S", "P", "c"),
  Meaning = c(
    "Total daily on-call salary cost",
    "Full-time start times",
    "Part-time start times",
    "English, Spanish full-timers starting at t",
    "English part-timers starting at k",
    "Cost per hire, set by start time"
  ),
  Values = c(
    "Minimize",
    "7, 9, 11 AM - 1, 3 PM",
    "3, 5 PM",
    "Agents hired (>= 0, continuous)",
    "Agents hired (>= 0, continuous)",
    paste0(money(cost_per_option["ft_7am"]), " at 7, 9, 11 - ",
           money(cost_per_option["ft_1pm"]), " at 1, 3 - ",
           money(cost_per_option["pt_5pm"]), " at 5")
  ),
  stringsAsFactors = FALSE
)

render_table_png(
  objective_symbols_table,
  "08_objective_symbols_table.png",
  "Minimize the daily cost of time on calls",
  c(0.12, 0.43, 0.45),
  12,
  note = "Z = sum over t of c_t (E_t + S_t) + sum over k of c_k P_k. Bilingual model: E, S and P become one bilingual team."
)

constraint_symbols_table <- data.frame(
  Symbol = c("r", "d", "s", "A(t)", "x"),
  Meaning = c(
    "Calls one agent handles per 2-hour block",
    "Calls in block t",
    "Language share of calls",
    "Hires on calls during block t (grid, slide 7)",
    "Agents hired"
  ),
  Values = c(
    as.character(agent_capacity_per_block),
    paste(demand$calls_per_block, collapse = ", "),
    paste0("English ", english_share, " - Spanish ", spanish_share,
           " - Bilingual 1.0"),
    "1-3 PM: the 9 AM and 1 PM starts",
    "E, S, P or B >= 0, continuous"
  ),
  stringsAsFactors = FALSE
)

render_table_png(
  constraint_symbols_table,
  "09_constraint_symbols_table.png",
  "Every call, in every block, is covered",
  c(0.12, 0.43, 0.45),
  12,
  note = "r x sum of x_j over A(t) >= s x d_t for every block t. 7 blocks x 2 languages = 14 rules with English-only + Spanish-only agents, 7 in the bilingual model."
)



# -----------------------------------------------------------------------------
# 14L. STAFFING TABLES (SLIDES 10, 12, 14) - ROUNDED TO WHOLE PEOPLE
# -----------------------------------------------------------------------------

baseline_staffing_table <- build_staffing_table(
  baseline_rounded,
  list(`FT English` = "eng_ft_", `FT Spanish` = "spa_ft_",
       `PT English` = "eng_pt_")
)

render_table_png(
  baseline_staffing_table,
  "10_scenario_I_staffing_table.png",
  paste0("English-only + Spanish-only: ", baseline_total_agents, " hires"),
  c(0.25, 0.25, 0.25, 0.25),
  12,
  note = "Rounded to whole people as the case asks; costs use the continuous solution. The rounded schedule leaves some blocks slightly short."
)

restricted_staffing_table <- build_staffing_table(
  restricted_rounded,
  list(`FT English` = "eng_ft_", `FT Spanish` = "spa_ft_",
       `PT English` = "eng_pt_")
)

render_table_png(
  restricted_staffing_table,
  "12_scenario_II_staffing_table.png",
  "Cap late English starts and the plan shifts earlier",
  c(0.25, 0.25, 0.25, 0.25),
  12,
  note = "Only one English FT agent may start at 1 PM, and one at 3 PM. Rounded to whole people; costs use the continuous solution."
)

bilingual_staffing_table <- build_staffing_table(
  bilingual_rounded,
  list(`FT bilingual` = "bil_ft_", `PT bilingual` = "bil_pt_")
)

render_table_png(
  bilingual_staffing_table,
  "14_scenario_III_staffing_table.png",
  "One bilingual team covers every caller",
  c(0.34, 0.33, 0.33),
  12,
  note = "Any agent can take any caller, so we staff to total demand. Rounded to whole people; costs use the continuous solution."
)



# -----------------------------------------------------------------------------
# 14M. COST BREAKDOWNS AND SCENARIO COMPARISON (SLIDES 11, 13, 15)
# -----------------------------------------------------------------------------

language_colors <- c(tesla_mid_gray, tesla_red, tesla_dark_gray)

render_horizontal_cost_chart(
  labels = c("English part-time", "Spanish full-time", "English full-time"),
  values = rev(baseline_breakdown),
  file_name = "11_scenario_I_cost_breakdown.png",
  title = paste0("English-only + Spanish-only: ", money(baseline_cost), " a day"),
  colors = language_colors,
  value_labels = paste0(money(rev(baseline_breakdown)), " - ",
                        round(rev(baseline_share_pct)), "%"),
  subtitle = paste0(
    round(baseline_agent_equivalents, 1), " agent-equivalents on calls - ",
    daily_baseline_capacity, " calls of capacity - ",
    pct(baseline_utilization_pct), " used - ",
    money(baseline_cost_per_call), " per call"
  ),
  note = "Cost = salary for call-handling time only, continuous LP solution."
)

render_horizontal_cost_chart(
  labels = c("English part-time", "Spanish full-time", "English full-time"),
  values = rev(restricted_breakdown),
  file_name = "13_scenario_II_cost_breakdown.png",
  title = paste0("The cap costs ", money(restricted_cost_increase), " a day"),
  colors = language_colors,
  value_labels = paste0(money(rev(restricted_breakdown)), " - ",
                        round(rev(restricted_share_pct)), "%"),
  subtitle = paste0(
    money(restricted_cost), " - ",
    round(restricted_agent_equivalents, 1), " agent-equivalents - ",
    daily_restricted_capacity, " calls of capacity - ",
    pct(restricted_utilization_pct), " used - ",
    money(restricted_cost_per_call), " per call"
  ),
  note = paste0("+", money(restricted_cost_increase), " (+",
                pct(restricted_cost_increase_pct), ") vs. Scenario I. Continuous LP solution.")
)

scenario_cost_values <- c(restricted_cost, baseline_cost, bilingual_cost)
scenario_cost_per_call <- c(restricted_cost_per_call, baseline_cost_per_call,
                            bilingual_cost_per_call)

render_horizontal_cost_chart(
  labels = c("II - English start limit", "I - English + Spanish",
             "III - Bilingual - lowest"),
  values = scenario_cost_values,
  file_name = "15_scenario_cost_comparison.png",
  title = paste0("Bilingual is the cheapest plan: ", money(bilingual_cost)),
  colors = scenario_colors[c("II", "I", "III")],
  value_labels = paste0(money(scenario_cost_values), " - ",
                        money(scenario_cost_per_call), "/call"),
  subtitle = paste0(
    "-", money(bilingual_savings), " (-", pct(bilingual_savings_pct),
    ") vs. Scenario I - ", money(bilingual_savings_vs_restricted), " (",
    pct(bilingual_savings_vs_restricted_pct), ") below Scenario II"
  ),
  note = paste0("Bars start at $0.00. Cost per call = daily cost / ", daily_calls,
                " calls. Breakdown: ", money(bilingual_breakdown["full_time"]),
                " full-time + ", money(bilingual_breakdown["part_time"]), " part-time.")
)



# -----------------------------------------------------------------------------
# 14N. BILINGUAL WAGE-PREMIUM CHART (SLIDE 16)
# -----------------------------------------------------------------------------

premium_grid <- seq(0, 4, by = 0.05)
premium_cost_line <- bilingual_cost * (1 + premium_grid / 100)

open_png("16_bilingual_wage_premium.png")

par(mar = c(5.5, 7.5, 7, 2), bg = tesla_background,
    col.axis = tesla_text_gray, col.lab = tesla_text_gray)

plot(
  premium_grid, premium_cost_line,
  type = "n",
  xlim = c(0, 4), ylim = c(4500, 4720),
  axes = FALSE, xlab = "Uniform bilingual wage premium", ylab = ""
)

abline(h = baseline_cost, lty = 2, lwd = 2, col = tesla_dark_gray)
abline(h = restricted_cost, lty = 2, lwd = 2, col = tesla_mid_gray)

lines(premium_grid, premium_cost_line, lwd = 4, col = tesla_red)

points(max_bilingual_premium_pct, baseline_cost, pch = 19, cex = 1.8,
       col = tesla_red)

axis(1, at = 0:4, labels = paste0(0:4, "%"), cex.axis = 0.85)
axis(2, at = seq(4500, 4700, 50), labels = money(seq(4500, 4700, 50)),
     las = 1, cex.axis = 0.8)
box(bty = "l")

text(4, baseline_cost - 12, paste0("English-/Spanish-only ", money(baseline_cost)),
     adj = c(1, 1), col = tesla_dark_gray, cex = 0.8)
text(0, restricted_cost + 12, paste0("English start limit ", money(restricted_cost)),
     adj = c(0, 0), col = tesla_mid_gray, cex = 0.8)
text(max_bilingual_premium_pct, baseline_cost + 14,
     paste0("Break-even at ", pct(max_bilingual_premium_pct)),
     pos = 2, font = 2, col = tesla_red, offset = 1)

chart_title(
  paste0("We can pay bilingual agents up to ", pct(max_bilingual_premium_pct), " more"),
  paste0("Bilingual cost = ", money(bilingual_cost), " x (1 + premium). Pay cap: ",
         money(premium_wage_before_5pm), " before 5 PM, ",
         money(premium_wage_after_5pm), " after 5 PM.")
)

mtext("Premium applied equally to both wage rates. Cost axis starts at $4,500.00 to show the crossing.",
      side = 1, adj = 0, line = 4.3, cex = 0.7, col = tesla_text_gray)

dev.off()



# -----------------------------------------------------------------------------
# 14O. SCALE-CONTEXT TABLE (SLIDE 17)
# -----------------------------------------------------------------------------

scale_context_table <- data.frame(
  Metric = c(
    "Vehicle deliveries",
    "Annualized delivery run rate",
    "Automotive sales revenue"
  ),
  `2017 / early 2018` = c(
    format(vehicle_deliveries_2017, big.mark = ",", scientific = FALSE),
    paste0("~", format(annualized_delivery_run_rate_start_2018, big.mark = ",",
                       scientific = FALSE)),
    paste0(money(automotive_sales_revenue_2017_million / 1000), "B")
  ),
  `2018 / year-end` = c(
    format(vehicle_deliveries_2018, big.mark = ",", scientific = FALSE),
    paste0(format(annualized_delivery_run_rate_end_2018, big.mark = ",",
                  scientific = FALSE), "+"),
    paste0(money(automotive_sales_revenue_2018_million / 1000), "B")
  ),
  Growth = c(
    paste0("+", round(vehicle_delivery_growth_pct), "%"),
    paste0("+", round(delivery_run_rate_growth_pct), "%"),
    paste0("+", round(automotive_revenue_growth_pct), "%")
  ),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

render_table_png(
  scale_context_table,
  "17_scale_context.png",
  "The fleet is growing faster than support",
  c(0.38, 0.22, 0.22, 0.18),
  12,
  note = "We don't forecast calls from sales; we use this growth to stress-test staffing at +10%, +20% and +30% call demand."
)



# -----------------------------------------------------------------------------
# 14P. DEMAND-GROWTH SENSITIVITY (SLIDE 18)
# -----------------------------------------------------------------------------

growth_labels <- c("Today", "+10%", "+20%", "+30%")

render_vertical_bar_chart(
  values = growth_results$minimum_cost,
  group_labels = paste0(growth_labels, "\n",
                        format(growth_results$calls_per_day, big.mark = ","),
                        " calls"),
  file_name = "18_growth_sensitivity.png",
  title = "If calls grow 30%, cost grows 30%",
  colors = c(tesla_red, rep(tesla_dark_gray, 3)),
  value_labels = money(growth_results$minimum_cost),
  ylim = c(0, 7000),
  y_label = "Daily on-call cost",
  y_axis_labels = money,
  subtitle = "Today's English-only + Spanish-only staffing; continuous LP cost",
  note = "Rules, wages and 80/20 mix unchanged. A sensitivity test, not a forecast.",
  space = 0.25
)

growth_sensitivity_table <- data.frame(
  Growth = growth_labels,
  `Calls/day` = format(growth_results$calls_per_day, big.mark = ","),
  `FT + PT` = paste0(growth_results$full_time_rounded, " + ",
                     growth_results$part_time_rounded),
  `Daily cost` = money(growth_results$minimum_cost),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

render_table_png(
  growth_sensitivity_table,
  "18_growth_sensitivity_table.png",
  "Cost scales with demand; staffing grows in step",
  c(0.22, 0.24, 0.24, 0.30),
  12,
  note = "FT + PT rounded shift by shift (whole people). Daily cost uses the continuous LP solution."
)



# -----------------------------------------------------------------------------
# 14Q. SERVICE-LEVEL UTILIZATION (SLIDE 19)
# -----------------------------------------------------------------------------

service_matrix <- rbind(
  Today = service_level_table$english_util_pct,
  PlusOne = service_level_table$plus_one_util_pct
)

render_vertical_bar_chart(
  values = service_matrix,
  group_labels = c("7-9", "9-11", "11-1", "1-3", "3-5", "5-7", "7-9"),
  file_name = "19_service_level_utilization.png",
  title = paste(c("One", "Two", "Three", "Four", "Five", "Six", "Seven")[blocks_over_100_english],
                "of seven blocks are highly utilized"),
  colors = c(tesla_dark_gray, tesla_red),
  value_labels = ifelse(is.na(service_matrix), "", pct(service_matrix)),
  ylim = c(50, 140),
  y_axis_labels = function(x) paste0(x, "%"),
  target_line = utilization_target_pct,
  target_label = paste0(utilization_target_pct, "% utilization target"),
  legend_labels = c("Today, rounded", "+1 agent per block"),
  subtitle = paste0("+", money(buffer_daily_cost),
                    "/day: four extra English full-timers (7 AM, 9 AM, 1 PM, 3 PM) bring every block under 100%"),
  note = "Utilization = required headcount (continuous LP) / staffed headcount (rounded, slide 10), English queue. Axis starts at 50%."
)

service_display_table <- data.frame(
  Block = c("7-9", "9-11", "11-1", "1-3", "3-5", "5-7", "7-9"),
  Required = formatC(service_level_table$english_required, format = "f", digits = 2),
  Staffed = service_level_table$english_staffed,
  Today = pct(service_level_table$english_util_pct),
  `+1 agent` = pct(service_level_table$plus_one_util_pct),
  `With 4 hires` = pct(service_level_table$buffer_util_pct),
  Spanish = pct(service_level_table$spanish_util_pct),
  Bilingual = pct(service_level_table$bilingual_util_pct),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

render_table_png(
  service_display_table,
  "19_service_level_table.png",
  "Rounded utilization by block and queue",
  rep(1, 8),
  11,
  note = paste0("Bilingual peaks at ", pct(max(bilingual_util_rounded, na.rm = TRUE)),
                " when rounded the same way: one shared queue absorbs the rounding. ",
                "Spanish 7-9 PM has no Spanish agent on calls in the rounded schedule.")
)



# -----------------------------------------------------------------------------
# 14R. RECOMMENDED PLAN (SLIDE 20)
# -----------------------------------------------------------------------------

plan_table <- data.frame(
  Start = c("7 AM", "9 AM", "11 AM", "1 PM", "3 PM"),
  `Bilingual full-time` = bilingual_rounded[paste0("bil_", ft_options)],
  `Bilingual part-time` = c(rep("-", 4), bilingual_rounded["bil_pt_3pm"]),
  `First bilingual seats` = sapply(ft_options, function(option) {
    seats <- solution_value(mixed_best$solution, paste0("bil_", option))
    if (option == "ft_3pm") {
      seats_pt <- solution_value(mixed_best$solution, "bil_pt_3pm")
      return(paste0(seats, " FT + ", seats_pt, " PT"))
    }
    if (seats == 0) "-" else paste0(seats, " FT")
  }),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

render_table_png(
  plan_table,
  "20_recommended_plan.png",
  "Shift toward one bilingual team, seat by seat",
  c(0.16, 0.28, 0.28, 0.28),
  12,
  note = paste0("Transition: start with the ", mixed_needed_k,
                " bilingual seats, then fill vacancies with bilingual hires. Target: ",
                money(bilingual_cost), "/day. Contingency only: English start limit plan, ",
                money(restricted_cost), "/day.")
)



# -----------------------------------------------------------------------------
# 14S. BUSINESS-CASE TABLE (SLIDE 21)
# -----------------------------------------------------------------------------

business_case_table <- data.frame(
  Metric = c(
    "Saved per year, continuous model",
    "Saved per year, whole people",
    "Cost per call",
    "Less unused capacity a day"
  ),
  Value = c(
    money(annual_savings_vs_baseline),
    money(annual_savings_whole_person),
    money(bilingual_cost_per_call),
    paste0(idle_capacity_reduction, " calls")
  ),
  Calculation = c(
    paste0(money(bilingual_savings), " x ", weekdays_per_year, " weekdays"),
    paste0(money(mixed_daily_saving), " x ", weekdays_per_year,
           ", from just ", mixed_needed_k, " bilingual agents"),
    paste0("Down from ", money(baseline_cost_per_call), " (-",
           pct(cost_per_call_reduction_pct), ")"),
    paste0(daily_baseline_capacity, " vs. ", daily_bilingual_capacity,
           " calls of capacity = ", round(idle_agent_hours_removed, 1),
           " paid hours")
  ),
  stringsAsFactors = FALSE
)

render_table_png(
  business_case_table,
  "21_business_case_metrics.png",
  "What a bilingual structure is worth in a year",
  c(0.32, 0.20, 0.48),
  12,
  note = paste0("Our extrapolation: ", weekdays_per_year,
                " weekdays/year, on-call salary only; excludes benefits, recruiting and training. ",
                "On-call hours: ", round(baseline_on_call_hours, 1), " vs. ",
                round(bilingual_on_call_hours, 1), ".")
)



# -----------------------------------------------------------------------------
# 14T. ILLUSTRATIVE EFFICIENCY LEVERS (SLIDE 22)
# -----------------------------------------------------------------------------

efficiency_levers_table <- data.frame(
  `Illustrative lever` = c(
    "Answer it on delivery day",
    "Move service to the app",
    "Train for first-call resolution",
    "Turn calls into upgrades"
  ),
  `Model link` = c(
    paste0(agent_capacity_per_block, " calls avoided in a block = 1 less agent"),
    "A lighter 1-3 PM peak shrinks the 9 AM group",
    paste0(calls_per_agent_hour, " -> ", improved_calls_per_agent_hour,
           " calls an hour = ", round(capacity_increase_pct), "% more capacity, same team"),
    "New KPI: upgrades per 100 calls"
  ),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

render_table_png(
  efficiency_levers_table,
  "22_efficiency_levers.png",
  "Fewer calls, faster calls, more upgrades",
  c(0.40, 0.60),
  12,
  note = "Ideas to test next, outside the optimization model."
)



# -----------------------------------------------------------------------------
# 14U. APPENDIX CHARTS AND ROUNDING AUDIT
# -----------------------------------------------------------------------------
#
# A1: continuous utilization by block for all three plans (calls / capacity).
#     Supports "96.5% of capacity used, vs. 94.3% today" (slides 3, 15).
#
# A2: mixed-team cost curve. Supports "4 bilingual agents" and "$420.00/day"
#     (slides 3, 20, 21).
#
# Rounding audit: checks whether naive rounding still meets every constraint.
# -----------------------------------------------------------------------------

a1_matrix <- t(as.matrix(continuous_block_utilization[, c("II", "I", "III")]))

render_vertical_bar_chart(
  values = a1_matrix,
  group_labels = c("7-9", "9-11", "11-1", "1-3", "3-5", "5-7", "7-9"),
  file_name = "A1_continuous_utilization_by_block.png",
  title = "Bilingual keeps utilization the most balanced",
  colors = scenario_colors[c("II", "I", "III")],
  value_labels = ifelse(a1_matrix < 99.95, paste0(round(a1_matrix), "%"), ""),
  ylim = c(50, 105),
  y_axis_labels = function(x) paste0(x, "%"),
  target_line = utilization_target_pct,
  target_label = paste0(utilization_target_pct, "% target"),
  legend_labels = c("II - English start limit", "I - today", "III - bilingual"),
  subtitle = paste0(
    "Average - slowest block: II ", pct(restricted_utilization_pct), " - ",
    pct(lowest_block_utilization["II"]), " | I ", pct(baseline_utilization_pct),
    " - ", pct(lowest_block_utilization["I"]), " | III ",
    pct(bilingual_utilization_pct), " - ", pct(lowest_block_utilization["III"])
  ),
  note = "Utilization = calls / capacity (agents on calls x 12) per block, continuous LP. Unlabeled bars are 100%. Axis starts at 50%."
)

render_vertical_bar_chart(
  values = mixed_team_curve$whole_person_cost,
  group_labels = mixed_team_curve$bilingual_agents,
  file_name = "A2_mixed_team_cost_curve.png",
  title = "A few bilingual agents capture all the savings",
  colors = ifelse(
    mixed_team_curve$bilingual_agents == 0, tesla_dark_gray,
    ifelse(mixed_team_curve$bilingual_agents == mixed_needed_k,
           tesla_red, tesla_soft_gray)
  ),
  value_labels = money(mixed_team_curve$whole_person_cost),
  ylim = c(4500, 5200),
  y_label = "Daily cost, whole people",
  y_axis_labels = money,
  subtitle = paste0(mixed_needed_k, " bilingual agents: -", money(mixed_daily_saving),
                    "/day vs. ", money(mixed_separate_cost),
                    ". Premium room: ~", round(mixed_breakeven_premium_pct), "%."),
  note = "Bilingual agents added to an English-only + Spanish-only team. Whole-person (integer) schedules; axis starts at $4,500.00.",
  space = 0.25
)

# Rounding audit: does nearest-integer staffing still meet every constraint?

audit_rounding <- function(label, rounded, solution, costs, mat, rhs, directions) {

  rounded <- rounded[colnames(mat)]
  offered <- as.numeric(mat %*% rounded)

  ok <- ifelse(
    directions == ">=",
    offered >= rhs - 1e-7,
    offered <= rhs + 1e-7
  )

  data.frame(
    scenario = label,
    continuous_cost = sum(solution * costs),
    rounded_cost = sum(rounded * costs),
    constraints_short = sum(!ok),
    feasible = all(ok),
    stringsAsFactors = FALSE
  )
}

rounding_audit <- rbind(
  audit_rounding("I", baseline_rounded, baseline_solution, baseline_costs,
                 constraint_matrix, constraint_rhs, constraint_directions),
  audit_rounding("II", restricted_rounded, restricted_solution, baseline_costs,
                 restricted_constraint_matrix, restricted_constraint_rhs,
                 restricted_constraint_directions),
  audit_rounding("III", bilingual_rounded, bilingual_solution, bilingual_costs,
                 bilingual_constraint_matrix, bilingual_constraint_rhs,
                 bilingual_constraint_directions)
)



# -----------------------------------------------------------------------------
# 14V. VALIDATION AGAINST THE DECK
# -----------------------------------------------------------------------------
#
# These checks stop the script if a model change moves any number the deck
# quotes. They are checks, not replacements for calculated results.
# -----------------------------------------------------------------------------

deck_checks <- c(
  baseline_cost = abs(baseline_cost - 4625) < 0.005,
  restricted_cost = abs(restricted_cost - 4665) < 0.005,
  bilingual_cost = abs(bilingual_cost - 4525) < 0.005,
  premium = round(max_bilingual_premium_pct, 1) == 2.2,
  baseline_headcount = baseline_ft_total == 31 && baseline_pt_english == 3,
  restricted_headcount = restricted_ft_total == 32 && restricted_pt_english == 3,
  bilingual_headcount = bilingual_ft_total == 33 && bilingual_pt_total == 4,
  growth_30 = abs(growth_30_cost - 6012.50) < 0.005,
  buffer = buffer_daily_cost == 540,
  utilization = round(bilingual_utilization_pct, 1) == 96.5 &&
    round(baseline_utilization_pct, 1) == 94.3,
  mixed_team = mixed_needed_k == 4 && abs(mixed_daily_saving - 420) < 0.005
)

if (!all(deck_checks)) {
  stop(paste("Deck numbers changed:",
             paste(names(deck_checks)[!deck_checks], collapse = ", ")))
}



# -----------------------------------------------------------------------------
# 14W. SUMMARY OUTPUT FILE
# -----------------------------------------------------------------------------
#
# Writes every calculation behind the deck, in slide order, with the logic
# and assumptions, to output/summary_output/summary_output.txt
# (also echoed to the console).
# -----------------------------------------------------------------------------

summary_console_path <-
  file.path(
    summary_output_dir,
    "summary_output.txt"
  )

sink(
  summary_console_path,
  split = TRUE
)

# Wide console so tables print on one line.
old_width <- options(width = 160)

line_rule <- function(title) {
  cat("\n============================================================\n")
  cat(title, "\n", sep = "")
  cat("============================================================\n\n")
}

note <- function(...) {
  wrapped <- strwrap(paste0(...), width = 72)
  cat("  Note: ", paste(wrapped, collapse = "\n        "), "\n", sep = "")
}

show_table <- function(x) {
  print(x, row.names = FALSE, right = FALSE)
  cat("\n")
}

cat("TESLA SUPPORT STAFFING - SUMMARY OUTPUT\n")
cat("ISBA 2400 - DataTech Solutions recommendation deck\n")
cat("Generated:", format(Sys.time(), "%Y-%m-%d %H:%M"), "\n")

line_rule("NUMBER RULES")

note("Daily costs, savings, cost per call, break-even premium, capacity and ",
     "utilization use the CONTINUOUS LP solution (lpSolve, all.int = FALSE). ",
     "Fractional agents are agent-equivalents, not people.")
note("Staffing tables are rounded to whole people shift by shift (nearest ",
     "person, .5 rounds up). The rounded schedule is a hiring guide only; ",
     "its cost is never reported because it leaves some blocks short.")
note("Whole-person analyses (service-level buffer, mixed team) are labeled ",
     "as such and only compared with other whole-person figures.")
note("All dollar figures are shown with 2 decimals.")

line_rule("SLIDE 2 - ANSWER KEY")
show_table(answer_key_table)

line_rule("SLIDE 3 - RECOMMENDATION")
show_table(recommendation_table)
note("Storyline: today's plan works on paper at current efficiency, but ",
     "separate English and Spanish queues leave idle capacity. Pooling ",
     "languages in one bilingual team covers the same 830 calls with less ",
     "paid capacity, and only a few bilingual seats are needed to capture ",
     "the savings, so the premium they can earn is high.")

line_rule("SLIDE 4 - TESLA IN 2018 (FINANCIAL CONTEXT)")
show_table(historical_context_table)
cat("Revenue growth: ", money(total_revenue_2018_million), "M / ",
    money(total_revenue_2017_million), "M - 1 = ",
    pct(total_revenue_growth_pct), " (shown as ",
    round(total_revenue_growth_pct), "%)\n", sep = "")
note("External values for context only; not model inputs. Verify the ",
     "quarterly figures against the 10-K before submission.")

line_rule("SLIDE 6 - DEMAND")
show_table(data.frame(
  block = demand$time_block,
  calls_per_hour = demand$calls_per_hour,
  english_per_hour = demand$english_calls_per_hour,
  spanish_per_hour = demand$spanish_calls_per_hour,
  calls_per_block = demand$calls_per_block,
  english_per_block = demand$english_calls_per_block,
  spanish_per_block = demand$spanish_calls_per_block
))
cat("Daily calls: ", daily_calls, " (English ", daily_english_calls,
    ", Spanish ", daily_spanish_calls, ")\n", sep = "")
cat("Peak / quietest block: ", max(demand$calls_per_hour), " / ",
    min(demand$calls_per_hour), " = ", round(peak_to_low_ratio, 1), "x\n", sep = "")
note("Assumption: the 20% non-English share is Spanish, applied uniformly ",
     "to every block (case gives no block-level language mix).")

line_rule("SLIDE 7 - OPERATING RULES")
show_table(operating_rules_table)
note("Only call-handling time is paid in the model: $60.00 per 2-hour block ",
     "before 5 PM and $90.00 after. FT = CALL-OFF-CALL-OFF (always start on ",
     "calls); PT = 4 straight hours on calls, 3 PM or 5 PM start. Per the ",
     "professor, nobody works after 9 PM, so FT cannot start at 5 PM.")

line_rule("SLIDES 8-9 - MODEL")
show_table(objective_symbols_table)
show_table(constraint_symbols_table)

line_rule("SLIDES 10-11 - SCENARIO I: ENGLISH-ONLY + SPANISH-ONLY (A, B)")
cat("Continuous LP solution (agent-equivalents):\n")
show_table(baseline_results[baseline_results$agents > 1e-9, ])
cat("Rounded staffing table (slide 10):\n")
show_table(baseline_staffing_table)
cat("A. ", baseline_ft_total, " FT (", baseline_ft_english, " English, ",
    baseline_ft_spanish, " Spanish) + ", baseline_pt_english, " PT = ",
    baseline_total_agents, " hires\n", sep = "")
cat("B. Minimum daily cost: ", money(baseline_cost), "\n", sep = "")
cat("   English FT ", money(baseline_breakdown["english_ft"]), " (",
    round(baseline_share_pct["english_ft"]), "%) | Spanish FT ",
    money(baseline_breakdown["spanish_ft"]), " (",
    round(baseline_share_pct["spanish_ft"]), "%) | English PT ",
    money(baseline_breakdown["english_pt"]), " (",
    round(baseline_share_pct["english_pt"]), "%)\n", sep = "")
cat("   Agent-equivalents on calls: ", round(baseline_agent_equivalents, 3),
    " | capacity: ", round(baseline_agent_equivalents, 3), " x 24 = ",
    daily_baseline_capacity, " calls | used: ", daily_calls, " / ",
    daily_baseline_capacity, " = ", pct(baseline_utilization_pct),
    " | idle: ", baseline_idle_capacity, " calls\n", sep = "")
cat("   Cost per call: ", money(baseline_cost), " / ", daily_calls, " = ",
    money(baseline_cost_per_call), "\n", sep = "")

line_rule("SLIDES 12-13 - SCENARIO II: ENGLISH START LIMIT (C, D)")
cat("Continuous LP solution (agent-equivalents):\n")
show_table(restricted_results[restricted_results$agents > 1e-9, ])
cat("Rounded staffing table (slide 12):\n")
show_table(restricted_staffing_table)
cat("C. ", restricted_ft_total, " FT (", restricted_ft_english, " English, ",
    restricted_ft_spanish, " Spanish) + ", restricted_pt_english, " PT = ",
    restricted_total_agents, " hires\n", sep = "")
cat("D. Minimum daily cost: ", money(restricted_cost), " (+",
    money(restricted_cost_increase), ", +", pct(restricted_cost_increase_pct),
    " vs. Scenario I)\n", sep = "")
cat("   English FT ", money(restricted_breakdown["english_ft"]), " (",
    round(restricted_share_pct["english_ft"]), "%) | Spanish FT ",
    money(restricted_breakdown["spanish_ft"]), " (",
    round(restricted_share_pct["spanish_ft"]), "%) | English PT ",
    money(restricted_breakdown["english_pt"]), " (",
    round(restricted_share_pct["english_pt"]), "%)\n", sep = "")
cat("   Agent-equivalents: ", round(restricted_agent_equivalents, 3),
    " | capacity: ", daily_restricted_capacity, " calls | used: ",
    pct(restricted_utilization_pct), " | idle: ", restricted_idle_capacity,
    " calls | per call: ", money(restricted_cost_per_call), "\n", sep = "")
note("Demand didn't change; flexibility did. Capping late English starts at ",
     "1 per start time forces extra 9 and 11 AM coverage and part of a $180.00 ",
     "5 PM part-timer. Contingency plan only.")

line_rule("SLIDES 14-15 - SCENARIO III: BILINGUAL TEAM (E, F)")
cat("Continuous LP solution (agent-equivalents):\n")
show_table(bilingual_results[bilingual_results$agents > 1e-9, ])
cat("Rounded staffing table (slide 14):\n")
show_table(bilingual_staffing_table)
cat("E. ", bilingual_ft_total, " FT + ", bilingual_pt_total, " PT = ",
    bilingual_total_agents, " hires\n", sep = "")
cat("F. Minimum daily cost: ", money(bilingual_cost), " (-",
    money(bilingual_savings), ", -", pct(bilingual_savings_pct),
    " vs. Scenario I; -", money(bilingual_savings_vs_restricted), ", -",
    pct(bilingual_savings_vs_restricted_pct), " vs. Scenario II)\n", sep = "")
cat("   Full-time ", money(bilingual_breakdown["full_time"]), " + part-time ",
    money(bilingual_breakdown["part_time"]), "\n", sep = "")
cat("   Agent-equivalents: ", round(bilingual_agent_equivalents, 3),
    " | capacity: ", daily_bilingual_capacity, " calls | used: ",
    pct(bilingual_utilization_pct), " | idle: ", bilingual_idle_capacity,
    " calls | per call: ", money(bilingual_cost_per_call), "\n", sep = "")
note("Any agent can take any caller, so the model staffs to total demand ",
     "instead of two separate queues. Bilingual agents are paid the same ",
     "base wage in this scenario. Rounded, the bilingual team has 3 more ",
     "people than Scenario I but still costs less in the continuous model.")

line_rule("SLIDE 16 - BILINGUAL WAGE PREMIUM (G)")
cat("G. Break-even premium = ", money(baseline_cost), " / ", money(bilingual_cost),
    " - 1 = ", formatC(max_bilingual_premium_pct, format = "f", digits = 2),
    "% (shown as ", pct(max_bilingual_premium_pct), ")\n", sep = "")
cat("   Pay cap: ", money(wage_before_5pm), " x ",
    formatC(1 + max_bilingual_premium, format = "f", digits = 4), " = ",
    money(premium_wage_before_5pm), " before 5 PM; ", money(wage_after_5pm),
    " x ", formatC(1 + max_bilingual_premium, format = "f", digits = 4), " = ",
    money(premium_wage_after_5pm), " after 5 PM\n", sep = "")
note("Premium applied uniformly to every bilingual agent and both wage ",
     "rates. Because the bilingual staffing is unchanged by a uniform ",
     "premium, cost scales linearly: ", money(bilingual_cost), " x (1 + p).")

line_rule("APPENDIX A1 - CONTINUOUS UTILIZATION BY BLOCK")
show_table(data.frame(
  block = continuous_block_utilization$time_block,
  II = pct(continuous_block_utilization$II),
  I = pct(continuous_block_utilization$I),
  III = pct(continuous_block_utilization$III)
))
cat("Average: II ", pct(restricted_utilization_pct), " | I ",
    pct(baseline_utilization_pct), " | III ", pct(bilingual_utilization_pct),
    "\n", sep = "")
cat("Slowest block: II ", pct(lowest_block_utilization["II"]), " | I ",
    pct(lowest_block_utilization["I"]), " | III ",
    pct(lowest_block_utilization["III"]), "\n", sep = "")
note("Utilization = calls / capacity, where capacity = agents on calls x 12. ",
     "One shared queue spreads the work more evenly: even its slowest block ",
     "stays busier, so fewer paid agents sit idle.")

line_rule("SLIDE 17 - SCALE CONTEXT")
show_table(scale_context_table)

line_rule("SLIDE 18 - DEMAND GROWTH (H)")
show_table(data.frame(
  growth = growth_labels,
  calls_per_day = growth_results$calls_per_day,
  ft_rounded = growth_results$full_time_rounded,
  pt_rounded = growth_results$part_time_rounded,
  ft_continuous = round(growth_results$full_time_agents, 3),
  pt_continuous = round(growth_results$part_time_agents, 3),
  daily_cost = money(growth_results$minimum_cost),
  cost_change = paste0("+", pct(growth_results$cost_change_pct)),
  cost_per_call = money(growth_results$cost_per_call)
))
cat("H. +30% calls: ", money(growth_30_cost), "/day (+",
    pct(growth_30_cost_change_pct), ")\n", sep = "")
note("Scenario I structure. Every demand constraint scales by the same ",
     "factor, so the continuous LP cost scales exactly with demand and cost ",
     "per call stays ", money(baseline_cost_per_call), ". Headcount is rounded ",
     "shift by shift at each growth level. Sensitivity test, not a forecast.")

line_rule("SLIDE 19 - SERVICE-LEVEL BUFFER (I)")
show_table(service_display_table)
cat("English blocks over 100%: Scenario I ", blocks_over_100_english,
    " of 7 | Scenario II ", blocks_over_100_restricted, " of 7 | ",
    "bilingual ", blocks_over_100_bilingual, " of 7\n", sep = "")
cat("I. Buffer: +1 English FT at 7 AM, 9 AM, 1 PM and 3 PM = ",
    paste(money(baseline_costs[buffer_hires]), collapse = " + "), " = +",
    money(buffer_daily_cost), "/day\n", sep = "")
note("Utilization here = required headcount (calls / 12, continuous) / ",
     "staffed headcount (rounded schedule). Example 7-9 AM: 5.33 / 5 = ",
     "106.7%. The +1 bars are block-by-block what-ifs; the 4 hires are the ",
     "real schedule fix (they also add one agent at 11-1 and a second at 1-3). ",
     "The ", utilization_target_pct, "% line is a planning target, not a case rule.")

line_rule("SLIDE 20 - RECOMMENDED PLAN")
show_table(plan_table)

line_rule("APPENDIX A2 - MIXED TEAM (WHOLE PEOPLE)")
show_table(data.frame(
  bilingual_agents = mixed_team_curve$bilingual_agents,
  whole_person_cost = money(mixed_team_curve$whole_person_cost),
  saving_vs_none = money(mixed_separate_cost - mixed_team_curve$whole_person_cost)
))
cat("Lowest-cost bilingual seats: ",
    paste(names(mixed_bilingual_seats), mixed_bilingual_seats, sep = " = ",
          collapse = ", "), "\n", sep = "")
cat("Daily saving with ", mixed_needed_k, " bilingual agents: ",
    money(mixed_separate_cost), " - ", money(mixed_best$cost), " = ",
    money(mixed_daily_saving), "\n", sep = "")
cat("Break-even premium for those agents: ",
    pct(mixed_breakeven_premium_pct), " (shown as ~",
    round(mixed_breakeven_premium_pct), "%)\n", sep = "")
note("Integer (whole-person) model: English-only + Spanish-only staff plus up ",
     "to k bilingual hires who can cover either queue. Whole-person costs are ",
     "higher than continuous LP costs and are compared only with each other. ",
     "Compare the ~", round(mixed_breakeven_premium_pct), "% premium room for ",
     "a few seats with ", pct(max_bilingual_premium_pct),
     " if everyone is bilingual (slide 16).")

line_rule("SLIDE 21 - BUSINESS CASE")
show_table(business_case_table)
cat("Annual savings vs. Scenario II: ", money(bilingual_savings_vs_restricted),
    " x ", weekdays_per_year, " = ", money(annual_savings_vs_restricted), "\n", sep = "")
cat("Cost per call: ", money(baseline_cost_per_call), " -> ",
    money(bilingual_cost_per_call), " (", pct(cost_per_call_reduction_pct),
    " less per call)\n", sep = "")
cat("On-call hours: ", daily_baseline_capacity, " / ", calls_per_agent_hour,
    " = ", round(baseline_on_call_hours, 1), " vs. ", daily_bilingual_capacity,
    " / ", calls_per_agent_hour, " = ", round(bilingual_on_call_hours, 1),
    " (", round(idle_agent_hours_removed, 1), " fewer)\n", sep = "")
note("Our extrapolation: ", weekdays_per_year, " weekdays/year, on-call salary ",
     "only; excludes benefits, recruiting and training.")

line_rule("SLIDE 22 - BEYOND THE MODEL")
show_table(efficiency_levers_table)
cat("Handling rate ", calls_per_agent_hour, " -> ", improved_calls_per_agent_hour,
    " calls/hour: +", pct(capacity_increase_pct), " capacity\n", sep = "")

line_rule("SLIDE 24 - LIMITS / ROUNDING AUDIT")
show_table(transform(rounding_audit,
                     continuous_cost = money(continuous_cost),
                     rounded_cost = money(rounded_cost)))
note("Every rounded schedule misses at least one block. Rounded I and II ",
     "even look cheaper than the continuous optimum, but only because they ",
     "leave blocks short. That is why the deck reports continuous costs and ",
     "treats rounded headcount as a hiring guide.")
note("Other limits: cost is the only goal (no service level); fixed 6 calls/",
     "hour; average weekday demand; flat 80/20 mix; set rotations; calls ",
     "routed to an agent who speaks the caller's language; bilinguals at full ",
     "speed in both languages; call time only.")

line_rule("DECK VALIDATION")
print(deck_checks)
cat("\nAll deck numbers reproduced: ", all(deck_checks), "\n", sep = "")

sink()

options(old_width)

cat("\nSummary written to: ", summary_console_path, "\n", sep = "")
cat("Charts written to:  ", summary_png_dir, "\n", sep = "")