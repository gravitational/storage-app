from quay.io/gravitational/rig:7.1.2

arg CHANGESET
env RIG_CHANGESET $CHANGESET

add entrypoint.sh /

entrypoint ["/usr/bin/dumb-init", "/entrypoint.sh"]
