#!/bin/bash
set -eu
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

exitCode=0
while IFS= read -r i; do
    if grep -q "$i" "$SCRIPT_DIR"/../.github/workflows/call-integration-tests.yaml ; then
        echo "Version is tested: $i"
    else
        echo "Unable to find version $i in integration tests"
        exitCode=1
    fi
done < <(jq -cr '.k8s_kind_versions[]' "$SCRIPT_DIR"/../component-config.json)

exit $exitCode
