#!env zsh

set -e

read_options() {
    while [[ $# -gt 0 ]]
    do
        local key="$1"
        case "$key" in
            --month)
            OPTION_MONTH='yes'
            OPTION_MONTH_PERIOD="$2"
            if [[ $# -gt 1 ]]
            then
                shift
            fi
            ;;
            --this-month)
            OPTION_THIS_MONTH='yes'
            ;;
            --prev-month)
            OPTION_PREV_MONTH='yes'
            ;;
        esac
        shift
    done
}

check_options() {
    local modes=0
    for mode in "$OPTION_MONTH" "$OPTION_THIS_MONTH" "$OPTION_PREV_MONTH"
    do
        if [ -n "$mode" ]
        then
            modes=$(( $modes + 1 ))
        fi
    done
    if [ 1 != $modes ]
    then
        OPTION_HELP='yes'
    fi
    if [ -n "$OPTION_MONTH" ] && ! [[ "$OPTION_MONTH_PERIOD" =~ '2[0-9]{5}' ]]
    then
        OPTION_HELP='yes'
    fi
}

try_help() {
    if [ -z "$OPTION_HELP" ]
    then
        return
    fi
    cat <<EOF >&2
Generates a copyright report for Kainos Gdansk for specified month.

    --month 'YYYYMM' Generate a report for given YYYY year and MM month.
    --this-month     Generate a report for this month.
    --prev-month     Generate a report for previous month.
EOF
    exit 1
}

resolve_period() {
    local period
    if [ -n "$OPTION_THIS_MONTH" ]
    then
        period=$(date --date 'now' '+%Y%m')
    fi
    if [ -n "$OPTION_PREV_MONTH" ]
    then
        period=$(date --date '1 month ago' '+%Y%m')
    fi
    if [ -n "$OPTION_MONTH" ]
    then
        period=$OPTION_MONTH_PERIOD
    fi

    YEAR=${period[1,4]}
    MONTH=${period[5,6]}
}

git_date() {
    local shift_months=$1
    local shift_days=$2

    date --date "$YEAR-$MONTH-01 + $shift_months month + $shift_days day" '+%Y-%m-%d'
}

git_email() {
    git config --get user.email
}

git_log() {
    git log --remotes --no-merges --author="$GIT_EMAIL" --since="$GIT_SINCE" --until="$GIT_UNTIL" "$@"
}

process_repositories() {
    for d in *(/); do
        cd $d
        if [ -d .git ]; then
            git_log --patch >> "$OUTPUT_TMP"
            git_log --oneline | awk --assign PROJECT="$d" '
            BEGIN {
                COL_DEFAULT = "\033[0m"
                COL_GREEN   = "\033[32m"
                COL_YELLOW  = "\033[33m"
            }
            {
                print COL_GREEN PROJECT, COL_YELLOW $1, COL_DEFAULT $0
            }
            '
        fi
        cd -
    done
}

read_options "$@"
check_options
try_help
resolve_period
GIT_SINCE=$(git_date 0  0)
GIT_UNTIL=$(git_date 1 -1)
GIT_EMAIL="$(git_email)"
OUTPUT_TMP="$(mktemp)"
OUTPUT="$HOME/copyright-${GIT_EMAIL}-${YEAR}${MONTH}.txt.xz"

process_repositories
xz "$OUTPUT_TMP"
mv "$OUTPUT_TMP.xz" "$OUTPUT"

echo "Saved to $OUTPUT"
