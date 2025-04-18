#!/bin/bash

set -eu -o pipefail

# Check if two arguments are provided (paths to past.json and current.json)
if [ $# -ne 2 ]; then
    echo "Usage: $0 <path_to_past.json> <path_to_current.json>"
    exit 1
fi

# Extract the file paths from command-line arguments
past_json_path="$1"
current_json_path="$2"

# Read the contents of past.json and current.json into variables
past_data=$(cat "$past_json_path")
current_data=$(cat "$current_json_path")

# Function to compare P90 values for a given statistic
compare_stat_p90() {
    local past_value="$1"
    local current_value="$2"
    local stat_name="$3"

    # Calculate 110% of the past value
    local threshold=$(calculate_threshold "$past_value")

    # Compare the current value with the threshold
    if (( $(awk 'BEGIN {print ("'"$current_value"'" > "'"$threshold"'")}') )); then
        echo "ERROR: $stat_name - Current P90 value ($current_value) exceeds the 110% threshold ($threshold) of the past P90 value ($past_value)"
        return 1
    fi

    return 0
}

calculate_threshold() {
    local past_value="$1"
    awk -v past="$past_value" 'BEGIN { print past * 1.1 }'
}

# Loop through each object in past.json and compare P90 values with current.json for all statistics
compare_p90_values() {
    local past_json="$1"
    local current_json="$2"

    local test_names=$(echo "$past_json" | jq -r '.benchmarkTests[].testName')

    # Use a flag to indicate if any regression has been detected
    local regression_detected=0

    for test_name in $test_names; do
        echo "Checking for regression in '$test_name'"
        for stat_name in "fullRunStats" "pullStats" "lazyTaskStats" "localTaskStats"; do
            local past_p90=$(echo "$past_json" | jq -r --arg test "$test_name" '.benchmarkTests[] | select(.testName == $test) | .'"$stat_name"'.pct90')
            local current_p90=$(echo "$current_json" | jq -r --arg test "$test_name" '.benchmarkTests[] | select(.testName == $test) | .'"$stat_name"'.pct90')

            # Call the compare_stat_p90 function
            compare_stat_p90 "$past_p90" "$current_p90" "$stat_name" || regression_detected=1
        done
    done

    # Check if any regression has been detected and return the appropriate exit code
    return $regression_detected
}

# ... (remaining code)

# Call compare_p90_values and store the exit code in a variable
compare_p90_values "$past_data" "$current_data"
exit_code=$?

# Check the return status and display appropriate message
if [ $exit_code -eq 0 ]; then
    echo "Comparison successful. No regressions detected, all P90 values are within the acceptable range."
else
    echo "Comparison failed. Regression detected."
fi

# Set the final exit code to indicate if any regression occurred
exit $exit_code
