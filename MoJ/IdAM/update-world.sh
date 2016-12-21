#!env zsh

# exit the script on an error
set -e

STATUS_FILE='.update-world.status'
PHASE_NO=0
DOCKER_TAG_TMP=updateworld
DOCKER_TAG_NOW=$(date +%Y%m%d%H%M%S)

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
        cd $d
        $1
        cd -
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

download_dependencies() {
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
         npm install --ignore-scripts chromedriver
         HTTPS_PROXY='' HTTP_PROXY='' node ./node_modules/chromedriver/install.js
         npm update
    fi
    if [ -f bower.json ]; then
        bower update
    fi
    find . -name 'requirements*.yml' | while read req; do
        ansible-galaxy install --role-file "$req" --force --roles-path roles || \
        ansible-galaxy install --role-file "$req" --force --roles-path roles || \
        ansible-galaxy install --role-file "$req" --force --roles-path roles || \
        ansible-galaxy install --role-file "$req" --force --roles-path roles
    done
}

get_docker_image_name() {
    local name="$(pwd | xargs basename | sed 's/^cpp.idam.am.//;s/^ansible-//')"
    if [ "$name" = 'idam-eventsconsumer-service' ]; then
        name='idam-events-service'
    fi
    if [ "$name" = 'c2istub-openig' ]; then
        name='c2istub-service'
    fi
    echo "$name"
}

build_base_docker() {
    for bf in dev-tools/docker/ dev-tools/docker/monit/; do
        cd
        make
        cd -
    done
}

build_docker() {
    if [ -f Dockerfile ]; then
        local image=$(get_docker_image_name)
        docker build . --tag ${image}:${DOCKER_TAG_TMP}
    fi
}

tag_docker() {
    if [ -f Dockerfile ]; then
        local image=$(get_docker_image_name)
        docker tag ${image}:${DOCKER_TAG_TMP} ${image}:${DOCKER_TAG_NOW}
        docker tag ${image}:${DOCKER_TAG_TMP} ${image}:latest
    fi
}

# go to the script's folder
cd $0:h

set_up_status_file
for_each_project download_changes
for_each_project apply_changes
for_each_project download_dependencies
build_base_docker
for_each_project build_docker
for_each_project tag_docker
tear_down_status_file
