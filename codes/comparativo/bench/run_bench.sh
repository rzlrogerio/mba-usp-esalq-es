#!/usr/bin/env bash
set -euo pipefail

# Usage: ./run_bench.sh [cert_path] [iterations]
# Runs the shell and Rust checks multiple times and reports timing statistics.

BASEDIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASEDIR"

CERT=${1:-certs/cert.pem}
ITERS=${2:-20}

SHELL_PROG=./shell/check_cert.sh
RUST_PROG=./rust/target/release/check_cert_rust

if [ ! -f "$SHELL_PROG" ]; then
	echo "Missing $SHELL_PROG" >&2
	exit 1
fi
if [ ! -x "$SHELL_PROG" ]; then
	chmod +x "$SHELL_PROG" || true
fi

if [ ! -x "$RUST_PROG" ]; then
	echo "Rust binary not found; building release..."
	(cd rust && cargo build --release) || { echo "cargo build failed" >&2; exit 1; }
fi

run_and_time() {
	local cmd="$1"
	local start end ns
	start=$(date +%s%N)
	eval "$cmd" >/dev/null 2>&1
	end=$(date +%s%N)
	ns=$((end-start))
	echo "$ns"
}

shell_sum=0; rust_sum=0
shell_min=0; shell_max=0
rust_min=0; rust_max=0

for i in $(seq 1 "$ITERS"); do
	s=$(run_and_time "$SHELL_PROG '$CERT'")
	r=$(run_and_time "$RUST_PROG '$CERT'")

	shell_sum=$((shell_sum + s))
	rust_sum=$((rust_sum + r))

	if [ "$i" -eq 1 ]; then
		shell_min=$s; shell_max=$s
		rust_min=$r; rust_max=$r
	else
		[ "$s" -lt "$shell_min" ] && shell_min=$s
		[ "$s" -gt "$shell_max" ] && shell_max=$s
		[ "$r" -lt "$rust_min" ] && rust_min=$r
		[ "$r" -gt "$rust_max" ] && rust_max=$r
	fi
done

# convert to milliseconds with awk for floating point
shell_avg_ms=$(awk "BEGIN{printf \"%.6f\", $shell_sum/($ITERS*1000000)}")
rust_avg_ms=$(awk "BEGIN{printf \"%.6f\", $rust_sum/($ITERS*1000000)}")
shell_min_ms=$(awk "BEGIN{printf \"%.6f\", $shell_min/1000000}")
shell_max_ms=$(awk "BEGIN{printf \"%.6f\", $shell_max/1000000}")
rust_min_ms=$(awk "BEGIN{printf \"%.6f\", $rust_min/1000000}")
rust_max_ms=$(awk "BEGIN{printf \"%.6f\", $rust_max/1000000}")

speedup=$(awk "BEGIN{printf \"%.2f\", ($shell_avg_ms==0||$rust_avg_ms==0)?0:($shell_avg_ms/$rust_avg_ms)}")

echo "Benchmark (cert: $CERT, iterations: $ITERS)"
echo "Shell: avg ${shell_avg_ms} ms | min ${shell_min_ms} ms | max ${shell_max_ms} ms"
echo "Rust:  avg ${rust_avg_ms} ms | min ${rust_min_ms} ms | max ${rust_max_ms} ms"
echo "Speedup: Rust is ${speedup}x faster (avg)"

exit 0
