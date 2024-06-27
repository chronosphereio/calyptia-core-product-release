#!/bin/bash
set -eux
# This does not work with a symlink to this script
# SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
# See https://stackoverflow.com/a/246128/24637657
SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  SCRIPT_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  [[ $SOURCE != /* ]] && SOURCE=$SCRIPT_DIR/$SOURCE
done
SCRIPT_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
REPO_ROOT=${REPO_ROOT:-$SCRIPT_DIR/..}

PRODUCTS=${PRODUCTS:?}
VERSIONS=${VERSIONS:?}

if ! command -v jq &> /dev/null; then
    echo "ERROR: missing jq command, please install"
    exit 1
fi

rm -f "$SCRIPT_DIR/component-config-new.json"

# Either a single entry or a comma-separate list
IFS=', ' read -r -a products <<< "$PRODUCTS"
IFS=', ' read -r -a versions <<< "$VERSIONS"

# Check we have a matching set of arrays
if [[ "${#products[@]}" -ne "${#versions[@]}" ]]; then
    echo "Mismatch in product vs version sizes (${#products[@]} != ${#versions[@]})"
    exit 1
fi

# Iterate over each entry to confirm it is valid and then update product=version
for index in "${!products[@]}"; do
    product="${products[index]}"
    version="${versions[index]}"

    echo "Updating $product=$version"

    # Does the product exist?
    if ! grep -q "$product" "$SCRIPT_DIR/../component-config.json"; then
        echo "Missing $product"
        exit 1
    fi

    # Do we have an actual version?
    if [[ -z "$version" ]]; then
        echo "Missing version for $product at index $index"
        exit 1
    fi

    # Strip any v's and ensure this is semver-compatible
    if [[ "$version" =~ ^v?([0-9]+\.[0-9]+\.[0-9]+)$ ]] ; then
        version=${BASH_REMATCH[1]}
        echo "$product = $version"
    else
        echo "ERROR: Invalid semver string ($product): $version"
        exit 1
    fi

    # Update the new file
    rm -f "$SCRIPT_DIR/component-config-new.json"
    jq ".versions.$product = \"$version\"" "$REPO_ROOT/component-config.json" | tee "$REPO_ROOT/component-config-new.json"
    mv -f "$SCRIPT_DIR/../component-config-new.json" "$REPO_ROOT/component-config.json"
done

cat "$SCRIPT_DIR/../component-config.json"
