#! /usr/bin/bash

set -eou pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

pushd $SCRIPT_DIR >/dev/null

source manifests/render.sh

# Template inputs
TARGET=${TARGET:-k0}
TIMESTAMP_NS="$(date --utc +%s)000000" # Nanoseconds since 01-01-1970
OPKSSH_GOOGLE_EMAIL=${OPKSSH_GOOGLE_EMAIL:-mark.andrew.farrell@gmail.com}

echo "Rendering config.yml for $TARGET"

jinja2 --strict \
    -D TIMESTAMP_NS=$TIMESTAMP_NS \
    -D RKE2_TOKEN=$RKE2_TOKEN \
    -D OPKSSH_GOOGLE_EMAIL=$OPKSSH_GOOGLE_EMAIL \
    -o $TARGET.yml config.yml.j2 ../env/$TARGET.env

popd >/dev/null
