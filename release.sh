#!/usr/bin/env bash 

set -e

TOOL_SOURCE="${BASH_SOURCE[0]}"
while [ -h "$TOOL_SOURCE" ] ; do TOOL_SOURCE="$(readlink "$TOOL_SOURCE")"; done
ssr_home="$( cd -P "$( dirname "$TOOL_SOURCE" )" && pwd )"

git rev-parse --abbrev-ref --symbolic-full-name '@{u}' > /dev/null || {
  echo 'No upstream set for current branch: aborting release'
  exit 1
}

upstream='@{u}'
local_branch=$(git rev-parse @)
remote_branch=$(git rev-parse "$upstream")
BASE=$(git merge-base @ "$upstream")

[[ "$local_branch" = "$remote_branch" ]] || {
  echo "Local branch ${local_branch} and remote ${remote_branch} are not aligned: aborting release"
  exit 1
}

git_dirty=$(git status --porcelain)
[[ -n "$git_dirty" ]] && {
  echo 'Uncommitted changes detected: aborting release'
  exit 1
}

SCOPE="$1"

if [ -z "$SCOPE" ]; then
    echo "Scope is empty. Trying to get from commit message..."
    SCOPE=$(git log -1 | egrep -ohi '(MAJOR|MINOR|PATCH)' | head -1 | tr '[:upper:]' '[:lower:]')
fi

if [ -z "$SCOPE" ]; then
  echo "Scope is still empty. Setting it to patch..."
  SCOPE="patch"
fi

echo "Using scope $SCOPE"

last_version=$(git -c 'versionsort.suffix=-' \
    ls-remote --exit-code --refs --sort='version:refname' --tags origin '*.*.*' \
    | egrep -o '[0-9]+\.[0-9]+\.[0-9]+' \
    | tail -1)
echo "Last version: $last_version"

if [ -z "$last_version" ]; then
    echo "ERROR: Empty last version"
    exit 1
fi

echo "Getting next version, without tagging"
chmod u+x "${ssr_home}/tools/shell-semver/increment_version.sh"
increment_version="${ssr_home}/tools/shell-semver/increment_version.sh"

next_version=$($increment_version -p $last_version)
if [ "$SCOPE" = "major" ]; then
    next_version=$($increment_version -M $last_version)
fi
if [ "$SCOPE" = "minor" ]; then
    next_version=$($increment_version -m $last_version)
fi

echo "Publishing with version: $next_version"

if [ -z "$next_version" ]; then
    echo "ERROR: Empty next version"
    exit 1
fi


tag_name="v${next_version}"
tag_exists=$(git tag -l "${tag_name}")
[[ -n "$tag_exists" ]] && {
  echo "Tag ${tag_name} exists: aborting release"
  exit 1
}

echo "Creating new tag ${tag_name}"
git tag "$tag_name"
echo "Pushing tag to origin"
git push origin --tags

export PROG_VERSION=$next_version

echo "Building"
sh build.sh

echo "Create release notes"
git log -1 | tail -n +5 > release-notes.md
