#!/bin/bash

  function prepend() {
      while read line; do echo "${1}${line}"; done;
  }



kubectl get pv | cut -d" " -f1 | tail -n +2 >cstor_volumes.txt
sed 's/[^[:space:],]\+/"&"/g' cstor_volumes.txt > cstor_volumes2.txt
cat cstor_volumes2.txt | prepend "- " > cstor_volumes3.txt



# replace the cStor pool names in the upgrade script
cStorVolumes=$(<cstor_volumes3.txt)

#echo "---> ${cStorVolumes} "
#exit

  cStorVolumesStrToReplace="CSTOR_VOLUMES"
  while IFS= read -r line; do
    echo "${line//$cStorVolumesStrToReplace/$cStorVolumes}"
  done < upgrade_cstor_volumes.yaml
