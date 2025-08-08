# 🚀 Deployment Guide

## Prerequisites

- Ruby 3.3+
- GitHub App with "Read repository data" permissions

## Installation

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

## Preview Vercel Deployment

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

5. **Configure Deployment Settings**
   - Follow the [Vercel Setup Guide](vercel-setup.md) to configure deployment settings
   - ⚠️ Note: Vercel auto-deployments should be disabled to ensure proper CI/CD workflow

6. **Known Limitations**
   - There are currently some Ruby version compatibility issues with Vercel's build system
   - Deployments are managed through GitHub Actions for better control and testing

## Edge Caching

The API is optimized with response caching using stale-while-revalidate:
- API Documentation: 1 hour cache, 2 hours stale
- Health Checks: 10 seconds cache, 1 minute stale
- Project Data: 10 minutes cache, 20 minutes stale
