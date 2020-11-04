#!/bin/bash

  function prepend() {
      while read line; do echo "${1}${line}"; done;
  }

#set -v -x -e

# check that we have the expected version
kubectl describe spc | grep Current > cstor_pool_version.txt
if ! grep -q 1.7.0 cstor_pool_version.txt; then
  echo " expected cStor pool version 1.7.0 not found " >> storage-app-upgrade.log
  exit 3
fi


kubectl get spc -A | cut -d" " -f1 | tail -n +2 >cstor_pools.txt
if [ ! -s cstor_pools.txt ]
 then
    echo " unable to find storage pool claims " >> storage-app-upgrade.log
   exit 0
fi


sed 's/[^[:space:],]\+/"&"/g' cstor_pools.txt > cstor_pools2.txt
cat cstor_pools2.txt | prepend "- " > cstor_pools3.txt

# replace the cStor pool names in the upgrade script
cStorPools=$(<cstor_pools3.txt)

#echo "---> ${cStorPools} "
#exit

  cStorPoolsStrToReplace="#CSTOR_POOLS"
  while IFS= read -r line; do
    echo "${line//$cStorPoolsStrToReplace/$cStorPools}"
  done < /var/lib/gravity/resources/upgrade_cstor_pools.yaml

#set +v +x +e
