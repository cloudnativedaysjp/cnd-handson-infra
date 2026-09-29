#!/usr/bin/env bash
# Create student-N branches with example.com replaced by vmNN.handson.cloudnativedays.jp.
# Run inside a clone of the hands-on repository (e.g. cnd-handson). Nothing is pushed.
#
# Usage: create-student-branches.sh <num_students> [base_ref]
set -euo pipefail

num=${1:?usage: $0 <num_students> [base_ref]}
base=${2:-origin/main}

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "working tree has uncommitted changes" >&2
  exit 1
fi

git fetch -q origin
orig=$(git rev-parse --abbrev-ref HEAD)
branches=()

for i in $(seq 1 "$num"); do
  domain=$(printf 'vm%02d.handson.cloudnativedays.jp' "$i")
  branch="student-$i"
  git switch -q -C "$branch" "$base"
  if git grep -qI 'example\.com'; then
    git grep -lzI 'example\.com' | xargs -0 perl -pi -e "s/example\\.com/$domain/g"
    git commit -qam "chore: replace example.com with $domain"
  fi
  branches+=("$branch")
  echo "$branch -> $domain"
done

git switch -q "$orig"
echo
echo "Review, then push (force is needed when regenerating):"
echo "  git push -f origin ${branches[*]}"
