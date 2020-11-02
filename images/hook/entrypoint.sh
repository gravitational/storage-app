#!/bin/sh

set -eu

echo "--> Assuming changeset from the environment: $RIG_CHANGESET"

if [ $1 = "update" ]; then

  echo "--> Checking: $RIG_CHANGESET"
  if rig status ${RIG_CHANGESET} --retry-attempts=1 --retry-period=1s; then
    exit 0
  fi

  # Step 1(Prerequisites) of the upgrade process described at:
  # https://github.com/openebs/openebs/blob/master/k8s/upgrades/README.md
  # Check versions of the existing components:
  # TODO get the old version value (1.12.0) from somewhere and verify that it is bigger than 1.0.0
  # kubectl get pods -n openebs -l openebs.io/version=1.7.0

  echo "--> Starting upgrade, changeset: $RIG_CHANGESET"
  rig cs delete --force -c cs/${RIG_CHANGESET}

  # TODO(r0mant): As this is the first release of OpenEBS as a Gravity application,
  #               the current "upgrade" procedure assumes that OpenEBS is not
  #               yet installed and thus just creates all OpenEBS resources
  #               from scratch.
  #               In the future, we'll need to develop a proper upgrade procedure
  #               for OpenEBS components and its pools/volumes like described in
  #               https://github.com/openebs/openebs/tree/master/k8s/upgrades.

  echo "--> Creating/updating OpenEBS resources for control plane"
  #rig upsert -f /var/lib/gravity/resources/openebs-operator.yaml --debug
  #kubectl apply -f https://openebs.github.io/charts/2.2.0/openebs-operator.yaml
  # kubectl apply -f ./openebs-operator_2.2.0.yaml
  rig upsert -f /var/lib/gravity/resources/openebs-operator_2.2.0.yaml --debug

  echo "--> verify that the control plane is in the desired status"
  listPods=$(kubectl get pods -n openebs -l openebs.io/version=2.2.0)
  echo "Pods after upgrade-> $listPods"
  # TODO parse the output to verify that the version is correct

  kubectl get pods -n openebs -l openebs.io/version=2.2.0 | grep 'maya-apiserver.*Running' >/dev/null
  if [ $? != 0 ]; then
    echo "Unable to upgrade the control plane. Maya server not running."
    exit 1
  fi

  kubectl get pods -n openebs -l openebs.io/version=2.2.0 | grep 'openebs-admission-server.*Running' >/dev/null
  if [ $? != 0 ]; then
    echo "Unable to upgrade the control plane. Admission server not running."
    exit 2
  fi

  echo "--> upgrade Jiva volumes if used:"
  #kubectl get pv  # TODO parse output
  #kubectl apply -f jiva-vol-2.2.0.yaml
  #rig upsert -f /var/lib/gravity/resources/jiva-vol-2.2.0.yaml --debug
  # check the Jiva volume update status
  #kubectl get job -n openebs
  #kubectl get pods -n openebs #to check on the name for the job pod
  #kubectl logs -n openebs jiva-upg-1120210-bgrhx

  echo "--> check if cStor is used and generate upgrade script for the cStor pools:"
  /bin/bash /var/lib/gravity/resources/upgrade_cstor_pools.sh > /var/lib/gravity/resources/upgrade_cstor_pools2.yaml
  rig upsert -f /var/lib/gravity/resources/upgrade_cstor_pools2.yaml --debug
  kubectl describe spc | grep Current

  echo "--> Upgrade cStor Volumes"
  /bin/bash /var/lib/gravity/resources/upgrade_cstor_volumes.sh > /var/lib/gravity/resources/upgrade_cstor_volumes.yaml
  rig upsert -f /var/lib/gravity/resources/upgrade_cstor_volumes.yaml --debug

  echo "--> Checking status"
  rig status ${RIG_CHANGESET} --retry-attempts=120 --retry-period=1s --debug

  echo "--> Freezing"
  rig freeze

elif [ $1 = "rollback" ]; then

  echo "--> Reverting changeset $RIG_CHANGESET"
  rig revert
  rig cs delete --force -c cs/${RIG_CHANGESET}

else

  echo "--> Missing argument, should be either 'update' or 'rollback'"

fi
