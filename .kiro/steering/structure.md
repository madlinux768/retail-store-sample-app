# Project Structure

## Repository Layout

```
├── src/                    # Application services
│   ├── cart/              # Shopping cart service (Java/Spring Boot)
│   ├── catalog/           # Product catalog service (Go)
│   ├── checkout/          # Checkout orchestration (Node.js/NestJS)
│   ├── orders/            # Order management (Java/Spring Boot)
│   ├── ui/                # Frontend web UI (Java/Spring Boot)
│   ├── app/               # Application-level deployment configs
│   ├── e2e/               # End-to-end tests (Cypress)
│   ├── load-generator/    # Load testing (Artillery)
│   └── misc/              # Shared resources (style configs)
├── terraform/             # Infrastructure as Code
│   ├── eks/               # EKS deployment patterns
│   ├── ecs/               # ECS deployment patterns
│   ├── apprunner/         # App Runner deployment
│   └── lib/               # Reusable Terraform modules
├── samples/               # Sample data (products, images)
├── scripts/               # Build and deployment scripts
├── docs/                  # Documentation and diagrams
└── oss/                   # Open source attribution
```

## Service Structure

Each service follows a consistent pattern:

```
src/<service>/
├── src/                   # Source code
├── chart/                 # Helm chart
├── Dockerfile             # Container build
├── docker-compose.yml     # Local development
├── project.json           # Nx project configuration
├── openapi.yml            # API specification (if applicable)
├── README.md              # Service documentation
└── scripts/               # Service-specific scripts
```

### Java Services (cart, orders, ui)
```
src/<service>/
├── src/
│   ├── main/
│   │   ├── java/com/amazon/sample/  # Application code
│   │   └── resources/               # Config, templates, static assets
│   └── test/                        # Unit and integration tests
├── pom.xml                          # Maven configuration
├── mvnw, mvnw.cmd                   # Maven wrapper
└── .mvn/                            # Maven wrapper config
```

### Go Service (catalog)
```
src/catalog/
├── api/                   # API handlers
├── config/                # Configuration
├── controller/            # Controllers
├── model/                 # Data models
├── repository/            # Data access layer
├── middleware/            # HTTP middleware
├── httputil/              # HTTP utilities
├── test/                  # Tests
├── main.go                # Entry point
├── go.mod, go.sum         # Go modules
└── repository/            # Sample data
```

### Node.js Service (checkout)
```
src/checkout/
├── src/                   # TypeScript source
├── test/                  # E2E tests
├── package.json           # npm configuration
├── tsconfig.json          # TypeScript config
└── nest-cli.json          # NestJS CLI config
```

## Configuration Files

- **nx.json**: Nx workspace configuration, target defaults
- **package.json**: Root workspace dependencies
- **yarn.lock**: Dependency lock file
- **.prettierrc**: Code formatting rules
- **renovate.json**: Dependency update automation
- **release-please-config.json**: Release automation

## Deployment Artifacts

- **Helm Charts**: `src/*/chart/` - per-service Kubernetes deployments
- **Helmfile**: `src/app/helmfile.yaml` - application-level orchestration
- **Docker Compose**: `src/app/docker-compose.yml` - local multi-service
- **Terraform Modules**: `terraform/lib/` - reusable infrastructure

## Tags & Organization

Services are tagged in nx for bulk operations:
- **service**: All application services
- **chart**: Services with Helm charts
- **sample**: Services with sample data

Use tags for bulk operations:
```bash
yarn nx run-many -t <target> --projects=tag:service
```
