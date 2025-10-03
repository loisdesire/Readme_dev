# Remove Secret from Git History

## Problem
The secret file is in an OLD commit (d88f82741d62be10526f7ca7ecb396f34f62fbee), so just removing it from the current commit isn't enough.

## Solution: Rewrite Git History

### **Option 1: Reset and Recommit (Easiest)**

This removes the problematic commits and creates a fresh one:

```powershell
cd C:\Users\loisf\Desktop\readme3\Readme_dev

# Find out how many commits ahead you are
git log --oneline -5

# Reset to before the secret was added (adjust number as needed)
# If you're 3 commits ahead, reset 3 commits back
git reset --soft HEAD~3

# Now all changes are unstaged
# Make sure serviceAccountKey.json is NOT staged
git status

# Stage everything EXCEPT the secret file
git add -A
git reset tools/serviceAccountKey.json

# Commit everything
git commit -m "Major update: Cleanup, PDF viewer fixes, AI tagging improvements"

# Force push (rewrites history)
git push --force origin main
```

### **Option 2: Use git filter-branch (More thorough)**

```powershell
cd C:\Users\loisf\Desktop\readme3\Readme_dev

# Remove file from ALL commits in history
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch tools/serviceAccountKey.json" \
  --prune-empty --tag-name-filter cat -- --all

# Force push
git push --force origin main
```

### **Option 3: Use BFG Repo-Cleaner (Fastest for large repos)**

```powershell
# Download BFG from: https://rtyley.github.io/bfg-repo-cleaner/
# Place bfg.jar in your Readme_dev folder

cd C:\Users\loisf\Desktop\readme3\Readme_dev

# Remove the file from all commits
java -jar bfg.jar --delete-files serviceAccountKey.json

# Clean up
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Force push
git push --force origin main
```

---

## Recommended: Option 1 (Reset and Recommit)

This is the simplest and safest:

```powershell
cd C:\Users\loisf\Desktop\readme3\Readme_dev

# Check how many commits you're ahead
git log --oneline origin/main..HEAD

# Count the commits, then reset that many back
# Example: if 3 commits ahead:
git reset --soft HEAD~3

# Verify serviceAccountKey.json is NOT in staging
git status

# If it shows up, remove it:
git reset tools/serviceAccountKey.json

# Stage everything else
git add -A

# Double-check the secret file is NOT staged:
git status | findstr serviceAccountKey

# If nothing shows, you're good! Commit:
git commit -m "Major update: Remove unused files, fix PDF viewer, improve AI tagging"

# Force push (this rewrites history)
git push --force origin main
```

---

## After Successful Push

### **Regenerate Your Firebase Credentials**

Since the old credentials were exposed in Git history (even briefly), it's best practice to:

1. Go to Firebase Console
2. Go to Project Settings → Service Accounts
3. Generate a new private key
4. Replace your local `tools/serviceAccountKey.json` with the new one
5. Delete the old service account key from Firebase

This ensures the exposed credentials can't be used.

---

## Prevention

Your `.gitignore` is now updated, so this won't happen again. The file will stay local only.

---

## Quick Command Summary

```powershell
cd C:\Users\loisf\Desktop\readme3\Readme_dev
git reset --soft HEAD~3
git reset tools/serviceAccountKey.json
git add -A
git commit -m "Major update: Cleanup and improvements"
git push --force origin main
```

**Run these commands to fix the issue!**
