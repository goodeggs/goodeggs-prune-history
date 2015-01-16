#!/bin/bash

set -e # exit on first error
COMMAND=$1

if [ ! -f 'package.json' ]; then
  echo "Must be run from the root of a repo"
  exit 1
elif [ -d 'src/orzo' ]; then
  echo "Rewriting will be much more effective if you first remove the orzo subtree."
  echo "You can add it back in afterwards."
  exit 1
fi

if [ "$COMMAND" = 'rewrite' ]; then

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
  echo "Usage: $0 [rewrite|clean]"
  echo
  echo "use clean after a successful rewrite to delete orphaned history"
  echo
fi

