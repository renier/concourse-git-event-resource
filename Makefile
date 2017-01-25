DOCKER_TAG?=latest
DOCKER_REPO=renier/git-event-resource
GO=go

default: pop push
	docker build -t $(DOCKER_REPO):$(DOCKER_TAG) .

pop:
	env GOOS="linux" GOARCH="amd64" $(GO) build -ldflags="-s -w" -o pop pop.go

push:
	env GOOS="linux" GOARCH="amd64" $(GO) build -ldflags="-s -w" -o push push.go

docker-push: default
	docker push $(DOCKER_REPO):$(DOCKER_TAG)

clean:
	rm -f pop push
