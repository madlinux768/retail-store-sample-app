# Technology Stack

## Build System

**Nx monorepo** - All projects managed through nx build system

### Common Commands

```bash
# Build a component
yarn nx build <component>

# Run tests
yarn nx test <component>

# Run integration tests
yarn nx test:integration <component>

# Serve locally (port 8080)
yarn nx serve <component>

# Build container image
yarn nx container <component>

# Run all tests for services
yarn nx run-many -t test --projects=tag:service

# Build all container images
yarn nx run-many -t container --projects=tag:service
```

## Languages & Frameworks

### Java Services (Cart, Orders, UI)
- **Framework**: Spring Boot 3.5.x
- **Java Version**: 21
- **Build Tool**: Maven (mvnw wrapper included)
- **Key Dependencies**: 
  - AWS SDK v2 (DynamoDB, STS)
  - Spring Boot Actuator
  - OpenTelemetry instrumentation
  - Micrometer Prometheus
  - Lombok, MapStruct
- **Testing**: JUnit, Testcontainers
- **Code Style**: Checkstyle (config in `src/misc/style/java/checkstyle.xml`)

### Go Service (Catalog)
- **Version**: Go 1.23+
- **Framework**: Gin web framework
- **Key Dependencies**:
  - GORM (MySQL/SQLite drivers)
  - OpenTelemetry SDK
  - Testcontainers
- **Testing**: Standard Go testing with testcontainers

### Node.js Service (Checkout)
- **Framework**: NestJS 11.x
- **Runtime**: Node.js (latest LTS)
- **Package Manager**: npm/yarn
- **Key Dependencies**:
  - OpenTelemetry auto-instrumentation
  - Redis client
  - Prometheus client
  - Class validator/transformer
- **Testing**: Jest

## Container & Orchestration

- **Container Engine**: Docker
- **Image Registry**: Amazon ECR Public
- **Orchestration**: Docker Compose, Kubernetes, Helm
- **Build Tool**: nx-container plugin

## Infrastructure as Code

- **Terraform**: Multiple deployment patterns (EKS, ECS, App Runner)
- **Helm Charts**: Per-service charts in `src/*/chart/`
- **Helmfile**: Application-level orchestration in `src/app/`

## Development Tools

- **devenv**: Optional development environment setup
- **Tilt**: Local Kubernetes development (Tiltfile in `src/app/`)
- **Prettier**: Code formatting (Java, XML, JSON)
- **Docker Compose**: Local multi-service development

## Observability

- **Metrics**: Prometheus exporters in all services
- **Tracing**: OpenTelemetry OTLP exporters
- **Health Checks**: Spring Actuator, NestJS Terminus

## Testing

- **Unit Tests**: Per-service test suites
- **Integration Tests**: Testcontainers for database/infrastructure
- **E2E Tests**: Cypress (in `src/e2e/`)
- **Load Testing**: Artillery (in `src/load-generator/`)
