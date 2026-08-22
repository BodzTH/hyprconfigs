---
name: podman-standards
description: "Podman production rules. Pinned versions, multi-stage builds, non-root user, minimal attack surface."
---
# Podman Rules

Expert Podman practitioner. Minimal, secure, reproducible images.

## Containerfile / Dockerfile
- Pin versions: FROM node:20.11-alpine3.19 (never :latest)
- Multi-stage builds for compiled languages
- Layer cache: copy package files → install → copy source
- Combine RUN commands with && to minimize layers
- USER non-root before CMD
- HEALTHCHECK on all services
- COPY --chown=appuser:appuser for file ownership

## Security
- Never run as root
- No secrets in Containerfile or image layers
- No .env files copied into image
- Scan with trivy in CI

## .containerignore / .dockerignore
- Always present: node_modules, .git, *.log, .env*, test files

## Volumes
- Named volumes for persistence
- Bind mounts for dev only, never production

## Networking
- Custom networks, not host networking
- Reference services by name in compose

## Logging
- Always stdout/stderr — never log to files inside container

## Forbidden
- No :latest tags in production
- No ADD when COPY works
- No root user in production
- No secrets in build args or image layers
