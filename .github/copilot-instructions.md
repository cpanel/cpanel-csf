# GitHub Copilot Instructions for CSF

This repository contains specialized coding standards and best practices for different components of the cPanel CSF ecosystem

## MANDATORY INSTRUCTION APPLICATION

**CRITICAL: Before responding to any request involving code changes, file creation, or analysis, the AI MUST:**

1. **Identify all file patterns** mentioned in the user's request or that will be affected by the work
2. **Match patterns** against the lookup table below to find applicable instruction files
3. **Read and apply** ALL matching instruction files using the `read_file` tool
4. **Follow the standards** specified in those instruction files for the response

**This is not optional - failure to apply relevant instructions violates cPanel & WHM coding standards.**

## Instruction Application System

Below is a lookup table that maps file patterns to their corresponding instruction files. When working with files that match these patterns, the AI will automatically apply the relevant coding standards, conventions, and best practices.

| Pattern | File Path | Description |
| ------- | --------- | ----------- |
| t/*.t | '.github/instructions/tests-perl.instructions.md' | Perl unit testing conventions using Test2 framework and coverage requirements |
| *.pm,*.pl | '.github/instructions/perl.instructions.md' | Perl unit testing conventions using Test2 framework and coverage requirements |
| **/*.{pm,pl,t}, lib/**/*.pm, t/*.t, /*.pl | '.github/instructions/cpanel-perl-instructions.md' | Perl development standards, module patterns, and Perl conventions |

## How This System Works

**MANDATORY WORKFLOW for the AI:**

1. **Pattern Matching**: For every request, scan all mentioned file paths against the pattern table above
2. **Instruction Loading**: Use `read_file` tool to load ALL matching instruction files before proceeding
3. **Standards Application**: Apply all loaded standards when generating code, tests, or providing advice
4. **Multiple Rules**: When files match multiple patterns, apply ALL applicable instruction sets
5. **Verification**: Ensure the final output complies with all loaded instruction requirements

**Examples of when to apply instructions:**
- User mentions `ConfigServer/AbuseIP.pm` → Load perl.instructions.md
- User requests tests for `.pm` files → Load both cpanel-perl.instructions.md AND tests-perl.instructions.md
- User works with Angular files → Load relevant Angular instructions + web-accessibility.instructions.md
- User modifies WHM binaries → Load whostmgr-binaries.instructions.md + cpanel-perl.instructions.md

## Automatic Detection & Application

The AI MUST automatically identify which instruction sets apply based on file paths and patterns, then load and apply those instructions. This ensures consistent code quality across different technologies and components in the cPanel & WHM ecosystem.

## Key Areas Covered

### Backend Development
- **Perl Standards**: Modern Perl, function signatures, and cPanel conventions

### Testing & Quality
- **Perl Testing**: Test2 framework with comprehensive coverage requirements

## Getting Help

When working with any file in this repository, simply describe what you want to accomplish. The AI will automatically:

1. **Scan file patterns** mentioned in your request
2. **Load relevant instruction files** using the read_file tool
3. **Apply appropriate coding standards** and conventions from those files
4. **Provide solutions** that follow cPanel & WHM best practices
5. **Ensure compliance** with security, accessibility, and performance requirements

**The AI is required to load and apply instruction files before responding to any code-related request.**

The instruction files are regularly updated to reflect the latest standards and practices. This automated system ensures you always get the most current and appropriate guidance for your specific development context.
