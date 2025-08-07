# CI/CD Workflows

This project uses GitHub Actions for continuous integration and deployment. There are three main workflows:

## 🔄 PR Workflow (`.github/workflows/pr.yml`)

Triggered on pushes to any branch except `main`.

### Jobs:
1. **checks** - Runs code quality checks
   - Rubocop (Ruby linting)
   - RSpec (unit tests, excluding e2e tests)

**Note**: Vercel preview deployment is currently disabled due to Ruby version compatibility issues with Vercel's build system.

## 🚀 Main Workflow (`.github/workflows/main.yml`)

Triggered on pushes to the `main` branch.

### Jobs:
1. **checks** - Runs code quality checks
   - Rubocop (Ruby linting)
   - RSpec (unit tests, excluding e2e tests)

**Note**: Vercel production deployment is currently disabled due to Ruby version compatibility issues with Vercel's build system.

## 🧪 E2E Tests Workflow (`.github/workflows/e2e-tests.yml`)

Triggered by Vercel repository dispatch events when deployments complete.

### Jobs:
1. **test-preview** - Tests preview deployments
   - Runs when `vercel.deployment.success` or `vercel.deployment.ready` events are received
   - Only executes for preview environment deployments
   - Uses `bin/test_api.rb` with the preview URL
   - Includes Chrome setup for browser-based testing

2. **test-production** - Tests production deployments
   - Runs when `vercel.deployment.success` or `vercel.deployment.ready` events are received
   - Only executes for production environment deployments
   - Uses `bin/test_api.rb` without arguments (tests production URL)
   - Includes Chrome setup for browser-based testing

## 🔐 Required Secrets

The following secrets must be configured in your GitHub repository settings:

### Vercel Secrets
- `VERCEL_TOKEN` - Your Vercel API token
- `VERCEL_ORG_ID` - Your Vercel organization ID
- `VERCEL_PROJECT_ID` - Your Vercel project ID

### Optional Secrets
- `VERCEL_AUTOMATION_BYPASS_SECRET` - Used to bypass Vercel's protection for automated testing

## 🛠️ Setup Instructions

1. **Get Vercel credentials:**
   ```bash
   # Install Vercel CLI
   npm i -g vercel

   # Login and link project
   vercel login
   vercel link

   # Get project info
   vercel project ls
   ```

2. **Add secrets to GitHub:**
   - Go to your repository settings
   - Navigate to "Secrets and variables" → "Actions"
   - Add the required secrets

3. **Test the workflows:**
   - Create a pull request to test the PR workflow
   - Merge to main to test the production workflow
   - E2E tests will run automatically when Vercel deployments complete

## 📋 Workflow Features

- **Dependency Caching**: Ruby gems are cached for faster builds
- **Parallel Execution**: Jobs run in parallel where possible
- **Fail Fast**: If checks fail, deployment is skipped
- **E2E Testing**: Automated testing of deployed applications via repository dispatch
- **Chrome Integration**: Uses headless Chrome for browser-based testing
- **Environment-Specific Testing**: Separate test jobs for preview and production environments

## ⚙️ Vercel Configuration

**Important**: You should disable Vercel's automatic deployments to avoid conflicts with GitHub Actions.

See [`docs/vercel-setup.md`](./vercel-setup.md) for detailed instructions.

## 🔍 Troubleshooting

- **Rubocop failures**: Check code style with `bundle exec rubocop`
- **RSpec failures**: Run tests locally with `bundle exec rspec`
- **Deployment failures**: Verify Vercel secrets are correct
- **E2E test failures**: Check if the deployed URL is accessible and API is responding
- **Duplicate deployments**: Make sure Vercel auto-deployments are disabled
- **Ruby version issues**: Vercel deployment jobs are disabled due to Ruby support issues

## 🚧 Current Limitations

- Vercel deployment jobs are temporarily disabled due to Ruby support issues
