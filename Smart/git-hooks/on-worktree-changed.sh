#!/usr/bin/zsh --

set -e

echo 'Flush smart-web-2.0'
[ ! -d smart-web-2.0/ui-tests/reports/ ] || rm --recursive smart-web-2.0/ui-tests/reports/

echo 'Index smart-web-2.0'
if [ -d smart-web-2.0/ ]; then
    pushd smart-web-2.0
    ctags --recurse --exclude={compiledts,node_modules,release,tmp}
    if [ -d node_modules ]; then
        echo 'Download JS dependencies for smart-web-2.0'
        yarn --prefer-offline
    fi
    popd
fi

echo 'Index pro-serv-web-app-v2'
if [ -d pro-serv-web-app-v2/ ]; then
    pushd pro-serv-web-app-v2
    ctags --recurse --exclude={libs,node_modules,release,test/jasmine-2.0.2}
    if [ -d node_modules ]; then
        echo 'Download JS dependencies for pro-serv-web-app-v2'
        yarn --prefer-offline
    fi
    popd
fi

echo 'Flush Vim/CtrlP'
pwd | \
    sed 's:/:%:g' | \
    while read d; do
        2>/dev/null ls -1 ~/.cache/ctrlp/"$d".txt ~/.cache/ctrlp/"$d"%*
    done | \
    xargs --no-run-if-empty rm

echo 'Migrate Smart DBs'
if [ -d nuvo/docker/migrator/ ]; then
    pushd nuvo/docker/migrator/
    ./migrator-apply.sh --skip-reports
    popd
fi

echo 'Latest DB migrations'
psql smart --no-psqlrc --tuples-only --command '
    SELECT
        db_schema,
        name
    FROM  migrator.migrator_migrations
    WHERE created > now() - INTERVAL '"'"'5 minutes'"'"'
    AND   name LIKE '"'"'202%'"'"'
    ORDER BY id ASC;
'
