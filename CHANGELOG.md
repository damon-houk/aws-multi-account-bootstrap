# Changelog

All notable changes to the AWS Multi-Account Bootstrap tool will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0](https://github.com/damon-houk/aws-multi-account-bootstrap/compare/v2.0.0...v2.1.0) (2025-10-21)

### Features

* Advanced cost estimation with AWS Pricing API and interactive mode ([#15](https://github.com/damon-houk/aws-multi-account-bootstrap/issues/15)) ([8725844](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/8725844e7842f47cc3a62f7bef0130aab37cf69e)), closes [#14](https://github.com/damon-houk/aws-multi-account-bootstrap/issues/14)

## [2.0.0](https://github.com/damon-houk/aws-multi-account-bootstrap/compare/v1.5.0...v2.0.0) (2025-10-20)

### ⚠ BREAKING CHANGES

* Version reset from v1.5.0 to v0.6.0 to reflect
pre-release status. Breaking changes expected between v0.x releases.

- Add comprehensive test suite for configuration system
- Tests run without AWS/GitHub resources (24/24 passing)
- Add VERSIONING.md explaining v0.x.x strategy
- Update README with pre-1.0 warning badges
- Update CHANGELOG with version reset notice
- Remove old PR_DESCRIPTION.md
* Version reset from v1.5.0 to v0.6.0 to reflect
pre-release status. Breaking changes expected between v0.x releases.

- Add comprehensive test suite for configuration system
- Tests run without AWS/GitHub resources (24/24 passing)
- Add VERSIONING.md explaining v0.x.x strategy
- Update README with pre-1.0 warning badges
- Update CHANGELOG with version reset notice
- Remove old PR_DESCRIPTION.md

* Release v0.6.0: Configuration system and version reset to pre-1.0 ([#12](https://github.com/damon-houk/aws-multi-account-bootstrap/issues/12)) ([d423ef8](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/d423ef89653e4faf0a343a6b84db0d64e5c2fe86)), closes [#10](https://github.com/damon-houk/aws-multi-account-bootstrap/issues/10) [#11](https://github.com/damon-houk/aws-multi-account-bootstrap/issues/11) [#11](https://github.com/damon-houk/aws-multi-account-bootstrap/issues/11)

### Features

* Add mode-based configuration system with YAML/JSON support ([#11](https://github.com/damon-houk/aws-multi-account-bootstrap/issues/11)) ([101fe4e](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/101fe4e784652c07fdfcf95e6fba5efcab2d7b56))
* Add test suite for config system and reset to v0.6.0 ([39baefb](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/39baefb16e6992cee0e84802ae05754a97ef4fb8)), closes [#11](https://github.com/damon-houk/aws-multi-account-bootstrap/issues/11)
* Add UI helper library for beautiful CLI experiences ([#10](https://github.com/damon-houk/aws-multi-account-bootstrap/issues/10)) ([dcb61b0](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/dcb61b087cb52a522e3df47ad345ad29c5c1906a))
* Upgrade version requirements and overhaul prerequisite checker UX ([2da3c17](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/2da3c173a0772910989c728365e65978a50e953a))

### Bug Fixes

* Add GitHub CLI prerequisite checks to setup-complete-project.sh ([594a288](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/594a288d2b88287a537fe4973b07de37804105fa))
* Remove .claude from version control and add to gitignore ([4c4a097](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/4c4a097b45244a633cdbf75ce279d9da7072fdca))
* Remove nameref usage to pass ShellCheck CI ([df3bf88](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/df3bf88e9c27cec46a7d31fc7a6490396d5f75b3))

### Code Refactoring

* Eliminate duplicate prerequisite checking code ([5e50ba7](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/5e50ba7ae6b5d4ec8aa3aa6e72ff460fbe1c49f2))

## IMPORTANT: Version Reset to v0.x.x

As of October 2025, we are resetting the version from v1.5.0 to v0.6.0 to better reflect the project's pre-release status. Since there are no production users yet and the project is still in active development with frequent breaking changes expected, the v0.x.x versioning is more appropriate. See [VERSIONING.md](VERSIONING.md) for details.

## [0.6.0] - 2025-10-19 (Unreleased)

### Added
- Mode-based configuration system with YAML/JSON support
- Environment variable configuration (BOOTSTRAP_* prefix)
- CI mode with auto-detection (CI, GITHUB_ACTIONS, GITLAB_CI)
- Input validation for PROJECT_CODE, EMAIL_PREFIX, OU_ID
- Comprehensive configuration guide (docs/CONFIGURATION.md)
- Test suite for configuration system (no AWS/GitHub resources required)
- VERSIONING.md to explain pre-1.0 status

### Changed
- setup-complete-project.sh refactored to use new config-manager library
- Configuration precedence now mode-based (interactive vs CI)
- yq added as optional dependency for YAML support
- **BREAKING**: Reset version from v1.5.0 to v0.6.0 to reflect pre-release status

### Fixed
- ShellCheck warnings in prerequisite-checker.sh
- Broken link in CONFIGURATION.md

---

## Previous Releases (Before Version Reset)

The following releases were made before we adopted proper v0.x.x versioning:

### [1.5.0] - 2025-10-19 (Now v0.5.0)

### Features

* Add UI helper library for beautiful CLI experiences ([#10](https://github.com/damon-houk/aws-multi-account-bootstrap/issues/10)) ([0504311](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/0504311c044737004fe9102ee235329fb181f51d))

## [1.4.0](https://github.com/damon-houk/aws-multi-account-bootstrap/compare/v1.3.0...v1.4.0) (2025-10-19)

### Features

* Add flexible IaC template validation for multi-IaC support ([3e5a011](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/3e5a011e0cb73d219d04e9acefd0754d3658cebe))
* Add make ci-local target to run CI checks before pushing ([85a6aef](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/85a6aefcaf685fe5a925d8ad124c9d6607f4c7f9))

### Bug Fixes

* Add GitHub CLI prerequisite checks to setup-complete-project.sh ([6abe788](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/6abe7882d0df10910dd87cd08a46da9317068642))
* Add non-interactive mode and generate package-lock.json ([adbaca8](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/adbaca83065e051f93817a6aa665273c6466103c))
* Add non-interactive mode to setup-github-repo.sh ([684dd38](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/684dd38d9da7079c9986c43742ff067b02d55f2a))
* Fix ShellCheck warnings and remove emojis from anchor link headings ([3b4153a](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/3b4153aa0a61bc0f94b4faab67d89842833e4d51))

### Documentation

* Update roadmap to reflect actual version progress (v1.2.1) ([e7f7497](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/e7f749769b683033d30840beccb2702553e97e49))

## [1.3.0](https://github.com/damon-houk/aws-multi-account-bootstrap/compare/v1.2.1...v1.3.0) (2025-10-17)

### Features

* Organize generated files into output/ directory and restore docs folder ([b07e1ab](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/b07e1abac21802dc2149232097a57f0acbe75f1d))

### Bug Fixes

* Add bash 3.x compatibility to setup-billing-alerts.sh ([db60777](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/db60777c27003107701b809342ec5ba301ba354f))
* Replace placeholder URLs with actual repository links ([094f523](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/094f523301aa170cf3c53b48e4a5dae8410dbec8))

### Documentation

* Update README cost breakdown to reflect actual baseline costs ([870c278](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/870c278e327fc5a388d3d97c2d850e929d506f2c))

## [1.2.1](https://github.com/damon-houk/aws-multi-account-bootstrap/compare/v1.2.0...v1.2.1) (2025-10-16)

### Bug Fixes

* Complete E2E testing and fix 6 critical bugs ([f8ba15e](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/f8ba15e0e0d5fcb1a2801ae96299b687680014f8))
* Remove inappropriate CDK synth test from CI workflow ([3d42867](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/3d428670eb132ad2c54417aaa411bef1092067d0))

### Documentation

* add E2E test plan and session continuity guide ([7d3d904](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/7d3d9045f19de92276c827e36ec16c1c3cd0abe1))

## [1.2.0](https://github.com/damon-houk/aws-multi-account-bootstrap/compare/v1.1.0...v1.2.0) (2025-10-15)

### Features

* add CDK synth testing to CI workflow ([f51cb07](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/f51cb0785969dad8a1f5cac94ef2688d1cfba8e2))

### Bug Fixes

* add package-lock.json for CI workflow ([5c10285](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/5c10285bce81c0b0033caff47a61f8a4250e2ee9))
* ignore relative markdown file links in link checker ([03518b0](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/03518b0c6abc06a7443766f4d01576cbb5df6145))
* remove broken discussions link from documentation ([cee9964](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/cee996413c10a799cf22d0e17755771bf6c63d27))
* resolve ShellCheck warnings in bash scripts ([c4b4e46](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/c4b4e463546aca6974dd4467a45744a05a968c97))

## [1.1.0](https://github.com/damon-houk/aws-multi-account-bootstrap/compare/v1.0.0...v1.1.0) (2025-10-15)

### Features

* add project configuration and testing infrastructure ([a268c7c](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/a268c7c85630249d2bbf82c8de145fefad74bd95))

### Bug Fixes

* add username ([92f5c87](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/92f5c874c14b1251f84cfd87d6763d6800719fa4))
* replace username with placeholder ([29bc424](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/29bc424bcc2fa60039400a083aeb76594e70e466))
* resolve CI workflow issues ([e2387f5](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/e2387f5af7a4ac197dd91cab4c8dfbcc28ca8e18))

### Documentation

* add CONTRIBUTING.md and ROADMAP.md ([68e5e27](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/68e5e27ee9b56a24588814bad11688edf5fd5f95))

## [Unreleased]

### Added
- package.json with npm scripts and dependencies
- .gitignore for Node.js, AWS, and IDE files
- jest.config.js for test configuration
- .github/CODEOWNERS for code review automation
- tests/ directory with README and example tests

## 1.0.0 (2025-10-15)

### Features

* add GitHub workflows for CI/CD and automated releases ([25b331b](https://github.com/damon-houk/aws-multi-account-bootstrap/commit/25b331ba100d51036faa5c5ee778fe04e92e91a1))
