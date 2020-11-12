#!/bin/bash

set -eu

echo "---> Assuming changeset from the environment: $RIG_CHANGESET"

TO_VERSION=2.2.0

function get_control_plane_version() {
  MAYA_POD=$(kubectl get pod -n openebs | grep -i api | cut -d" " -f1)
  VERSION=$(kubectl exec -it "${MAYA_POD}" mayactl version -nopenebs | grep ^Version | cut -d" " -f2 | perl -pe's/(\d+.\d+.\d+).*/$1/')

  echo "$VERSION"
}

function check_control_plane() {
  echo "Checking control plane for version=$1"
  # TODO control plane file name to be declared in a variable
  kubectl get pods -n openebs -l openebs.io/version="$1" > control_plane_components.txt


  echo "Found control plane components:"
  cat control_plane_components.txt

  grep 'provisioner.*Running' control_plane_components.txt >/dev/null &&
    grep 'admission-server.*Running' control_plane_components.txt >/dev/null &&
    grep 'maya-apiserver.*Running' control_plane_components.txt >/dev/null &&
    grep 'ndm.*Running' control_plane_components.txt >/dev/null &&
    grep 'snapshot-operator.*Running' control_plane_components.txt >/dev/null

  return $?
}

if [ "$1" = "update" ]; then

  echo "--> Checking: $RIG_CHANGESET"
  if rig status "${RIG_CHANGESET}" --retry-attempts=1 --retry-period=1s; then
    exit 0
  fi

  echo "--> Starting upgrade, changeset: $RIG_CHANGESET"
  #rig cs delete --force -c cs/${RIG_CHANGESET}

  # TODO(r0mant): As this is the first release of OpenEBS as a Gravity application,
  #               the current "upgrade" procedure assumes that OpenEBS is not
  #               yet installed and thus just creates all OpenEBS resources
  #               from scratch.
  #               In the future, we'll need to develop a proper upgrade procedure
  #               for OpenEBS components and its pools/volumes like described in
  #               https://github.com/openebs/openebs/tree/master/k8s/upgrades.

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
        exit 4
      fi
    fi
  else
    echo "Exiting because unable to retrieve existing control plane version. Got: '$FROM_VERSION'."
    exit 7
  fi

  if [ "$FROM_VERSION" != "$TO_VERSION" ]; then
    echo "Performing control plane upgrade TO_VERSION=$TO_VERSION..."
    if ! rig upsert -f /var/lib/gravity/resources/openebs-operator_2.2.0.yaml --debug;
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
    exit 8
  fi

  echo "--> Checking status"
  rig status "${RIG_CHANGESET}" --retry-attempts=120 --retry-period=1s --debug

  echo "--> Freezing"
  rig freeze

elif [ "$1" = "rollback" ]; then

  echo "--> Reverting changeset $RIG_CHANGESET"
  rig revert
  rig cs delete --force -c "cs/${RIG_CHANGESET}"

else

  echo "--> Missing argument, should be either 'update' or 'rollback'"

fi
