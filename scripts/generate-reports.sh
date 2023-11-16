#!/bin/bash
set -eu
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

OUTPUT_DIR=${OUTPUT_DIR:-$(mktemp -d)}
TAR_NAME=${TAR_NAME:-/tmp/calyptia-sboms.tgz}
ZIP_NAME=${ZIP_NAME:-/tmp/calyptia-sboms.zip}

if ! command -v docker &> /dev/null; then
    echo "ERROR: missing docker command, please install"
    exit 1
fi
if ! command -v jq &> /dev/null; then
    echo "ERROR: missing jq command, please install"
    exit 1
fi

CORE_FB_VERSION=${CORE_FB_VERSION:-$(jq -r .versions.core_fluent_bit "$SCRIPT_DIR/../component-config.json")}
FRONTEND_VERSION=${FRONTEND_VERSION:-$(jq -r .versions.frontend "$SCRIPT_DIR/../component-config.json")}
LUASANDBOX_VERSION=${LUASANDBOX_VERSION:-$(jq -r .versions.lua_sandbox "$SCRIPT_DIR/../component-config.json")}
CORE_OPERATOR_VERSION=${CORE_OPERATOR_VERSION:-$(jq -r .versions.core_operator "$SCRIPT_DIR/../component-config.json")}
HOT_RELOAD_VERSION=${HOT_RELOAD_VERSION:-$(jq -r .versions.configmap_reload "$SCRIPT_DIR/../component-config.json")}
INGEST_CHECKS_VERSION=${INGEST_CHECKS_VERSION:-$(jq -r .versions.core_sidecar_ingest_check "$SCRIPT_DIR/../component-config.json")}

declare -a images=("ghcr.io/calyptia/configmap-reload:$HOT_RELOAD_VERSION"
"ghcr.io/calyptia/core/calyptia-fluent-bit:$CORE_FB_VERSION"
"ghcr.io/calyptia/core/ingest-check:$INGEST_CHECKS_VERSION"
"ghcr.io/calyptia/core-operator:$CORE_OPERATOR_VERSION"
"ghcr.io/calyptia/core-operator/sync-to-cloud:$CORE_OPERATOR_VERSION"
"ghcr.io/calyptia/core-operator/sync-from-cloud:$CORE_OPERATOR_VERSION"
"ghcr.io/calyptia/frontend:$FRONTEND_VERSION"
"ghcr.io/calyptia/cloud-lua-sandbox:$LUASANDBOX_VERSION"
)

rm -rf "${OUTPUT_DIR:?}/*"
mkdir -p "$OUTPUT_DIR"

for image in "${images[@]}"
do
  output_file=${image//\//-}
  output_file=${output_file//:/-}
  echo "Generating sbom for $image to $OUTPUT_DIR/$output_file"
  docker sbom "$image" --output "$OUTPUT_DIR"/"$output_file.spdx.json" --format spdx-json
  docker sbom "$image" --output "$OUTPUT_DIR"/"$output_file.cyclonedx.json" --format cyclonedx-json
  docker scan "$image" --json --group-issues > "$OUTPUT_DIR"/"$output_file.scan.json"
done

tar -czf "$TAR_NAME" -C "$OUTPUT_DIR" .
zip -jr "$ZIP_NAME" "$OUTPUT_DIR"
