#! /usr/bin/bash

set -eou pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

pushd $SCRIPT_DIR >/dev/null

source render.sh

pushd $SCRIPT_DIR/rendered >/dev/null

for FILE in $(ls ${1:-*.yml}); do
    echo "Applying manifest: $FILE"
    kubectl apply -f $FILE --wait
done;

popd >/dev/null

source clean.sh

popd >/dev/null
