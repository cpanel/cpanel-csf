# Data Model: Modernize cseUI.pm

**Feature**: 002-modernize-cseui  
**Date**: 2026-01-23

## Overview

This is a code modernization task with no data model changes. This document captures the existing data structures for reference.

## Entities

### %config

Configuration hash loaded from `/etc/csf/csf.conf`.

| Key | Type | Description |
|-----|------|-------------|
| `UI_CXS` | Boolean | Enable CXS integration in UI |
| `UI_CSE` | Boolean | Enable CSE (ConfigServer Explorer) in UI |
| (others) | Various | CSF configuration values |

### %FORM

Form input hash passed from CGI request.

| Key | Type | Description |
|-----|------|-------------|
| `do` | String | Action to perform: view, browse, edit, save, del, setp, seto, ren, moveit, copyit, cnewd, cnewf, console, cd, uploadfile |
| `p` | String | Current path |
| `n` | String | File/directory name |
| `origpath` | String | Original path for move/copy operations |
| `destpath` | String | Destination path for move/copy operations |
| `perm` | String | Permission mode (octal) |
| `owner` | String | Owner for chown operations |
| `text` | String | File content for save operations |
| (others) | Various | Form-specific input values |

### Package Variables

Variables used for inter-subroutine communication:

| Variable | Type | Description |
|----------|------|-------------|
| `$script` | String | CGI script URL path |
| `$script_da` | String | DirectAdmin script path |
| `$images` | String | Images directory path |
| `$myv` | String | Module version |
| `$fileinc` | Ref | File upload reference |
| `$webpath` | String | Web-accessible path |
| `$thisdir` | String | Current directory being processed |
| `@thisdirs` | Array | Directories in current listing |
| `@thisfiles` | Array | Files in current listing |
| `$message` | String | Status/error message to display |
| `$extramessage` | String | Additional message content |

## Relationships

```
%FORM (input) → main() → dispatch to action handler
                  ↓
             %config (read from file)
                  ↓
             Action handlers (_browse, _edit, etc.)
                  ↓
             HTML output (printed to STDOUT)
```

## No Schema Changes

This modernization does not change any data structures or relationships. All changes are purely syntactic/organizational.
