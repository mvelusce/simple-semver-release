#!/usr/bin/env bash 

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
chmod u+x ./tools/shell-semver/increment_version.sh
increment_version=./tools/shell-semver/increment_version.sh

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

export PROG_VERSION=$next_version

echo "Building"
sh build.sh || { echo 'build failed' ; exit 1; }

echo "Create release notes"
echo "# Release v$next_version\n\n## Changes:\n" > release-notes.md
git log -1 --pretty=oneline --abbrev-commit >> release-notes.md

echo "Release commit"
git config --global user.email "marco.veluscek@skytv.it"
git config --global user.name "Marco Veluscek"

git add --all
git commit -m "Release: v$next_version" || { echo 'release commit failed' ; exit 1; }

echo "Pushing commit to origin"
git push origin master || { echo 'push failed' ; exit 1; }

echo "Creating new tag"
git tag "v$next_version"
echo "Pushing tag to origin"
git push origin --tags || { echo 'tag push failed' ; exit 1; }
