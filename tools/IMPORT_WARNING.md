# ⚠️ CRITICAL WARNING: User Import Tool

## DO NOT RUN `import_users.js` UNLESS ABSOLUTELY NECESSARY

This script imports users from the **old project** (readme-40267) to the **current project** (readmev2).

## ⚠️ DANGER: Will Restore Deleted Users

If you have deleted users from readmev2, running this script will **reimport them** from the old project because they still exist there.

## When This Script Should Be Run

✅ **ONLY** during initial data migration
✅ **ONLY** if you need to restore a backup
❌ **NEVER** as part of routine operations
❌ **NEVER** during or after leaderboard resets
❌ **NEVER** if you've recently deleted test/unwanted users

## Safety Features

- ✅ Requires manual "yes" confirmation
- ✅ Logs all imports to `import_users_log.txt`
- ✅ Skips existing users

## Before Running

1. **Confirm** you actually want to restore deleted users
2. **Check** `import_users_log.txt` for last import date
3. **Verify** both Firebase projects are accessible
4. **Backup** current data if needed

## After Running

1. **Review** `import_users_log.txt` for results
2. **Verify** no unwanted users were restored
3. **Document** why the import was necessary

## Alternative Solutions

- **For testing:** Create new test users in readmev2 directly
- **For deleted users:** They were deleted for a reason - don't restore them
- **For leaderboard issues:** Fix the leaderboard logic, don't import old data
