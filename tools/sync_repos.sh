#!/bin/bash

# Define paths using HOME for user-specific directories
REPO_PUBLIC_PATH="$HOME/Repos/lichen63.github.io"
REPO_PRIVATE_PATH="$HOME/Repos/lichen63.github.io-private"

# Clone the public and private repositories if not already cloned
clone_repos() {
  if [ ! -d "$REPO_PUBLIC_PATH" ]; then
    git clone https://github.com/lichenliu/lichen63.github.io.git "$REPO_PUBLIC_PATH"
  fi

  if [ ! -d "$REPO_PRIVATE_PATH" ]; then
    git clone https://github.com/lichenliu/lichen63.github.io-private.git "$REPO_PRIVATE_PATH"
  fi
}

# Pull the latest changes from both the public and private repositories
pull_latest_changes() {
  git -C "$REPO_PUBLIC_PATH" pull
  git -C "$REPO_PRIVATE_PATH" pull
}

# Compare and sync changes from the public repo to the private repo
sync_changes() {
  git -C "$REPO_PRIVATE_PATH" checkout main

  DIFF=$(git -C "$REPO_PUBLIC_PATH" diff --name-status --ignore-submodules -- ':!*.github')

  while IFS=$'\t' read -r status file_path; do
    case "$status" in
      A)  # Added files
        git -C "$REPO_PRIVATE_PATH" checkout main
        git -C "$REPO_PRIVATE_PATH" checkout "$REPO_PUBLIC_PATH/$file_path" "$file_path"
        ;;
      D)  # Deleted files
        git -C "$REPO_PRIVATE_PATH" rm "$file_path"
        ;;
      M)  # Modified files
        git -C "$REPO_PRIVATE_PATH" checkout main
        git -C "$REPO_PRIVATE_PATH" checkout "$REPO_PUBLIC_PATH/$file_path" "$file_path"
        ;;
      R)  # Renamed files
        # Handle renamed files: Rename in the private repo as well
        git -C "$REPO_PRIVATE_PATH" mv "$REPO_PRIVATE_PATH/$(basename "$file_path")" "$file_path"
        ;;
      C)  # Copied files
        # Handle copied files: Copy in the private repo
        cp "$REPO_PUBLIC_PATH/$file_path" "$REPO_PRIVATE_PATH/$file_path"
        ;;
      U)  # Unmerged files (this is a merge conflict, typically handled manually)
        echo "Unmerged file: $file_path. Please resolve conflicts manually."
        ;;
      ??)  # Untracked files (files that are not under version control yet)
        echo "Untracked file: $file_path. Consider adding it to version control."
        ;;
      *)
        echo "Unknown status: $status for file $file_path"
        ;;
    esac
  done <<< "$DIFF"

  # Commit and push changes to the private repository
  git -C "$REPO_PRIVATE_PATH" add .
  git -C "$REPO_PRIVATE_PATH" commit -m "Sync changes from repo_public"
  git -C "$REPO_PRIVATE_PATH" push
}

# Execute all operations
clone_repos
pull_latest_changes
sync_changes