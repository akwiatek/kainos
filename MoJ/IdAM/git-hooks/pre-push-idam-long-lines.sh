#!/bin/sh

remote="$1"
url="$2"

z40=0000000000000000000000000000000000000000

while read local_ref local_sha remote_ref remote_sha
do
    if [ "$local_sha" = $z40 ]
    then
        # Handle delete
        :
    else
        if [ "$remote_sha" = $z40 ]
        then
            # New branch, examine all commits
            range="$local_sha"
        else
            # Update to existing branch, examine new commits
            range="$remote_sha..$local_sha"
        fi

        # Check for IdAM too long lines
        git show --no-color --find-copies --find-renames --unified=0 "$range" \
            | sed --silent --regexp-extended '
                # for each file
                /^diff --git /,/^[+-]/! {
                    # check only given file types
                    /[.](groovy|java|js)(.j2)?$/I,/^[+-]/! {
                        /^[+].{100}./p
                    }
                }' \
            | grep --color=no '.'
        if [ 0 == $? ]
        then
            echo >&2 "Too long lines found in commit $local_ref, not pushing"
            exit 1
        fi
    fi
done

exit 0
