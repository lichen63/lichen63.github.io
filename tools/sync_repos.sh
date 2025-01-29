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

# Compare and sync changes from the public repo to the private repo
sync_changes() {
  echo "Checking for differences between public and private repositories..."

  DIFF=$(git -C "$REPO_PUBLIC_PATH" diff --name-status --ignore-submodules -- ':!*.github')

  # Check if there are any differences
  if [ -z "$DIFF" ]; then
    echo "No changes detected between the repositories."
    return 0
  fi

  echo "Diff output: $DIFF"

  while IFS=$'\t' read -r status file_path; do
    # Handle case where file_path is empty (could happen if diff format is unexpected)
    if [ -z "$file_path" ]; then
      echo "Unknown status for file."
      continue
    fi

    echo "Processing file: $file_path (Status: $status)"

    case "$status" in
      A)  # Added files
        echo "Adding file $file_path to private repo..."
        git -C "$REPO_PRIVATE_PATH" checkout main
        cp "$REPO_PUBLIC_PATH/$file_path" "$REPO_PRIVATE_PATH/$file_path"
        ;;
      D)  # Deleted files
        echo "Removing file $file_path from private repo..."
        git -C "$REPO_PRIVATE_PATH" rm "$file_path"
        ;;
      M)  # Modified files
        echo "Updating file $file_path in private repo..."
        git -C "$REPO_PRIVATE_PATH" checkout main
        cp "$REPO_PUBLIC_PATH/$file_path" "$REPO_PRIVATE_PATH/$file_path"
        ;;
      R)  # Renamed files
        echo "Renaming file $file_path in private repo..."
        git -C "$REPO_PRIVATE_PATH" mv "$REPO_PRIVATE_PATH/$(basename "$file_path")" "$file_path"
        ;;
      C)  # Copied files
        echo "Copying file $file_path to private repo..."
        cp "$REPO_PUBLIC_PATH/$file_path" "$REPO_PRIVATE_PATH/$file_path"
        ;;
      U)  # Unmerged files (manual conflict resolution required)
        echo "Unmerged file: $file_path. Please resolve conflicts manually."
        ;;
      ??)  # Untracked files
        echo "Untracked file: $file_path. Consider adding it to version control."
        ;;
      *)
        echo "Unknown status: $status for file $file_path"
        ;;
    esac
  done <<< "$DIFF"

  # Add and commit the changes to the private repo
  echo "Committing changes to private repo..."
  git -C "$REPO_PRIVATE_PATH" add .
  git -C "$REPO_PRIVATE_PATH" commit -m "Sync changes from repo_public"

  # Push the changes to the private repo
  echo "Pushing changes to private repo..."
  git -C "$REPO_PRIVATE_PATH" push
}

# Execute all operations
clone_repos
pull_latest_changes
sync_changes