# Multi-stage build for Elixir application
# Stage 1: Builder
FROM elixir:1.15.0-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git

# Copy dependency files
COPY mix.exs mix.lock ./
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get

# Build assets if needed
COPY assets ./assets
RUN if [ -f ./assets/package.json ]; then \
    apk add --no-cache npm && \
    cd assets && npm install && npm run build && \
    cd .. ; \
    fi

# Compile application
COPY lib ./lib
COPY config ./config
COPY priv ./priv
RUN MIX_ENV=prod mix compile

# Build release
RUN MIX_ENV=prod mix release

# Stage 2: Runtime
FROM alpine:3.18

WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache \
    libssl3 \
    ca-certificates \
    curl

# Copy release from builder
COPY --from=builder /app/_build/prod/rel/clientats ./

# Create non-root user
RUN addgroup -S app && adduser -S app -G app
USER app

# Expose port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:4000/health || exit 1

# Start application
CMD ["bin/clientats", "start"]
