# Shortcut targets
default: image

###############################################################################
DOCKERFILE ?= Dockerfile
DOCKER_BUILD_ARGS=--platform "linux/amd64,linux/arm64,linux/ppc64le,linux/s390x"
VERSION ?= v5.3
DEFAULTORG ?= calico
DEFAULTIMAGE ?= $(DEFAULTORG)/bpftool:$(VERSION)
BPFTOOLIMAGE ?= $(DEFAULTIMAGE)-$(BUILDARCH)
KERNELREF ?= $(VERSION)
KERNELREPO ?= git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git

MANIFEST_TOOL_VERSION := v0.7.0
MANIFEST_TOOL_DIR := $(shell mktemp -d)
export PATH := $(MANIFEST_TOOL_DIR):$(PATH)

space :=
space +=
comma := ,
prefix_linux = $(addprefix linux/,$(strip $(subst armv,arm/v,$1)))
join_platforms = $(subst $(space),$(comma),$(call prefix_linux,$(strip $1)))

###############################################################################
# Building the image
###############################################################################
image: $(DEFAULTORG)/bpftool
$(DEFAULTORG)/bpftool:
	# Make sure we re-pull the base image to pick up security fixes.
	# Limit the build to use only one CPU, This helps to work around qemu bugs such as https://bugs.launchpad.net/qemu/+bug/1098729
	docker buildx build $(DOCKER_BUILD_ARGS) --build-arg KERNEL_REF=$(KERNELREF) --build-arg KERNEL_REPO=$(KERNELREPO) -t $(DEFAULTIMAGE) -f $(DOCKERFILE) .

push:
	docker buildx build $(DOCKER_BUILD_ARGS) --build-arg KERNEL_REF=$(KERNELREF) --build-arg KERNEL_REPO=$(KERNELREPO) --push -t $(DEFAULTIMAGE) -f $(DOCKERFILE) .

###############################################################################
# UTs
###############################################################################
test:
	docker run --rm $(BPFTOOLIMAGE) /bpftool version | grep -q "bpftool v"
	@echo "success"

###############################################################################
# CI
###############################################################################
.PHONY: ci
## Run what CI runs
ci: image test

###############################################################################
# CD
###############################################################################
.PHONY: cd
## Deploys images to registry
cd:
ifndef CONFIRM
	$(error CONFIRM is undefined - run using make <target> CONFIRM=true)
endif
ifndef BRANCH_NAME
	$(error BRANCH_NAME is undefined - run using make <target> BRANCH_NAME=var or set an environment variable)
endif
	$(MAKE) push-all VERSION=${BRANCH_NAME}
	$(MAKE) push-manifest VERSION=${BRANCH_NAME}
