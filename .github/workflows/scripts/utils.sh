
get_last_tag() {
 

 # These environment vars should be set by the GIT Actions environment
 if [ -z "${GITHUB_REPOSITORY}" ]; then
  >&2 echo "required environment var (GITHUB_REPOSITORY) was not set"
  return 1
 fi

 if [ -z "${GITHUB_API_URL}" ]; then
  >&2 echo "required environment var (GITHUB_API_URL) was not set"
  return 1
 fi

 >&2 echo "retrieving last tag from git ${GITHUB_API_URL} for repo ${GITHUB_REPOSITORY}"
 URL="${GITHUB_API_URL}/repos/${GITHUB_REPOSITORY}/releases"
 last_tag=$(wget -q "${URL}" -O - | jq -r ". | first | .tag_name" | grep -Po "[vV]?\K[0-9]+\.[0-9]+\.[0-9]+")

 if [ -z "${last_tag}" ]; then
   if [ -f "gradle.properties" ]; then
     >&2 echo "No relase found in git, Looking in gradel properties for version"
     last_tag=$(grep -oP 'version\=\K([0-9]+\.[0-9]+\.[0-9]+)' gradle.properties)
   fi
 fi

 if [ -z "${last_tag}" ]; then
   last_tag="0.0.0"
 fi

 echo "${last_tag}"
 return 0

}

image_exists_with_tag() {
 SERVER=$1
 ORG=$2
 DOCKER_REPO=$3
 TAG=$4

  docker pull "${SERVER}/${ORG}/${DOCKER_REPO}:${TAG}" >& /dev/null
  RC=$?
  if [ $RC == 0 ]; then
    echo "true"
  else
    echo "false"
  fi
}

increment_tag_level() {
  TAG=$1
  HOW=$2


  MAJOR=$(echo "${TAG}" | cut -d "." -f 1)
  MINOR=$(echo "${TAG}" | cut -d "." -f 2)
  PATCH=$(echo "${TAG}" | cut -d "." -f 3)

  case "${HOW}" in
    "release-major")
	    MAJOR=$((MAJOR+1))
	    MINOR=0
	    PATCH=0
	    ;;
    "release-minor")
	    MINOR=$((MINOR+1))
	    PATCH=0
	    ;;
    "release-patch")
	    PATCH=$((PATCH+1))
	    ;;
    *)
	    PATCH=$((PATCH+1))
	    ;;
  esac
  echo "${MAJOR}.${MINOR}.${PATCH}"
}

calculate_tag() {
  DOCKER_REPO=$1
  DOCKER_SERVER=$2
  DOCKER_ORG=$3
  RELEASE_TYPE=$4

  last_tag=$(get_last_tag)
  TAG=$(increment_tag_level "${last_tag}" "${RELEASE_TYPE}")

  # if there is already a docker image, then we need a new tag
  RC=$(image_exists_with_tag "${DOCKER_SERVER}" "${DOCKER_ORG}" "${DOCKER_REPO}" "${TAG}" )
  while [ $RC == "true" ]; do
    >&2 echo "Tag ${TAG} already has a docker image associated with it, incrementing again..."
    TAG=$(increment_tag_level "${TAG}" "release-patch")
    RC=$(image_exists_with_tag "${DOCKER_SERVER}" "${DOCKER_ORG}" "${DOCKER_REPO}" "${TAG}")
  done

  echo "${TAG}"
}

