# ConfigServer Firewall (CSF) - OBS Build Setup

This repository has been "obs-ified" to support building RPM packages through the Open Build Service (OBS) infrastructure used by cPanel.

## Repository Structure

```
app-csf/
├── SPECS/              # RPM spec files
│   └── cpanel-csf.spec
├── SOURCES/            # Source tarballs (auto-generated)
│   └── README.md       # Explains the tarball approach
├── Makefile            # Enhanced with OBS build targets
├── .gitignore          # Updated to ignore build artifacts
└── (source files)      # Original CSF source code
```

## Key Changes

### 1. RPM Spec File

Created [SPECS/cpanel-csf.spec](SPECS/cpanel-csf.spec) that:
- Defines the package metadata (name, version, dependencies)
- Translates install.sh logic into RPM %install section
- Sets up systemd services
- Configures cPanel WHM integration
- Manages file permissions and ownership
- Includes post-install scripts for setup

**Note:** Fixed an issue in the original install.sh where `etc/ui/images/icon.gif` was referenced but doesn't exist. The spec file uses `csf.svg` instead with a compatibility symlink.

### 2. Enhanced Makefile

The Makefile now includes:
- **OBS Integration**: `OBS_PROJECT` and `OBS_PACKAGE` variables
- **Automatic Tarball Generation**: `tarball` target creates `csf-VERSION.tar.gz`
- **Build Hooks**: Ensures tarball is created before `local` or `obs` builds
- **Preserved Functionality**: All original targets (`sandbox`, `test`, `man`, `install`) still work

Key Makefile additions:
```makefile
OBS_PROJECT := cpanel-plugins
OBS_PACKAGE := cpanel-csf
-include $(EATOOLS_BUILD_DIR)obs.mk

VERSION := $(shell cat etc/version.txt)
```

### 3. Automated Tarball Creation

Instead of manually maintaining source files in SOURCES/, the build process:
1. Reads version from `etc/version.txt`
2. Creates `SOURCES/csf-VERSION.tar.gz` with proper directory structure
3. Excludes build artifacts (`.git`, `SPECS`, `OBS.*`, etc.)
4. Includes all files needed by the RPM spec file

This approach:
- ✅ Eliminates duplication
- ✅ Automatically includes changes when building
- ✅ Works seamlessly with `et obs` workflow
- ✅ Tarballs are gitignored (auto-generated)

### 4. Updated .gitignore

Added patterns to ignore:
- `OBS.*` - OBS working directories
- `SOURCES/*.tar.gz` - Generated tarballs
- `RPMS/*` and `SRPMS/*` - Built packages
- `debian/*` and `cpanel-csf_*` - Debian build artifacts

## Building Locally

### Using rpmbuild

```bash
# Generate tarball
make tarball

# Copy files to rpmbuild directory
cp SOURCES/csf-*.tar.gz ~/rpmbuild/SOURCES/
cp SPECS/cpanel-csf.spec ~/rpmbuild/SPECS/

# Build RPM
cd ~/rpmbuild
rpmbuild -ba SPECS/cpanel-csf.spec
```

### Using OBS local build

```bash
# This will build in an OBS-like chroot environment
ARCH=x86_64 REPO=Rocky_9 make local
```

## Deploying to OBS

### Initial Setup

Before first use, ensure your OBS credentials are configured:
```bash
# Check configuration
cat ~/.oscrc
```

### Pushing to Build Server

```bash
# Generate tarball and push to OBS
make obs

# Or use et tool
et obs cpanel-plugins
```

The `make obs` command will:
1. Automatically generate the tarball
2. Branch from OBS project `cpanel-plugins`
3. Upload all files from SOURCES/ and SPECS/
4. Commit changes
5. Trigger OBS build

## Version Management

The version is stored in `etc/version.txt` and referenced by:
- Makefile (for tarball naming)
- RPM spec file (via `%define csf_version 15.00`)

To bump the version:
1. Update `etc/version.txt`
2. Update `%define csf_version` in `SPECS/cpanel-csf.spec`
3. Add changelog entry to spec file

## Testing

All existing test functionality is preserved:

```bash
# Run Perl tests
make test

# Set up development sandbox
make sandbox

# Generate man page help
make man
```

## Differences from install.sh

The RPM package provides the same functionality as `install.sh` but:

1. **Package Management**: Proper install/uninstall via RPM
2. **Dependency Tracking**: RPM automatically tracks dependencies
3. **Upgrade Path**: Clean upgrade from version to version
4. **Systemd Integration**: Proper systemd unit files
5. **File Tracking**: RPM database tracks all installed files
6. **No Shell Script Errors**: Fixed the missing `icon.gif` issue

## File Manifest

Key files installed by the RPM:

- `/usr/sbin/csf` - Main firewall script
- `/usr/sbin/lfd` - Login Failure Daemon
- `/etc/csf/` - Configuration files
- `/usr/local/csf/` - Libraries, templates, profiles
- `/var/lib/csf/` - Runtime data
- `/usr/lib/systemd/system/csf.service` - CSF systemd unit
- `/usr/lib/systemd/system/lfd.service` - LFD systemd unit
- `/usr/local/cpanel/whostmgr/` - cPanel WHM integration

## Known Issues and Solutions

### Issue: icon.gif doesn't exist
**Solution**: Spec file uses `csf.svg` with backward-compatible symlink

### Issue: Makefile warnings about overriding targets
**Solution**: Harmless - obs.mk and local Makefile both define `clean` and `test`. Local definitions take precedence.

### Issue: OBS project doesn't exist yet
**Solution**: Run `make obs` to create the project on first push

## Maintenance

When making changes to CSF:

1. Edit source files as normal
2. Run `make test` to verify
3. Commit changes to git
4. Run `make obs` to rebuild and deploy

The tarball will automatically include your changes - no manual tarball management needed!

## Support

For issues with:
- **CSF itself**: See original README.md and documentation
- **OBS build process**: Consult ea-cpanel-tools documentation
- **Spec file bugs**: Check SPECS/cpanel-csf.spec comments

## Migration Notes

This OBS setup replaces the traditional:
```bash
./install.sh    # Old way
```

With:
```bash
yum install cpanel-csf    # New way (after OBS build)
```

The functionality is identical, but now integrated with cPanel's package management infrastructure.
