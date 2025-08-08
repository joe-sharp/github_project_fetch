# 🪄 GitHub Project Fetch

<p align="center">
  <img width=400 src="https://raw.githubusercontent.com/joe-sharp/github_project_fetch/refs/heads/images/github-project-fetch.webp">
</p>

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
- **Edge Caching**: Optimized response caching using `stale-while-revalidate` for fast, up-to-date responses

## 📡 API Endpoints

### Fetch User Repositories
```http
curl https://github-project-fetch.vercel.app/api/projects?octocat
```
Fetches all public repositories and their language information for a given GitHub username. Example: `octocat`

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

### Utility Endpoints

#### API Information
```http
curl https://github-project-fetch.vercel.app/api
```
Returns API information and available endpoints.

#### Health Check
```http
curl https://github-project-fetch.vercel.app/api/health
```
Returns the health status of the GitHub API connection.

## 📚 Documentation

> 📝 **Note**: This documentation is for developers who have forked this repository. If you're looking to use the API directly, go back [up here.](#-api-endpoints)

- [Development Guide](docs/development.md) - Setup, testing, and architecture details
- [Deployment Guide](docs/deployment.md) - Installation and deployment instructions
- [CI/CD Documentation](docs/ci-cd.md) - Continuous integration and deployment workflows
- [Vercel Setup Guide](docs/vercel-setup.md) - Vercel-specific configuration

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
