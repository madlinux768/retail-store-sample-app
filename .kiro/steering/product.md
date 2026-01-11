# AWS Containers Retail Sample

A sample retail store application demonstrating container concepts on AWS. Features a product catalog, shopping cart, and checkout flow.

## Purpose

Educational demonstration of:
- Microservices architecture with polyglot services
- Container orchestration (Docker Compose, Kubernetes, EKS, ECS, App Runner)
- AWS-native persistence (DynamoDB, RDS, ElastiCache, MQ)
- Observability (Prometheus metrics, OpenTelemetry tracing)
- Multi-architecture support (x86-64, ARM64)

## Key Components

- **UI**: Store frontend (Java/Spring Boot)
- **Catalog**: Product catalog API (Go)
- **Cart**: Shopping cart API (Java/Spring Boot)
- **Orders**: Order management API (Java/Spring Boot)
- **Checkout**: Checkout orchestration (Node.js/NestJS)

## Important Notes

- **Not for production use** - educational purposes only
- Pre-built images available in Amazon ECR Public Gallery
- Supports multiple deployment targets via Terraform
- All services instrumented for observability
