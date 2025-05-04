#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e
set -o pipefail

# Ensure we're running from the root of the repository
cd $(git rev-parse --show-toplevel)

# Find current branch name
current_branch=$(git rev-parse --abbrev-ref HEAD)

# Find latest tag even if not an ancestor of HEAD
latest_tag=$(git describe --tags --abbrev=0 $(git rev-list --tags --max-count=1))

# Ensure we're not an ancestor of the latest tag
if git merge-base --is-ancestor HEAD "$latest_tag" ; then
  echo "This branch is already released. Please run the script from a branch which is NOT an ancestor of the latest tag."
  exit 1
fi

# Print the trailer from the latest tag
trailers=$(git log --pretty=format:"%(trailers:key=Milestone,valueonly=true,separator=)" $latest_tag..HEAD)

# Extract the biggest change type from the trailers (major, minor, patch)
# If unknown, set to patch
change_type="patch"
if [[ $trailers == *"major"* ]]; then
    change_type="major"
elif [[ $trailers == *"minor"* ]]; then
    change_type="minor"
fi

# Compute new version
IFS='.' read -r major minor patch <<< "$latest_tag"
if [[ $change_type == "major" ]]; then
    major=$((major + 1))
    minor=0
    patch=0
elif [[ $change_type == "minor" ]]; then
    minor=$((minor + 1))
    patch=0
else
    patch=$((patch + 1))
fi
new_version="$major.$minor.$patch"

# Update all JSON files to the latest version
# main => $new_version
find . -name '*.json' -exec sed -i .bck -E "s@#$current_branch@#$new_version@" {} ';'
find . -name '*.json.bck' -delete

# Create the new tag
git checkout --detach
git commit --all --message "Release $new_version" --message "It's time to create the release!" --trailer "Milestone:$change_type"
git tag --sign "$new_version" --message "Release $new_version" --trailer "Milestone:$change_type"
git push origin --tags
git checkout -
