#!/usr/bin/env bash
# Run Kodiak bare-metal workloads one at a time and report PASS/FAIL for each.
#
# Usage: run-kodiak-workloads.sh [-t TIMEOUT_S] [-o OUT_DIR] [WORKLOAD ...] [-- FIRESIM_ARGS ...]
#
#   WORKLOAD      Name without the "kodiak-" prefix or ".json" suffix (e.g. vec-sgemm).
#                 Defaults to every deploy/workloads/kodiak-*.json.
#   FIRESIM_ARGS  Passed to every firesim call, e.g. -a <hwdb.yaml> -c <runtime.yaml>.
#
# Run from a shell where sourceme-manager.sh has been sourced. The workload is
# selected with -x, so config_runtime.yaml is never modified.

set -uo pipefail

TIMEOUT=600
DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$DEPLOY_DIR/results-kodiak/$(date +%Y-%m-%d--%H-%M-%S)"
WORKLOADS=()
FIRESIM_ARGS=()

while [ $# -gt 0 ]; do
    case "$1" in
        -t) TIMEOUT="$2"; shift 2 ;;
        -o) OUT_DIR="$2"; shift 2 ;;
        -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        --) shift; FIRESIM_ARGS=("$@"); break ;;
        *) WORKLOADS+=("$1"); shift ;;
    esac
done

if [ ${#WORKLOADS[@]} -eq 0 ]; then
    for f in "$DEPLOY_DIR"/workloads/kodiak-*.json; do
        n="$(basename "$f" .json)"
        WORKLOADS+=("${n#kodiak-}")
    done
fi

mkdir -p "$OUT_DIR"
SUMMARY="$OUT_DIR/summary.csv"
echo "workload,status,cycles,wallclock_s" > "$SUMMARY"
cd "$DEPLOY_DIR"

n_pass=0
n_fail=0
for w in "${WORKLOADS[@]}"; do
    wl="kodiak-$w"
    if [ ! -f "workloads/$wl.json" ]; then
        echo "[$w] no such workload: workloads/$wl.json" >&2
        echo "$w,MISSING,," >> "$SUMMARY"
        n_fail=$((n_fail + 1))
        continue
    fi

    echo "[$w] infrasetup"
    status=""
    if ! timeout "$TIMEOUT" firesim infrasetup -x "workload workload_name $wl.json" "${FIRESIM_ARGS[@]}" \
            > "$OUT_DIR/$w-infrasetup.log" 2>&1; then
        status="INFRA_FAIL"
    else
        echo "[$w] runworkload"
        timeout "$TIMEOUT" firesim runworkload -x "workload workload_name $wl.json" "${FIRESIM_ARGS[@]}" \
            > "$OUT_DIR/$w-runworkload.log" 2>&1
        [ $? -eq 124 ] && status="TIMEOUT"
    fi

    cycles=""
    wall=""
    result_dir="$(ls -td results-workload/*-"$wl"/ 2>/dev/null | head -1)"
    uartlog="$( [ -n "$result_dir" ] && find "$result_dir" -name uartlog | head -1)"
    if [ -n "$uartlog" ]; then
        cp "$uartlog" "$OUT_DIR/$w-uartlog"
        cycles="$(grep -oP 'after \K[0-9]+(?= cycles)' "$uartlog" | tail -1)"
        wall="$(grep -oP 'Wallclock Time Elapsed: \K[0-9.]+' "$uartlog" | tail -1)"
        if [ -z "$status" ]; then
            if grep -q "PASSED" "$uartlog"; then status="PASS"
            elif grep -q "FAILED" "$uartlog"; then status="FAIL"
            fi
        fi
    fi
    status="${status:-UNKNOWN}"

    if [ "$status" = "PASS" ]; then
        n_pass=$((n_pass + 1))
    else
        n_fail=$((n_fail + 1))
        # Make sure a hung or failed simulation doesn't hold the FPGA for the next run.
        firesim kill "${FIRESIM_ARGS[@]}" > "$OUT_DIR/$w-kill.log" 2>&1 || true
    fi
    echo "[$w] $status ${cycles:+($cycles cycles, ${wall}s)}"
    echo "$w,$status,$cycles,$wall" >> "$SUMMARY"
done

echo
echo "$n_pass passed, $n_fail failed. Logs and uartlogs in $OUT_DIR"
column -s, -t < "$SUMMARY"
[ "$n_fail" -eq 0 ]
