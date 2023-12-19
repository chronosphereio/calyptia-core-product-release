#!/bin/bash
set -eux
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

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
    jq ".versions.$product = \"$version\"" "$SCRIPT_DIR/../component-config.json" | tee "$SCRIPT_DIR/../component-config-new.json"
    mv -f "$SCRIPT_DIR/../component-config-new.json" "$SCRIPT_DIR/../component-config.json"
done

cat "$SCRIPT_DIR/../component-config.json"
