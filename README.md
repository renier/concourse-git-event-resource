# git-event-resource

Concourse.ci resource to read github push events out of a siberite queue

Meant to be used with [github-webhook-catcher](https://github.com/renier/github-webhook-catcher) and [siberite](http://siberite.org/) (required).

Can be used in place of concourse's git resource. Will checkout the appropiate branch/commit that correspond to the push event sent by github. It will place the event json information with the source for optional additional processing down the pipeline.
