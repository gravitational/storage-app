#!/bin/bash

  function prepend() {
      while read line; do echo "${1}${line}"; done;
  }

#set -v -x -e

kubectl get spc -A | cut -d" " -f1 | tail -n +2 >cstor_pools.txt
if [ -s cstor_pools.txt ]
then
    echo "found cStor pools:"
    cat cstor_pools.txt
else
  echo "Unable to find any cStor Pools."
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
