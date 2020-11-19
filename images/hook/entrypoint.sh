#!/bin/bash

set -eu

echo "--> Assuming changeset from the environment: $RIG_CHANGESET"

function get_control_plane_version() {
  MAYA_POD=$(kubectl get pod -n openebs | grep -i api | cut -d" " -f1)
  VERSION=$(kubectl exec -it "${MAYA_POD}" mayactl version -nopenebs | grep ^Version | cut -d" " -f2 | perl -pe's/(\d+.\d+.\d+).*/$1/')

  echo "$VERSION"
}

# Verifies that the control plane components are of the expected version
function check_control_plane() {
  echo "Checking control plane for version=$1"

  CONTROL_PLANE_COMPONENTS=control_plane_components.txt
  kubectl get pods -n openebs -l openebs.io/version="$1" > $CONTROL_PLANE_COMPONENTS

  echo "Found control plane components:"
  cat $CONTROL_PLANE_COMPONENTS

  grep 'provisioner.*Running' $CONTROL_PLANE_COMPONENTS >/dev/null &&
    grep 'admission-server.*Running' $CONTROL_PLANE_COMPONENTS >/dev/null &&
    grep 'maya-apiserver.*Running' $CONTROL_PLANE_COMPONENTS >/dev/null &&
    grep 'ndm.*Running' $CONTROL_PLANE_COMPONENTS >/dev/null &&
    grep 'snapshot-operator.*Running' $CONTROL_PLANE_COMPONENTS >/dev/null

  return $?
}

if [ "$1" = "update" ]; then
  TO_VERSION=2.2.0

  echo "--> Checking: $RIG_CHANGESET"
  if rig status "${RIG_CHANGESET}" --retry-attempts=1 --retry-period=1s; then
    exit 0
  fi

  echo "--> Starting upgrade, changeset: $RIG_CHANGESET"

  echo "Starting the control plane upgrade process as described at:"
  echo "https://github.com/openebs/openebs/blob/master/k8s/upgrades/README.md"

  echo "Checking the existing control plane version..."
  FROM_VERSION=$(get_control_plane_version)
  if [[ "$FROM_VERSION" =~ ^[0-9]+.[0-9]+.[0-9]+$ ]]; then
    if [ "$FROM_VERSION" == "$TO_VERSION" ]; then
      echo "The control plane is already upgraded TO_VERSION=$TO_VERSION."
    else
      if [ "$FROM_VERSION" == "1.4.0" ] || [ "$FROM_VERSION" == "1.5.0" ] || [ "$FROM_VERSION" == "1.7.0" ]; then
        echo "Found control plane components of expected FROM_VERSION=$FROM_VERSION."
      else
        echo "Exiting because unable to find expected control plane components FROM_VERSION. Got: '$FROM_VERSION'."
        exit 1
      fi
    fi
  else
    echo "Exiting because unable to retrieve existing control plane version. Got: '$FROM_VERSION'."
    exit 2
  fi

  if [ "$FROM_VERSION" != "$TO_VERSION" ]; then
    echo "Performing control plane upgrade TO_VERSION=$TO_VERSION..."
    if ! rig upsert -f /var/lib/gravity/resources/openebs-operator.yaml --debug;
    then
      echo "Failed rig upsert openebs-operator. Exiting."
      exit $?
    fi

    for i in {1..7}; do
      sleep 30s

      if check_control_plane $TO_VERSION; then
        echo "Successfully upgraded the control plane components TO_VERSION=$TO_VERSION."
        exit 0
      else
        echo "The control plane is still not upgraded, wait loop count=$i."
      fi
    done

    echo "Failed to upgrade the control plane after several attempts. Exiting."
    exit 3
  fi

  echo "--> Checking status"
  rig status "${RIG_CHANGESET}" --retry-attempts=120 --retry-period=1s --debug

  echo "--> Freezing"
  rig freeze

elif [ "$1" = "rollback" ]; then

  echo "--> Skipping reverting changeset $RIG_CHANGESET because rollback is not supported by OpenEBS for upgrade path: fromVersion=1.7.0 -> toVersion=2.2.0 "
  # OpenEBS doesn't recommend a rollback because of breaking changes. The following is from the Slack channel of the OpenEBS team:
  # "So I was discussing this with the team and there were some major breaking changes
  # in the control plane in 2.0.0 version also some data plane changes except the image and labels.
  # This can make the rollback difficult."
  # "The labels will come back but the blockdevices have paths that may have changed in the upgrade from 1.7.0 to 2.2.0 which will not work now"
  # "The rollback is not recommended by openebs"
  #
  # "Rolling back from 2.2.0-2.0.0 is perfectly possible.
  # But from 2.0.0 to 1.7.0 it's a major version change.
  # There has been some breaking change that was introduced in the control plane component NDM in version 2.0.
  # It was mainly around disk identification algorithm that's used.
  # If you roll back there are chances that there will be lot of stale entries for blockdevices in the cluster.
  # Again it has not been tested."

else
  echo "--> Missing argument, should be either 'update' or 'rollback'"
fi
