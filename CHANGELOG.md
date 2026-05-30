# Changelog

## [1.5.0](https://github.com/madlinux768/retail-store-sample-app/compare/v1.4.0...v1.5.0) (2026-05-30)


### Features

* add current state report and pre-demo checklist script ([df501dd](https://github.com/madlinux768/retail-store-sample-app/commit/df501ddcf75a03b22c51c798d84c8297ebaa3be4))
* add demo prompts with real timestamps, fix injection scripts ([10ae956](https://github.com/madlinux768/retail-store-sample-app/commit/10ae956e72502d78d93f36135092c014e08f3bd0))
* **ci:** add EKS deploy workflow with S3 remote backend ([4d0985c](https://github.com/madlinux768/retail-store-sample-app/commit/4d0985c98dc6ca53fc4ff355a168defb0aeb5e09))
* **eks:** attach SSM policy to node groups for tunnel access ([28dd8ec](https://github.com/madlinux768/retail-store-sample-app/commit/28dd8ec97d766a07aaa974045dbb74521531a0cc))
* **fault-injection:** add all fault injection scripts for 3-space demo ([fbfeea8](https://github.com/madlinux768/retail-store-sample-app/commit/fbfeea89c3d831cacb665f3d21fae9c4319a40e0))
* **monitoring:** add comprehensive observability for ECS cluster ([62feecd](https://github.com/madlinux768/retail-store-sample-app/commit/62feecddc0722beede6ec2e5effe0e81c9f63060))
* **monitoring:** enable Application Signals with ADOT auto-instrumentation ([3854d28](https://github.com/madlinux768/retail-store-sample-app/commit/3854d28547c9d5d5554729bc06f6e7de98c03231))
* **networking:** add comprehensive logging and HTML report ([16b5bb9](https://github.com/madlinux768/retail-store-sample-app/commit/16b5bb936de80f367c71911662cf9090d9f8c3d6))
* **networking:** add networking-demo module with GitHub Actions CI/CD ([4176b3d](https://github.com/madlinux768/retail-store-sample-app/commit/4176b3d50a1d1722802777a5442e8c2c02d094a9))
* **observability:** add DevOps Agent support with CloudWatch observability ([a61fdcd](https://github.com/madlinux768/retail-store-sample-app/commit/a61fdcd018ae03c113b1fb9800cae51805e54814))
* **orders:** add Azure Service Bus messaging provider ([#5](https://github.com/madlinux768/retail-store-sample-app/issues/5)) ([0b8988f](https://github.com/madlinux768/retail-store-sample-app/commit/0b8988fe4ede651226746cc5e03907befa7eab2c))


### Bug Fixes

* **checkout:** add missing peer dependencies for Docker build ([66c81a2](https://github.com/madlinux768/retail-store-sample-app/commit/66c81a266ae78e633965efd88ddc90704eaef326))
* **ci:** disable terraform wrapper to capture plan exit codes ([c4f3a2e](https://github.com/madlinux768/retail-store-sample-app/commit/c4f3a2e67ae9d05169cc61870bc5f699f542b0d4))
* **ci:** grant full ECR permissions to GitHub Actions role ([687b534](https://github.com/madlinux768/retail-store-sample-app/commit/687b534ce54f9b0722b5d9cabe217241463f9fd1))
* **ci:** grant full IAM permissions to GitHub Actions role ([6275a33](https://github.com/madlinux768/retail-store-sample-app/commit/6275a3379071075818814bfc0dcab6c0749a0753))
* **ecs/default:** wire azurerm provider and azure flag into root caller ([#6](https://github.com/madlinux768/retail-store-sample-app/issues/6)) ([8fe151b](https://github.com/madlinux768/retail-store-sample-app/commit/8fe151b9fc3c37895e453b466cbc40d17001d245))
* **ecs:** bump orders healthcheck startPeriod to 180s ([#11](https://github.com/madlinux768/retail-store-sample-app/issues/11)) ([6fbdf5f](https://github.com/madlinux768/retail-store-sample-app/commit/6fbdf5f794f6d594fb823ce0811b20d97449e716))
* **ecs:** map AWS lib/tags output to canonical schema for Azure module ([#9](https://github.com/madlinux768/retail-store-sample-app/issues/9)) ([d56266e](https://github.com/madlinux768/retail-store-sample-app/commit/d56266e55e0b99db0c03a3c4e0b6d2644ff08e28))
* **eks:** align node group scaling config with actual state ([2bf13e0](https://github.com/madlinux768/retail-store-sample-app/commit/2bf13e0e3594dcc177a60621608a6162916cf94b))
* **logging:** add log4j-layout-template-json and monitoring workflow input ([cf8d7d4](https://github.com/madlinux768/retail-store-sample-app/commit/cf8d7d4388efd845dd50e7c538e2c7dc99f8ced1))
* **monitoring:** resolve SLO and Contributor Insights apply errors ([a2fbfb5](https://github.com/madlinux768/retail-store-sample-app/commit/a2fbfb5e8a921ab7e0345dce7ec491940e21e0c3))
* **monitoring:** set deployment.environment for Application Signals ([1b94fbf](https://github.com/madlinux768/retail-store-sample-app/commit/1b94fbfb337cfc95df2397eb8ce21a1e3334158a))
* **monitoring:** tune memory anomaly detection to reduce false positives ([9f898c9](https://github.com/madlinux768/retail-store-sample-app/commit/9f898c93fd5b46dc31b481dbdf0f28e41ae85dbb))
* **mq:** ignore user changes on RabbitMQ broker after creation ([40a30c6](https://github.com/madlinux768/retail-store-sample-app/commit/40a30c6d98888f4cf5bdff553be24fb5ea6c7b69))
* **mq:** use RabbitMQ-compatible instance type mq.m7g.medium ([374b483](https://github.com/madlinux768/retail-store-sample-app/commit/374b483c0c0e0004b3c6bed8d8d92dbd9c56e29c))
* **networking:** add 60s delay for RAM share propagation before TGW attach ([9c9d5a1](https://github.com/madlinux768/retail-store-sample-app/commit/9c9d5a1908d429376166035caf0e4635738a6634))
* **networking:** add TGW attachment accepter for cross-org accounts ([64abd93](https://github.com/madlinux768/retail-store-sample-app/commit/64abd931c5a467a4d05609e6fb0ede9de5178949))
* **networking:** both providers use explicit assume_role ([5b4d7b1](https://github.com/madlinux768/retail-store-sample-app/commit/5b4d7b108395708e1ce69055c41c506c60869014))
* **networking:** broaden app account role to service-level wildcards ([1588aaf](https://github.com/madlinux768/retail-store-sample-app/commit/1588aaf3db4faf435d23dcffd09e7043c8923c58))
* **networking:** broaden EC2 read permissions with ec2:Describe* ([e9b41cd](https://github.com/madlinux768/retail-store-sample-app/commit/e9b41cdcad664d346b0cca075129d960e888e1b1))
* **networking:** clear env credentials so AWS_PROFILE takes effect ([639625a](https://github.com/madlinux768/retail-store-sample-app/commit/639625a2b2ae19892ab19c3541c5cee3d39999f2))
* **networking:** consolidate to single job for plan+apply ([79402f3](https://github.com/madlinux768/retail-store-sample-app/commit/79402f34d6043ff1fbccd85bfd8b3cf2ed305547))
* **networking:** look up main route table instead of subnet-associated ([0d09d51](https://github.com/madlinux768/retail-store-sample-app/commit/0d09d512120d68e8d2e12a8407a9be85296ea490))
* **networking:** make OIDC provider optional in networking CFN template ([e599c55](https://github.com/madlinux768/retail-store-sample-app/commit/e599c550802010c6254c2be28c0d64665bf7d70f))
* **networking:** pass app route table ID as variable ([84237c6](https://github.com/madlinux768/retail-store-sample-app/commit/84237c6c707a5c9af9aa579d3a7166e913f2ff42))
* **networking:** pass networking_role_arn as env var in apply job ([a01d0fc](https://github.com/madlinux768/retail-store-sample-app/commit/a01d0fc0078dad69bf2a0dd74b02934daf8a4d15))
* **networking:** remove failed TGW attachment from state (one-time) ([0ec29d6](https://github.com/madlinux768/retail-store-sample-app/commit/0ec29d6d1638be8185a3d6a2b141f0d37764737f))
* **networking:** remove invalid quoted heredoc syntax ([7a9da96](https://github.com/madlinux768/retail-store-sample-app/commit/7a9da969674c0e9f64e825fcd27bd007a057e45c))
* **networking:** remove TGW accepter since auto-accept works ([8ee9533](https://github.com/madlinux768/retail-store-sample-app/commit/8ee9533ed3f64200a440a971aa155429e9e5bbd0))
* **networking:** simplify to single OIDC + cross-account assume_role ([0fa9bad](https://github.com/madlinux768/retail-store-sample-app/commit/0fa9bad843168d8c034120ff2519be7e8ff69d38))
* **networking:** strip indentation from AWS credentials file ([d15d03a](https://github.com/madlinux768/retail-store-sample-app/commit/d15d03a87435bd824761513660d504529467036e))
* **networking:** use aws_route_tables data source for app VPC ([0742a75](https://github.com/madlinux768/retail-store-sample-app/commit/0742a7574f32ef61cca886054ae910a3496831af))
* **networking:** use ec2:* and ram:* for networking demo role ([0cc1533](https://github.com/madlinux768/retail-store-sample-app/commit/0cc153374dcac1adc66de9f72511be4daef5d51d))
* **networking:** use python3 http.server instead of httpd ([2803638](https://github.com/madlinux768/retail-store-sample-app/commit/2803638a806f70302759227709bb4e86aca4f4aa))
* **networking:** use systemd service for partner HTTP server ([093317d](https://github.com/madlinux768/retail-store-sample-app/commit/093317daf985f652c20c6d85887fd57631ee61fa))
* **orders:** exclude Azure health indicator from ECS readiness probe ([#12](https://github.com/madlinux768/retail-store-sample-app/issues/12)) ([5fe8c58](https://github.com/madlinux768/retail-store-sample-app/commit/5fe8c58b1e844a0c0249a5432f00726126c103c1))
* **orders:** probe Azure Service Bus health via send link ([#13](https://github.com/madlinux768/retail-store-sample-app/issues/13)) ([2eaed1b](https://github.com/madlinux768/retail-store-sample-app/commit/2eaed1b0c831bb42ea61d74453ff37ec0f66f66d))
* **orders:** strip EntityPath from connection string for admin client ([#10](https://github.com/madlinux768/retail-store-sample-app/issues/10)) ([80174a1](https://github.com/madlinux768/retail-store-sample-app/commit/80174a16d92e4b8ebc2213c046660c47f9e4cd24))
* **orders:** strip Micrometer .count suffix from Azure publish-failures metric ([#14](https://github.com/madlinux768/retail-store-sample-app/issues/14)) ([374717f](https://github.com/madlinux768/retail-store-sample-app/commit/374717fb6a13672d9983bfe2058afeaeeb76ee97))
* **security:** make UI load balancer internal ([7b7cce7](https://github.com/madlinux768/retail-store-sample-app/commit/7b7cce7fcb07d142f29bc5b96f5295ac8d7cb20b))
* **terraform:** pin VPC module to v5 for AWS provider v5 compatibility ([4614341](https://github.com/madlinux768/retail-store-sample-app/commit/46143412888dca0c8115284e13147ef07b2078bd))
* **terraform:** relax AWS provider constraint to allow v6 ([22c11fb](https://github.com/madlinux768/retail-store-sample-app/commit/22c11fb867955ed37c38e791acc4367422164d1b))

## [1.4.0](https://github.com/aws-containers/retail-store-sample-app/compare/v1.3.0...v1.4.0) (2026-01-30)


### Features

* Support redis TLS for checkout service ([#943](https://github.com/aws-containers/retail-store-sample-app/issues/943)) ([d587fb8](https://github.com/aws-containers/retail-store-sample-app/commit/d587fb80954b5666dd0f9b0b7b48199df7a33dd0))


### Bug Fixes

* Set shipping informations in checkout ([#951](https://github.com/aws-containers/retail-store-sample-app/issues/951)) ([457407b](https://github.com/aws-containers/retail-store-sample-app/commit/457407bf585578051d5959a1928d86fc7dc32f07))

## [1.3.0](https://github.com/aws-containers/retail-store-sample-app/compare/v1.2.4...v1.3.0) (2025-09-16)


### Features

* Add EventBridge lifecycle events for ECS Container Insights and update ADOT to CloudWatch Agent ([#913](https://github.com/aws-containers/retail-store-sample-app/issues/913)) ([549594b](https://github.com/aws-containers/retail-store-sample-app/commit/549594bf1f47d16f19a02ce040b55e4353dd8be6))


### Bug Fixes

* Add UI teal theme color ([#923](https://github.com/aws-containers/retail-store-sample-app/issues/923)) ([b382620](https://github.com/aws-containers/retail-store-sample-app/commit/b382620fcc7753b0e9c5256e972bc0844e8d9039))
* **deps:** update dependency org.openapitools:jackson-databind-nullable to v0.2.7 ([#926](https://github.com/aws-containers/retail-store-sample-app/issues/926)) ([46849a7](https://github.com/aws-containers/retail-store-sample-app/commit/46849a74089f06acad31222b6c4d7cdb8da32984))
* **deps:** update dependency org.projectlombok:lombok to v1.18.40 ([#927](https://github.com/aws-containers/retail-store-sample-app/issues/927)) ([4544834](https://github.com/aws-containers/retail-store-sample-app/commit/454483476947cc4e911f707969fdb898b4e9ae62))
* **deps:** update dependency org.springframework.ai:spring-ai-bom to v1.0.2 ([#928](https://github.com/aws-containers/retail-store-sample-app/issues/928)) ([948ce82](https://github.com/aws-containers/retail-store-sample-app/commit/948ce82b2192135ca5c69bb4582011f176dbda1b))
* **deps:** update dependency org.springframework.boot:spring-boot-starter-parent to v3.5.5 ([#929](https://github.com/aws-containers/retail-store-sample-app/issues/929)) ([72fa4e8](https://github.com/aws-containers/retail-store-sample-app/commit/72fa4e8f15253cce61c15657d0a396d3c95d5b50))
* **deps:** update kiota to v1.8.10 ([#930](https://github.com/aws-containers/retail-store-sample-app/issues/930)) ([a1012bf](https://github.com/aws-containers/retail-store-sample-app/commit/a1012bf29c862c4e91acf4fbd2547e62af95132a))
* Improved CW Logging for ECS default deployment ([#921](https://github.com/aws-containers/retail-store-sample-app/issues/921)) ([eff0668](https://github.com/aws-containers/retail-store-sample-app/commit/eff06680c3639acda4d878a2f01d68216955be95))
* Revert Spring AI to 1.0.0 ([0a9994b](https://github.com/aws-containers/retail-store-sample-app/commit/0a9994b447e0e5e44c092eb0d5b4940bbe829e62))
* wait for VPC resource controller before deploying workloads ([#914](https://github.com/aws-containers/retail-store-sample-app/issues/914)) ([902302a](https://github.com/aws-containers/retail-store-sample-app/commit/902302a84aa52f9a0a84f8b807d7918deccee6d4))

## [1.2.4](https://github.com/aws-containers/retail-store-sample-app/compare/v1.2.3...v1.2.4) (2025-08-13)


### Bug Fixes

* Fix load generator not completing orders ([#915](https://github.com/aws-containers/retail-store-sample-app/issues/915)) ([c43a8bb](https://github.com/aws-containers/retail-store-sample-app/commit/c43a8bb753008b860b59c795622e3e327233c398))

## [1.2.3](https://github.com/aws-containers/retail-store-sample-app/compare/v1.2.2...v1.2.3) (2025-08-01)


### Bug Fixes

* Consistent OpenTelemetry versions in Java components ([5ea06b9](https://github.com/aws-containers/retail-store-sample-app/commit/5ea06b9900d2d4878f560673c3664cb1386d7fb9))
* **deps:** update dependency software.amazon.awssdk:bom to v2.32.13 ([#884](https://github.com/aws-containers/retail-store-sample-app/issues/884)) ([ebe9760](https://github.com/aws-containers/retail-store-sample-app/commit/ebe9760c6bda84e83dd38544384d30bc6d3ea9c9))
* **deps:** update kiota to v1.8.8 ([#885](https://github.com/aws-containers/retail-store-sample-app/issues/885)) ([393fb36](https://github.com/aws-containers/retail-store-sample-app/commit/393fb3697e3ca9dc67bb3d95b72e3e38b41f95b7))
* Use correct RabbitMQ credential field names ([#911](https://github.com/aws-containers/retail-store-sample-app/issues/911)) ([2bbedc1](https://github.com/aws-containers/retail-store-sample-app/commit/2bbedc12863ec36bec65598d6f64b259530517f9))

## [1.2.2](https://github.com/aws-containers/retail-store-sample-app/compare/v1.2.1...v1.2.2) (2025-07-14)


### Bug Fixes

* **deps:** update dependency axios to v1.10.0 ([#874](https://github.com/aws-containers/retail-store-sample-app/issues/874)) ([4c0113e](https://github.com/aws-containers/retail-store-sample-app/commit/4c0113e8144252a068b199a7c00c0924ac52fb90))
* **deps:** update dependency org.springframework.boot:spring-boot-starter-parent to v3.5.3 ([#879](https://github.com/aws-containers/retail-store-sample-app/issues/879)) ([08120b1](https://github.com/aws-containers/retail-store-sample-app/commit/08120b10d311d5b30bbf3b30f7a80537ec61b912))
* Remove catalog in-memory db logging ([#880](https://github.com/aws-containers/retail-store-sample-app/issues/880)) ([83ca5dd](https://github.com/aws-containers/retail-store-sample-app/commit/83ca5dd7f7c30c4b752d9feca12f14a18b93f231))

## [1.2.1](https://github.com/aws-containers/retail-store-sample-app/compare/v1.2.0...v1.2.1) (2025-07-03)


### Bug Fixes

* **deps:** update dependency software.amazon.awssdk:bom to v2.31.76 ([#857](https://github.com/aws-containers/retail-store-sample-app/issues/857)) ([9565e5e](https://github.com/aws-containers/retail-store-sample-app/commit/9565e5e386c4c7e6863c1691c70d6f6151901152))
* **deps:** update kiota to v1.8.7 ([#854](https://github.com/aws-containers/retail-store-sample-app/issues/854)) ([726ba0b](https://github.com/aws-containers/retail-store-sample-app/commit/726ba0b484fed0573aaf76b0c13ead590f24ebdd))
* **deps:** update module github.com/gin-gonic/gin to v1.10.1 ([#855](https://github.com/aws-containers/retail-store-sample-app/issues/855)) ([e81b40e](https://github.com/aws-containers/retail-store-sample-app/commit/e81b40e88c1286c86f705b68f1b4b16995a24cd7))
* **deps:** update opentelemetry-go monorepo to v1.37.0 ([#819](https://github.com/aws-containers/retail-store-sample-app/issues/819)) ([5312383](https://github.com/aws-containers/retail-store-sample-app/commit/531238309930200fdd1dd58200619c91d56a7f6e))
* UI mock catalog tag filters ([114b3c9](https://github.com/aws-containers/retail-store-sample-app/commit/114b3c9584c7ac49be19868ce33e2c51b5f17916))

## [1.2.0](https://github.com/aws-containers/retail-store-sample-app/compare/v1.1.0...v1.2.0) (2025-07-02)


### Features

* Allow serving sample images from filesystem ([#853](https://github.com/aws-containers/retail-store-sample-app/issues/853)) ([43f3283](https://github.com/aws-containers/retail-store-sample-app/commit/43f3283f84ad0db99f75fa05e7eb7130c56d149e))
* Optimize asset image sizes ([#840](https://github.com/aws-containers/retail-store-sample-app/issues/840)) ([65a7748](https://github.com/aws-containers/retail-store-sample-app/commit/65a7748dfd99a1392baf788d2a059228a35062ce))
* Upgraded checkout to NestJS v11 ([#842](https://github.com/aws-containers/retail-store-sample-app/issues/842)) ([4f1c921](https://github.com/aws-containers/retail-store-sample-app/commit/4f1c921320061e6e7716a14409fa3c640c98a917))


### Bug Fixes

* **deps:** bump golang.org/x/crypto in /src/catalog ([#829](https://github.com/aws-containers/retail-store-sample-app/issues/829)) ([50ff85c](https://github.com/aws-containers/retail-store-sample-app/commit/50ff85c654aa7f4c4469d8fb27a28c2c96988214))
* **deps:** bump golang.org/x/net from 0.34.0 to 0.38.0 in /src/catalog ([#831](https://github.com/aws-containers/retail-store-sample-app/issues/831)) ([6303846](https://github.com/aws-containers/retail-store-sample-app/commit/63038463f862f2d18518c17b72355f53cf5b173c))
* **deps:** update dependency io.opentelemetry.instrumentation:opentelemetry-instrumentation-bom to v2.17.0 ([#811](https://github.com/aws-containers/retail-store-sample-app/issues/811)) ([7ee50f7](https://github.com/aws-containers/retail-store-sample-app/commit/7ee50f71c86fe8bf27f5b7d3651e44d59c11086a))
* **deps:** update dependency io.swagger:swagger-annotations to v1.6.16 ([#849](https://github.com/aws-containers/retail-store-sample-app/issues/849)) ([17b44b6](https://github.com/aws-containers/retail-store-sample-app/commit/17b44b655bdd8011bc65d38301b720588042ead2))
* **deps:** update dependency org.projectlombok:lombok to v1.18.38 ([#850](https://github.com/aws-containers/retail-store-sample-app/issues/850)) ([2f76853](https://github.com/aws-containers/retail-store-sample-app/commit/2f768538e9ad409dba0ae4b1b83f76e3b0aed8b0))
* **deps:** update dependency org.springdoc:springdoc-openapi-starter-webmvc-ui to v2.8.9 ([#851](https://github.com/aws-containers/retail-store-sample-app/issues/851)) ([4a1a201](https://github.com/aws-containers/retail-store-sample-app/commit/4a1a2014222dd549850352f78851646830693143))
* **deps:** update dependency software.amazon.awssdk:bom to v2.31.75 ([#852](https://github.com/aws-containers/retail-store-sample-app/issues/852)) ([3229234](https://github.com/aws-containers/retail-store-sample-app/commit/32292347ae4b7ffd2172e4b17ef5210966527d64))
* UI chart should only set theme if configured ([88ec5cd](https://github.com/aws-containers/retail-store-sample-app/commit/88ec5cd95722d5e164ddafdc1eb230d233667c4f))

## [1.1.0](https://github.com/aws-containers/retail-store-sample-app/compare/v1.0.2...v1.1.0) (2025-03-23)


### Features

* Chaos testing endpoints ([#818](https://github.com/aws-containers/retail-store-sample-app/issues/818)) ([f8f2207](https://github.com/aws-containers/retail-store-sample-app/commit/f8f22078ea67049144bc2d59efc7a60c730c67f0))


### Bug Fixes

* **deps:** update dependency axios to v1.8.4 ([#791](https://github.com/aws-containers/retail-store-sample-app/issues/791)) ([06fe506](https://github.com/aws-containers/retail-store-sample-app/commit/06fe506a860bdadbe7fa69251b87ff62878f7f5d))
* **deps:** update dependency de.codecentric:chaos-monkey-spring-boot to v3.1.4 ([#769](https://github.com/aws-containers/retail-store-sample-app/issues/769)) ([8aeeea4](https://github.com/aws-containers/retail-store-sample-app/commit/8aeeea4ec3bbd6ec93c3a13aea43d15d805c0c3c))
* **deps:** update dependency de.codecentric:chaos-monkey-spring-boot to v3.2.0 ([#810](https://github.com/aws-containers/retail-store-sample-app/issues/810)) ([aff5aa9](https://github.com/aws-containers/retail-store-sample-app/commit/aff5aa94a81923765d38f3a4dd7b639706be1563))
* **deps:** update dependency org.springframework.boot:spring-boot-starter-parent to v3.4.4 ([#802](https://github.com/aws-containers/retail-store-sample-app/issues/802)) ([3a9b53f](https://github.com/aws-containers/retail-store-sample-app/commit/3a9b53f1a1387ea0bfeabd7d6495983f15922ac3))
* **deps:** update dependency org.springframework.cloud:spring-cloud-gateway-webflux to v4.2.1 ([#798](https://github.com/aws-containers/retail-store-sample-app/issues/798)) ([0506dac](https://github.com/aws-containers/retail-store-sample-app/commit/0506dac93cb109d12665c418b3412db3d2eca53b))
* **deps:** update dependency reflect-metadata to ^0.2.0 ([#813](https://github.com/aws-containers/retail-store-sample-app/issues/813)) ([4b67fc5](https://github.com/aws-containers/retail-store-sample-app/commit/4b67fc57514596585c7d4aa5d75042f6a6dd95ba))
* **deps:** update dependency rxjs to v7.8.2 ([#772](https://github.com/aws-containers/retail-store-sample-app/issues/772)) ([04d1b3c](https://github.com/aws-containers/retail-store-sample-app/commit/04d1b3c3a7e0a75252ec26d99c5ca488e84b7fbe))
* **deps:** update dependency software.amazon.awssdk:bom to v2.31.5 ([#793](https://github.com/aws-containers/retail-store-sample-app/issues/793)) ([83365cb](https://github.com/aws-containers/retail-store-sample-app/commit/83365cb236b055a61d559896e27ffec7478e7169))
* **deps:** update dependency software.amazon.awssdk:bom to v2.31.6 ([#815](https://github.com/aws-containers/retail-store-sample-app/issues/815)) ([40f9e98](https://github.com/aws-containers/retail-store-sample-app/commit/40f9e98af9395dabb2278f5f6f246caa7cf5b413))
* **deps:** update module gorm.io/plugin/opentelemetry to v0.1.12 ([#799](https://github.com/aws-containers/retail-store-sample-app/issues/799)) ([b04eb5f](https://github.com/aws-containers/retail-store-sample-app/commit/b04eb5f984ea6c408165e988f7f25c80da9d2b85))

## [1.0.2](https://github.com/aws-containers/retail-store-sample-app/compare/v1.0.1...v1.0.2) (2025-03-20)


### Bug Fixes

* Expose UI chat configuration in chart ([58597cc](https://github.com/aws-containers/retail-store-sample-app/commit/58597cc9206758f95cf50f6b37df02fa828059d1))

## [1.0.1](https://github.com/aws-containers/retail-store-sample-app/compare/v1.0.0...v1.0.1) (2025-03-13)


### Bug Fixes

* safely remove cart items ([#752](https://github.com/aws-containers/retail-store-sample-app/issues/752)) ([c766bd3](https://github.com/aws-containers/retail-store-sample-app/commit/c766bd3a9f2b24395f3a1276e0a1bc9fc7804f0d))

## 1.0.0 (2025-02-28)


### Features

* Add headers, panic, echo and store utilities ([#728](https://github.com/aws-containers/retail-store-sample-app/issues/728)) ([c4f703b](https://github.com/aws-containers/retail-store-sample-app/commit/c4f703bc78bd832116a78e78bf44024aa5c361ca))
* Application v1 ([#742](https://github.com/aws-containers/retail-store-sample-app/issues/742)) ([2ea99fb](https://github.com/aws-containers/retail-store-sample-app/commit/2ea99fbf94c891c4da166c2527f082ab5c621240))
