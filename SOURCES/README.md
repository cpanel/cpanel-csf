# SOURCES Directory

This directory contains source files and patches for the CSF RPM build.

## Tarball Generation

Unlike traditional OBS packages where source files are committed directly to the SOURCES directory, this package uses an automated tarball generation approach.

### Why This Approach?

1. **Avoids Duplication**: The actual source files already exist in the repository root. Duplicating them in SOURCES would be redundant and error-prone.

2. **Automatic Updates**: When you make changes to the source code, you don't need to manually copy files to SOURCES or regenerate tarballs.

3. **Build Server Compatibility**: When using `et obs $PROJECT` to push to the build server, the Makefile automatically generates the required tarball.

### How It Works

The `Makefile` includes a `tarball` target that:

1. Reads the version from `etc/version.txt`
2. Creates a tarball named `csf-VERSION.tar.gz`
3. Includes all necessary source files (excluding build artifacts, git files, etc.)
4. Places the tarball in this SOURCES directory

### Usage

**For local development:**
```bash
make tarball              # Generate tarball manually
make local                # Build locally (auto-generates tarball)
rpmbuild -ba SPECS/cpanel-csf.spec  # Build RPM (requires tarball exists)
```

**For OBS builds:**
```bash
make obs                  # Push to OBS (auto-generates tarball)
et obs cpanel-plugins     # Alternative using et tool
```

### Generated Files

Files matching `csf-*.tar.gz` are automatically generated and should **NOT** be committed to git. They are listed in `.gitignore`.

### Manual Tarball Creation

If you need to manually create a tarball for testing:

```bash
make clean-tarball  # Remove any existing tarballs
make tarball        # Generate fresh tarball
```

The tarball will contain the source tree with the structure expected by the RPM spec file's `%setup -q -n csf-VERSION` directive.
