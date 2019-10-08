REPOSITORY := gravitational.io
NAME := storage-app
VERSION ?= $(shell git describe --tags)
OUT ?= $(NAME).tar.gz
GRAVITY ?= gravity
export

OPENEBS_VERSION := 1.3.0
OPENEBS_NDM_VERSION := v0.4.3
OPENEBS_TOOLS_VERSION := 3.8
LINUX_UTILS_VERSION := 3.9
DEBIAN_VERSION := buster

IMPORT_IMAGE_FLAGS := --set-image=openebs/m-apiserver:$(OPENEBS_VERSION) \
	--set-image=openebs/openebs-k8s-provisioner:$(OPENEBS_VERSION) \
	--set-image=openebs/snapshot-controller:$(OPENEBS_VERSION) \
	--set-image=openebs/snapshot-provisioner:$(OPENEBS_VERSION) \
	--set-image=openebs/admission-server:$(OPENEBS_VERSION) \
	--set-image=openebs/provisioner-localpv:$(OPENEBS_VERSION) \
	--set-image=openebs/jiva:$(OPENEBS_VERSION) \
	--set-image=openebs/cstor-istgt:$(OPENEBS_VERSION) \
	--set-image=openebs/cstor-pool:$(OPENEBS_VERSION) \
	--set-image=openebs/cstor-pool-mgmt:$(OPENEBS_VERSION) \
	--set-image=openebs/cstor-volume-mgmt:$(OPENEBS_VERSION) \
	--set-image=openebs/m-exporter:$(OPENEBS_VERSION) \
	--set-image=openebs/node-disk-manager-amd64:$(OPENEBS_NDM_VERSION) \
	--set-image=openebs/node-disk-operator-amd64:$(OPENEBS_NDM_VERSION) \
	--set-image=openebs/linux-utils:$(LINUX_UTILS_VERSION) \
	--set-image=openebs/openebs-tools:$(OPENEBS_TOOLS_VERSION) \
	--set-image=gravitational/debian-tall:$(DEBIAN_VERSION) \
	--set-image=gravitational/storage-app-hook:$(VERSION)

GRAVITY_EXTRA_FLAGS ?=

.PHONY: tarball
tarball: import
	$(GRAVITY) package export \
		--ops-url=$(OPS_URL) --insecure \
		$(GRAVITY_EXTRA_FLAGS) \
		$(REPOSITORY)/$(NAME):$(VERSION) $(NAME)-$(VERSION).tar.gz

.PHONY: import
import: hook
	-$(GRAVITY) app delete \
		$(REPOSITORY)/$(NAME):$(VERSION) \
		--force --insecure $(GRAVITY_EXTRA_FLAGS)
	$(GRAVITY) app import --vendor \
        $(IMPORT_IMAGE_FLAGS) $(GRAVITY_EXTRA_FLAGS) \
		--include=resources --include=registry .

.PHONY: hook
hook:
	$(MAKE) -C images hook

.PHONY: version
version:
	@echo $(VERSION)
