#! /usr/bin/bash

set -eou pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

pushd $SCRIPT_DIR >/dev/null

for FILE in $(ls *.j2); do
    echo "Rendering manifest: $FILE"
    jinja2 --strict \
        -D GITHUB_OAUTH_CLIENT_ID_B64=$(echo -n $GITHUB_OAUTH_CLIENT_ID | base64 -w0) \
        -D GITHUB_OAUTH_CLIENT_SECRET_B64=$(echo -n $GITHUB_OAUTH_CLIENT_SECRET | base64 -w0) \
        -D ROUTE53_HOSTED_ZONE_ID=$ROUTE53_HOSTED_ZONE_ID \
        -D ROUTE53_DYNAMIC_DNS_AWS_ACCESS_KEY_ID_B64=$(echo -n $ROUTE53_DYNAMIC_DNS_AWS_ACCESS_KEY_ID | base64 -w0) \
        -D ROUTE53_DYNAMIC_DNS_AWS_ACCESS_KEY_B64=$(echo -n $ROUTE53_DYNAMIC_DNS_AWS_ACCESS_KEY | base64 -w0) \
        -o rendered/${FILE%.*} $FILE
done;

cp *.yml rendered/

popd >/dev/null