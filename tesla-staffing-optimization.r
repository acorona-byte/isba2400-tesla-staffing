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



# =============================================================================
# 12. SUMMARY OUTPUT
# =============================================================================
#
# Purpose:
#
#   Produce the tables, charts, graphs, and summary calculations used in the
#   Tesla support-staffing recommendation deck.
#
#   Required objects from prior sections:
#
#     demand
#     coverage_matrix
#     cost_per_option
#     baseline_solution
#     baseline_costs
#     baseline_model
#     english_ft_vars
#     spanish_ft_vars
#     english_pt_vars
#     restricted_solution
#     restricted_model
#     bilingual_solution
#     bilingual_costs
#     bilingual_model
#     growth_results
#     agent_capacity_per_block
#
#   External historical values used only for presentation context are defined
#   below and cited directly in the code comments.
#
#   Output:
#
#     output/summary_output/png/*.png
#     output/summary_output/summary_console_output.txt
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


# -----------------------------------------------------------------------------
# 14B. DECK COLOR PALETTE
# -----------------------------------------------------------------------------


tesla_red         <- "#E31937"
tesla_dark        <- "#171A20"
tesla_dark_gray   <- "#393C41"
tesla_text_gray   <- "#5C5E62"
tesla_mid_gray    <- "#8E8E8E"
tesla_light_gray  <- "#DCDCDD"
tesla_lighter_gray <- "#E5E5E6"
tesla_background  <- "#FCFCFC"
tesla_white       <- "#F4F4F4"


# -----------------------------------------------------------------------------
# 14C. EXTERNAL HISTORICAL CONTEXT
# -----------------------------------------------------------------------------
#
# These values are NOT optimization inputs.
#
# They are included only to reproduce the historical / financial context used
# in the presentation.
#
# References:
#
# Tesla, Inc. (2019). Form 10-K for fiscal year 2018.
# U.S. Securities and Exchange Commission.
#
# Tesla, Inc. (2019, January 2).
# Q4 2018 Vehicle Production & Deliveries.
# Form 8-K, Exhibit 99.1.
#
# Tesla, Inc. (2019, January 30).
# Fourth Quarter & Full Year 2018 Update.
#
# Paul Tan's Automotive News. (2019, January 31).
# Tesla ended 2018 with a net loss of USD976 million.
# -----------------------------------------------------------------------------


# ----- Historical context -----

model_3_deliveries_2018 <- 145846

total_revenue_2018_billion <- 21.5
total_revenue_2017_billion <- 11.8

net_loss_2018_million <- -976

q3_profit_2018_million <- 312
q4_profit_2018_million <- 140


# ----- Scale-context values -----

vehicle_deliveries_2017 <- 103122
vehicle_deliveries_2018 <- 245240

annualized_delivery_run_rate_start_2018 <- 120000
annualized_delivery_run_rate_end_2018 <- 350000

automotive_sales_revenue_2017_billion <- 8.5
automotive_sales_revenue_2018_billion <- 17.6


# ----- Presentation-only assumptions -----

weekdays_per_year <- 260

improved_calls_per_agent_hour <- 7


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


# Render a presentation-style table to PNG.

render_table_png <- function(
  table_data,
  file_name,
  title,
  column_widths = NULL,
  font_size = 10
) {

  png(
    filename = file.path(
      summary_png_dir,
      file_name
    ),
    width = 1600,
    height = 900,
    res = 144,
    bg = tesla_background
  )

  grid::grid.newpage()

  grid::grid.text(
    title,
    x = grid::unit(
      0.03,
      "npc"
    ),
    y = grid::unit(
      0.94,
      "npc"
    ),
    just = c(
      "left",
      "center"
    ),
    gp = grid::gpar(
      col = tesla_dark,
      fontsize = 24,
      fontface = "bold"
    )
  )

  n_body_rows <-
    nrow(
      table_data
    )

  n_rows <-
    n_body_rows +
    1

  n_cols <-
    ncol(
      table_data
    )

  if (
    is.null(
      column_widths
    )
  ) {

    column_widths <-
      rep(
        1 / n_cols,
        n_cols
      )
  }

  column_widths <-
    column_widths /
    sum(
      column_widths
    )

  left <- 0.03
  right <- 0.97
  top <- 0.84
  bottom <- 0.08

  x_edges <-
    left +
    c(
      0,
      cumsum(
        column_widths
      )
    ) *
    (
      right -
      left
    )

  row_height <-
    (
      top -
      bottom
    ) /
    n_rows


  # Header row.

  for (
    column_index in seq_len(
      n_cols
    )
  ) {

    x0 <-
      x_edges[
        column_index
      ]

    x1 <-
      x_edges[
        column_index +
        1
      ]

    grid::grid.rect(
      x = grid::unit(
        (
          x0 +
          x1
        ) /
        2,
        "npc"
      ),
      y = grid::unit(
        top -
        row_height /
        2,
        "npc"
      ),
      width = grid::unit(
        x1 -
        x0,
        "npc"
      ),
      height = grid::unit(
        row_height,
        "npc"
      ),
      gp = grid::gpar(
        fill = tesla_dark,
        col = tesla_light_gray,
        lwd = 0.7
      )
    )

    grid::grid.text(
      names(
        table_data
      )[
        column_index
      ],
      x = grid::unit(
        x0 +
        0.008,
        "npc"
      ),
      y = grid::unit(
        top -
        row_height /
        2,
        "npc"
      ),
      just = c(
        "left",
        "center"
      ),
      gp = grid::gpar(
        col = tesla_white,
        fontsize = font_size,
        fontface = "bold"
      )
    )
  }


  # Body rows.

  for (
    row_index in seq_len(
      n_body_rows
    )
  ) {

    row_top <-
      top -
      row_height *
      row_index

    fill_color <-
      if (
        row_index %% 2 ==
        1
      ) {
        tesla_background
      } else {
        tesla_lighter_gray
      }

    for (
      column_index in seq_len(
        n_cols
      )
    ) {

      x0 <-
        x_edges[
          column_index
        ]

      x1 <-
        x_edges[
          column_index +
          1
        ]

      grid::grid.rect(
        x = grid::unit(
          (
            x0 +
            x1
          ) /
          2,
          "npc"
        ),
        y = grid::unit(
          row_top -
          row_height /
          2,
          "npc"
        ),
        width = grid::unit(
          x1 -
          x0,
          "npc"
        ),
        height = grid::unit(
          row_height,
          "npc"
        ),
        gp = grid::gpar(
          fill = fill_color,
          col = tesla_light_gray,
          lwd = 0.6
        )
      )

      cell_text <-
        as.character(
          table_data[
            row_index,
            column_index
          ]
        )

      wrapped_text <-
        paste(
          strwrap(
            cell_text,
            width = 34
          ),
          collapse = "\n"
        )

      grid::grid.text(
        wrapped_text,
        x = grid::unit(
          x0 +
          0.008,
          "npc"
        ),
        y = grid::unit(
          row_top -
          row_height /
          2,
          "npc"
        ),
        just = c(
          "left",
          "center"
        ),
        gp = grid::gpar(
          col = tesla_dark,
          fontsize = font_size
        )
      )
    }
  }

  dev.off()
}


# Render a horizontal cost chart.

render_horizontal_cost_chart <- function(
  labels,
  values,
  file_name,
  title,
  red_bar = NA_integer_
) {

  png(
    file.path(
      summary_png_dir,
      file_name
    ),
    width = 1600,
    height = 900,
    res = 144,
    bg = tesla_background
  )

  par(
    mar = c(
      6,
      13,
      5,
      4
    ),
    bg = tesla_background,
    fg = tesla_dark,
    col.axis = tesla_dark,
    col.lab = tesla_dark
  )

  colors <-
    rep(
      tesla_dark_gray,
      length(
        values
      )
    )

  if (
    !is.na(
      red_bar
    )
  ) {

    colors[
      red_bar
    ] <-
      tesla_red
  }

  bars <-
    barplot(
      values,
      names.arg = labels,
      horiz = TRUE,
      las = 1,
      col = colors,
      border = NA,
      xlab = "Daily on-call cost ($)",
      main = title,
      cex.names = 1.0
    )

  text(
    x = values +
      max(
        values
      ) *
      0.02,
    y = bars,
    labels = paste0(
      "$",
      format(
        values,
        big.mark = ",",
        trim = TRUE
      )
    ),
    pos = 4,
    col = tesla_dark
  )

  dev.off()
}


# -----------------------------------------------------------------------------
# 14E. SUMMARY CALCULATIONS
# -----------------------------------------------------------------------------


# ----- Scenario costs -----

baseline_cost <-
  baseline_model$objval

restricted_cost <-
  restricted_model$objval

bilingual_cost <-
  bilingual_model$objval


# ----- Scenario staffing totals -----

baseline_ft_english <-
  sum(
    baseline_solution[
      english_ft_vars
    ]
  )

baseline_ft_spanish <-
  sum(
    baseline_solution[
      spanish_ft_vars
    ]
  )

baseline_pt_english <-
  sum(
    baseline_solution[
      english_pt_vars
    ]
  )

baseline_ft_total <-
  baseline_ft_english +
  baseline_ft_spanish

baseline_total_agents <-
  baseline_ft_total +
  baseline_pt_english


restricted_ft_english <-
  sum(
    restricted_solution[
      english_ft_vars
    ]
  )

restricted_ft_spanish <-
  sum(
    restricted_solution[
      spanish_ft_vars
    ]
  )

restricted_pt_english <-
  sum(
    restricted_solution[
      english_pt_vars
    ]
  )

restricted_ft_total <-
  restricted_ft_english +
  restricted_ft_spanish

restricted_total_agents <-
  restricted_ft_total +
  restricted_pt_english


bilingual_ft_total <-
  sum(
    bilingual_solution[
      grepl(
        "^bil_ft_",
        names(
          bilingual_solution
        )
      )
    ]
  )

bilingual_pt_total <-
  sum(
    bilingual_solution[
      grepl(
        "^bil_pt_",
        names(
          bilingual_solution
        )
      )
    ]
  )

bilingual_total_agents <-
  bilingual_ft_total +
  bilingual_pt_total


# ----- Scenario savings -----

restricted_cost_increase <-
  restricted_cost -
  baseline_cost

restricted_cost_increase_pct <-
  (
    restricted_cost /
    baseline_cost -
    1
  ) *
  100


bilingual_savings <-
  baseline_cost -
  bilingual_cost

bilingual_savings_pct <-
  (
    1 -
    bilingual_cost /
    baseline_cost
  ) *
  100


bilingual_savings_vs_restricted <-
  restricted_cost -
  bilingual_cost

bilingual_savings_vs_restricted_pct <-
  (
    1 -
    bilingual_cost /
    restricted_cost
  ) *
  100


# ----- Cost per call -----

daily_calls <-
  sum(
    demand$calls_per_block
  )

baseline_cost_per_call <-
  baseline_cost /
  daily_calls

restricted_cost_per_call <-
  restricted_cost /
  daily_calls

bilingual_cost_per_call <-
  bilingual_cost /
  daily_calls


# ----- Bilingual wage premium -----

max_bilingual_premium <-
  (
    baseline_cost /
    bilingual_cost
  ) -
  1

max_bilingual_premium_pct <-
  max_bilingual_premium *
  100

premium_wage_before_5pm <-
  wage_before_5pm *
  (
    1 +
    max_bilingual_premium
  )

premium_wage_after_5pm <-
  wage_after_5pm *
  (
    1 +
    max_bilingual_premium
  )


# ----- Annualized business case -----

annual_savings_vs_baseline <-
  bilingual_savings *
  weekdays_per_year

annual_savings_vs_restricted <-
  bilingual_savings_vs_restricted *
  weekdays_per_year


# ----- Historical growth calculations -----

total_revenue_growth_pct <-
  (
    total_revenue_2018_billion /
    total_revenue_2017_billion -
    1
  ) *
  100


vehicle_delivery_growth_pct <-
  (
    vehicle_deliveries_2018 /
    vehicle_deliveries_2017 -
    1
  ) *
  100


delivery_run_rate_growth_pct <-
  (
    annualized_delivery_run_rate_end_2018 /
    annualized_delivery_run_rate_start_2018 -
    1
  ) *
  100


automotive_revenue_growth_pct <-
  (
    automotive_sales_revenue_2018_billion /
    automotive_sales_revenue_2017_billion -
    1
  ) *
  100


# -----------------------------------------------------------------------------
# 14F. ANSWER-KEY SUMMARY TABLE
# -----------------------------------------------------------------------------


answer_key_table <-
  data.frame(
    Section = c(
      "A",
      "B",
      "C",
      "D",
      "E",
      "F",
      "G",
      "H"
    ),
    `What Alex asked` = c(
      "English-/Spanish-only hires by shift",
      "English-/Spanish-only minimum cost",
      "Hires with 1 PM / 3 PM English cap",
      "Minimum cost with the cap",
      "Hires if every agent is bilingual",
      "Bilingual minimum cost",
      "Max bilingual wage premium",
      "Cost if calls grow 10-30%"
    ),
    `Our answer` = c(
      paste0(
        baseline_ft_total,
        " FT (",
        baseline_ft_english,
        " English, ",
        baseline_ft_spanish,
        " Spanish) + ",
        baseline_pt_english,
        " PT"
      ),
      paste0(
        "$",
        format(
          baseline_cost,
          big.mark = ",",
          nsmall = 2
        ),
        " per day"
      ),
      paste0(
        restricted_ft_total,
        " FT (",
        restricted_ft_english,
        " English, ",
        restricted_ft_spanish,
        " Spanish) + ",
        restricted_pt_english,
        " PT"
      ),
      paste0(
        "$",
        format(
          restricted_cost,
          big.mark = ",",
          nsmall = 2
        ),
        " (+$",
        restricted_cost_increase,
        ", +",
        round(
          restricted_cost_increase_pct,
          1
        ),
        "%)"
      ),
      paste0(
        bilingual_ft_total,
        " FT + ",
        bilingual_pt_total,
        " PT"
      ),
      paste0(
        "$",
        format(
          bilingual_cost,
          big.mark = ",",
          nsmall = 2
        ),
        " (-$",
        bilingual_savings,
        ", -",
        round(
          bilingual_savings_pct,
          1
        ),
        "%)"
      ),
      paste0(
        round(
          max_bilingual_premium_pct,
          1
        ),
        "%"
      ),
      paste0(
        "+30% calls: $",
        format(
          growth_results$minimum_cost[
            growth_results$demand_growth_pct ==
            "30%"
          ],
          big.mark = ","
        ),
        "/day"
      )
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )


render_table_png(
  answer_key_table,
  "01_answer_key_table.png",
  "Every answer at a glance",
  c(
    0.08,
    0.42,
    0.50
  ),
  9
)


# -----------------------------------------------------------------------------
# 14G. HISTORICAL FINANCIAL CONTEXT
# -----------------------------------------------------------------------------


historical_context_table <-
  data.frame(
    Metric = c(
      "Model 3 deliveries",
      "Total revenue",
      "Revenue growth",
      "Net loss",
      "Q3 profit",
      "Q4 profit"
    ),
    Value = c(
      format(
        model_3_deliveries_2018,
        big.mark = ",",
        scientific = FALSE
      ),
      paste0(
        "$",
        total_revenue_2018_billion,
        "B"
      ),
      paste0(
        round(
          total_revenue_growth_pct
        ),
        "%"
      ),
      paste0(
        "-$",
        abs(
          net_loss_2018_million
        ),
        "M"
      ),
      paste0(
        "$",
        q3_profit_2018_million,
        "M"
      ),
      paste0(
        "$",
        q4_profit_2018_million,
        "M"
      )
    ),
    Context = c(
      "2018",
      "2018",
      "vs. 2017",
      "2018",
      "2018 Q3",
      "2018 Q4"
    ),
    stringsAsFactors = FALSE
  )


render_table_png(
  historical_context_table,
  "02_2018_financial_context.png",
  "Tesla in 2018: financial context",
  c(
    0.45,
    0.25,
    0.30
  ),
  12
)


# -----------------------------------------------------------------------------
# 14H. DEMAND PROFILE
# -----------------------------------------------------------------------------


english_calls_per_hour <-
  demand$english_calls_per_hour

spanish_calls_per_hour <-
  demand$spanish_calls_per_hour

total_calls_per_hour <-
  demand$calls_per_hour


png(
  file.path(
    summary_png_dir,
    "03_demand_profile.png"
  ),
  width = 1600,
  height = 900,
  res = 144,
  bg = tesla_background
)

par(
  mar = c(
    7,
    6,
    5,
    3
  ),
  bg = tesla_background,
  col.axis = tesla_dark,
  col.lab = tesla_dark
)

demand_positions <-
  barplot(
    rbind(
      english_calls_per_hour,
      spanish_calls_per_hour
    ),
    beside = FALSE,
    col = c(
      tesla_dark_gray,
      tesla_red
    ),
    border = NA,
    names.arg = demand$time_block,
    ylab = "Average calls per hour",
    main = "Calls peak at 1-3 PM and fade after 5 PM",
    ylim = c(
      0,
      max(
        total_calls_per_hour
      ) *
      1.18
    )
  )

text(
  demand_positions,
  total_calls_per_hour +
  3,
  labels = total_calls_per_hour,
  col = tesla_dark,
  font = 2
)

legend(
  "topright",
  legend = c(
    "English - 80%",
    "Spanish - 20%"
  ),
  fill = c(
    tesla_dark_gray,
    tesla_red
  ),
  border = NA,
  bty = "n"
)

dev.off()


# -----------------------------------------------------------------------------
# 14I. OPERATING-RULE TABLE
# -----------------------------------------------------------------------------


operating_rules_table <-
  data.frame(
    `Hire option` = c(
      "FT start 7 AM",
      "FT start 9 AM",
      "FT start 11 AM",
      "FT start 1 PM",
      "FT start 3 PM",
      "PT start 3 PM",
      "PT start 5 PM"
    ),
    `7-9` = c(
      "CALL",
      "",
      "",
      "",
      "",
      "",
      ""
    ),
    `9-11` = c(
      "off",
      "CALL",
      "",
      "",
      "",
      "",
      ""
    ),
    `11-1` = c(
      "CALL",
      "off",
      "CALL",
      "",
      "",
      "",
      ""
    ),
    `1-3` = c(
      "off",
      "CALL",
      "off",
      "CALL",
      "",
      "",
      ""
    ),
    `3-5` = c(
      "",
      "off",
      "CALL",
      "off",
      "CALL",
      "CALL",
      ""
    ),
    `5-7` = c(
      "",
      "",
      "off",
      "CALL",
      "off",
      "CALL",
      "CALL"
    ),
    `7-9` = c(
      "",
      "",
      "",
      "off",
      "CALL",
      "",
      "CALL"
    ),
    Cost = paste0(
      "$",
      cost_per_option
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )


render_table_png(
  operating_rules_table,
  "04_operating_rules_table.png",
  "Each hire covers a fixed set of blocks",
  c(
    0.18,
    rep(
      0.09,
      7
    ),
    0.09
  ),
  9
)


# -----------------------------------------------------------------------------
# 14J. MODEL-SYMBOL TABLES
# -----------------------------------------------------------------------------


objective_symbols_table <-
  data.frame(
    Symbol = c(
      "Z",
      "T",
      "K",
      "E, S",
      "P",
      "c"
    ),
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
      "7, 9, 11 AM · 1, 3 PM",
      "3, 5 PM",
      "Agents hired (whole numbers)",
      "Agents hired (whole numbers)",
      "$120 at 7, 9, 11 · $150 at 1, 3 · $180 at 5"
    ),
    stringsAsFactors = FALSE
  )


render_table_png(
  objective_symbols_table,
  "05_objective_symbols_table.png",
  "Objective function symbols",
  c(
    0.12,
    0.46,
    0.42
  ),
  11
)


constraint_symbols_table <-
  data.frame(
    Symbol = c(
      "r",
      "d",
      "s",
      "A(t)",
      "x"
    ),
    Meaning = c(
      "Calls one agent handles per 2-hour block",
      "Calls in block t",
      "Language share of calls",
      "Hires on calls during block t",
      "Agents hired: E, S, P or B"
    ),
    Values = c(
      agent_capacity_per_block,
      paste(
        demand$calls_per_block,
        collapse = ", "
      ),
      "English 0.8 · Spanish 0.2 · Bilingual 1.0",
      "Defined by the coverage matrix",
      "Whole numbers >= 0"
    ),
    stringsAsFactors = FALSE
  )


render_table_png(
  constraint_symbols_table,
  "06_constraint_symbols_table.png",
  "Constraint symbols",
  c(
    0.12,
    0.48,
    0.40
  ),
  11
)


# -----------------------------------------------------------------------------
# 14K. STAFFING TABLES
# -----------------------------------------------------------------------------


staffing_start_labels <-
  c(
    "7 AM",
    "9 AM",
    "11 AM",
    "1 PM",
    "3 PM",
    "5 PM"
  )


staffing_option_names <-
  c(
    "7am",
    "9am",
    "11am",
    "1pm",
    "3pm"
  )


baseline_staffing_table <-
  data.frame(
    Start = staffing_start_labels,
    `FT English` = c(
      sapply(
        staffing_option_names,
        function(start_name) {
          solution_value(
            baseline_solution,
            paste0(
              "eng_ft_",
              start_name
            )
          )
        }
      ),
      "–"
    ),
    `FT Spanish` = c(
      sapply(
        staffing_option_names,
        function(start_name) {
          solution_value(
            baseline_solution,
            paste0(
              "spa_ft_",
              start_name
            )
          )
        }
      ),
      "–"
    ),
    `PT English` = c(
      "–",
      "–",
      "–",
      "–",
      solution_value(
        baseline_solution,
        "eng_pt_3pm"
      ),
      solution_value(
        baseline_solution,
        "eng_pt_5pm"
      )
    ),
    `On calls` = c(
      "7-9, 11-1",
      "9-11, 1-3",
      "11-1, 3-5",
      "1-3, 5-7",
      "FT 3-5, 7-9; PT 3-7",
      "PT 5-9"
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )


baseline_staffing_table <-
  rbind(
    baseline_staffing_table,
    data.frame(
      Start = "Total",
      `FT English` = baseline_ft_english,
      `FT Spanish` = baseline_ft_spanish,
      `PT English` = baseline_pt_english,
      `On calls` = paste0(
        baseline_total_agents,
        " hires"
      ),
      check.names = FALSE
    )
  )


render_table_png(
  baseline_staffing_table,
  "07_baseline_staffing_table.png",
  "Scenario I: optimal staffing",
  c(
    0.12,
    0.14,
    0.14,
    0.14,
    0.46
  ),
  11
)


restricted_staffing_table <-
  data.frame(
    Start = staffing_start_labels,
    `FT English` = c(
      sapply(
        staffing_option_names,
        function(start_name) {
          solution_value(
            restricted_solution,
            paste0(
              "eng_ft_",
              start_name
            )
          )
        }
      ),
      "–"
    ),
    `FT Spanish` = c(
      sapply(
        staffing_option_names,
        function(start_name) {
          solution_value(
            restricted_solution,
            paste0(
              "spa_ft_",
              start_name
            )
          )
        }
      ),
      "–"
    ),
    `PT English` = c(
      "–",
      "–",
      "–",
      "–",
      solution_value(
        restricted_solution,
        "eng_pt_3pm"
      ),
      solution_value(
        restricted_solution,
        "eng_pt_5pm"
      )
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )


restricted_staffing_table <-
  rbind(
    restricted_staffing_table,
    data.frame(
      Start = "Total",
      `FT English` = restricted_ft_english,
      `FT Spanish` = restricted_ft_spanish,
      `PT English` = restricted_pt_english,
      check.names = FALSE
    )
  )


render_table_png(
  restricted_staffing_table,
  "09_restricted_staffing_table.png",
  "Scenario II: restricted-start staffing",
  c(
    0.18,
    0.20,
    0.20,
    0.20
  ),
  11
)


bilingual_staffing_table <-
  data.frame(
    Start = staffing_start_labels,
    `FT bilingual` = c(
      sapply(
        staffing_option_names,
        function(start_name) {
          solution_value(
            bilingual_solution,
            paste0(
              "bil_ft_",
              start_name
            )
          )
        }
      ),
      "–"
    ),
    `PT bilingual` = c(
      "–",
      "–",
      "–",
      "–",
      solution_value(
        bilingual_solution,
        "bil_pt_3pm"
      ),
      solution_value(
        bilingual_solution,
        "bil_pt_5pm"
      )
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )


bilingual_staffing_table <-
  rbind(
    bilingual_staffing_table,
    data.frame(
      Start = "Total",
      `FT bilingual` = bilingual_ft_total,
      `PT bilingual` = bilingual_pt_total,
      check.names = FALSE
    )
  )


render_table_png(
  bilingual_staffing_table,
  "11_bilingual_staffing_table.png",
  "Scenario III: bilingual staffing",
  c(
    0.30,
    0.35,
    0.35
  ),
  11
)


# -----------------------------------------------------------------------------
# 14L. COST BREAKDOWNS
# -----------------------------------------------------------------------------


baseline_english_cost <-
  sum(
    baseline_solution[
      english_ft_vars
    ] *
    baseline_costs[
      english_ft_vars
    ]
  )

baseline_spanish_cost <-
  sum(
    baseline_solution[
      spanish_ft_vars
    ] *
    baseline_costs[
      spanish_ft_vars
    ]
  )

baseline_part_time_cost <-
  sum(
    baseline_solution[
      english_pt_vars
    ] *
    baseline_costs[
      english_pt_vars
    ]
  )


restricted_english_cost <-
  sum(
    restricted_solution[
      english_ft_vars
    ] *
    baseline_costs[
      english_ft_vars
    ]
  )

restricted_spanish_cost <-
  sum(
    restricted_solution[
      spanish_ft_vars
    ] *
    baseline_costs[
      spanish_ft_vars
    ]
  )

restricted_part_time_cost <-
  sum(
    restricted_solution[
      english_pt_vars
    ] *
    baseline_costs[
      english_pt_vars
    ]
  )


render_horizontal_cost_chart(
  c(
    "English full-time",
    "Spanish full-time",
    "English part-time"
  ),
  c(
    baseline_english_cost,
    baseline_spanish_cost,
    baseline_part_time_cost
  ),
  "08_baseline_cost_breakdown.png",
  "Scenario I: where the money goes",
  2
)


render_horizontal_cost_chart(
  c(
    "English full-time",
    "Spanish full-time",
    "English part-time"
  ),
  c(
    restricted_english_cost,
    restricted_spanish_cost,
    restricted_part_time_cost
  ),
  "10_restricted_cost_breakdown.png",
  "Scenario II: where the money goes",
  2
)


render_horizontal_cost_chart(
  c(
    "II - English start limit",
    "I - English + Spanish",
    "III - Bilingual"
  ),
  c(
    restricted_cost,
    baseline_cost,
    bilingual_cost
  ),
  "12_scenario_cost_comparison.png",
  "Daily cost by scenario",
  3
)


# -----------------------------------------------------------------------------
# 14M. CAPACITY POOLING
# -----------------------------------------------------------------------------


baseline_ft_counts <-
  baseline_solution[
    english_ft_vars
  ] +
  baseline_solution[
    spanish_ft_vars
  ]

baseline_pt_counts <-
  baseline_solution[
    english_pt_vars
  ]

baseline_total_counts <-
  c(
    baseline_ft_counts,
    baseline_pt_counts
  )

names(
  baseline_total_counts
) <-
  rownames(
    coverage_matrix
  )


restricted_ft_counts <-
  restricted_solution[
    english_ft_vars
  ] +
  restricted_solution[
    spanish_ft_vars
  ]

restricted_pt_counts <-
  restricted_solution[
    english_pt_vars
  ]

restricted_total_counts <-
  c(
    restricted_ft_counts,
    restricted_pt_counts
  )

names(
  restricted_total_counts
) <-
  rownames(
    coverage_matrix
  )


bilingual_total_counts <-
  bilingual_solution

names(
  bilingual_total_counts
) <-
  sub(
    "^bil_",
    "",
    names(
      bilingual_total_counts
    )
  )


baseline_capacity <-
  as.numeric(
    baseline_total_counts[
      rownames(
        coverage_matrix
      )
    ] %*%
    coverage_matrix
  ) *
  agent_capacity_per_block


restricted_capacity <-
  as.numeric(
    restricted_total_counts[
      rownames(
        coverage_matrix
      )
    ] %*%
    coverage_matrix
  ) *
  agent_capacity_per_block


bilingual_capacity <-
  as.numeric(
    bilingual_total_counts[
      rownames(
        coverage_matrix
      )
    ] %*%
    coverage_matrix
  ) *
  agent_capacity_per_block


daily_baseline_capacity <-
  sum(
    baseline_capacity
  )

daily_restricted_capacity <-
  sum(
    restricted_capacity
  )

daily_bilingual_capacity <-
  sum(
    bilingual_capacity
  )


baseline_idle_capacity <-
  daily_baseline_capacity -
  daily_calls

restricted_idle_capacity <-
  daily_restricted_capacity -
  daily_calls

bilingual_idle_capacity <-
  daily_bilingual_capacity -
  daily_calls


idle_agent_hours_removed <-
  (
    baseline_idle_capacity -
    bilingual_idle_capacity
  ) /
  calls_per_agent_hour


png(
  file.path(
    summary_png_dir,
    "13_capacity_pooling.png"
  ),
  width = 1600,
  height = 900,
  res = 144,
  bg = tesla_background
)

par(
  mar = c(
    7,
    6,
    5,
    3
  ),
  bg = tesla_background,
  col.axis = tesla_dark,
  col.lab = tesla_dark
)

barplot(
  rbind(
    demand$calls_per_block,
    baseline_capacity,
    bilingual_capacity
  ),
  beside = TRUE,
  col = c(
    tesla_mid_gray,
    tesla_dark_gray,
    tesla_red
  ),
  border = NA,
  names.arg = demand$time_block,
  ylab = "Calls per 2-hour block",
  main = "Pooling removes the idle cushion"
)

legend(
  "topright",
  legend = c(
    "Calls (demand)",
    "English-/Spanish-only capacity",
    "Bilingual capacity"
  ),
  fill = c(
    tesla_mid_gray,
    tesla_dark_gray,
    tesla_red
  ),
  border = NA,
  bty = "n"
)

dev.off()


# -----------------------------------------------------------------------------
# 12N. BILINGUAL WAGE-PREMIUM CHART
# -----------------------------------------------------------------------------


premium_grid <-
  seq(
    0,
    0.12,
    by = 0.0025
  )

premium_costs <-
  bilingual_cost *
  (
    1 +
    premium_grid
  )


png(
  file.path(
    summary_png_dir,
    "14_bilingual_wage_premium.png"
  ),
  width = 1600,
  height = 900,
  res = 144,
  bg = tesla_background
)

par(
  mar = c(
    7,
    7,
    5,
    3
  ),
  bg = tesla_background,
  col.axis = tesla_dark,
  col.lab = tesla_dark
)

plot(
  premium_grid *
  100,
  premium_costs,
  type = "l",
  lwd = 3,
  col = tesla_red,
  xlab = "Uniform bilingual wage premium (%)",
  ylab = "Daily on-call cost ($)",
  main = "We can pay bilingual agents up to 9% more"
)

abline(
  h = baseline_cost,
  col = tesla_dark,
  lty = 2
)

abline(
  h = restricted_cost,
  col = tesla_mid_gray,
  lty = 2
)

abline(
  v = max_bilingual_premium_pct,
  col = tesla_light_gray,
  lty = 3
)

points(
  max_bilingual_premium_pct,
  baseline_cost,
  pch = 19,
  cex = 1.5,
  col = tesla_red
)

dev.off()


# -----------------------------------------------------------------------------
# 14O. BUSINESS-CASE TABLE
# -----------------------------------------------------------------------------


business_case_table <-
  data.frame(
    Metric = c(
      "Annual savings vs. baseline",
      "Annual savings vs. restricted",
      "Bilingual cost per call",
      "Idle agent time removed"
    ),
    Value = c(
      paste0(
        "$",
        round(
          annual_savings_vs_baseline /
          1000
        ),
        "K"
      ),
      paste0(
        "$",
        round(
          annual_savings_vs_restricted /
          1000
        ),
        "K"
      ),
      paste0(
        "$",
        format(
          round(
            bilingual_cost_per_call,
            2
          ),
          nsmall = 2
        )
      ),
      paste0(
        round(
          idle_agent_hours_removed,
          1
        ),
        " hrs"
      )
    ),
    Calculation = c(
      paste0(
        "$",
        bilingual_savings,
        " x ",
        weekdays_per_year,
        " weekdays"
      ),
      paste0(
        "$",
        bilingual_savings_vs_restricted,
        " x ",
        weekdays_per_year,
        " weekdays"
      ),
      paste0(
        "$",
        format(
          bilingual_cost,
          big.mark = ","
        ),
        " / ",
        daily_calls,
        " calls"
      ),
      paste0(
        "(",
        baseline_idle_capacity,
        " - ",
        bilingual_idle_capacity,
        " calls) / ",
        calls_per_agent_hour,
        " calls/hr"
      )
    ),
    stringsAsFactors = FALSE
  )


render_table_png(
  business_case_table,
  "15_business_case_metrics.png",
  "What bilingual staffing is worth in a year",
  c(
    0.40,
    0.20,
    0.40
  ),
  12
)


# -----------------------------------------------------------------------------
# 14P. SCALE-CONTEXT TABLE
# -----------------------------------------------------------------------------


scale_context_table <-
  data.frame(
    Metric = c(
      "Vehicle deliveries",
      "Annualized delivery run rate",
      "Automotive sales revenue"
    ),
    `2017 / early 2018` = c(
      format(
        vehicle_deliveries_2017,
        big.mark = ",",
        scientific = FALSE
      ),
      paste0(
        "~",
        format(
          annualized_delivery_run_rate_start_2018,
          big.mark = ",",
          scientific = FALSE
        )
      ),
      paste0(
        "$",
        automotive_sales_revenue_2017_billion,
        "B"
      )
    ),
    `2018 / year-end` = c(
      format(
        vehicle_deliveries_2018,
        big.mark = ",",
        scientific = FALSE
      ),
      paste0(
        format(
          annualized_delivery_run_rate_end_2018,
          big.mark = ",",
          scientific = FALSE
        ),
        "+"
      ),
      paste0(
        "$",
        automotive_sales_revenue_2018_billion,
        "B"
      )
    ),
    Growth = c(
      paste0(
        "+",
        round(
          vehicle_delivery_growth_pct
        ),
        "%"
      ),
      paste0(
        ">+",
        round(
          delivery_run_rate_growth_pct
        ),
        "%"
      ),
      paste0(
        "+",
        round(
          automotive_revenue_growth_pct
        ),
        "%"
      )
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )


render_table_png(
  scale_context_table,
  "16_scale_context.png",
  "The next constraint: scale",
  c(
    0.38,
    0.22,
    0.22,
    0.18
  ),
  12
)


# -----------------------------------------------------------------------------
# 14Q. DEMAND-GROWTH SENSITIVITY
# -----------------------------------------------------------------------------


growth_calls <-
  round(
    daily_calls *
    (
      1 +
      as.numeric(
        sub(
          "%",
          "",
          growth_results$demand_growth_pct,
          fixed = TRUE
        )
      ) /
      100
    )
  )


growth_total_agents <-
  growth_results$full_time_agents +
  growth_results$part_time_agents


growth_cost_per_call <-
  growth_results$minimum_cost /
  growth_calls


png(
  file.path(
    summary_png_dir,
    "17_growth_sensitivity.png"
  ),
  width = 1600,
  height = 900,
  res = 144,
  bg = tesla_background
)

par(
  mar = c(
    7,
    6,
    5,
    3
  ),
  bg = tesla_background,
  col.axis = tesla_dark,
  col.lab = tesla_dark
)

growth_colors <-
  c(
    tesla_red,
    rep(
      tesla_dark_gray,
      nrow(
        growth_results
      ) -
      1
    )
  )


growth_positions <-
  barplot(
    growth_results$minimum_cost,
    names.arg = growth_results$demand_growth_pct,
    col = growth_colors,
    border = NA,
    ylab = "Daily on-call cost ($)",
    main = "If calls grow 30%, cost grows about 25%",
    ylim = c(
      0,
      max(
        growth_results$minimum_cost
      ) *
      1.20
    )
  )


text(
  growth_positions,
  growth_results$minimum_cost +
  150,
  labels = paste0(
    "$",
    format(
      growth_results$minimum_cost,
      big.mark = ","
    ),
    "\n",
    growth_total_agents,
    " hires"
  ),
  col = tesla_dark
)

dev.off()


growth_sensitivity_table <-
  data.frame(
    Growth = growth_results$demand_growth_pct,
    `Calls/day` = format(
      growth_calls,
      big.mark = ",",
      scientific = FALSE
    ),
    `FT + PT` = paste0(
      growth_results$full_time_agents,
      " + ",
      growth_results$part_time_agents
    ),
    `Daily cost` = paste0(
      "$",
      format(
        growth_results$minimum_cost,
        big.mark = ",",
        scientific = FALSE
      )
    ),
    `Per call` = paste0(
      "$",
      format(
        round(
          growth_cost_per_call,
          2
        ),
        nsmall = 2
      )
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )


render_table_png(
  growth_sensitivity_table,
  "18_growth_sensitivity_table.png",
  "Demand-growth sensitivity output",
  c(
    0.17,
    0.18,
    0.18,
    0.23,
    0.24
  ),
  12
)


# -----------------------------------------------------------------------------
# 14R. ILLUSTRATIVE EFFICIENCY LEVERS
# -----------------------------------------------------------------------------


capacity_increase_pct <-
  (
    improved_calls_per_agent_hour /
    calls_per_agent_hour -
    1
  ) *
  100


efficiency_levers_table <-
  data.frame(
    `Illustrative lever` = c(
      "Avoid calls in one 2-hour block",
      "Raise handling rate"
    ),
    Change = c(
      paste0(
        agent_capacity_per_block,
        " calls"
      ),
      paste0(
        calls_per_agent_hour,
        " -> ",
        improved_calls_per_agent_hour,
        " calls/hour"
      )
    ),
    `Model implication` = c(
      "Approximately 1 active agent-block",
      paste0(
        "+",
        round(
          capacity_increase_pct,
          1
        ),
        "% capacity with the same team"
      )
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )


render_table_png(
  efficiency_levers_table,
  "19_efficiency_levers.png",
  "Illustrative levers beyond the optimization",
  c(
    0.42,
    0.22,
    0.36
  ),
  12
)


# -----------------------------------------------------------------------------
# 12S. CONSOLE OUTPUT
# -----------------------------------------------------------------------------


summary_console_path <-
  file.path(
    summary_output_dir,
    "summary_console_output.txt"
  )


sink(
  summary_console_path,
  split = TRUE
)


cat("\n============================================================\n")
cat("14. SUMMARY OUTPUT\n")
cat("============================================================\n\n")


cat("SCENARIO SUMMARY\n")
cat("----------------\n")

cat(
  "Baseline:         ",
  baseline_total_agents,
  " agents | $",
  baseline_cost,
  "/day | $",
  round(
    baseline_cost_per_call,
    2
  ),
  "/call\n",
  sep = ""
)

cat(
  "Restricted:       ",
  restricted_total_agents,
  " agents | $",
  restricted_cost,
  "/day | $",
  round(
    restricted_cost_per_call,
    2
  ),
  "/call\n",
  sep = ""
)

cat(
  "Bilingual:        ",
  bilingual_total_agents,
  " agents | $",
  bilingual_cost,
  "/day | $",
  round(
    bilingual_cost_per_call,
    2
  ),
  "/call\n\n",
  sep = ""
)


cat("BILINGUAL VALUE\n")
cat("---------------\n")

cat(
  "Daily savings vs. baseline:      $",
  bilingual_savings,
  "\n",
  sep = ""
)

cat(
  "Percent savings vs. baseline:    ",
  round(
    bilingual_savings_pct,
    1
  ),
  "%\n",
  sep = ""
)

cat(
  "Annual savings vs. baseline:     $",
  format(
    annual_savings_vs_baseline,
    big.mark = ","
  ),
  "\n",
  sep = ""
)

cat(
  "Annual savings vs. restricted:   $",
  format(
    annual_savings_vs_restricted,
    big.mark = ","
  ),
  "\n",
  sep = ""
)

cat(
  "Break-even bilingual premium:    ",
  round(
    max_bilingual_premium_pct,
    1
  ),
  "%\n",
  sep = ""
)

cat(
  "Pay cap before 5 PM:             $",
  round(
    premium_wage_before_5pm,
    2
  ),
  "\n",
  sep = ""
)

cat(
  "Pay cap after 5 PM:              $",
  round(
    premium_wage_after_5pm,
    2
  ),
  "\n\n",
  sep = ""
)


cat("CAPACITY / POOLING\n")
cat("------------------\n")

cat(
  "Daily demand:                    ",
  daily_calls,
  " calls\n",
  sep = ""
)

cat(
  "Baseline call capacity:          ",
  daily_baseline_capacity,
  "\n",
  sep = ""
)

cat(
  "Restricted call capacity:        ",
  daily_restricted_capacity,
  "\n",
  sep = ""
)

cat(
  "Bilingual call capacity:         ",
  daily_bilingual_capacity,
  "\n",
  sep = ""
)

cat(
  "Baseline idle call capacity:     ",
  baseline_idle_capacity,
  "\n",
  sep = ""
)

cat(
  "Bilingual idle call capacity:    ",
  bilingual_idle_capacity,
  "\n",
  sep = ""
)

cat(
  "Idle agent time removed:         ",
  round(
    idle_agent_hours_removed,
    1
  ),
  " hours/day\n\n",
  sep = ""
)


cat("2018 SCALE CONTEXT\n")
cat("------------------\n")

cat(
  "Vehicle-delivery growth:         +",
  round(
    vehicle_delivery_growth_pct,
    1
  ),
  "%\n",
  sep = ""
)

cat(
  "Delivery run-rate growth:        +",
  round(
    delivery_run_rate_growth_pct,
    1
  ),
  "%\n",
  sep = ""
)

cat(
  "Automotive revenue growth:       +",
  round(
    automotive_revenue_growth_pct,
    1
  ),
  "%\n\n",
  sep = ""
)


cat("DEMAND-GROWTH SENSITIVITY\n")
cat("-------------------------\n")

print(
  growth_sensitivity_table,
  row.names = FALSE
)

cat("\n")


growth_30_cost_change_pct <-
  (
    growth_results$minimum_cost[
      growth_results$demand_growth_pct ==
      "30%"
    ] /
    baseline_cost -
    1
  ) *
  100


cat(
  "+30% calls -> cost change:        +",
  round(
    growth_30_cost_change_pct,
    1
  ),
  "%\n",
  sep = ""
)

cat(
  "6 -> 7 calls/hour capacity gain: +",
  round(
    capacity_increase_pct,
    1
  ),
  "%\n\n",
  sep = ""
)

# -----------------------------------------------------------------------------
# 12T. OPTIONAL UTILIZATION SENSITIVITY - NOT PART OF THE OPTIMIZATION
# -----------------------------------------------------------------------------
# Professor feedback: retain minimum staffing cost as the main answer.
# This is a post-solution comparison, not a new objective or constraint.
# Add one English FT agent starting at 9 AM to the returned baseline schedule.
# The existing rotation covers calls at 9-11 AM and 1-3 PM only.
# Utilization = English forecast calls / English theoretical call capacity.
# It does not predict waiting times or guarantee a service level. The roughly
# 80% utilization discussion is context only, not an imposed threshold.
# Alternative optimal schedules can produce different utilization percentages.

util_sensitivity_solution <- baseline_solution
util_sensitivity_solution["eng_ft_9am"] <-
  util_sensitivity_solution["eng_ft_9am"] + 1

# Select English FT and PT only; do not pool Spanish capacity into this measure.
util_english_vars <- c(english_ft_vars, english_pt_vars)
util_english_patterns <- sub("^eng_", "", util_english_vars)
util_coverage <- coverage_matrix[util_english_patterns, , drop = FALSE]

util_baseline_capacity <- as.numeric(
  baseline_solution[util_english_vars] %*% util_coverage
) * agent_capacity_per_block
util_sensitivity_capacity <- as.numeric(
  util_sensitivity_solution[util_english_vars] %*% util_coverage
) * agent_capacity_per_block

# Positive capacity is required to report meaningful utilization percentages.
stopifnot(
  all(is.finite(util_baseline_capacity)),
  all(util_baseline_capacity > 0),
  all(is.finite(util_sensitivity_capacity)),
  all(util_sensitivity_capacity > 0)
)

util_sensitivity_table <- data.frame(
  time_block = demand$time_block,
  english_calls = demand$english_calls_per_block,
  baseline_capacity = util_baseline_capacity,
  plus_one_capacity = util_sensitivity_capacity,
  baseline_utilization_pct =
    100 * demand$english_calls_per_block / util_baseline_capacity,
  plus_one_utilization_pct =
    100 * demand$english_calls_per_block / util_sensitivity_capacity
)
util_sensitivity_table$reduction_percentage_points <-
  util_sensitivity_table$baseline_utilization_pct -
  util_sensitivity_table$plus_one_utilization_pct

util_baseline_daily_cost <- sum(
  baseline_solution * baseline_costs[names(baseline_solution)]
)
util_sensitivity_daily_cost <- sum(
  util_sensitivity_solution * baseline_costs[names(util_sensitivity_solution)]
)
util_incremental_daily_cost <-
  util_sensitivity_daily_cost - util_baseline_daily_cost

# Validate the change against the existing shift coverage and wage definitions.
stopifnot(
  isTRUE(all.equal(
    util_sensitivity_capacity - util_baseline_capacity,
    as.numeric(coverage_matrix["ft_9am", ]) * agent_capacity_per_block
  )),
  isTRUE(all.equal(
    util_incremental_daily_cost,
    unname(baseline_costs["eng_ft_9am"])
  )),
  all(util_sensitivity_table$reduction_percentage_points >= -1e-8)
)

cat("\nOPTIONAL UTILIZATION SENSITIVITY - NOT PART OF THE OPTIMIZATION\n")
cat("Baseline plus one English full-time agent starting at 9 AM.\n")
print(util_sensitivity_table, row.names = FALSE, digits = 4)
cat(sprintf(
  "\nBaseline cost: $%.2f/day; optional scenario: $%.2f/day; increase: $%.2f/day.\n",
  util_baseline_daily_cost, util_sensitivity_daily_cost,
  util_incremental_daily_cost
))
cat("Utilization is theoretical; this comparison does not predict waiting times\n")
cat("or guarantee an 80% service buffer. The minimum-cost answer is unchanged.\n")

write.csv(
  util_sensitivity_table,
  file.path(summary_output_dir, "optional_english_utilization_sensitivity.csv"),
  row.names = FALSE
)
