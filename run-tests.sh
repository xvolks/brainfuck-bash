#!/usr/bin/env bash
#
# Runs every .bf file of samples/ through the interpreter and compares the
# produced output with the expected one, byte for byte.
#
# Usage:
#   ./run-tests.sh                 # run every test
#   ./run-tests.sh hello countdown # only run tests whose name contains a filter
#   VERBOSE=1 ./run-tests.sh       # show the whole interpreter output on failure

set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
INTERPRETER=${BF:-$HERE/bf}
SAMPLES_DIR="$HERE/samples"

# Expected stdout for each samples/<name>.bf
declare -A expected=(
  [hello]="Hello World!"
  [hello_world_full]="Hello World!"
  [counter]="123456789"
  [countdown]="987654321"
  [abc]="abc"
  [garbage]="d"
  [multi_cell]="multi"
  [wrap_around]="#"
  [line]=$'\n\n'
  [empty]=""
  [test]="JIPPS/YSVPH0"
)

if [[ -t 1 ]]; then
  C_RESET=$'\e[0m'
  C_PASS=$'\e[32m'
  C_FAIL=$'\e[31m'
  C_BOLD=$'\e[1m'
else
  C_RESET='' C_PASS='' C_FAIL='' C_BOLD=''
fi

log() { printf '%s%s%s\n' "$C_BOLD" "$1" "$C_RESET"; }

# Make bytes printable so a mismatch can be displayed safely
display() {
  LC_ALL=C sed -e 's/\\/\\\\/g' -e 's/[^[:print:]]/\\x/g' <<<"$(tr -d '\0' <<<"$1")"
}

tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/bf-tests.XXXXXX") || exit 1
trap 'rm -rf -- "$tmpdir"' EXIT

# The interpreter expands the source unquoted, so a '*' in a sample would be
# globbed against the current directory. Run from an empty directory to keep
# the results independent from where the tests are started.
mkdir -p "$tmpdir/cwd" || exit 1

pass=0
fail=0
skip=0
failed_names=()

run_test() {
  local name=$1
  local got_file="$tmpdir/$name.got"
  local want_file="$tmpdir/$name.want"
  local err_file="$tmpdir/$name.err"
  local status

  printf '%s' "${expected[$name]}" >"$want_file"

  # stdin is closed so that a program using ',' cannot block the test run
  ( cd "$tmpdir/cwd" && "$INTERPRETER" "$SAMPLES_DIR/$name.bf" </dev/null ) >"$got_file" 2>"$err_file"
  status=$?

  if [[ $status -ne 0 ]]; then
    log "FAIL $name: interpreter exited with status $status"
    [[ -s $err_file ]] && log "  stderr: $(display "$(<"$err_file")")"
    return 1
  fi

  if cmp -s "$want_file" "$got_file"; then
    return 0
  fi

  log "FAIL $name: wrong output"
  log "  expected [$(wc -c <"$want_file" | tr -d ' ') bytes]: $(display "$(<"$want_file")")"
  log "  got      [$(wc -c <"$got_file" | tr -d ' ') bytes]: $(display "$(<"$got_file")")"
  return 1
}

if [[ ! -x $INTERPRETER ]]; then
  echo "Interpreter not found or not executable: $INTERPRETER" >&2
  exit 1
fi

filters=("$@")
log "Running brainfuck tests from $SAMPLES_DIR"
log ""

for file in "$SAMPLES_DIR"/*.bf; do
  [[ -e $file ]] || continue
  name=$(basename -- "$file" .bf)

  if [[ ! -v expected[$name] ]]; then
    log "SKIP $name: no expected output declared in run-tests.sh"
    (( skip++ ))
    continue
  fi

  if [[ ${#filters[@]} -gt 0 ]]; then
    matched=0
    for filter in "${filters[@]}"; do
      if [[ $name == *"$filter"* ]]; then
        matched=1
        break
      fi
    done
    if [[ $matched -eq 0 ]]; then
      (( skip++ ))
      continue
    fi
  fi

  if run_test "$name"; then
    log "${C_PASS}PASS${C_RESET} $name"
    (( pass++ ))
  else
    log "${C_FAIL}FAIL${C_RESET} $name"
    (( fail++ ))
    failed_names+=("$name")
  fi
done

log ""
log "passed: $pass  failed: $fail  skipped: $skip"

if [[ $fail -gt 0 ]]; then
  log "${C_FAIL}failing tests:${C_RESET} ${failed_names[*]}"
  exit 1
fi

exit 0
