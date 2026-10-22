IMAGE ?= local/iio-oscilloscope
TAG   ?= dev
ARCH  ?= amd64
DOCKER    ?= docker
APPTAINER ?= apptainer

SIF := dist/osc-$(TAG)-$(ARCH).sif

.PHONY: all docker sif test publish publish-docker publish-sif check-image clean

all: test

docker:
	$(DOCKER) build --platform linux/$(ARCH) $(DOCKER_BUILD_FLAGS) -t $(IMAGE):$(TAG) .

sif: docker
	mkdir -p dist
	$(DOCKER) save -o dist/image.tar $(IMAGE):$(TAG)
	$(APPTAINER) build $(APPTAINER_BUILD_FLAGS) --force $(SIF) docker-archive:dist/image.tar
	rm dist/image.tar
	cd dist && sha256sum $(notdir $(SIF)) > $(notdir $(SIF)).sha256

test: sif
	$(APPTAINER) exec --cleanenv $(SIF) osc-smoke-test

# Publishes what `make all` built (same IMAGE/TAG/ARCH); refuses the local default name.
publish: publish-docker publish-sif

check-image:
	@test "$(IMAGE)" != local/iio-oscilloscope || { echo "Set IMAGE=<dockerhub-user>/iio-oscilloscope" >&2; exit 1; }

publish-docker: check-image
	$(DOCKER) push $(IMAGE):$(TAG)

publish-sif: check-image
	$(APPTAINER) push $(APPTAINER_PUSH_FLAGS) $(SIF) oras://registry-1.docker.io/$(IMAGE):$(TAG)-sif

clean:
	rm -rf dist
