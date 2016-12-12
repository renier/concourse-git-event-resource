DOCKER_TAG?=latest
DOCKER_REPO=renier/git-event-resource
GO=go

default: pop
	docker build -t $(DOCKER_REPO):$(DOCKER_TAG) .

pop:
	env GOOS="linux" GOARCH="amd64" $(GO) build -ldflags="-s -w" -o pop pop.go

push:
	docker push $(DOCKER_REPO):$(DOCKER_TAG)

clean:
	rm -f pop
