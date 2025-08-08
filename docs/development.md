# 🧙🏻 Development Guide

## 🔧 Configuration

### Environment Variables

Copy the example environment file and update it with your values:

```bash
cp .env.example .env
```

Then edit `.env` and replace the placeholder values with your actual GitHub App configuration.

### GitHub App Setup

1. Go to [GitHub App Settings](https://github.com/settings/apps/new)
2. Create a new app with:
   - **App name**: Repository Fetcher (or your preferred name)
   - **Homepage URL**: Your Vercel deployment URL
   - **Callback URL**: `https://your-vercel-url.vercel.app/auth/callback`
   - **Webhook URL**: `https://your-vercel-url.vercel.app/webhook`
   - **Permissions**: Repository access (Read)
3. Generate a private key and save it
4. Note your App ID and Client Secret

## 🧪 Testing

Run the test suite:
```bash
bundle exec rspec
```

### Automated Testing with Guard

Guard provides automated testing and code quality checks that run whenever you change files:

```bash
# Start Guard (runs tests and RuboCop automatically on file changes)
bundle exec guard

# Start Guard without initial run
bundle exec guard --no-interactions
```

Guard will automatically:
- Run RuboCop when Ruby files change
- Run RSpec tests when code or spec files change
- Output results to `tmp/rubocop_status.txt` and `tmp/rspec_status.txt`
- Display a status summary showing current test and code quality status

### Status Summary

Get a quick overview of your project's health:

```bash
# Run status summary (shows RuboCop and RSpec results)
bin/status_summary
```

The status summary displays:
- ✅ RuboCop: Clean code style or ⚠️ with offense count
- ✅ Tests: All passing or ❌ with failure count

### Manual Testing

Test GitHub App authentication:
```bash
bin/test_github.rb
```

Debug GitHub authentication:
```bash
bin/debug_github_auth.rb
```

E2E Test:
```bash
# Test against production URL
bin/test_api.rb

# Test against preview URL
bin/test_api.rb https://your-preview-url.vercel.app
```

## 🏗️ Architecture

### Core Library (`lib/`)
- **`github_repo_fetcher.rb`**: Main application entry point and library loader
- **`github_repo_fetcher/github_client.rb`**: GitHub API client with JWT authentication
- **`github_repo_fetcher/project_service.rb`**: Service for fetching and processing repository data
- **`github_repo_fetcher/health_service.rb`**: Health check service
- **`github_repo_fetcher/api_response_service.rb`**: Response formatting and API response handling

### API Endpoints (`api/`)
- **`index.rb`**: Vercel serverless function entry point (`/api`)
- **`health.rb`**: Health check endpoint (`/api/health`)
- **`projects.rb`**: Projects (repositories) fetching endpoint (`/api/projects`)

### Utilities (`bin/`)
- **`test_github.rb`**: Test GitHub App authentication
- **`debug_github_auth.rb`**: Debug authentication issues
- **`status_summary`**: Display project health status

### Testing (`spec/`)
- **`github_repo_fetcher/`**: Comprehensive test suite for all services
- **`spec_helper.rb`**: Test configuration and setup
