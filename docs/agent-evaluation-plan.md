# AWS Agent Evaluation Plan

## Overview

This document outlines the plan to use the AWS Containers Retail Sample application as a foundation for evaluating **AWS DevOps Agent** and **AWS Security Agent** with a fully automated GitHub Actions deployment pipeline to ECS Managed Instances.

## AWS Agents Overview

### AWS DevOps Agent (Preview)
**Purpose**: Autonomous incident response and operational improvement

**Key Capabilities**:
- **Automated Incident Investigation** - Begins investigating immediately when alerts trigger
- **Application Topology Mapping** - Builds comprehensive resource relationship graphs
- **Mitigation Plans** - Provides specific actions to resolve incidents
- **Preventative Recommendations** - Analyzes patterns to prevent future incidents
- **Tool Integration** - Works with CloudWatch, Datadog, Dynatrace, New Relic, Splunk, GitHub Actions, GitLab

**How It Works**:
- Organized around "Agent Spaces" (logical containers for AWS accounts and integrations)
- Dual-console architecture: AWS Console for admin, DevOps Agent web app for operations
- Correlates telemetry, code, and deployment data
- Routes findings through Slack, ServiceNow, PagerDuty
- Creates AWS Support cases with full context

**Benefits for This Project**:
- Monitor ECS Managed Instances for operational issues
- Investigate container failures, resource constraints, deployment issues
- Correlate CloudWatch metrics with GitHub deployments
- Reduce MTTR from hours to minutes
- Learn from incidents to improve infrastructure

### AWS Security Agent (Preview)
**Purpose**: Proactive application security throughout development lifecycle

**Key Capabilities**:
- **Design Security Review** - Validates architectural documents against org requirements
- **Code Security Review** - Analyzes pull requests for vulnerabilities (SQL injection, XSS, etc.)
- **On-Demand Penetration Testing** - Context-aware testing with sophisticated attack chains
- **GitHub Integration** - Provides remediation guidance directly in PRs
- **Automated Fixes** - Creates pull requests with ready-to-implement code fixes

**How It Works**:
- Define organizational security requirements once in AWS Console
- Automatically enforces requirements during design and code reviews
- Analyzes source code and documentation to understand application context
- Executes multi-step attack scenarios to discover vulnerabilities
- Validates findings through proof-based exploitation (no false positives)

**Benefits for This Project**:
- Secure microservices code changes before deployment
- Validate Java, Go, and Node.js code against security standards
- Test deployed ECS services for vulnerabilities
- Ensure container security best practices
- Scale security reviews across all 5 microservices

## Architecture Plan

### Deployment Target: ECS Managed Instances

**Why ECS Managed Instances?**
- Full EC2 instance access while AWS handles infrastructure management
- Cost optimization through multi-task placement (vs Fargate's 1:1 isolation)
- Automatic patching and security updates (14-day cycle)
- Access to specialized instance types if needed
- Better for agent evaluation (more visibility into infrastructure)
- GuardDuty Runtime Monitoring support

**Key Features**:
- Automatic instance selection and right-sizing
- Active workload consolidation
- Secure configuration (no SSH, immutable root filesystem, SELinux)
- Compatible with existing Fargate task definitions

### Application Components

**5 Microservices** (all will be custom-built):
1. **UI** (Java/Spring Boot) - Store frontend
2. **Catalog** (Go) - Product catalog API
3. **Cart** (Java/Spring Boot) - Shopping cart API
4. **Orders** (Java/Spring Boot) - Order management API
5. **Checkout** (Node.js/NestJS) - Checkout orchestration

**AWS Services**:
- Amazon ECR (Private) - Custom container images
- ECS Managed Instances - Container orchestration
- RDS (PostgreSQL, MySQL) - Databases
- DynamoDB - Cart data
- ElastiCache (Redis) - Checkout cache
- Amazon MQ (RabbitMQ) - Orders messaging
- CloudWatch - Metrics, logs, alarms
- GuardDuty - Runtime threat detection

## Implementation Phases

### Phase 1: Bootstrap Infrastructure ✅ COMPLETE
- [x] S3 bucket for Terraform state
- [x] DynamoDB table for state locking
- [x] GitHub OIDC provider
- [x] IAM role for GitHub Actions
- [x] GitHub secret configured (AWS_ROLE_ARN)

### Phase 2: Container Image Pipeline
**Goal**: Build and push custom images to private ECR

**Tasks**:
1. Create ECR private repositories (one per service)
2. Update bootstrap IAM role with ECR permissions
3. Create GitHub Actions workflow:
   - Trigger on code changes to microservices
   - Build multi-arch images (x86_64, ARM64) using nx
   - Tag with commit SHA and semantic versions
   - Push to private ECR
   - Scan images for vulnerabilities

**Deliverables**:
- `.github/workflows/build-images.yml`
- ECR repositories created via Terraform
- Image scanning enabled

### Phase 3: ECS Managed Instances Deployment
**Goal**: Deploy application to ECS with Managed Instances

**Tasks**:
1. Modify existing `terraform/ecs/default` module:
   - Switch from Fargate to Managed Instances capacity provider
   - Configure instance requirements and optimization
   - Set up IAM roles (infrastructure role + instance profile)
   - Enable Container Insights
   - Configure GuardDuty Runtime Monitoring
2. Create GitHub Actions deployment workflow:
   - Trigger on image push or manual dispatch
   - Run Terraform plan/apply
   - Update ECS task definitions with new image tags
   - Perform rolling deployments
   - Validate deployment health
3. Set up monitoring and alerting

**Deliverables**:
- `terraform/ecs/managed-instances/` (new module or modified default)
- `.github/workflows/deploy-ecs.yml`
- CloudWatch dashboards
- GuardDuty configuration

### Phase 4: AWS Agent Integration
**Goal**: Configure and evaluate both AWS agents

#### AWS DevOps Agent Setup:
1. Create DevOps Agent Space in AWS Console
2. Configure integrations:
   - CloudWatch (metrics, logs, alarms)
   - GitHub (repositories, Actions)
   - Slack (incident notifications)
3. Set up application topology mapping
4. Configure automated incident response
5. Test incident investigation workflows

#### AWS Security Agent Setup:
1. Create Security Agent Space in AWS Console
2. Define organizational security requirements:
   - Authorization libraries (Spring Security, JWT)
   - Logging standards (structured logging, PII handling)
   - Data access policies (database encryption, API security)
3. Configure GitHub integration for code reviews
4. Set up penetration testing scopes:
   - UI endpoints
   - API endpoints (catalog, cart, orders, checkout)
   - Authentication flows
5. Run initial security assessments

**Deliverables**:
- Agent Space configurations
- Security requirements documentation
- Integration test results
- Incident response playbooks

### Phase 5: Evaluation & Documentation
**Goal**: Assess agent effectiveness and document findings

**Evaluation Criteria**:

**AWS DevOps Agent**:
- Time to detect incidents (MTTI)
- Time to resolution (MTTR)
- Quality of mitigation recommendations
- Accuracy of topology mapping
- Integration effectiveness with existing tools
- False positive rate

**AWS Security Agent**:
- Vulnerability detection accuracy
- False positive rate
- Quality of remediation guidance
- PR integration effectiveness
- Penetration testing coverage
- Time savings vs manual reviews

**Deliverables**:
- Evaluation report
- Lessons learned
- Best practices guide
- Cost analysis

## GitHub Actions Workflow Strategy

### Workflow 1: Build & Push Images
**Trigger**: Push to `main` or PR to `main` (for services)
**Steps**:
1. Checkout code
2. Configure AWS credentials (OIDC)
3. Login to ECR
4. Build images using nx (parallel builds)
5. Scan images for vulnerabilities
6. Push to ECR (only on main)
7. Trigger deployment workflow

### Workflow 2: Deploy to ECS
**Trigger**: Workflow dispatch or image push
**Steps**:
1. Checkout code
2. Configure AWS credentials (OIDC)
3. Terraform init (with remote backend)
4. Terraform plan
5. Terraform apply (with approval for prod)
6. Update ECS services with new task definitions
7. Wait for deployment completion
8. Run health checks
9. Notify on success/failure

### Workflow 3: Security Scan
**Trigger**: PR creation, scheduled (nightly)
**Steps**:
1. Run AWS Security Agent code review
2. Run container image scanning
3. Run dependency vulnerability checks
4. Comment findings on PR
5. Block merge if critical issues found

## Success Metrics

### Deployment Automation
- [ ] Zero-touch deployments from code commit to production
- [ ] < 15 minutes from commit to deployed
- [ ] 100% deployment success rate
- [ ] Automated rollback on failure

### Agent Effectiveness
- [ ] AWS DevOps Agent detects incidents within 5 minutes
- [ ] AWS Security Agent finds vulnerabilities before deployment
- [ ] < 10% false positive rate for both agents
- [ ] Actionable recommendations in > 90% of findings

### Operational Excellence
- [ ] All 5 microservices running on ECS Managed Instances
- [ ] CloudWatch dashboards showing full observability
- [ ] GuardDuty Runtime Monitoring active
- [ ] Automated security scanning on every PR

## Cost Estimate

**Monthly Costs** (estimated):
- ECS Managed Instances: ~$100-150
- RDS (2 instances): ~$50-80
- DynamoDB: ~$10-20
- ElastiCache: ~$20-30
- Amazon MQ: ~$30-40
- CloudWatch: ~$10-20
- GuardDuty: ~$10-20
- ECR: ~$5-10
- **Total**: ~$235-370/month

**Agent Costs** (Preview - Free during preview):
- AWS DevOps Agent: TBD after preview
- AWS Security Agent: TBD after preview

## Timeline

- **Week 1**: Phase 2 - Container image pipeline
- **Week 2**: Phase 3 - ECS Managed Instances deployment
- **Week 3**: Phase 4 - AWS Agent integration
- **Week 4**: Phase 5 - Evaluation and documentation

## Next Steps

1. **Immediate**: Create ECR repositories and update IAM permissions
2. **Next**: Build image build/push GitHub Actions workflow
3. **Then**: Modify ECS Terraform for Managed Instances
4. **Finally**: Configure and test AWS agents

## References

- [AWS DevOps Agent Documentation](https://docs.aws.amazon.com/devopsagent/latest/userguide/)
- [AWS Security Agent Documentation](https://docs.aws.amazon.com/securityagent/latest/userguide/)
- [ECS Managed Instances Documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ManagedInstances.html)
- [GuardDuty Runtime Monitoring](https://docs.aws.amazon.com/guardduty/latest/ug/runtime-monitoring.html)
