# csf Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-01-22

## Active Technologies
- Perl 5.36+ (cPanel-provided at `/usr/local/cpanel/3rdparty/bin/perl`) + Fcntl, File::Find, File::Copy, IPC::Open3 (002-modernize-cseui)
- File system operations (read/write/copy/delete files and directories) (002-modernize-cseui)
- Perl 5.36+ (cPanel-provided at `/usr/local/cpanel/3rdparty/bin/perl`) + ConfigServer::Config, Cpanel::Slurp, Fcntl (004-modernize-ports)
- N/A (reads from /proc filesystem) (004-modernize-ports)
- Perl 5.36+ (cPanel-provided at `/usr/local/cpanel/3rdparty/bin/perl`) + Fcntl, File::Copy, IPC::Open3 (003-modernize-displayui)
- File-based configuration at `/etc/csf/csf.conf` (003-modernize-displayui)
- Perl 5.36+ (cPanel-provided at `/usr/local/cpanel/3rdparty/bin/perl`) + ConfigServer::Config, ConfigServer::Slurp, Carp, POSIX, Net::SMTP (conditional) (006-modernize-sendmail)
- N/A (sends email via SMTP or sendmail binary) (006-modernize-sendmail)

- Perl 5.36+ (cPanel-provided at `/usr/local/cpanel/3rdparty/bin/perl`) Net::IP, Fcntl (001-modernize-rblcheck)

## Project Structure

```text
src/
tests/
```

## Commands

# Add commands for Perl 5.36+ (cPanel-provided at `/usr/local/cpanel/3rdparty/bin/perl`)

## Code Style

Perl 5.36+ (cPanel-provided at `/usr/local/cpanel/3rdparty/bin/perl`): Follow standard conventions

## Recent Changes
- 006-modernize-sendmail: Added Perl 5.36+ (cPanel-provided at `/usr/local/cpanel/3rdparty/bin/perl`) + ConfigServer::Config, ConfigServer::Slurp, Carp, POSIX, Net::SMTP (conditional)
- 004-modernize-ports: Added Perl 5.36+ (cPanel-provided at `/usr/local/cpanel/3rdparty/bin/perl`) + ConfigServer::Config, Cpanel::Slurp, Fcntl
- 003-modernize-displayui: Added Perl 5.36+ (cPanel-provided at `/usr/local/cpanel/3rdparty/bin/perl`) + Net::CIDR::Lite, Fcntl, File::Copy, IPC::Open3


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
