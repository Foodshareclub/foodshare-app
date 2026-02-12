# Google Play Store Setup Guide

This guide walks you through setting up automated deployment to Google Play Store.

## Prerequisites

- Google Play Console account
- App created in Play Console
- Admin access to the app

## Step 1: Create Service Account

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select or create a project
3. Navigate to **IAM & Admin** → **Service Accounts**
4. Click **Create Service Account**
5. Name: `foodshare-android-deploy`
6. Click **Create and Continue**
7. Skip role assignment (we'll do this in Play Console)
8. Click **Done**

## Step 2: Generate Service Account Key

1. Click on the service account you just created
2. Go to **Keys** tab
3. Click **Add Key** → **Create new key**
4. Select **JSON** format
5. Click **Create**
6. Save the downloaded JSON file securely

## Step 3: Grant Play Console Access

1. Go to [Google Play Console](https://play.google.com/console/)
2. Select your app
3. Go to **Setup** → **API access**
4. Click **Link** next to your service account
5. Grant the following permissions:
   - **Releases**: Create and edit releases
   - **Release to production, exclude devices, and use Play App Signing**: Manage
6. Click **Invite user**
7. Click **Send invitation**

## Step 4: Add Secret to GitHub

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `PLAY_STORE_SERVICE_ACCOUNT`
5. Value: Paste the entire contents of the JSON file from Step 2
6. Click **Add secret**

## Step 5: Verify Setup

1. Create a new release or re-run the deployment workflow
2. Check GitHub Actions for successful deployment
3. Verify the release appears in Play Console

## Required Secrets

Your repository needs these secrets configured:

- ✅ `SUPABASE_URL` - Supabase API URL
- ✅ `SUPABASE_ANON_KEY` - Supabase anonymous key
- ✅ `SENTRY_DSN` - Sentry DSN (optional)
- ✅ `KEYSTORE_PASSWORD` - Android keystore password
- ✅ `KEY_ALIAS` - Android key alias
- ✅ `KEY_PASSWORD` - Android key password
- ⚠️  `PLAY_STORE_SERVICE_ACCOUNT` - Play Store service account JSON

## Troubleshooting

### "Unknown error occurred"
- Verify service account JSON is valid
- Check service account has proper permissions in Play Console
- Ensure app is created in Play Console

### "Package not found"
- Verify `packageName` in workflow matches Play Console
- Ensure app is published (at least to internal testing)

### "Insufficient permissions"
- Re-check service account permissions in Play Console
- Ensure invitation was accepted

## Manual Deployment

If automated deployment fails, you can manually upload:

1. Download the AAB from GitHub Actions artifacts
2. Go to Play Console → **Release** → **Production**
3. Click **Create new release**
4. Upload the AAB file
5. Fill in release notes
6. Click **Review release** → **Start rollout to Production**

## Release Tracks

The workflow deploys to **production** by default. To change:

Edit `.github/workflows/ci-cd.yml`:
```yaml
track: internal  # or alpha, beta, production
```

## Support

For issues with:
- **Service account**: Check Google Cloud Console
- **Play Console access**: Contact your Play Console admin
- **GitHub Actions**: Check workflow logs
- **App signing**: Verify keystore configuration

---

**Next Steps:**
1. Complete the setup above
2. Create a new release: `gh release create v3.0.4`
3. Monitor deployment in GitHub Actions
4. Verify in Play Console
