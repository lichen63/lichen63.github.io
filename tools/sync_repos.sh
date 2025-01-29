#!/bin/bash

# Define paths using HOME for user-specific directories
REPO_PUBLIC_PATH="$HOME/Repos/lichen63.github.io"
REPO_PRIVATE_PATH="$HOME/Repos/lichen63.github.io-private"

# Clone the public and private repositories if not already cloned
clone_repos() {
  if [ ! -d "$REPO_PUBLIC_PATH" ]; then
    echo "Cloning public repo..."
    git clone https://github.com/lichenliu/lichen63.github.io.git "$REPO_PUBLIC_PATH"
  fi

  if [ ! -d "$REPO_PRIVATE_PATH" ]; then
    echo "Cloning private repo..."
    git clone https://github.com/lichenliu/lichen63.github.io-private.git "$REPO_PRIVATE_PATH"
  fi
}

# Pull the latest changes from both the public and private repositories
pull_latest_changes() {
  echo "Pulling latest changes from the public repo..."
  git -C "$REPO_PUBLIC_PATH" pull

  echo "Pulling latest changes from the private repo..."
  git -C "$REPO_PRIVATE_PATH" pull
}

# Sync commits from public repo to private repo (only unpushed commits)
sync_commits() {
  echo "Checking for unpushed commits in the public repo..."

  # Fetch the latest changes from the public repo
  git -C "$REPO_PUBLIC_PATH" fetch origin

  # Find unpushed commits in the public repo
  UNPUSHED_COMMITS=$(git -C "$REPO_PUBLIC_PATH" log origin/main..HEAD --oneline)

  if [ -z "$UNPUSHED_COMMITS" ]; then
    echo "No unpushed commits detected."
    return 0
  fi

  echo "Unpushed commits found:"
  echo "$UNPUSHED_COMMITS"

  # Check out to the private repo and merge unpushed commits
  git -C "$REPO_PRIVATE_PATH" checkout main
  git -C "$REPO_PRIVATE_PATH" fetch origin

  # Cherry-pick each unpushed commit into the private repo
  while IFS= read -r commit_hash; do
    COMMIT_ID=$(echo $commit_hash | awk '{print $1}')
    echo "Cherry-picking commit $COMMIT_ID into private repo..."
    git -C "$REPO_PRIVATE_PATH" cherry-pick "$COMMIT_ID"
  done <<< "$UNPUSHED_COMMITS"

  # Commit and push changes to private repo
  echo "Pushing changes to private repo..."
  git -C "$REPO_PRIVATE_PATH" push
}

# Execute all operations
clone_repos
pull_latest_changes
sync_commits