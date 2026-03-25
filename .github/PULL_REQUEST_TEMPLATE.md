## Description

Please include a summary of the changes and related context.

## Type of Change

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to change)
- [ ] Documentation update
- [ ] Infrastructure improvement
- [ ] Security enhancement

## Related Issues

Closes #(issue number)

## Changes Made

- [ ] Change 1
- [ ] Change 2
- [ ] Change 3

## Testing

Please describe the tests you ran to verify your changes:

```bash
# Example test commands
terraform validate
terraform fmt -check -recursive .
checkov -d .
```

## Deployment Impact

- **Backward Compatible**: Yes / No
- **Requires State Migration**: Yes / No
- **Requires Manual Steps**: Yes / No

If yes, please describe:

## Checklist

- [ ] My code follows the style guidelines of this project
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests passed locally with my changes
- [ ] Any dependent changes have been merged and published
- [ ] I have not included sensitive data (account IDs, keys, etc.)
- [ ] I have verified Terraform validation passes
- [ ] I have verified security scanning passes

## Screenshots (if applicable)

Add screenshots or diagrams if applicable.

## Additional Notes

Add any additional notes or context here.

## Reviewers

Please review this PR and provide feedback.

---

**Before submitting, please ensure:**
1. ✅ All tests pass
2. ✅ Code is formatted with `terraform fmt`
3. ✅ Security scanning passes with `checkov`
4. ✅ Documentation is updated
5. ✅ No sensitive data is included
