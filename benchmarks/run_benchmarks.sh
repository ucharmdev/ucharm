#!/bin/bash
# Comprehensive benchmarks: Python vs Go vs ucharm
# Run from the benchmarks/ directory

set -e

cd "$(dirname "$0")"

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

MCHARM="../cli/zig-out/bin/ucharm"

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          ucharm Benchmark Suite                          ║"
echo "║          Python vs Go vs ucharm                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check dependencies
echo -e "${DIM}Checking dependencies...${NC}"
command -v python3 >/dev/null || { echo "python3 not found"; exit 1; }
command -v go >/dev/null || { echo "go not found"; exit 1; }
command -v micropython >/dev/null || { echo "micropython not found"; exit 1; }
[ -f "$MCHARM" ] || { echo "ucharm not built"; exit 1; }

# Build Go binaries
echo -e "${DIM}Building Go binaries...${NC}"
go build -o hello_go hello.go
go build -o fib_go fib.go
go build -o loop_go loop.go
go build -o json_go json_parse.go

# Build ucharm universal binaries
echo -e "${DIM}Building ucharm universal binaries...${NC}"
rm -rf /tmp/ucharm-*  # Clear cache
$MCHARM build hello.py -o hello_ucharm --mode universal >/dev/null 2>&1
$MCHARM build fib.py -o fib_ucharm --mode universal >/dev/null 2>&1
$MCHARM build loop.py -o loop_ucharm --mode universal >/dev/null 2>&1
$MCHARM build json_parse.py -o json_ucharm --mode universal >/dev/null 2>&1

echo ""

# Helper function to run benchmark
benchmark() {
    local name="$1"
    local cmd="$2"
    local runs="${3:-5}"

    # Warmup run
    eval "$cmd" >/dev/null 2>&1

    # Timed runs
    local total=0
    for i in $(seq 1 $runs); do
        local start=$(python3 -c "import time; print(int(time.time() * 1000))")
        eval "$cmd" >/dev/null 2>&1
        local end=$(python3 -c "import time; print(int(time.time() * 1000))")
        local elapsed=$((end - start))
        total=$((total + elapsed))
    done

    local avg=$((total / runs))
    echo "$avg"
}

# Print table header
print_header() {
    echo -e "${BOLD}$1${NC}"
    echo "┌──────────────────────┬──────────┬──────────┬──────────┬──────────┐"
    echo "│ Runtime              │ Time     │ vs Go    │ vs Py    │ vs mpy   │"
    echo "├──────────────────────┼──────────┼──────────┼──────────┼──────────┤"
}

print_row() {
    local name="$1"
    local time="$2"
    local vs_go="$3"
    local vs_py="$4"
    local vs_mpy="$5"
    printf "│ %-20s │ %6sms │ %8s │ %8s │ %8s │\n" "$name" "$time" "$vs_go" "$vs_py" "$vs_mpy"
}

print_footer() {
    echo "└──────────────────────┴──────────┴──────────┴──────────┴──────────┘"
    echo ""
}

calc_ratio() {
    local a="$1"
    local b="$2"
    if [ "$b" -eq 0 ]; then
        echo "N/A"
    else
        python3 -c "print(f'{$a/$b:.1f}x')"
    fi
}

# ============================================================================
# STARTUP TIME BENCHMARK
# ============================================================================
echo -e "${YELLOW}Running startup benchmarks (Hello World)...${NC}"

# Clear ucharm cache for cold start test
rm -rf /tmp/ucharm-*

go_hello=$(benchmark "Go" "./hello_go" 10)
py_hello=$(benchmark "Python" "python3 hello.py" 10)
mpy_hello=$(benchmark "MicroPython" "micropython hello.py" 10)
ucharm_cold=$(benchmark "ucharm (cold)" "./hello_ucharm" 1)
ucharm_warm=$(benchmark "ucharm (warm)" "./hello_ucharm" 10)

print_header "Startup Time (Hello World)"
print_row "Go" "$go_hello" "-" "$(calc_ratio $py_hello $go_hello)" "$(calc_ratio $mpy_hello $go_hello)"
print_row "Python 3" "$py_hello" "$(calc_ratio $py_hello $go_hello)" "-" "$(calc_ratio $mpy_hello $py_hello)"
print_row "MicroPython" "$mpy_hello" "$(calc_ratio $mpy_hello $go_hello)" "$(calc_ratio $mpy_hello $py_hello)" "-"
print_row "ucharm (cold)" "$ucharm_cold" "$(calc_ratio $ucharm_cold $go_hello)" "$(calc_ratio $ucharm_cold $py_hello)" "$(calc_ratio $ucharm_cold $mpy_hello)"
print_row "ucharm (warm)" "$ucharm_warm" "$(calc_ratio $ucharm_warm $go_hello)" "$(calc_ratio $ucharm_warm $py_hello)" "$(calc_ratio $ucharm_warm $mpy_hello)"
print_footer

# ============================================================================
# FIBONACCI BENCHMARK
# ============================================================================
echo -e "${YELLOW}Running compute benchmarks (Fibonacci 30)...${NC}"

go_fib=$(benchmark "Go" "./fib_go" 5)
py_fib=$(benchmark "Python" "python3 fib.py" 5)
mpy_fib=$(benchmark "MicroPython" "micropython fib.py" 5)
ucharm_fib=$(benchmark "ucharm" "./fib_ucharm" 5)

print_header "Compute Performance (Fibonacci 30)"
print_row "Go" "$go_fib" "-" "$(calc_ratio $py_fib $go_fib)" "$(calc_ratio $mpy_fib $go_fib)"
print_row "Python 3" "$py_fib" "$(calc_ratio $py_fib $go_fib)" "-" "$(calc_ratio $mpy_fib $py_fib)"
print_row "MicroPython" "$mpy_fib" "$(calc_ratio $mpy_fib $go_fib)" "$(calc_ratio $mpy_fib $py_fib)" "-"
print_row "ucharm" "$ucharm_fib" "$(calc_ratio $ucharm_fib $go_fib)" "$(calc_ratio $ucharm_fib $py_fib)" "$(calc_ratio $ucharm_fib $mpy_fib)"
print_footer

# ============================================================================
# LOOP BENCHMARK
# ============================================================================
echo -e "${YELLOW}Running loop benchmarks (1M iterations)...${NC}"

go_loop=$(benchmark "Go" "./loop_go" 5)
py_loop=$(benchmark "Python" "python3 loop.py" 5)
mpy_loop=$(benchmark "MicroPython" "micropython loop.py" 5)
ucharm_loop=$(benchmark "ucharm" "./loop_ucharm" 5)

print_header "Loop Performance (1M iterations)"
print_row "Go" "$go_loop" "-" "$(calc_ratio $py_loop $go_loop)" "$(calc_ratio $mpy_loop $go_loop)"
print_row "Python 3" "$py_loop" "$(calc_ratio $py_loop $go_loop)" "-" "$(calc_ratio $mpy_loop $py_loop)"
print_row "MicroPython" "$mpy_loop" "$(calc_ratio $mpy_loop $go_loop)" "$(calc_ratio $mpy_loop $py_loop)" "-"
print_row "ucharm" "$ucharm_loop" "$(calc_ratio $ucharm_loop $go_loop)" "$(calc_ratio $ucharm_loop $py_loop)" "$(calc_ratio $ucharm_loop $mpy_loop)"
print_footer

# ============================================================================
# JSON BENCHMARK
# ============================================================================
echo -e "${YELLOW}Running JSON benchmarks (10K parses)...${NC}"

go_json=$(benchmark "Go" "./json_go" 5)
py_json=$(benchmark "Python" "python3 json_parse.py" 5)
mpy_json=$(benchmark "MicroPython" "micropython json_parse.py" 5)
ucharm_json=$(benchmark "ucharm" "./json_ucharm" 5)

print_header "JSON Parsing (10K iterations)"
print_row "Go" "$go_json" "-" "$(calc_ratio $py_json $go_json)" "$(calc_ratio $mpy_json $go_json)"
print_row "Python 3" "$py_json" "$(calc_ratio $py_json $go_json)" "-" "$(calc_ratio $mpy_json $py_json)"
print_row "MicroPython" "$mpy_json" "$(calc_ratio $mpy_json $go_json)" "$(calc_ratio $mpy_json $py_json)" "-"
print_row "ucharm" "$ucharm_json" "$(calc_ratio $ucharm_json $go_json)" "$(calc_ratio $ucharm_json $py_json)" "$(calc_ratio $ucharm_json $mpy_json)"
print_footer

# ============================================================================
# BINARY SIZE COMPARISON
# ============================================================================
echo -e "${YELLOW}Binary sizes...${NC}"

echo -e "${BOLD}Binary Sizes${NC}"
echo "┌──────────────────────┬──────────────┐"
echo "│ Binary               │ Size         │"
echo "├──────────────────────┼──────────────┤"

format_size() {
    local size=$1
    if [ $size -ge 1048576 ]; then
        python3 -c "print(f'{$size/1048576:.1f} MB')"
    elif [ $size -ge 1024 ]; then
        python3 -c "print(f'{$size/1024:.0f} KB')"
    else
        echo "${size} B"
    fi
}

go_size=$(stat -f%z hello_go 2>/dev/null || stat -c%s hello_go)
ucharm_size=$(stat -f%z hello_ucharm 2>/dev/null || stat -c%s hello_ucharm)
ucharm_cli_size=$(stat -f%z "$MCHARM" 2>/dev/null || stat -c%s "$MCHARM")

printf "│ %-20s │ %12s │\n" "Go hello" "$(format_size $go_size)"
printf "│ %-20s │ %12s │\n" "ucharm hello" "$(format_size $ucharm_size)"
printf "│ %-20s │ %12s │\n" "ucharm CLI" "$(format_size $ucharm_cli_size)"
echo "└──────────────────────┴──────────────┘"
echo ""

# ============================================================================
# MEMORY USAGE
# ============================================================================
echo -e "${YELLOW}Memory usage (peak RSS)...${NC}"

get_memory() {
    local cmd="$1"
    # Use /usr/bin/time for memory measurement (macOS format)
    local output=$( /usr/bin/time -l $cmd 2>&1 )
    local mem=$(echo "$output" | grep -E "maximum resident|max resident" | awk '{print $1}')
    if [ -z "$mem" ]; then
        echo "N/A"
    else
        # macOS reports in bytes, convert to KB
        echo $((mem / 1024))
    fi
}

echo -e "${BOLD}Peak Memory Usage${NC}"
echo "┌──────────────────────┬──────────────┐"
echo "│ Runtime              │ Peak RSS     │"
echo "├──────────────────────┼──────────────┤"

go_mem=$(get_memory "./hello_go")
py_mem=$(get_memory "python3 hello.py")
mpy_mem=$(get_memory "micropython hello.py")
ucharm_mem=$(get_memory "./hello_ucharm")

printf "│ %-20s │ %10s KB │\n" "Go" "$go_mem"
printf "│ %-20s │ %10s KB │\n" "Python 3" "$py_mem"
printf "│ %-20s │ %10s KB │\n" "MicroPython" "$mpy_mem"
printf "│ %-20s │ %10s KB │\n" "ucharm" "$ucharm_mem"
echo "└──────────────────────┴──────────────┘"
echo ""

# Cleanup
echo -e "${DIM}Cleaning up...${NC}"
rm -f hello_go fib_go loop_go json_go
rm -f hello_ucharm fib_ucharm loop_ucharm json_ucharm

echo -e "${GREEN}${BOLD}Benchmarks complete!${NC}"
