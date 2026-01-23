# Implementation Plan: Modernize RBLCheck.pm

**Branch**: `001-modernize-rblcheck` | **Date**: 2026-01-22 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-modernize-rblcheck/spec.md`

## Summary

Modernize ConfigServer::RBLCheck to follow cPanel Perl standards: remove package-level config loading, convert internal functions to private (`_` prefix), add POD documentation for public API only, disable non-ConfigServer imports, and create unit tests with MockConfig isolation. Pattern follows CloudFlare.pm modernization (commit 7bd732d).

## Technical Context

**Language/Version**: Perl 5.36+ (cPanel-provided at `/usr/local/cpanel/3rdparty/bin/perl`)  
**Primary Dependencies**: ConfigServer::Config, ConfigServer::RBLLookup, ConfigServer::GetEthDev, Net::IP, Fcntl  
**Storage**: `/var/lib/csf/{ip}.rbls` (cache files), `/etc/csf/csf.rblconf` (config)  
**Testing**: Test2::V0, Test2::Plugin::NoWarnings, t/lib/MockConfig.pm  
**Target Platform**: Linux server with CSF installed  
**Project Type**: Single module modernization within existing codebase  
**Performance Goals**: No regression from existing behavior  
**Constraints**: Must preserve existing error handling; cannot break production systems  
**Scale/Scope**: 275-line module, 1 public function, 5 internal functions

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Design Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Security-First Design | ✅ PASS | Existing file operations use `sysopen` with flags; no new security vectors introduced |
| II. Perl Standards Compliance | ⚠️ REQUIRES FIX | Current: `use strict` → Must change to `use cPstrict;`; Perl 4 `&func` calls → Must convert; imports not disabled |
| III. Test-First & Isolation | ⚠️ REQUIRES FIX | No test file exists; config loaded at package level → Must defer loading |
| IV. Configuration Discipline | ⚠️ REQUIRES FIX | `$ipv4reg`/`$ipv6reg` at package level → Must move into functions |
| V. Simplicity & Maintainability | ✅ PASS | Functions are reasonably sized; no complexity violations |

**Gate Result**: PROCEED with fixes required (II, III, IV)

### Post-Design Re-Check

| Principle | Status | Resolution |
|-----------|--------|------------|
| I. Security-First Design | ✅ PASS | No changes to security posture |
| II. Perl Standards Compliance | ✅ WILL PASS | Plan addresses: cPstrict (P2), Perl 4 calls (P3), disabled imports (P2) |
| III. Test-First & Isolation | ✅ WILL PASS | Plan addresses: test file (P5), config deferred (P1) |
| IV. Configuration Discipline | ✅ WILL PASS | Plan addresses: remove $ipv4reg/$ipv6reg (P1), %config in function (P1) |
| V. Simplicity & Maintainability | ✅ PASS | Private functions improve API clarity |

**Post-Design Gate Result**: ✅ ALL PRINCIPLES ADDRESSED BY PLAN

## Project Structure

### Documentation (this feature)

```text
specs/001-modernize-rblcheck/
├── plan.md              # This file
├── spec.md              # Feature specification (complete)
├── research.md          # Phase 0 output (pattern analysis)
├── data-model.md        # Phase 1 output (entity definitions)
├── quickstart.md        # Phase 1 output (implementation guide)
├── contracts/           # Phase 1 output (API contracts)
│   └── rblcheck-api.md  # Public API contract
└── tasks.md             # Phase 2 output (NOT created by /speckit.plan)
```

### Source Code (affected files)

```text
lib/ConfigServer/
└── RBLCheck.pm          # Module to modernize

t/
├── ConfigServer-RBLCheck.t  # New test file (to create)
└── lib/
    └── MockConfig.pm        # Existing mock utility (reuse)
```

**Structure Decision**: Single module modernization; no new directories needed. Test file follows existing naming convention `t/ConfigServer-{ModuleName}.t`.

## Complexity Tracking

*No violations requiring justification. All changes align with constitution.*
