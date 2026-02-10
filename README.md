# CSF fork Way to the Web Limited Scripts

This code base is the former contents of the [csf subdir](https://github.com/cpanel/waytotheweb-scripts/tree/main/csf) in the original main branch.

We are only developing CSF here.

## RPM packaging notes

- The `cpanel-csf` RPM is intended for cPanel & WHM systems only and will fail
	installation when cPanel is not detected.
- The RPM depends on `cpanel-perl` and required Perl modules for runtime.
