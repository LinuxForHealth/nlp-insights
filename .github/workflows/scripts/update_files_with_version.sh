#!/bin/bash

for i in "$@"; do
  case $i in
   --project_dir=*)
     PROJECT_DIR="${i#*=}"
     shift # past argument=value
     ;;
   --version=*)
     VERSION="${i#*=}"
     shift # past argument=value
     ;;
   --docker_org=*)
     DOCKER_ORG="${i#*=}"
     shift # past argument=value
     ;;
   --docker_repo=*)
     DOCKER_REPO="${i#*=}"
     shift # past argument=value
     ;;
   *)
     >&2 echo "Unknown option ${i}"
     ;;
 esac
done

if [ -z ${PROJECT_DIR} ] || [ -z ${VERSION} ] || [ -z ${DOCKER_ORG} ] || [ -z ${DOCKER_REPO} ]; then
  echo "usage: $0 --project_dir=<dir> --version=<dir> --docker_org=<org> --docker_repo=<repo>"
  exit 1
fi

set -ex
updates=0

######
# update values.yaml
######
values_yaml=${PROJECT_DIR}/chart/values.yaml

# Org and Repo
last_org="$(grep "repository:" ${values_yaml} | sed -r 's/\s*repository:\s*(.*)/\1/' | sed -r 's/(.*)\/'${DOCKER_REPO}'/\1/')"
last_org=`echo $last_org | sed -e 's/^[[:space:]]*//'`

if [ "${DOCKER_ORG}" != "${last_org}" ]; then
  >&2 echo "Updating ${values_yaml} to org = ${DOCKER_ORG}/${DOCKER_REPO}"
  sed -i -e 's/\(\s*repository:\).*/\1 '${DOCKER_ORG}'\/'${DOCKER_REPO}'/' ${values_yaml}
  updates=$((updates+1))
fi

# Tag
last_tag="$(grep "tag:" ${values_yaml} | sed -r 's/\s*tag:\s*(.*)/\1/')"
last_tag=`echo $last_tag | sed -e 's/^[[:space:]]*//'`
if [ ${VERSION} != ${last_tag} ]; then
  >&2 echo "Updating ${values_yaml} to version ${VERSION}"
  sed -i -e 's/\(\s*tag:\).*/\1 '${VERSION}'/' ${values_yaml}
  updates=$((updates+1))
fi


######
# Update chart yaml
######
chart_yaml=${PROJECT_DIR}/chart/Chart.yaml

# version
last_service_helm_ver="$(grep "version:" ${chart_yaml} | sed -r 's/version: (.*)/\1/')"
last_service_helm_ver=`echo $last_service_helm_ver | sed -e 's/^[[:space:]]*//'`
if [[ ${last_service_helm_ver} != ${VERSION} ]]; then
  >&2 echo "Updating ${chart_yaml} to version ${VERSION}"
  sed -i -e 's/version: '${last_service_helm_ver}'/version: '${VERSION}'/' ${chart_yaml}
  updates=$((updates+1))
fi

# app version
last_app_ver="$(grep "version:" ${chart_yaml} | sed -r 's/appVersion: (.*)/\1/')"
last_app_ver=`echo $last_app_ver | sed -e 's/^[[:space:]]*//'`
if [[ ${last_app_ver} != ${VERSION} ]]; then
  >&2 echo "Updating ${chart_yaml} appVersion to version ${VERSION}"
  sed -i -e 's/appVersion: '${last_app_ver}'/appVersion: '${VERSION}'/' ${chart_yaml}
  updates=$((updates+1))
fi

## Re-package
if [[ ${last_service_helm_ver} != ${VERSION} ]] || [[ ${last_tag} != ${VERSION} ]] ||  [[ ${last_org} != ${DOCKER_ORG} ]]; then
  PACKAGE="${PROJECT_DIR}/docs/charts"
  >&2 echo "Repackaging to ${PACKAGE} ..."
  #if [ -f ${PACKAGE}/*.tgz ]; then
  #   rm ${PACKAGE}/*.tgz
  #fi

  helm package "${PROJECT_DIR}/chart" -d ${PACKAGE}
  helm repo index ${PACKAGE}
  updates=$((updates+1))
fi


###
# Update gradle.properties
###
last_gradle_tag=$(grep -oP 'version\=\K([0-9]+\.[0-9]+\.[0-9]+)' ${PROJECT_DIR}/gradle.properties)
if [[ ${last_gradle_tag} != ${VERSION} ]]; then
  >&2 echo "Updating gradle.properties"
  sed -i -e "s/version\W*=.*/version=${VERSION}/" ${PROJECT_DIR}/gradle.properties
  updates=$((updates+1))
fi


exit $((updates))
