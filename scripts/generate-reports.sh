#!/bin/bash
set -eu
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

OUTPUT_DIR=${OUTPUT_DIR:-$(mktemp -d)}
TAR_NAME=${TAR_NAME:-/tmp/calyptia-sboms.tgz}
ZIP_NAME=${ZIP_NAME:-/tmp/calyptia-sboms.zip}

if ! command -v syft &> /dev/null; then
    echo "Installing syft"
    curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sudo sh -s -- -b /usr/local/bin
fi

if ! command -v grype &> /dev/null; then
    echo "Installing grype"
    curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sudo sh -s -- -b /usr/local/bin
fi

if ! command -v jq &> /dev/null; then
    echo "ERROR: missing jq command, please install"
    exit 1
fi

CLOUD_VERSION=${CLOUD_VERSION:-$(jq -r .versions.cloud "$SCRIPT_DIR/../component-config.json")}
CORE_FB_VERSION=${CORE_FB_VERSION:-$(jq -r .versions.core_fluent_bit "$SCRIPT_DIR/../component-config.json")}
FRONTEND_VERSION=${FRONTEND_VERSION:-$(jq -r .versions.frontend "$SCRIPT_DIR/../component-config.json")}
LUASANDBOX_VERSION=${LUASANDBOX_VERSION:-$(jq -r .versions.lua_sandbox "$SCRIPT_DIR/../component-config.json")}
CORE_OPERATOR_VERSION=${CORE_OPERATOR_VERSION:-$(jq -r .versions.core_operator "$SCRIPT_DIR/../component-config.json")}
HOT_RELOAD_VERSION=${HOT_RELOAD_VERSION:-$(jq -r .versions.configmap_reload "$SCRIPT_DIR/../component-config.json")}
INGEST_CHECKS_VERSION=${INGEST_CHECKS_VERSION:-$(jq -r .versions.core_sidecar_ingest_check "$SCRIPT_DIR/../component-config.json")}

CLOUD_IMAGE=${CLOUD_IMAGE:-$(jq -r .containers.cloud "$SCRIPT_DIR/../component-config.json")}
CORE_FB_IMAGE=${CORE_FB_IMAGE:-$(jq -r .containers.core_fluent_bit "$SCRIPT_DIR/../component-config.json")}
FRONTEND_IMAGE=${FRONTEND_IMAGE:-$(jq -r .containers.frontend "$SCRIPT_DIR/../component-config.json")}
LUASANDBOX_IMAGE=${LUASANDBOX_IMAGE:-$(jq -r .containers.lua_sandbox "$SCRIPT_DIR/../component-config.json")}
CORE_OPERATOR_IMAGE=${CORE_OPERATOR_IMAGE:-$(jq -r .containers.core_operator "$SCRIPT_DIR/../component-config.json")}
CORE_OPERATOR_SYNC_TO_IMAGE=${CORE_OPERATOR_SYNC_TO_IMAGE:-$(jq -r .containers.core_operator_sync_to "$SCRIPT_DIR/../component-config.json")}
CORE_OPERATOR_SYNC_FROM_IMAGE=${CORE_OPERATOR_SYNC_FROM_IMAGE:-$(jq -r .containers.core_operator_sync_from "$SCRIPT_DIR/../component-config.json")}
HOT_RELOAD_IMAGE=${HOT_RELOAD_IMAGE:-$(jq -r .containers.configmap_reload "$SCRIPT_DIR/../component-config.json")}
INGEST_CHECKS_IMAGE=${INGEST_CHECKS_IMAGE:-$(jq -r .containers.core_sidecar_ingest_check "$SCRIPT_DIR/../component-config.json")}

declare -a images=("$HOT_RELOAD_IMAGE:$HOT_RELOAD_VERSION"
"$CORE_FB_IMAGE:$CORE_FB_VERSION"
"$INGEST_CHECKS_IMAGE:$INGEST_CHECKS_VERSION"
"$CORE_OPERATOR_IMAGE:$CORE_OPERATOR_VERSION"
"$CORE_OPERATOR_SYNC_TO_IMAGE:$CORE_OPERATOR_VERSION"
"$CORE_OPERATOR_SYNC_FROM_IMAGE:$CORE_OPERATOR_VERSION"
"$CLOUD_IMAGE:$CLOUD_VERSION"
"$FRONTEND_IMAGE:$FRONTEND_VERSION"
"$LUASANDBOX_IMAGE:$LUASANDBOX_VERSION"
)

rm -rf "${OUTPUT_DIR:?}/*"
mkdir -p "$OUTPUT_DIR"

for image in "${images[@]}"
do
  output_file=${image//\//-}
  output_file=${output_file//:/-}
  echo "Generating sbom for $image to $OUTPUT_DIR/$output_file"
  # shellcheck disable=SC2140
  syft docker:"$image" --output syft-json > "${OUTPUT_DIR}/${output_file}.syft.json"
  syft docker:"$image" --output spdx-json > "${OUTPUT_DIR}/${output_file}.spdx.json"
  syft docker:"$image" --output cyclonedx-json > "${OUTPUT_DIR}/${output_file}.cyclonedx.json"
  grype docker:"$image" --add-cpes-if-none --by-cve --output json > "${OUTPUT_DIR}"/"${output_file}.cves.json"
  grype docker:"$image" --add-cpes-if-none --by-cve --output cyclonedx-json > "${OUTPUT_DIR}"/"${output_file}.cves.cyclonedx.json"
done

tar -czf "$TAR_NAME" -C "$OUTPUT_DIR" .
zip -jr "$ZIP_NAME" "$OUTPUT_DIR"
