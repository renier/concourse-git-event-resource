#!/bin/bash

set -e
exec 3>&1 # make stdout available as fd 3 for the result
exec 1>&2 # redirect all output to stderr for logging

# for jq
PATH=/usr/local/bin:$PATH

default_queue="$(ip route | awk '/default/ { print $3 }'):22133"
payload=$TMPDIR/git-event-resource-request

cat > $payload <&0

GH_TOKEN=$(jq -r '.source.gh_token // ""' < $payload)
GITHUB_HOST=$(jq -r '.source.github_host // "github.com"' < $payload)
QUEUE_ADDR=$(jq -r '.source.queue_addr // ""' < $payload)
[ -z "${QUEUE_ADDR}" ] && QUEUE_ADDR="${default_queue}"
QUEUE_NAME=$(jq -r '.source.queue_name // ""' < $payload)
ref=$(jq -r '.version.ref // ""' < $payload)

echo "Checking push event queue..."
event=$TMPDIR/push-event
pop $QUEUE_ADDR ${QUEUE_NAME}/peek > $event
if [[ $? -ne 0 ]]; then
    echo "Nothing in the $QUEUE_NAME queue"
    if [ "$ref" == "" ]; then
        echo '[]' >&3
    else
        echo "[{\"ref\":\"$ref\"}]" >&3
    fi
    exit 0
fi

# Ignore create/delete events
ref_type=$(jq -r '.ref_type // ""' < $event)
if [ "${ref_type}" != "" ]; then
    event_ref=$(jq -r '.ref' < $event)
    echo "Ignoring ${ref_type} event: ${event_ref}"
    pop $QUEUE_ADDR ${QUEUE_NAME} # remove event from the queue
    echo "[{\"ref\":\"$ref\"}]" >&3 # say no new updates found
    exit 0
fi

deleted=$(jq -r '.deleted' < $event)
if [ "${deleted}" == "null" ] || [ "${deleted}" == "true" ]; then
    echo "Repository was just deleted. Nothing to do."
    if [ "$ref" == "" ]; then
        echo '[]' >&3
    else
        echo "[{\"ref\":\"$ref\"}]" >&3
    fi
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

destination=$TMPDIR/git-event-resource-repo-cache
echo -e "machine $GITHUB_HOST\n  login $GH_TOKEN\n  password x-oauth-basic\n  protocol https" >> ~/.netrc

if [ -d $destination ]; then
    cd $destination
    git fetch origin $branch
    git reset --hard FETCH_HEAD
else
    branchflag="--branch $branch"

    git clone --single-branch $url $branchflag $destination
    cd $destination
fi

git log --oneline $range
git checkout $after

{
    git log --format='%H' $range
} | jq -R '.' | jq -s "map({ref: .})" >&3
