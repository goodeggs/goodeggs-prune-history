#!/bin/bash

set -e # exit on first error
COMMAND=$1

if [ ! -f 'package.json' ]; then
  echo "Must be run from the root of a repo"
  exit 1
fi

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
  git rebase --onto $ORPHAN_COMMIT $TRUNCATE_COMMIT -X ours

  echo
  echo "After truncate:"
  git count-objects -vH

elif [ "$COMMAND" = 'rewrite' ]; then
  # Derived from http://stackoverflow.com/a/17909526/407845.

  if [ -d 'src/orzo' ]; then
    echo "Rewriting will be much more effective if you first remove the orzo subtree."
    echo "You can add it back in afterwards."
    exit 1
  fi

  echo "Before:"
  git count-objects -vH

  git ls-files > keep-these.txt
  git filter-branch --index-filter \
    "git rm  --ignore-unmatch --cached -qr . ; \
    cat $PWD/keep-these.txt | xargs git reset -q \$GIT_COMMIT --" \
    --prune-empty --tag-name-filter cat -- --all

  echo "After rewrite:"
  git count-objects -vH

elif [ "$COMMAND" = 'clean' ]; then
  rm -rf .git/refs/original/
  git reflog expire --expire=now --all
  git gc --prune=now


  echo "After clean:"
  git count-objects -vH

else
  echo
  echo "Usage: $0 [truncate|rewrite|clean]"
  echo
  echo "See github.com/goodeggs/goodeggs-prune-history for details"
  echo
fi

