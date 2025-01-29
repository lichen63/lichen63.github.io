#!/bin/bash

# Define repository paths
REPO_PUBLIC_PATH="$HOME/Repos/lichen63.github.io"
REPO_PRIVATE_PATH="$HOME/Repos/lichen63.github.io-private"

# Function to add private remote if not already added
add_private_remote() {
  # Check if the private remote already exists
  if ! git remote get-url private &>/dev/null; then
    echo "Adding private remote..."
    git remote add private https://github.com/lichen63/lichen63.github.io-private.git
  else
    echo "Private remote already exists."
  fi
}

# Function to add, commit, and push changes
push_changes() {
  echo "Adding changes to staging area..."
  git add .

  # Prompt user to enter commit message
  echo "Enter commit message: "
  read -r commit_message

  # Check if commit message is empty
  if [ -z "$commit_message" ]; then
    echo "Commit message cannot be empty. Please try again."
    exit 1
  fi

  echo "Committing changes with message: $commit_message"
  git commit -m "$commit_message"

  # Push to origin (public repo)
  echo "Pushing changes to public repo..."
  git push origin main

  # Push changes to private repo with a custom sync message
  echo "Pushing changes to private repo..."
  
  # Switch to private repo directory
  cd "$REPO_PRIVATE_PATH" || { echo "Private repo path not found."; exit 1; }

  # Fetch latest changes from public repo
  echo "Fetching latest changes from public repo..."
  git fetch origin

  # Checkout main branch of private repo and merge changes
  echo "Switching to private repo main branch..."
  git checkout main

  # Merge public repo's main branch into private repo
  echo "Merging public repo main branch into private repo..."
  git merge "$REPO_PUBLIC_PATH/main" --allow-unrelated-histories --no-edit

  # Commit the changes to the private repo with sync message
  echo "Committing changes to private repo..."
  git commit --amend --no-edit -m "[SYNC] $commit_message"

  # Push the changes to private repo
  echo "Pushing changes to private repo..."
  git push private main
}

# Main script execution
cd "$REPO_PUBLIC_PATH" || { echo "Public repo path not found."; exit 1; }

# Add private remote if not present
add_private_remote

# Add, commit, and push changes
push_changes

echo "Changes synced between public and private repositories."