# Contributing to aws-enterprise-network-architecture

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to this project.

---

## Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Focus on the code, not the person
- Help others learn and grow

---

## Getting Started

### Prerequisites

- Terraform >= 1.5.0
- AWS CLI v2
- Git
- Basic understanding of AWS networking and Terraform

### Setup Development Environment

```bash
# Clone the repository
git clone https://github.com/[org]/aws-enterprise-network-architecture.git
cd aws-enterprise-network-architecture

# Create a feature branch
git checkout -b feature/your-feature-name

# Install pre-commit hooks (optional but recommended)
pre-commit install
```

---

## Development Workflow

### 1. Make Changes

- Create a feature branch from `main`
- Make focused, atomic commits
- Write clear commit messages
- Follow existing code style and conventions

### 2. Test Locally

```bash
# Validate Terraform syntax
terraform fmt -recursive .
terraform validate

# Run security scanning
checkov -d .

# Plan changes
cd deployments/[deployment-name]
terraform plan -out=tfplan
```

### 3. Commit and Push

```bash
# Stage changes
git add .

# Commit with clear message
git commit -m "feat: add [feature description]"

# Push to remote
git push origin feature/your-feature-name
```

### 4. Create Pull Request

- Create PR with clear title and description
- Reference any related issues
- Ensure all checks pass
- Request review from maintainers

---

## Commit Message Guidelines

Follow conventional commits format:

```
type(scope): subject

body

footer
```

### Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, missing semicolons, etc.)
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Test additions or changes
- `chore`: Build, dependencies, tooling

### Examples
```
feat(cloudwan): add support for additional segments
fix(firewall): correct rule ordering in inspection VPC
docs(readme): update deployment instructions
refactor(vpc): simplify subnet configuration
```

---

## Code Style

### Terraform

- Use `terraform fmt` for formatting
- Use descriptive variable and resource names
- Add comments for complex logic
- Follow module structure conventions
- Use consistent indentation (2 spaces)

### Documentation

- Use clear, concise language
- Include examples where helpful
- Update README when adding features
- Keep documentation in sync with code

---

## Testing

### Terraform Validation

```bash
# Format check
terraform fmt -check -recursive .

# Syntax validation
terraform validate

# Security scanning
checkov -d . --framework terraform
```

### Manual Testing

1. Plan changes in test environment
2. Review plan output carefully
3. Apply in non-production first
4. Verify expected behavior
5. Document any issues

---

## Documentation

### When to Update Documentation

- Adding new features
- Changing existing behavior
- Adding new modules
- Modifying deployment procedures
- Fixing bugs that affect usage

### Documentation Files

- **README.md** - Overview and quick start
- **DEPLOYMENT_GUIDE.md** - Deployment instructions
- **COMPLETE_SOLUTION_OVERVIEW.md** - Architecture details
- **OPERATIONS_GUIDE.md** - Operations procedures
- **Module READMEs** - Module-specific documentation

---

## Security

### Security Considerations

- Never commit sensitive data (keys, passwords, account IDs)
- Use placeholders for customer-specific values
- Follow AWS security best practices
- Review security scanning results
- Report security issues privately

### Reporting Security Issues

Please report security vulnerabilities via the [AWS vulnerability reporting page](https://aws.amazon.com/security/vulnerability-reporting/) rather than using the issue tracker.

---

## Pull Request Process

1. **Update Documentation**: Update README and relevant docs
2. **Add Tests**: Include test cases if applicable
3. **Run Checks**: Ensure all validation passes
4. **Request Review**: Ask for review from maintainers
5. **Address Feedback**: Respond to review comments
6. **Merge**: Maintainer merges after approval

### PR Checklist

- [ ] Code follows style guidelines
- [ ] Documentation is updated
- [ ] Terraform validation passes
- [ ] Security scanning passes
- [ ] Commit messages are clear
- [ ] No sensitive data included
- [ ] Changes are tested

---

## Reporting Issues

### Bug Reports

Include:
- Clear description of the issue
- Steps to reproduce
- Expected behavior
- Actual behavior
- Environment details (Terraform version, AWS region, etc.)
- Error messages or logs

### Feature Requests

Include:
- Clear description of the feature
- Use case and motivation
- Proposed implementation (if applicable)
- Potential impact on existing functionality

---

## Review Process

### What Reviewers Look For

- Code quality and style
- Security implications
- Documentation completeness
- Test coverage
- Backward compatibility
- Performance impact

### Review Timeline

- Initial review: 2-3 business days
- Follow-up reviews: 1-2 business days
- Merge after approval: 1 business day

---

## Release Process

### Versioning

This project follows [Semantic Versioning](https://semver.org/):
- MAJOR: Incompatible API changes
- MINOR: Backward-compatible functionality additions
- PATCH: Backward-compatible bug fixes

### Release Steps

1. Update version in relevant files
2. Update CHANGELOG.md
3. Create release branch
4. Create git tag
5. Create GitHub release
6. Announce release

---

## Questions?

- Check existing documentation
- Review closed issues and PRs
- Open a discussion or issue
- Contact maintainers

---

## License

By contributing, you agree that your contributions will be licensed under the MIT-0 License.

---

Thank you for contributing to aws-enterprise-network-architecture! 🎉
