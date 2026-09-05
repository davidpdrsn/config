# Source this file, call start_task for each command, then wait_for_tasks.
labels=()
pids=()
exit_codes=()

start_task() {
  local label="$1"
  shift

  echo "==> started ${label}"

  (
    set -o pipefail
    "$@" 2>&1 | while IFS= read -r line; do
      printf '[%s] %s\n' "$label" "$line"
    done
  ) &

  labels+=("$label")
  pids+=("$!")
}

wait_for_tasks() {
  local failed=0 i code label

  for i in "${!pids[@]}"; do
    label="${labels[$i]}"

    if wait "${pids[$i]}"; then
      code=0
    else
      code=$?
      failed=1
    fi

    exit_codes+=("$code")
    echo "==> done ${label} (exit ${code})"
  done

  echo "==> summary"
  for i in "${!labels[@]}"; do
    echo "  ${labels[$i]}: exit ${exit_codes[$i]}"
  done

  return "$failed"
}
