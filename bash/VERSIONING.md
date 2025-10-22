# Versioning Strategy

## Current Status: Pre-1.0 (v0.x.x)

This project is in **active development** and has not yet reached v1.0.0. We follow [Semantic Versioning](https://semver.org/) with the understanding that **breaking changes may occur between any v0.x releases**.

## Version History

### Why v0.x.x?

We initially released versions 1.0.0 through 1.5.0, but realized this was premature. Since the project has no production users yet and is still evolving rapidly, we've **reset to v0.x.x** to better reflect reality:

- **v0.x.x** = Pre-release, active development, breaking changes expected
- **v1.0.0** = First stable release (future)

### Version Mapping

For historical reference:
- v1.5.0 → v0.5.0 (October 2024)
- v1.6.0 (planned) → v0.6.0 (Configuration system)

## Version Guidelines

### During v0.x.x (Current Phase)

While in v0.x.x:
- **Breaking changes are expected** between any versions
- **No guarantee of backward compatibility**
- **API and CLI interfaces may change**
- **Documentation may become outdated quickly**

Version increments:
- **v0.x.0** - New features, potentially breaking
- **v0.x.y** - Bug fixes and minor improvements

### When We'll Release v1.0.0

We will release v1.0.0 when:
1. Core features are complete and stable
2. CLI interface is finalized
3. Configuration format is stable
4. We have production users successfully using the tool
5. Documentation is comprehensive
6. Test coverage is adequate

### After v1.0.0

Once we reach v1.0.0, we'll follow strict semantic versioning:
- **Major (x.0.0)** - Breaking changes
- **Minor (0.x.0)** - New features, backward compatible
- **Patch (0.0.x)** - Bug fixes only

## For Early Adopters

If you're using this tool before v1.0.0:
- **Expect breaking changes** between updates
- **Read release notes carefully** before upgrading
- **Pin to specific versions** in your workflows
- **Provide feedback** to help us reach v1.0.0

## Release Channels

- **main branch** - Latest stable v0.x release
- **develop branch** - Next v0.x release in development
- **Tags** - Specific releases (v0.6.0, v0.7.0, etc.)

## Example Version Progression

```
v0.6.0 - Configuration system (breaking: new config format)
v0.7.0 - Multi-account templates (breaking: changes default structure)
v0.8.0 - GitLab support (non-breaking)
v0.9.0 - Multi-region (breaking: new parameters required)
v0.10.0 - Bug fixes
v1.0.0 - First stable release!
```

## Questions?

If you have questions about our versioning:
1. Check the [CHANGELOG.md](CHANGELOG.md) for details
2. Open an issue on GitHub
3. Review our [ROADMAP.md](docs/ROADMAP.md) for planned features

---

**Remember:** This is pre-1.0 software. While we strive for quality, expect changes!