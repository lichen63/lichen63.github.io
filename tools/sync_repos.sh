#!/bin/bash

# Define repository paths
REPO_PUBLIC_PATH="$HOME/Repos/lichen63.github.io"
REPO_PRIVATE_PATH="$HOME/Repos/lichen63.github.io-private"

# Navigate to the private repository
cd "$REPO_PRIVATE_PATH" || exit

# Check if the 'public' remote exists in the private repository
git remote get-url public &> /dev/null

# If the 'public' remote doesn't exist, add it
if [ $? -ne 0 ]; then
    echo "'public' remote not found. Adding it now..."
    git remote add public https://github.com/lichen63/lichen63.github.io.git
else
    echo "'public' remote already exists."
fi

# Now, navigate to the public repository and push changes to main
cd "$REPO_PUBLIC_PATH" || exit
git checkout main  # Ensure you're on the main branch
git add .  # Add all changes (adjust as necessary)

# Ask user for a commit message to be used for both repositories
echo "Enter the commit message for both the public and private repositories:"
read COMMIT_MSG

# Commit and push changes to the public repository
git commit -m "$COMMIT_MSG"  # Commit with the provided message
git push origin main  # Push changes to the public repository

# Now, navigate back to the private repository
cd "$REPO_PRIVATE_PATH" || exit

# Make sure the private repository is on the main branch
git checkout main

# Fetch the latest changes from the public repository
git fetch public

# Merge the changes from the public repository without opening an editor
git merge --no-edit -m "[SYNC] $COMMIT_MSG" public/main

# If there is a conflict, display an error message
if [ $? -ne 0 ]; then
    echo "Merge conflict occurred! Please resolve it manually."
    exit 1
fi

# Check if there are exactly two recent commits (one with [SYNC], one without)
NUM_COMMITS=$(git log --oneline -n 2 | wc -l)

if [ "$NUM_COMMITS" -eq 2 ]; then
    echo "Removing the original commit and keeping only [SYNC] commit..."
    
    # Move HEAD back by one commit while keeping changes staged
    git reset --soft HEAD~1  
    
    # Recommit using only [SYNC] message
    git commit --amend -m "[SYNC] $COMMIT_MSG"  
    
    # Force push to update the remote repository
    git push origin main --force  
else
    # Push normally if there's only one commit
    git push origin main
fi

echo "Synchronization complete!"