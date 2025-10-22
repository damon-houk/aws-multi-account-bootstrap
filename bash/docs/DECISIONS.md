# Architecture Decision Records

This document captures key architectural decisions made during the development of the AWS Multi-Account Bootstrap project. Each decision is documented with context, rationale, and consequences.

---

## ADR-001: Three Accounts vs Five+ Accounts

**Date:** 2025-01-15
**Status:** Accepted
**Deciders:** Project team

### Context

AWS Well-Architected Framework recommends 5-7 accounts with separate organizational units for Security, Logging, Network, Shared Services, and Workloads. This is considered best practice for enterprise organizations. However, this approach adds significant complexity:

- More accounts to manage and monitor
- Higher baseline costs (even minimal resources × 5+ accounts)
- Longer setup time
- Steeper learning curve for teams new to AWS
- More complex cross-account permissions

Our target audience is startups, solo developers, and small teams (2-10 people) who want to follow best practices without enterprise overhead.

### Decision

Start with **3 accounts** (dev, staging, prod) as the v1.0 default configuration.

### Rationale

1. **Simplicity First:** Lower barrier to entry for small teams
2. **Cost Conscious:** Reduces baseline AWS costs significantly (~60% fewer accounts)
3. **Sufficient Isolation:** Three environments provide adequate separation for most use cases
4. **Proven Pattern:** Industry-standard dev/staging/prod workflow familiar to developers
5. **Scalable:** Can migrate to 5-7 account structure later when needed (planned for v1.1 with templates)

### Consequences

**Positive:**
- Faster onboarding (setup completes in ~5 minutes vs 15+ minutes)
- Lower monthly costs (~$75/month vs $125+/month baseline)
- Easier to understand and maintain
- Meets needs of target audience (startups, small teams)
- Less overwhelming for AWS newcomers

**Negative:**
- May not meet enterprise compliance requirements initially
- Shared management account has multiple concerns (organization + workloads)
- CloudTrail logs stored in management account (not separate audit account)
- Future migration to 5+ accounts requires careful planning

**Mitigation:**
- Document migration path in roadmap
- v1.1 will include account templates (minimal/standard/enterprise)
- v2.0 will add Control Tower integration for enterprise needs

---

## ADR-002: GitHub Actions vs AWS CodePipeline

**Date:** 2025-01-15
**Status:** Accepted
**Deciders:** Project team

### Context

AWS provides native CI/CD via CodePipeline, CodeBuild, and CodeDeploy. However, most modern development teams use GitHub for source control and prefer GitHub Actions for CI/CD. We needed to choose which CI/CD platform to support in v1.0.

Alternative solutions we reviewed:
- **oliverschenk/aws-multi-account-terraform:** Uses CodeCommit only (AWS-native)
- **Most enterprise tools:** Require Jenkins, GitLab CI, or other complex setups

### Decision

Implement **GitHub Actions with OIDC** as the primary CI/CD platform for v1.0.

### Rationale

1. **Developer Preference:** Most developers already use GitHub
2. **Security Best Practice:** OIDC eliminates long-lived credentials (no access keys stored in GitHub)
3. **Modern Workflow:** GitHub Actions marketplace, semantic versioning ecosystem
4. **Better DX:** Integrated PR checks, branch protection, automated releases
5. **Ecosystem Fit:** semantic-release, commitlint, and other tools work natively
6. **Differentiator:** Existing AWS tools are AWS-native only; we're GitHub-first

### Consequences

**Positive:**
- No AWS credentials stored in GitHub (OIDC token exchange)
- Automatic semantic versioning via conventional commits
- Rich GitHub ecosystem (Actions marketplace)
- Familiar workflow for most developers
- Automated changelog generation
- Branch protection and environment approvals built-in

**Negative:**
- Requires GitHub (not vendor-agnostic)
- Network path: GitHub → AWS (external dependency)
- Cannot use AWS CodeStar connections
- Teams using GitLab/Bitbucket must wait for v1.1

**Mitigation:**
- v1.1 will add GitLab CI support
- v2.0 will add AWS CodePipeline option for AWS-native deployments
- Document alternative CI/CD setup in docs/CUSTOM_CICD.md

---

## ADR-003: AWS CDK (TypeScript) vs Terraform

**Date:** 2025-01-15
**Status:** Accepted
**Deciders:** Project team

### Context

Infrastructure as Code can be implemented with AWS CloudFormation, AWS CDK, Terraform, Pulumi, or other tools. We compared:

1. **AWS CDK (TypeScript):** AWS-native, programming language (TypeScript/Python/Java)
2. **Terraform (HCL):** Multi-cloud, declarative DSL, mature ecosystem
3. **AWS CloudFormation:** AWS-native, JSON/YAML templates
4. **Pulumi:** Programming languages, multi-cloud

Existing alternatives:
- **oliverschenk/aws-multi-account-terraform:** Uses Terraform + Terragrunt (complex)
- **grendel-consulting/terraform-aws-cdk_bootstrap:** Uses Terraform to bootstrap CDK (niche use case)

### Decision

Use **AWS CDK with TypeScript** for infrastructure definitions.

### Rationale

1. **Developer Friendly:** TypeScript provides excellent IDE support (autocomplete, type checking)
2. **Familiar Language:** JavaScript/TypeScript developers don't need to learn HCL
3. **Modern Constructs:** L2/L3 constructs provide sensible defaults and best practices
4. **AWS Native:** First-class support from AWS, latest features available quickly
5. **Reusability:** Easy to create custom constructs and share patterns
6. **Ecosystem Fit:** Node.js ecosystem (npm, jest, eslint) familiar to developers
7. **Target Audience:** Small teams using Node.js for application code

### Consequences

**Positive:**
- Better developer experience for TypeScript/JavaScript developers
- Type safety catches errors at compile time
- Easier to write unit tests (Jest, standard testing frameworks)
- Simpler abstractions (L2/L3 constructs)
- Faster development iteration

**Negative:**
- AWS-only (not multi-cloud like Terraform)
- Requires Node.js runtime
- Smaller community than Terraform
- State managed by CloudFormation (less portable)
- Teams already using Terraform must learn new tooling

**Mitigation:**
- Document Terraform alternative in README (link to oliverschenk's project)
- v1.2 will add Terraform bootstrap option for hybrid teams
- Provide CDK → Terraform migration guide in docs

---

## ADR-004: Apache 2.0 License

**Date:** 2025-01-15
**Status:** Accepted
**Deciders:** Project team

### Context

Open source infrastructure tools need licenses that:
1. Allow commercial use (businesses will use this for production)
2. Protect project contributors from patent trolls
3. Maximize adoption (minimal restrictions)
4. Are compatible with AWS ecosystem

License options considered:
- **MIT:** Simple, permissive, but no patent protection
- **Apache 2.0:** Permissive + explicit patent grant
- **GPL v3:** Copyleft, forces derivatives to be open source
- **BSD 3-Clause:** Permissive, minimal patent protection

### Decision

Use **Apache License 2.0**.

### Rationale

1. **Patent Protection:** Explicit patent grant protects users and contributors
2. **Business Friendly:** Allows commercial use without forcing open source derivatives
3. **Ecosystem Standard:** Most AWS SDKs and tools use Apache 2.0
4. **Adoption Focus:** Permissive license maximizes usage
5. **Contributor Safety:** Patent retaliation clause protects contributors
6. **Clear Terms:** Well-understood by legal teams (easier corporate adoption)

### Consequences

**Positive:**
- Companies can use it in production without legal concerns
- Patent grant protects against infringement claims
- Compatible with most other open source licenses
- Standard in cloud infrastructure space
- Encourages commercial and community contributions

**Negative:**
- Companies can fork and commercialize without contributing back
- No copyleft requirement to share improvements
- More verbose than MIT/BSD licenses

**Accepted Trade-offs:**
- Maximizing adoption is more valuable than forcing contribution
- Building community through quality and maintenance, not license restrictions

---

## ADR-005: One-Command Setup Philosophy

**Date:** 2025-01-15
**Status:** Accepted
**Deciders:** Project team

### Context

Infrastructure bootstrap tools typically require multiple manual steps:
1. Run scripts in specific order
2. Copy/paste values between steps
3. Manually configure GitHub/CI
4. Set up billing alerts separately
5. Write documentation

Existing tools (reviewed during research):
- **oliverschenk/aws-multi-account-terraform:** 10+ manual steps, complex
- **AWS Control Tower:** 30+ minute setup, multiple console workflows
- **Manual Setup:** Days of work, error-prone

Our users are time-constrained developers who want to **build applications, not configure infrastructure**.

### Decision

Everything must work with a **single command**:
```bash
make setup-all PROJECT_CODE=XYZ EMAIL_PREFIX=dev OU_ID=ou-xxx GITHUB_ORG=org REPO_NAME=repo
```

This command must:
1. Create AWS accounts
2. Bootstrap CDK
3. Configure OIDC
4. Create GitHub repository
5. Set up CI/CD workflows
6. Configure billing alerts
7. Generate documentation
8. Create initial release

### Rationale

1. **Time Savings:** 5 minutes vs 2-3 hours of manual work
2. **Reduce Errors:** No manual copy/paste mistakes
3. **Reproducible:** Same command works every time
4. **Clear Differentiator:** Competitors require many manual steps
5. **User Delight:** Exceeds expectations ("it just works!")
6. **Lower Barrier:** Encourages adoption and experimentation

### Consequences

**Positive:**
- Fastest time-to-value in the market
- Eliminates common configuration mistakes
- Easy to demonstrate (live demo in 5 minutes)
- Users can iterate quickly (tear down and rebuild)
- Documentation is simpler (one command to document)

**Negative:**
- Less flexibility for customization during setup
- Must handle many edge cases in automation
- Harder to debug when something fails mid-process
- Single command hides complexity (both good and bad)

**Mitigation:**
- Provide individual step commands (`make create-accounts`, `make bootstrap`, etc.)
- Verbose output shows progress at each step
- Generate detailed summary files for review
- Script validation checks prerequisites before starting

---

## ADR-006: Cost-Conscious Design

**Date:** 2025-01-15
**Status:** Accepted
**Deciders:** Project team

### Context

Target audience includes:
- Solo developers with side projects
- Early-stage startups with limited runway
- Students learning AWS
- Small teams (2-10 people) with tight budgets

These users are **extremely cost-sensitive** and surprised by AWS bills can cause abandonment.

Original use case (therapy practice SaaS) required:
- Predictable costs for budgeting
- Alerts to catch runaway spending
- Optimization guidance
- Free tier maximization

### Decision

Make **cost consciousness** a core design principle:

1. **Conservative Billing Alerts:**
   - CloudWatch alarm at $15/month per account
   - Budget limit at $25/month per account
   - Total: ~$75/month for all 3 environments

2. **Cost Documentation:**
   - BILLING_MANAGEMENT.md with optimization strategies
   - Free tier guidance
   - Cost estimates in README
   - Shutdown patterns for dev resources

3. **Default to Cost-Effective:**
   - Small instance sizes
   - Serverless-first recommendations
   - Efficient resource tagging

### Rationale

1. **Prevent Surprise Bills:** #1 complaint about AWS from newcomers
2. **Build Trust:** Users won't abandon tool due to unexpected costs
3. **Competitive Advantage:** Most tutorials ignore cost management
4. **Target Audience Fit:** Small teams need predictability
5. **Risk Mitigation:** Alerts catch mistakes/attacks early

### Consequences

**Positive:**
- Users feel confident experimenting
- Early warning system prevents bill shock
- Documentation helps optimize costs from day one
- Email alerts create accountability
- Budget limits protect against runaway costs

**Negative:**
- Alerts may be too sensitive for some use cases
- $15/$25 limits may be low for active development
- Email fatigue if frequently hitting thresholds
- Users must adjust thresholds for production workloads

**Mitigation:**
- Document how to adjust thresholds
- Provide guidance on typical costs
- Make thresholds configurable in scripts
- v1.1 will add cost estimation before deployment

---

## Decision Log

### Pending Decisions

**PEN-001:** Multi-region strategy
- **Context:** Should v1.1 support multi-region deployments?
- **Options:** Single region only, active-active, active-passive
- **Target:** v1.2 release

**PEN-002:** Testing strategy
- **Context:** How to test infrastructure automation?
- **Options:** Manual, bats-core scripts, localstack, isolated AWS org
- **Target:** v1.1 release

### Superseded Decisions

None yet.

---

## How to Use This Document

### When to Create an ADR

Create an ADR for decisions that:
1. Have significant impact on the project architecture
2. Are difficult or expensive to reverse
3. Affect multiple components or systems
4. Require explanation of trade-offs
5. Set precedent for future decisions

### ADR Template

```markdown
## ADR-XXX: [Short Title]

**Date:** YYYY-MM-DD
**Status:** [Proposed | Accepted | Rejected | Superseded | Deprecated]
**Deciders:** [Who made this decision]

### Context
[What is the issue we're facing? What forces are at play?]

### Decision
[What did we decide? State clearly and concisely.]

### Rationale
[Why did we make this decision? List key factors.]

### Consequences
**Positive:**
[Good outcomes from this decision]

**Negative:**
[Drawbacks or limitations]

**Mitigation:**
[How we address the negatives]
```

### Updating ADRs

- ADRs are **immutable** once accepted
- To change a decision, create a new ADR that supersedes the old one
- Update the old ADR's status to "Superseded by ADR-XXX"
- Preserve historical context (don't delete or heavily edit accepted ADRs)

---

## References

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [AWS Multi-Account Strategy](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_best-practices.html)
- [Architecture Decision Records (ADR)](https://adr.github.io/)
- [Comparison: oliverschenk/aws-multi-account-terraform](https://github.com/oliverschenk/aws-multi-account-multi-region-bootstrapping-terraform)
- [Comparison: grendel-consulting/terraform-aws-cdk_bootstrap](https://github.com/grendel-consulting/terraform-aws-cdk_bootstrap)