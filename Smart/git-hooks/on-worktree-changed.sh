#!/bin/bash

set -e

echo 'Flush smart-web-2.0'
[ ! -d smart-web-2.0/ui-tests/reports/ ] || rm --recursive smart-web-2.0/ui-tests/reports/

echo 'Index smart-web-2.0'
cd smart-web-2.0
ctags --recurse --exclude={bower_components,node_modules,release,tmp}
cd ..

echo 'Index pro-serv-web-app-v2'
cd pro-serv-web-app-v2
ctags --recurse --exclude={libs,node_modules,release,test/jasmine-2.0.2}
cd ..

echo 'Flush Vim/CtrlP'
pwd | \
    sed 's:/:%:g' | \
    while read d; do
        2>/dev/null ls -1 ~/.cache/ctrlp/"$d".txt ~/.cache/ctrlp/"$d"%*.txt
    done | \
    xargs --no-run-if-empty rm
