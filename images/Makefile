HOOK_TAG := gravitational/storage-app-hook:$(VERSION)

.PHONY: hook
hook: check-vars
	$(eval CHANGESET = $(shell echo $$VERSION | sed -e 's/[\.]//g'))
	if [ -z "$(CHANGESET)" ]; then \
	  echo "CHANGESET is not set"; exit 1; \
	fi;
	docker build --build-arg CHANGESET=storage-$(CHANGESET) \
		--pull -t $(HOOK_TAG) hook

.PHONY: check-vars
check-vars:
	@if [ -z "$(VERSION)" ]; then \
		echo "VERSION is not set"; exit 1; \
	fi;
