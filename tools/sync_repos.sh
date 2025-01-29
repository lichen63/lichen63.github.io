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
    # Extract the commit hash
    COMMIT_ID=$(echo $commit_hash | awk '{print $1}')
    
    # Debugging: check if the commit hash is valid
    echo "Trying to cherry-pick commit: $COMMIT_ID"

    # Ensure the commit exists in the public repo
    git -C "$REPO_PUBLIC_PATH" cat-file commit "$COMMIT_ID" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
      echo "Commit $COMMIT_ID does not exist in the public repo."
      continue
    fi

    # Try cherry-picking the commit
    git -C "$REPO_PRIVATE_PATH" cherry-pick "$COMMIT_ID"
    if [ $? -ne 0 ]; then
      echo "Failed to cherry-pick commit $COMMIT_ID. Please check the commit hash or resolve conflicts manually."
      continue
    fi
  done <<< "$UNPUSHED_COMMITS"

  # Commit and push changes to private repo
  echo "Pushing changes to private repo..."
  git -C "$REPO_PRIVATE_PATH" push
}

# Execute all operations
clone_repos
pull_latest_changes
sync_commits