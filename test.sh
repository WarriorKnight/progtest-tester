#!/bin/bash

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

PROGRAM_TESTED="code.c" # Default value of the program to be tested
TEST_DATA_FOLDER="testData" # Default value of the test data folder

OUTPUT_DIRECTORY="$TEST_DATA_FOLDER/actual_outputs"
PROGRAM_DIRECTORY=""
COMPILE_FLAGS=""
ERRORS_ON_COMPILE=0
WARNINGS_ON_COMPILE=0

# Check for the --strict flag
for arg in "$@"; do
    if [ "$arg" == "--strict" ]; then
        COMPILE_FLAGS="-Wall -Wextra -pedantic"
        echo Strict mode enabled
        break
    fi
done

beginTest () {
    COMPILE_LOG="$2/compile_errors.log"
    g++ -o "./$PROGRAM_DIRECTORY$(basename "$1" .c).out" "$1" $COMPILE_FLAGS 2> "$COMPILE_LOG"
    # Check if g++ failed (non-zero exit status)

    # Check if there were any errors or warnings
    if grep -q "error:" "$COMPILE_LOG"; then
        ERRORS_ON_COMPILE=1
        echo -e "${RED}Errors detected during compilation. Stopping tests.${NC}"
        cat "$COMPILE_LOG"
        exit 1
    elif grep -q "warning:" "$COMPILE_LOG"; then
        WARNINGS_ON_COMPILE=1
        PROGRAM="$(basename "$1" .c)"
        echo -e "${YELLOW}Compiler finished with warnings: $PROGRAM"
    else
        PROGRAM="$(basename "$1" .c)"
        echo "Compiler finished: $PROGRAM"
    fi

    PROGRAM_STRIPPED="$PROGRAM_DIRECTORY$(basename "$1" .c).out"

    mkdir -p "./$OUTPUT_DIRECTORY"

    # Loop through all input files matching the pattern *_in.txt
    for input_file in "$2"/*_in.txt; do
        # Check if there are no matching input files
        if [ ! -e "$input_file" ]; then
            echo -e "${RED}No input files found matching the pattern *_in.txt${NC}"
            exit 1
        fi

        base_name=$(basename "$input_file" _in.txt)

        expected_output_file="$2/${base_name}_out.txt"
        actual_output_file="$OUTPUT_DIRECTORY/${base_name}_actual_out.txt"
        diff_output_file="$OUTPUT_DIRECTORY/${base_name}_diff_out.txt"

        # Run the program and capture the output along with measuring the time taken
        start_time=$(date +%s.%N)
        ./"$PROGRAM_STRIPPED" < "$input_file" > "$actual_output_file"
        end_time=$(date +%s.%N)

        # Calculate elapsed time
        runtime=$(echo "$end_time - $start_time" | bc)
        runtime_ms=$(echo "$runtime * 1000" | bc)

        # Compare the actual output with the expected output
        if diff "$actual_output_file" "$expected_output_file" > /dev/null; then
            echo -e "${GREEN}$base_name: Passed (Runtime: ${runtime_ms} ms)${NC}"
        else
            echo -e "${RED}$base_name: Failed${NC}"
            diff "$actual_output_file" "$expected_output_file" > "$diff_output_file"
        fi
    done
} 

# Check if the first argument is a .c file and if there is a second argument which is a directory
if [[ "$1" == *.c && -n "$2" && -d "$2" ]]; then #If true, then the first argument is a .c file and the second argument is a directory
    PROGRAM_TESTED="$1"
    TEST_DATA_FOLDER="$2"
    OUTPUT_DIRECTORY="$TEST_DATA_FOLDER/actual_outputs"
    beginTest "$PROGRAM_TESTED" "$TEST_DATA_FOLDER"
# Check if the first argument is a .c file or a directory
elif [[ "$1" == *.c ]]; then #If true, then the first argument is a .c file
    PROGRAM_TESTED="$1"
    beginTest "$PROGRAM_TESTED" "$TEST_DATA_FOLDER"
elif [ -n "$1" ] && [ -d "./$1" ]; then #If true, then the first argument is a directory
    TEST_DATA_FOLDER="$1"
    OUTPUT_DIRECTORY="$TEST_DATA_FOLDER/actual_outputs"
    beginTest "$PROGRAM_TESTED" "$TEST_DATA_FOLDER"
elif [ "$1" == "-o" ]; then #If true, there is a -o option
    if [ -n "$2" ] && [ -d "./$2" ]; then #If true, then the second argument is a directory
        PROGRAM_DIRECTORY="$(basename "$2" /)/"
        PROGRAM_TESTED="$PROGRAM_DIRECTORY/$PROGRAM_TESTED"
        TEST_DATA_FOLDER="$PROGRAM_DIRECTORY/$TEST_DATA_FOLDER"
        OUTPUT_DIRECTORY="$TEST_DATA_FOLDER/actual_outputs"
        beginTest "$PROGRAM_TESTED" "$TEST_DATA_FOLDER"
    else
        echo -e "${RED}Directory $2 does not exist${NC}"
        exit 1
    fi
else
    # Check if the default values exist in the current directory
    if [ -e "$PROGRAM_TESTED" ]; then
        # Check if the folder exists
        if [ -d "$TEST_DATA_FOLDER" ]; then
            beginTest "$PROGRAM_TESTED" "$TEST_DATA_FOLDER"
        else
            echo -e "${RED}Test data folder $TEST_DATA_FOLDER does not exist in the current work directory${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Program $PROGRAM_TESTED does not exist in the current work directory${NC}"
        exit 1
    fi
fi

