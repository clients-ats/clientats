# CI/CD Pipeline Setup Guide

This document describes the CI/CD pipeline configuration for ClientATS using GitHub Actions.

## Overview

The CI/CD pipeline includes:

1. **Continuous Integration (CI)**
   - Automated testing on every PR and push
   - Code quality checks (formatting, linting, type checking)
   - Security vulnerability scanning
   - Build verification

2. **Continuous Deployment (CD)**
   - Docker image building and pushing
   - Staging deployment
   - Production deployment (on tags)
   - Release notes generation

## Architecture

### CI Pipeline (`.github/workflows/ci.yml`)

Runs on every push to `main`/`develop` and all PRs.

#### Jobs

1. **Test Job**
   - Uses SQLite database (no external services needed)
   - Runs full test suite with coverage
   - Uploads coverage reports to Codecov
   - ~5-10 minutes runtime

2. **Lint & Format Job**
   - Checks code formatting with `mix format`
   - Runs Credo (static analysis)
   - Runs Dialyzer (type checking)
   - ~3-5 minutes runtime

3. **Security Job**
   - Checks for vulnerable dependencies with `mix deps.audit`
   - Runs Sobelow (security linter)
   - ~2-3 minutes runtime

4. **Compile Job**
   - Verifies code compiles without warnings
   - ~3-5 minutes runtime

### CD Pipeline (`.github/workflows/deploy.yml`)

Runs on push to `main` and on version tags.

#### Jobs

1. **Build Job**
   - Builds Docker image with multi-stage build
   - Pushes to GitHub Container Registry (GHCR)
   - Caches layers for faster rebuilds
   - ~8-12 minutes runtime

2. **Deploy to Staging**
   - Deploys built image to staging environment
   - Runs health checks
   - Manual approval (recommended)

3. **Generate Release Notes**
   - Creates GitHub release with auto-generated notes
   - Runs on version tags

4. **Deploy to Production**
   - Requires manual approval (GitHub environment)
   - Deploys to production
   - Sends Slack notification

## Setup Instructions

### 1. GitHub Actions Configuration

#### Secrets Required

Add these secrets in GitHub Settings → Secrets and variables → Actions:

- `STAGING_DEPLOYMENT_TOKEN`: Token for staging deployment (if using CI/CD platform)
- `PRODUCTION_DEPLOYMENT_TOKEN`: Token for production deployment
- `SLACK_WEBHOOK`: Webhook URL for deployment notifications (optional)

#### Environments Configuration

1. Go to Settings → Environments
2. Create `production` environment
3. Add required reviewers for production deployments
4. Add environment-specific secrets if needed

### 2. Docker Image Registry

#### Using GitHub Container Registry (GHCR)

1. Authenticate with GitHub CLI:
```bash
gh auth login
```

2. Grant package write permissions:
```bash
gh secret set GITHUB_TOKEN -b "$(gh auth token)"
```

3. Images automatically push to:
```
ghcr.io/yourusername/clientats:branch-name
ghcr.io/yourusername/clientats:sha-shortcode
```

### 3. Deployment Integration

#### Option A: Kubernetes

Update the deploy job with:
```yaml
- name: Deploy to staging
  run: |
    kubectl set image deployment/clientats \
      clientats=${{ needs.build.outputs.image }} \
      -n staging
    kubectl rollout status deployment/clientats -n staging
```

#### Option B: Docker Compose

Update the deploy job with:
```yaml
- name: Deploy to staging
  run: |
    # SSH into server and pull latest image
    ssh deploy@staging.example.com \
      "cd /opt/clientats && \
       docker-compose pull && \
       docker-compose up -d"
```

#### Option C: Heroku

Add Heroku deployment action:
```yaml
- name: Deploy to Heroku
  uses: akhileshns/heroku-deploy@v3.12.12
  with:
    heroku_api_key: ${{ secrets.HEROKU_API_KEY }}
    heroku_app_name: "clientats-staging"
```

### 4. Local Development with Docker

#### Prerequisites

- Docker and Docker Compose installed

#### Setup

1. **Start services:**
```bash
docker-compose up -d
```

2. **Access the application:**
```bash
# Application runs on http://localhost:4000
# SQLite database is created automatically
# Migrations run on startup
```

#### Using Optional Services

Enable Ollama (LLM):
```bash
docker-compose --profile llm up
```

Enable Redis (caching):
```bash
docker-compose --profile cache up
```

Enable both:
```bash
docker-compose --profile llm --profile cache up
```

### 5. Testing Locally

#### Run Test Suite

```bash
# All tests
mix test

# Specific test file
mix test test/clientats/jobs/search_test.exs

# With coverage
mix test --cover
```

#### Code Quality Checks

```bash
# Format check
mix format --check-formatted

# Format code
mix format

# Credo linting
mix credo

# Dialyzer type checking
mix dialyzer

# Security audit
mix deps.audit

# Sobelow security check
mix sobelow
```

### 6. Containerization

#### Build Docker Image

```bash
# Development image
docker build -t clientats:dev .

# Production image (with optimizations)
docker build --target=runtime -t clientats:prod .
```

#### Run Container

```bash
docker run -p 4000:4000 \
  -v clientats_data:/app/data \
  -e DATABASE_PATH=/app/data/clientats.db \
  -e SECRET_KEY_BASE=your-secret-key \
  -e PHX_SERVER=true \
  clientats:prod
```

## Environment Configuration

### Build Environment Variables

Required for CI/CD runs:

```env
MIX_ENV=test          # For testing
MIX_ENV=prod          # For release builds
```

### Application Environment Variables

Required for deployments:

```env
# Required
SECRET_KEY_BASE=generated-secret-key
PHX_HOST=example.com
LLM_ENCRYPTION_KEY=encryption-key

# Optional
DATABASE_PATH=/custom/path/clientats.db  # Default: platform-specific location
POOL_SIZE=10
HEALTH_CHECK_TOKEN=secret-token
METRICS_TOKEN=metrics-secret-token
OLLAMA_BASE_URL=http://localhost:11434
```

## Workflow Triggers

### CI Pipeline

- ✅ On push to `main` or `develop`
- ✅ On all pull requests to `main` or `develop`
- ✅ Manual trigger via `workflow_dispatch`

### CD Pipeline

- ✅ On push to `main` (staging deployment)
- ✅ On version tags (release + production deployment)
- ✅ Manual trigger with environment selection

## Monitoring and Troubleshooting

### Check Workflow Status

1. Go to repository → Actions
2. View workflow runs and job logs
3. Download test coverage reports

### Common Issues

#### Tests Failing in CI

1. Check database initialization in workflow
2. Verify SQLite database file is created correctly
3. Check for environment variable mismatches
4. Look for test data dependencies

#### Docker Build Failures

1. Check Dockerfile syntax
2. Verify all source files are present
3. Check for missing dependencies in `mix.lock`
4. Review build logs for specific errors

#### Deployment Failures

1. Verify deployment secrets are set correctly
2. Check target environment accessibility
3. Review deployment script logs
4. Verify image was successfully built and pushed

### Debug Tips

1. **Add debug output:**
```yaml
- name: Debug
  run: |
    echo "Image: ${{ needs.build.outputs.image }}"
    docker image ls
    echo "${{ secrets }}" | grep -v "PRIVATE"
```

2. **Run job conditionally:**
```yaml
if: github.event_name == 'pull_request'
```

3. **Use workflow_dispatch for manual testing:**
```yaml
on:
  workflow_dispatch:
    inputs:
      debug_mode:
        description: 'Run in debug mode'
        required: false
        default: false
```

## Advanced Configuration

### Matrix Testing

Test across multiple Elixir/OTP versions:

```yaml
strategy:
  matrix:
    otp-version: ['25.0', '26.0']
    elixir-version: ['1.14.0', '1.15.0']
```

### Conditional Deployments

Only deploy from specific branches:

```yaml
if: github.ref == 'refs/heads/main' && github.event_name == 'push'
```

### Artifact Management

Save and download artifacts:

```yaml
- name: Upload coverage
  uses: actions/upload-artifact@v3
  with:
    name: coverage-report
    path: cover/
```

## Performance Optimization

### Caching Strategy

Current implementation caches:
- Mix dependencies (`deps`)
- Compiled artifacts (via layer caching)

### Build Time Optimization

1. Use layer caching in Docker builds
2. Only run security checks on matrix combinations
3. Use `continue-on-error` for optional checks
4. Run jobs in parallel where possible

## Security Best Practices

1. ✅ Secrets stored in GitHub Secrets (not in code)
2. ✅ Production deployments require manual approval
3. ✅ Code review before merge to main
4. ✅ Dependency vulnerability scanning
5. ✅ Docker image scanning (via container registry)
6. ✅ RBAC via GitHub roles and environments

### Recommended Additions

1. **Branch protection rules:**
   - Require PR reviews
   - Require status checks to pass
   - Require branches to be up to date

2. **CODEOWNERS file:**
```
* @maintainer
/lib/admin/ @admin-team
/lib/llm/ @ml-team
```

3. **Commit signing:**
   - Enable required commit signatures
   - Verify commit authors

## Release Process

### Creating a Release

1. Create a version tag:
```bash
git tag v1.0.0
git push origin v1.0.0
```

2. Pipeline automatically:
   - Builds Docker image
   - Generates release notes
   - Deploys to production
   - Creates GitHub release

### Versioning Strategy

Follow [Semantic Versioning](https://semver.org/):
- `v1.0.0` - Major release
- `v1.1.0` - Feature release
- `v1.0.1` - Bug fix

## Documentation

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Elixir Testing Guide](https://hexdocs.pm/mix/Mix.Tasks.Test.html)
- [Docker Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Kubernetes Deployment](https://kubernetes.io/docs/tasks/run-application/)

## Support

For issues or questions:
1. Check GitHub Actions logs
2. Review workflow YAML syntax
3. Consult team documentation
4. Check status page for platform incidents
