#!/bin/bash

set +e
exec 3>&1 # make stdout available as fd 3 for the result
exec 1>&2 # redirect all output to stderr for logging

# for jq
PATH=/usr/local/bin:$PATH

ZERO="0000000000000000000000000000000000000000"

default_queue="$(ip route | awk '/default/ { print $3 }'):22133"
payload=$(mktemp $TMPDIR/resource-check.XXXXXX)

cat > $payload <&0

GH_TOKEN=$(jq -r '.source.gh_token // ""' < $payload)
GITHUB_HOST=$(jq -r '.source.github_host // "github.com"' < $payload)
QUEUE_ADDR=$(jq -r '.source.queue_addr // ""' < $payload)
[ -z "${QUEUE_ADDR}" ] && QUEUE_ADDR="${default_queue}"
QUEUE_NAME=$(jq -r '.source.queue_name // ""' < $payload)
ref=$(jq -r '.version.ref // ""' < $payload)

echo "Checking push event queue..."
event=$(mktemp $TMPDIR/resource-event.XXXXXX)
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
set -e

# Ignore create/delete events
ref_type=$(jq -r '.ref_type // ""' < $event)
if [ "${ref_type}" != "" ]; then
    event_ref=$(jq -r '.ref' < $event)
    echo "Ignoring ${ref_type} event: ${event_ref}"
    pop $QUEUE_ADDR ${QUEUE_NAME} # remove event from the queue
    if [ "$ref" == "" ]; then
        echo '[]' >&3
    else
        echo "[{\"ref\":\"$ref\"}]" >&3
    fi
    exit 0
fi

deleted=$(jq -r '.deleted' < $event)
if [ "${deleted}" == "null" ] || [ "${deleted}" == "true" ]; then
    echo "Repository or branch was deleted. Nothing to do."
    pop $QUEUE_ADDR ${QUEUE_NAME} # remove event from the queue
    if [ "$ref" == "" ]; then
        echo '[]' >&3
    else
        echo "[{\"ref\":\"$ref\"}]" >&3
    fi
    exit 0
fi

created=$(jq -r '.created // ""' < $event)
branch=$(cat $event | jq -r '.ref' | sed -e 's/refs\/heads\///')
[[ "$branch" == *"/tags/"* ]] && TAG=1
branch=$(echo $branch | sed -e 's/refs\/tags\///')
url=$(jq -r '.repository.clone_url // ""' < $event)
before=$(jq -r '.before // ""' < $event)
[ "$created" == "true" ] && [ "$before" == "$ZERO" ] && TAG=1
after=$(jq -r '.after' < $event)
[ -n "$TAG" ] && after="$branch"

if [ -z "${before}" ] || [ "${before}" == "${ZERO}" ]; then
    before=$(jq -r '.commits[0].id // ""' < $event)

    if [ -z "${before}" ]; then # a new tag?
        if [ -n "$TAG" ]; then
            before="${after}~1"
        else
            before="${ref}"
        fi
    fi
fi

range="${before}..${after}"
if [ "${before}" == "${ZERO}" ] || [ -z "${before}" ] || [ "$before" == "$after" ]; then
    range="${after}~1..${after}"
fi

destination=$TMPDIR/git-event-resource-repo-cache
echo -e "machine $GITHUB_HOST\n  login $GH_TOKEN\n  password x-oauth-basic\n  protocol https" >> ~/.netrc

set +e
if [ -d $destination ]; then
    cd $destination
    git fetch origin $branch
    if [[ $? -ne 0 ]]; then
        echo "Fetching from branch $branch failed."
        pop $QUEUE_ADDR ${QUEUE_NAME} # remove event from the queue
        echo "[{\"ref\":\"$ref\"}]" >&3
        exit 2
    fi
    git reset --hard FETCH_HEAD
else
    branchflag="--branch $branch"

    git clone --single-branch $url $branchflag $destination
    if [[ $? -ne 0 ]]; then
        echo "Cloning branch $branch failed."
        pop $QUEUE_ADDR ${QUEUE_NAME} # remove event from the queue
        echo "[{\"ref\":\"$ref\"}]" >&3
        exit 2
    fi
    cd $destination
fi
set -e

[ -z "$TAG" ] && git log --oneline $range
git checkout $after

if [ -n "$TAG" ]; then
    echo "[{\"ref\":\"$branch\"}]" >&3
    exit 0
fi

{
    git log --format='%H' $range
} | jq -R '.' | jq -s "map({ref: .})" >&3
