# 🪄 GitHub Repository Fetcher

A Ruby serverless application that fetches public repositories from GitHub users using the GitHub API with JWT authentication, deployed on Vercel.

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

- Ruby 3.4.5+
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

5. **Start the server**
   ```bash
   ruby lib/github_repo_fetcher.rb
   ```

## 🔧 Configuration

### Environment Variables

Create a `.env` file with the following variables:

```env
# GitHub App Configuration
GITHUB_APP_ID=your_app_id_here
GITHUB_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----\nYour private key content here\n-----END RSA PRIVATE KEY-----"
GITHUB_WEBHOOK_SECRET=your_webhook_secret_here
GITHUB_CLIENT_ID=Iv23li8mXIuQ2n1WXDLf
GITHUB_CLIENT_SECRET=your_client_secret_here

# Vercel Configuration
VERCEL_URL=https://your-app-name.vercel.app

# Development Configuration
NODE_ENV=development
```

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

### Health Check
```http
GET /api/health
```
Returns the health status of the GitHub API connection.

### API Information
```http
GET /api
```
Returns API information and available endpoints.

### Fetch User Repositories
```http
GET /api/repositories?username=:username
```
Fetches all public repositories for a given GitHub username.

**Response Example:**
```json
{
  "username": "octocat",
  "repositories_count": 2,
  "repositories": [
    {
      "name": "Hello-World",
      "description": "My first repository on GitHub!",
      "languages": {
        "Ruby": 1000,
        "JavaScript": 500
      },
      "forks_count": 5,
      "stargazers_count": 10,
      "html_url": "https://github.com/octocat/Hello-World",
      "created_at": "2023-01-01T00:00:00Z",
      "updated_at": "2023-12-01T00:00:00Z"
    }
  ]
}
```

## 🧪 Testing

Run the test suite:
```bash
bundle exec rspec
```

Test GitHub App authentication:
```bash
ruby bin/test_github_auth.rb
```

## 🚀 Deployment

### Vercel Deployment

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

- **`lib/github_repo_fetcher.rb`**: Main application entry point and library loader
- **`lib/github_repo_fetcher/github_client.rb`**: GitHub API client with JWT authentication
- **`api/index.rb`**: Vercel serverless function entry point (`/api`)
- **`api/health.rb`**: Health check endpoint (`/api/health`)
- **`api/repositories.rb`**: Repository fetching endpoint (`/api/repositories`)
- **`bin/`**: Utility scripts for testing and debugging
- **`spec/`**: Comprehensive test suite with mocking

## 🔮 Next Steps

- [ ] Add webhook support for real-time updates
- [ ] Implement caching for better performance
- [ ] Add rate limiting and request throttling
- [ ] Create a web interface for repository browsing
- [ ] Add support for private repositories (with user authentication)

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
