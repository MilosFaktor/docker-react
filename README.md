# # React Frontend — Docker Dev/Prod + Secure CI/CD (GitHub Actions OIDC → ECR → Elastic Beanstalk)

This repository contains a React frontend application with:

- Local development in Docker (hot reload via volumes)
- Containerized testing (interactive + CI mode)
- Optimized production build (multi-stage Docker → NGINX)
- CI/CD pipeline that builds in GitHub Actions, pushes to Amazon ECR, and deploys via Elastic Beanstalk

---

## Architecture Overview

LOCAL
Docker (or Docker Compose)
→ Dev server with live reload
→ Test runner inside container

CI (GitHub Actions)
→ Run tests on Pull Request
→ Build Docker image with caching
→ Push image to Amazon ECR
→ Deploy to Elastic Beanstalk

PRODUCTION
Elastic Beanstalk
→ Pulls prebuilt image from ECR
→ Runs container (NGINX serving static React build)

This separates build-time responsibilities (CI) from runtime responsibilities (platform), following artifact-based deployment principles.

---

## Branch Strategy

- `main` is protected
- Development happens in `feature/*` branches
- Pull Requests required to merge
- Tests must pass before merge
- Push to `main` triggers deployment

This ensures production stability and enforces CI validation before deployment.
---

## Docker Images

### Development — Dockerfile.dev

Used for local dev + tests.

```dockerfile
FROM node:20-alpine3.23

WORKDIR /app

COPY package.json .
RUN npm install
COPY . .

CMD ["npm", "run", "start"]
```
Caching Strategy:
- Copying package.json before npm install allows Docker to cache dependency layers.
- npm install only re-runs when package.json changes.

Purpose:
- Runs React dev server
- Supports bind mounts for hot reload
- Matches Node version used in build stage

---

### Production — Dockerfile

Multi-stage build:
1) Build React app
2) Serve static assets via NGINX

```dockerfile
FROM node:20-alpine3.23 AS builder

WORKDIR /app

COPY package.json .
RUN npm install
COPY . .

RUN npm run build

FROM nginx:alpine
EXPOSE 80
COPY --from=builder /app/build /usr/share/nginx/html
```

Benefits:
- Smaller final image (~60MB)
- No dev dependencies in runtime
- Clean build/runtime separation

---

## NPM Commands

```bash
npm run start   # start dev server
npm run test    # run tests (watch mode locally)
npm run build   # production build
```

---

## Local Development (Docker + Volumes)

### Build dev image

```bash
docker build -f Dockerfile.dev -t milosfaktor/nginx .
```

### Run dev container with live reload

```bash
docker run -p 3000:3000 \
  -v /app/node_modules \
  -v $(pwd):/app \
  milosfaktor/nginx:latest
```

Explanation:
- .:/app mounts local source code
- /app/node_modules prevents host override of container dependencies

Open:
http://localhost:3000

---

## Testing in Docker

### Run tests in CI mode (exit after completion)

```bash
docker run -e CI=true milosfaktor/nginx:latest npm test
```

Note:
Use CI=true (not CI=ture) so tests exit automatically.

### Run tests interactively (watch mode)

```bash
docker run -it milosfaktor/nginx:latest npm test
```

---

## Run Tests Inside a Running Dev Container

1) Start container with volumes

```bash
docker run -p 3000:3000 \
  -v /app/node_modules \
  -v $(pwd):/app \
  milosfaktor/nginx:latest
```

2) In a new terminal:

```bash
docker ps
```

3) Execute tests inside container:

```bash
docker exec -it <container_id> npm run test
```

---

## Docker Compose (Dev + Tests)

Run both services:

docker compose -f docker-compose-dev.yml up --build

Example docker-compose-dev.yml:

```yml
version: "3"
services:
  web:
    build:
      context: .
      dockerfile: Dockerfile.dev
    ports:
      - "3000:3000"
    volumes:
      - /app/node_modules
      - .:/app

  tests:
    build:
      context: .
      dockerfile: Dockerfile.dev
    volumes:
      - /app/node_modules
      - .:/app
    command: ["npm", "run", "test"]
```
---

## CI/CD Optimization

Initial setup:
- Elastic Beanstalk built Docker image during deployment
- No Docker layer caching
- ~4 minute deployments

Refactored setup:
- GitHub Actions builds Docker image
- Docker BuildKit caching enabled
- Image tagged with commit SHA
- Image pushed to Amazon ECR
- Elastic Beanstalk pulls prebuilt image

Result:
- Deployment time reduced to ~2 minutes
- Immutable SHA-based deployments
- Deterministic rollbacks
- Clean artifact-based pipeline

---

## AWS Components Used

- Amazon ECR (Docker image registry)
- Elastic Beanstalk (Docker environment)
- IAM Role + OIDC trust policy for GitHub Actions (assume role to push to ECR and deploy)
- IAM Role for Elastic Beanstalk EC2 (ECR pull)

## GitHub Actions Authentication (OIDC)

This pipeline uses **GitHub Actions OIDC** (OpenID Connect) to assume an **AWS IAM Role** at runtime, instead of storing long-lived credentials (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY) as GitHub Secrets.

Benefits:
- No static access keys in GitHub
- Short-lived credentials (assume role)
- Least-privilege access via IAM role + trust policy