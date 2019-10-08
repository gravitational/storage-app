HOOK_TAG := gravitational/storage-app-hook:$(VERSION)

.PHONY: hook
hook:
	$(eval CHANGESET = $(shell echo $$VERSION | sed -e 's/[\.]//g'))
	if [ -z "$(CHANGESET)" ]; then \
	  echo "CHANGESET is not set"; exit 1; \
	fi;
	docker build --build-arg CHANGESET=storage-$(CHANGESET) \
		--pull -t $(HOOK_TAG) hook
