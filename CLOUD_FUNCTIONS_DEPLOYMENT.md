# Cloud Functions Deployment Guide

## Overview
Updated Cloud Functions with improved quiz generation and weekly leaderboard reset functionality.

## Changes Made

### 1. Enhanced Quiz Generation (`generateBookQuiz`)
**Improvements:**
- ✅ Better error handling and detailed logging
- ✅ Improved JSON parsing (handles code blocks from AI responses)
- ✅ Validates quiz format before saving
- ✅ More specific error messages for debugging
- ✅ Checks for PDF URL existence
- ✅ Validates extracted text length

**Error Messages Now Include:**
- Missing bookId
- Book not found
- No PDF URL
- Insufficient text extracted
- AI service unavailable
- PDF processing failed

### 2. Weekly Leaderboard Reset (`resetWeeklyLeaderboard`)
**New Scheduled Function:**
- Runs every Monday at 00:00 UTC
- Resets `weeklyBooksRead`, `weeklyPoints`, `weeklyReadingMinutes`
- Updates all users in batch
- Logs success/failure

### 3. Manual Weekly Reset (`manualWeeklyReset`)
**New Callable Function:**
- For testing and manual triggers
- Same functionality as scheduled reset
- Can be called from app or Firebase Console

## Deployment Steps

### 1. Deploy Functions
```bash
cd functions
npm install
firebase deploy --only functions
```

### 2. Set Environment Variables
Make sure OpenAI API key is set:
```bash
firebase functions:config:set openai.key="YOUR_OPENAI_API_KEY"
```

Check current config:
```bash
firebase functions:config:get
```

### 3. Enable Cloud Scheduler (for weekly reset)
The scheduled function requires Cloud Scheduler to be enabled in your GCP project:
1. Go to [Cloud Scheduler](https://console.cloud.google.com/cloudscheduler)
2. Enable the API if prompted
3. The function will automatically create a schedule when deployed

## Testing

### Test Quiz Generation
1. **Via Firebase Console:**
   - Go to Functions → generateBookQuiz → Test
   - Payload: `{"data": {"bookId": "YOUR_BOOK_ID"}}`

2. **Check Logs:**
```bash
firebase functions:log --only generateBookQuiz
```

Look for:
- `📝 Generating quiz for book: ...`
- `📚 Fetched book: ...`
- `⬇️ Downloading PDF...`
- `📄 Extracting text...`
- `🤖 Calling AI...`
- `✅ Quiz saved...`

### Test Weekly Reset
1. **Manual Trigger:**
```bash
# Via Firebase Console - Functions → manualWeeklyReset → Test
# Or from app code:
FirebaseFunctions.instance.httpsCallable('manualWeeklyReset').call()
```

2. **Check Scheduled Function:**
```bash
firebase functions:log --only resetWeeklyLeaderboard
```

3. **Verify in Firestore:**
Check any user document for:
- `weeklyBooksRead: 0`
- `weeklyPoints: 0`
- `weeklyReadingMinutes: 0`
- `lastWeeklyReset: [timestamp]`

## Common Issues & Solutions

### Quiz Generation Failures

**Issue: "AI service is currently unavailable"**
- Check OpenAI API key is set correctly
- Verify OpenAI account has credits
- Check OpenAI service status

**Issue: "Failed to process book PDF"**
- Verify PDF URL is accessible
- Check PDF is not corrupted
- Ensure PDF is text-based (not scanned images)

**Issue: "Could not extract enough text from PDF"**
- PDF might be image-based
- PDF might be corrupted
- PDF might have copy protection

**Issue: "Invalid quiz question format"**
- AI response format validation failed
- Check logs for AI response
- May need to retry (AI can occasionally return malformed JSON)

### Weekly Reset Issues

**Issue: Schedule not running**
- Verify Cloud Scheduler is enabled
- Check IAM permissions for Cloud Scheduler
- Look for errors in Cloud Scheduler console

**Issue: Not all users updated**
- Check Firestore write limits
- Verify batch size (current: all users in one batch)
- For large user bases, may need to paginate

## Monitoring

### Key Metrics to Watch
1. **Quiz Generation:**
   - Success rate
   - Average execution time
   - Cache hit rate
   - Error types

2. **Weekly Reset:**
   - Execution success
   - Number of users updated
   - Execution time

### Firebase Console Monitoring
1. Go to Functions → Metrics
2. Monitor:
   - Invocations
   - Execution time
   - Memory usage
   - Errors

### Set Up Alerts
1. Go to Functions → [function name] → Logs
2. Click "Create metric"
3. Set alert conditions for errors

## Cost Optimization

### Quiz Generation
- Quizzes are cached in Firestore (only generated once per book)
- Cost = OpenAI API calls (one per book)
- Estimated: $0.01-0.02 per quiz with gpt-4o-mini

### Weekly Reset
- Runs once per week
- Cost = Firestore batch writes
- For 1000 users: ~$0.0003 per week

## Rollback Plan

If issues occur after deployment:
```bash
# View deployment history
firebase functions:list

# Rollback to previous version
firebase rollback functions
```

Or redeploy from git:
```bash
git checkout <previous-commit>
cd functions
firebase deploy --only functions
```

## Next Steps

1. ✅ Deploy functions
2. ✅ Test quiz generation with a sample book
3. ✅ Trigger manual weekly reset to test
4. ✅ Monitor logs for 24 hours
5. ✅ Verify scheduled reset runs next Monday
6. ✅ Set up error alerts

## Support

If you encounter issues:
1. Check Firebase Functions logs
2. Check Cloud Scheduler logs (for weekly reset)
3. Check OpenAI API status
4. Review Firestore rules and quotas
5. Check GCP billing and quotas

---

**Last Updated:** January 12, 2026
**Functions Version:** 2.0
**Firebase SDK:** v2
