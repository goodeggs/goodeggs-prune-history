#!/bin/bash

set -e # exit on first error
COMMAND=$1

if [ "$COMMAND" = 'truncate' ]; then
  # Inspired by http://git-scm.com/2010/03/17/replace.html
  git co -b temp

  echo "Before:"
  git count-objects -vH
  echo

  # Find first commit less than 2 years old
  TRUNCATE_DATE=`date -r $(( $(date +%s) - 60 * 60 * 24 * 365 * 2 )) +%Y-%m-%d`
  TRUNCATE_COMMIT=`git rev-list -1 --before=${TRUNCATE_DATE} master`
  echo "Truncating history before ${TRUNCATE_DATE} ${TRUNCATE_COMMIT}"

  # Orphan older commits with rebase
  ORPHAN_COMMIT=`echo "Truncated history before ${TRUNCATE_COMMIT}" | git commit-tree ${TRUNCATE_COMMIT}^{tree}`
  git rebase -s ours --onto $ORPHAN_COMMIT $TRUNCATE_COMMIT

  echo
  echo "After truncate:"
  prune-history stat

elif [ "$COMMAND" = 'rewrite' ]; then
  # Derived from http://stackoverflow.com/a/17909526/407845.

  if [ ! -f 'package.json' ]; then
    echo "Must be run from the root of a repo"
    exit 1
  fi

  echo "Before:"
  prune-history stat

  # Record most recent commit so we can update later
  SOURCE_COMMIT=`git rev-list -1 master`

  # Remove orzo subtree
  rm -rf src/orzo
  git add .
  git commit -m"Remove orzo"

  # Remove orzo commits
  git filter-branch -f --commit-filter '
    if [ `git rev-list --all --grep "\[orzo\]" | grep -c "$GIT_COMMIT"` -gt 0 ]
    then
      skip_commit "$@";
    else
      git commit-tree "$@";
    fi
  ' -- --all

  # Remove deleted files from commits
  git ls-files > keep-these.txt
  git filter-branch -f --index-filter " \
    git rm  --ignore-unmatch --cached -qr . ; \
    cat $PWD/keep-these.txt | xargs git reset -q \$GIT_COMMIT -- \
  " --prune-empty  -- --all

  echo $SOURCE_COMMIT > 'filter_branch_old_master.txt'

  echo "After rewrite:"
  prune-history stat

elif [ "$COMMAND" = 'update' ]; then
  SOURCE_COMMIT=`cat filter_branch_old_master.txt`
  git fetch origin
  git rebase --onto HEAD $SOURCE_COMMIT origin/master

elif [ "$COMMAND" = 'trial' ]; then
  SOURCE=$2
  DEST=$3

  rm -rf $DEST
  git clone --depth 20 file:///Users/$USER/Projects/$SOURCE $DEST
  cd $DEST
  prune-history rewrite
  prune-history clean

elif [ "$COMMAND" = 'stat' ]; then
  git count-objects -vH
  echo "commits: $(git rev-list HEAD --count)"

elif [ "$COMMAND" = 'clean' ]; then
  rm -rf .git/refs/original/
  git reflog expire --expire=now --all
  git gc --prune=now

  echo "After clean:"
  prune-history stat

else
  echo
  echo "Usage: $0 [truncate|rewrite|clean|update]"
  echo
  echo "See github.com/goodeggs/goodeggs-prune-history for details"
  echo
fi

