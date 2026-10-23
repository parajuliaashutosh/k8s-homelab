IMAGE ?= 192.168.0.100:32630/pg-backup
TAG   ?= v3

.PHONY: all build push

all: push

build:
	docker build -t $(IMAGE):$(TAG) .

push: build
	docker push $(IMAGE):$(TAG)
