#!/bin/bash

# "...must fetch the resource and place it in the given directory"
# "The script must emit the fetched version (metadata optional)"

set -e
exec 3>&1 # make stdout available as fd 3 for the result
exec 1>&2 # redirect all output to stderr for logging

# for jq
PATH=/usr/local/bin:$PATH

default_queue="$(ip route | awk '/default/ { print $3 }'):22133"
payload=$(mktemp $TMPDIR/resource-in.XXXXXX)

# source, version.ref, params
cat > $payload <&0

ref=$(jq -r '.version.ref // ""' < $payload)
GH_TOKEN=$(jq -r '.source.gh_token // ""' < $payload)
GITHUB_HOST=$(jq -r '.source.github_host // "github.com"' < $payload)
echo -e "machine $GITHUB_HOST\n  login $GH_TOKEN\n  password x-oauth-basic\n  protocol https" >> ~/.netrc

QUEUE_ADDR=$(jq -r '.source.queue_addr // ""' < $payload)
[ -z "${QUEUE_ADDR}" ] && QUEUE_ADDR="${default_queue}"
QUEUE_NAME=$(jq -r '.source.queue_name // ""' < $payload)

ref=$(jq -r '.version.ref' < $payload)

echo "Checking push event queue..."
event=$(mktemp $TMPDIR/push-event.XXXXXX)
pop $QUEUE_ADDR $QUEUE_NAME > $event
if [ $? != 0 ]; then
    echo "Nothing in the $QUEUE_NAME queue, though it was expected to have something"
    echo "{}" >&3
    exit 1
fi

deleted=$(jq -r '.deleted' < $event)
if [ "${deleted}" == "null" ] || [ "${deleted}" == "true" ]; then
    echo "Repository was just deleted. Nothing to do."
    echo "{\"version\":{\"ref\":\"$ref\"}}" >&3
    exit 0
fi

branch=$(cat $event | jq -r '.ref' | sed -e 's/refs\/heads\///')
url=$(jq -r '.repository.clone_url // ""' < $event)
before=$(jq -r '.before' < $event)
after=$(jq -r '.after' < $event)

range="${before}..${after}"
if [ "${before}" == "0000000000000000000000000000000000000000" ]; then
    range="${after}"
fi

# destination directory as $1
destination=${1}
if [ -d $destination/.git ]; then
    cd $destination
    git fetch
    git reset --hard FETCH_HEAD
else
    branchflag="--branch $branch"

    git clone --single-branch $url $branchflag $destination
    cd $destination
fi

git log --oneline $range
git checkout $after

cp $event ./event.json

echo "{\"version\":{\"ref\":\"$after\"}}" >&3
