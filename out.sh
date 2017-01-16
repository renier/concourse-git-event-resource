#!/bin/bash

set -e
exec 3>&1 # make stdout available as fd 3 for the result
exec 1>&2 # redirect all output to stderr for logging

payload=$TMPDIR/git-event-resource-out

cat > $payload <&0

echo "put (out) is not supported"

cd $(dirname `find ${1} -type d -name ".git" | head -n1`)
ref=$(git log --format='%H' -1)

echo "{\"version\":{\"ref\":\"$ref\"}}" >&3
