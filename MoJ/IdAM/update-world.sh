#!env zsh

# exit the script on an error
set -e

STATUS_FILE='.update-world.status'
PHASE_NO=0
DOCKER_TAG_AFTER_BUILD=updateworld
DOCKER_TAG_BEFORE_BUILD=preupdateworld
DOCKER_TAG_NOW=$(date +%Y%m%d%H%M%S)
# Actual Dockerfile used to build images
# .md extension has been added in order to be ignored with .dockerignore
DOCKERFILE=Dockerfile.tmp.md

ARG_DOCKER_INCREMENTAL='NO'

read_arguments() {
    while [[ $# -gt 0 ]]
    do
        local key="$1"
        case $key in
            --incremental)
            ARG_DOCKER_INCREMENTAL='YES'
            ;;
        esac
        shift
    done
}

set_up_status_file() {
    [ -e $STATUS_FILE ] || touch $STATUS_FILE
}

tear_down_status_file() {
    rm $STATUS_FILE
}

for_each_project() {
    (( PHASE_NO = $PHASE_NO + 1 ))
    echo "-------------------------------------- PHASE_NO: $PHASE_NO $(date) ------------------------------"
    for d in *(/); do
        if grep --quiet "^$PHASE_NO $d$" $STATUS_FILE; then
            continue
        fi
        echo "---- $d ----"
        pushd $d
        $1
        popd
        echo "$PHASE_NO $d" >> $STATUS_FILE
    done
}

download_changes() {
    if [ -d .git ]; then
        git fetch azure --prune || \
        git fetch azure --prune || \
        git fetch azure --prune || \
        git fetch azure --prune
    fi
}

apply_changes() {
    if [ -d .git ]; then
        git stash save --include-untracked
        git checkout develop
        git reset --hard @{upstream}
    fi
}

download_dev_dependencies() {
    if [ -f pom.xml ]; then
        mvn \
            --define findbugs.skip=true \
            --define pmd.skip=true \
            --define sonar.skip=true \
            --define skip.installnodenpm=true \
            dependency:go-offline \
            dependency:resolve \
            dependency:resolve-plugins \
            dependency:sources \
            test-compile
    fi
    if [ -f package.json ]; then
        npm update
        npm prune
    fi
    if [ -f bower.json ]; then
        bower update
    fi
}

download_ops_dependencies() {
    find . -name 'requirements*.yml' | while read req; do
        pushd "$(dirname $req)"
        local breq="$(basename $req)"
        ansible-galaxy install --role-file "$breq" --force --roles-path roles || \
        ansible-galaxy install --role-file "$breq" --force --roles-path roles || \
        ansible-galaxy install --role-file "$breq" --force --roles-path roles || \
        ansible-galaxy install --role-file "$breq" --force --roles-path roles || \
        ansible-galaxy install --role-file "$breq" --force --roles-path roles || \
        ansible-galaxy install --role-file "$breq" --force --roles-path roles
        popd
    done
}

get_docker_image_name() {
    local name="$(pwd | xargs basename | sed 's/^cpp.idam.am.//;s/^ansible-//')"
    if [ "$name" = 'idam-eventsconsumer-service' ]; then
        name='idam-events-service'
    fi
    echo "$name"
}

build_dev_docker() {
    for bf in dev-tools/docker/base/ dev-tools/docker/monit/; do
        pushd $bf
        make
        popd
    done
}

build_docker() {
    if [ -f Dockerfile ]; then
        local image=$(get_docker_image_name)
        if [ 'YES' = "${ARG_DOCKER_INCREMENTAL}" ]; then
            docker tag ${image}:latest ${image}:${DOCKER_TAG_BEFORE_BUILD} || docker tag idam:2.0 ${image}:${DOCKER_TAG_BEFORE_BUILD}
        else
            docker tag idam:2.0 ${image}:${DOCKER_TAG_BEFORE_BUILD}
        fi
        cat Dockerfile | sed 's/^FROM\s.*/FROM '"${image}"':'"${DOCKER_TAG_BEFORE_BUILD}"'\nUSER root/' > "${DOCKERFILE}"
        docker build --tag ${image}:${DOCKER_TAG_AFTER_BUILD} --file "${DOCKERFILE}" .
        rm "${DOCKERFILE}"
        docker rmi ${image}:${DOCKER_TAG_BEFORE_BUILD}
    fi
}

tag_docker() {
    if [ -f Dockerfile ]; then
        local image=$(get_docker_image_name)
        docker tag ${image}:${DOCKER_TAG_AFTER_BUILD} ${image}:${DOCKER_TAG_NOW}
        docker tag ${image}:${DOCKER_TAG_AFTER_BUILD} ${image}:latest
        docker rmi ${image}:${DOCKER_TAG_AFTER_BUILD}
    fi
}

tag_demo_data() {
    pushd idam-demo-data
    git tag update-world-${DOCKER_TAG_NOW}
    popd
}

clean_up_docker() {
    docker ps     --filter=status=exited  --quiet | xargs --no-run-if-empty docker rm
    docker ps     --filter=status=created --quiet | xargs --no-run-if-empty docker rm
    docker images --filter=dangling=true  --quiet | xargs --no-run-if-empty docker rmi

    docker images | awk '$2 ~ /^[0-9]{14}$/ { print $2 }' | sort --reverse | uniq | tail --lines=+3
}

# go to the script's folder
pushd $0:h

read_arguments
set_up_status_file
for_each_project download_changes
for_each_project apply_changes
for_each_project download_ops_dependencies
clean_up_docker
build_dev_docker
for_each_project build_docker
for_each_project tag_docker
tag_demo_data
for_each_project download_dev_dependencies
tear_down_status_file
