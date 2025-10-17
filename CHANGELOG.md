# Changelog

All notable changes to the AWS Multi-Account Bootstrap tool will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
