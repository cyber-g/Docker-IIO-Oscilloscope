.DEFAULT_GOAL := all

DEFAULT_IMAGE := local/iio-oscilloscope
IMAGE ?= $(DEFAULT_IMAGE)
TAG ?= dev
ARCH ?= amd64
JOBS ?= $(shell nproc 2>/dev/null || echo 2)

DOCKER ?= docker
APPTAINER ?= apptainer
DOCKER_BUILD_FLAGS ?=
APPTAINER_BUILD_FLAGS ?=
APPTAINER_PUSH_FLAGS ?=
SIF_REGISTRY ?= oras://registry-1.docker.io

DIST := dist
REF := $(IMAGE):$(TAG)
SIF := $(DIST)/osc-$(TAG)-$(ARCH).sif
ARCHIVE := $(DIST)/docker-$(TAG)-$(ARCH).tar

.PHONY: all docker sif test publish publish-docker publish-sif check-image clean

all: test

docker:
	$(DOCKER) build --platform linux/$(ARCH) --build-arg JOBS=$(JOBS) \
		$(DOCKER_BUILD_FLAGS) --tag "$(REF)" .

sif: docker
	mkdir -p "$(DIST)"
	$(DOCKER) save --output "$(ARCHIVE)" "$(REF)"
	$(APPTAINER) build $(APPTAINER_BUILD_FLAGS) --force "$(SIF)" "docker-archive:$(ARCHIVE)"
	rm -f "$(ARCHIVE)"
	cd "$(DIST)" && sha256sum "$(notdir $(SIF))" > "$(notdir $(SIF)).sha256"

test: sif
	$(APPTAINER) exec --cleanenv "$(SIF)" osc-smoke-test

# Publishing never rebuilds: run `make all` first with the same IMAGE/TAG/ARCH.
publish: publish-docker publish-sif

check-image:
	@if [ "$(IMAGE)" = "$(DEFAULT_IMAGE)" ]; then \
		echo "Refusing to publish '$(IMAGE)': set IMAGE=<dockerhub-user>/iio-oscilloscope" >&2; \
		exit 1; \
	fi

publish-docker: check-image
	$(DOCKER) push "$(REF)"

publish-sif: check-image
	test -s "$(SIF)"
	$(APPTAINER) push $(APPTAINER_PUSH_FLAGS) "$(SIF)" "$(SIF_REGISTRY)/$(IMAGE):$(TAG)-sif"

clean:
	rm -rf "$(DIST)"
