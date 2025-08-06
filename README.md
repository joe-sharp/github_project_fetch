# 🪄 GitHub Project Fetch

A Ruby serverless application that fetches public repositories along with their language data from GitHub users, deployed on Vercel.

## ✨ Features

- **GitHub App Authentication**: Uses JWT tokens for secure GitHub API access
- **Repository Data**: Fetches comprehensive repository information including:
  - Name and description
  - Programming languages with byte counts
  - Fork and star counts
  - Creation and update dates
- **RESTful API**: Clean JSON endpoints for easy integration
- **Error Handling**: Comprehensive error handling for API limits and failures
- **Vercel Ready**: Configured for serverless deployment on Vercel

## 🚀 Quick Start

### Prerequisites

- Ruby 3.3+
- GitHub App with "Read repository data" permissions

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd github_project_fetch
   ```

2. **Install dependencies**
   ```bash
   bundle install
   ```

3. **Set up environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your GitHub App credentials
   ```

4. **Run tests**
   ```bash
   bundle exec rspec
   ```

5. **Run the test suite**
   ```bash
   bundle exec rspec
   ```

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

## 📡 API Endpoints

### API Information
```http
GET /api
```
Returns API information and available endpoints.

### Health Check
```http
GET /api/health
```
Returns the health status of the GitHub API connection.

### Fetch User Repositories (with extra language information)
```http
GET /api/projects?username
```
Fetches all public repositories and their language information for a given GitHub username.

**Response Example:**
```json
{
  "username": "octocat",
  "projects_count": 8,
  "projects": [
    {
      "name": "linguist",
      "description": "Language Savant. If your repository's language is being reported incorrectly, send us a pull request!",
      "languages": {
        "Ruby": 204865,
        "Shell": 910
      },
      "forks_count": 219,
      "stargazers_count": 576,
      "html_url": "https://github.com/octocat/linguist",
      "created_at": "2016-08-02 17:35:14 UTC",
      "updated_at": "2025-08-03 07:36:00 UTC"
    }
   ...
```

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

## 🚀 Deployment

### Preview Vercel Deployment

1. **Install Vercel CLI**
   ```bash
   npm i -g vercel
   ```

2. **Deploy**
   ```bash
   vercel
   ```

3. **Set environment variables in Vercel dashboard**
   - Add all variables from your `.env` file

4. **Update GitHub App URLs**
   - Update your GitHub App's webhook and callback URLs to point to your Vercel deployment

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

### Testing (`spec/`)
- **`github_repo_fetcher/`**: Comprehensive test suite for all services
- **`spec_helper.rb`**: Test configuration and setup

## 🔮 Next Steps

- [ ] Add webhook support for real-time updates

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

---

Built with 🪄 by Joe Sharp
