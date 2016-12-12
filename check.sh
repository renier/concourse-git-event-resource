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
QUEUE_ADDR=$(jq -r '.source.queue_addr // ""' < $payload)
[ -z "${QUEUE_ADDR}" ] && QUEUE_ADDR="${default_queue}"
QUEUE_NAME=$(jq -r '.source.queue_name // ""' < $payload)

echo "Checking push event queue..."
event=$TMPDIR/push-event
pop $QUEUE_ADDR $QUEUE_NAME > $event
if [ $? != 0 ]; then
    echo "Nothing in the $QUEUE_NAME queue"
    echo '[]' >&3
    exit 0
fi

branch=$(cat $event | jq -r '.ref' | sed -e 's/refs\/heads\///')
url=$(jq -r '.repository.clone_url // ""' < $event)
before=$(jq -r '.before' < $event)
after=$(jq -r '.after' < $event)

destination=$TMPDIR/git-event-resource-repo-cache

if [ -d $destination ]; then
  cd $destination
  git fetch
  git reset --hard FETCH_HEAD
else
  branchflag="--branch $branch"

  git clone --single-branch $uri $branchflag $destination
  cd $destination
fi

git log --oneline $before..$after
git checkout $after

# TODO...

if [ -n "$ref" ] && git cat-file -e "$ref"; then
  init_commit=$(git rev-list --max-parents=0 HEAD)
  if [ "${ref}" = "${init_commit}" ]; then
    log_range="--reverse HEAD"
  else
    log_range="--reverse ${ref}~1..HEAD"
  fi
else
  log_range="-1"
fi

{
  git log --format='%H' $before..$after
} | jq -R '.' | jq -s "map({ref: .})" >&3
