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
- Perl 5.36+ (cPanel-provided at `/usr/local/cpanel/3rdparty/bin/perl`) + GD::Graph::bars, GD::Graph::pie, GD::Graph::lines, Fcntl (006-modernize-serverstats)
- Reads from `/var/lib/csf/stats/system`, writes GIF images to configurable directory (006-modernize-serverstats)
- Perl 5.36+ (cPanel-provided at `/usr/local/cpanel/3rdparty/bin/perl`) Net::IP, Fcntl (001-modernize-rblcheck)
- Perl 5.36+ (cPanel-provided at `/usr/local/cpanel/3rdparty/bin/perl`) + None (pure refactoring, no new dependencies) (008-remove-ampersand)
- File system (modify existing `.pl`, `.pm`, `.t` files in place) (008-remove-ampersand)

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
- 008-remove-ampersand: Added Perl 5.36+ (cPanel-provided at `/usr/local/cpanel/3rdparty/bin/perl`) + None (pure refactoring, no new dependencies)
- 006-modernize-serverstats: Added Perl 5.36+ (cPanel-provided at `/usr/local/cpanel/3rdparty/bin/perl`) + GD::Graph::bars, GD::Graph::pie, GD::Graph::lines, Fcntl
- 006-modernize-sendmail: Added Perl 5.36+ (cPanel-provided at `/usr/local/cpanel/3rdparty/bin/perl`) + ConfigServer::Config, ConfigServer::Slurp, Carp, POSIX, Net::SMTP (conditional)


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
