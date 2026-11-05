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



# =============================================================================
# REQUIRED PACKAGE
# =============================================================================
#
# This project uses the lpSolve package for integer linear optimization.
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
  all.int = TRUE
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
cat("BASELINE OPTIMAL STAFFING PLAN\n")
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
#   C. What staffing plan minimizes cost?
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
  all.int = TRUE
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
cat("RESTRICTED-START OPTIMAL STAFFING PLAN\n")
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
#   E. What FT/PT staffing plan minimizes operating cost?
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
  all.int = TRUE
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
cat("BILINGUAL OPTIMAL STAFFING PLAN\n")
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
# 13. MANAGERIAL EXTENSION - DEMAND GROWTH SENSITIVITY
# -----------------------------------------------------------------------------
#
# This section tests how the optimal staffing plan changes if customer-support
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
    all.int = TRUE
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
