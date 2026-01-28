# Quickstart: Remove Ampersand Prefix from Perl Function Calls

**Feature**: [spec.md](spec.md)  
**Research**: [research.md](research.md)  
**Date**: 2026-01-28

## Overview

This quickstart provides a step-by-step workflow for safely modernizing Perl function call syntax across the CSF codebase by removing legacy ampersand (`&`) prefixes.

## Prerequisites

- ✅ Feature branch `008-remove-ampersand` checked out
- ✅ Clean working directory (`git status` shows no uncommitted changes)
- ✅ Baseline test suite passes: `make test` returns success
- ✅ Perl 5.36+ available at `/usr/local/cpanel/3rdparty/bin/perl`

## Workflow

### Phase 1: Establish Baseline

```bash
# Record baseline test results
make test > /tmp/baseline-test-results.txt 2>&1
echo $? > /tmp/baseline-exit-code.txt

# Verify all files pass syntax check
find . -type f \( -name '*.pl' -o -name '*.pm' -o -name '*.t' \) \
  ! -path './etc/*' ! -path './.git/*' ! -path './tpl/*' \
  | xargs -I {} sh -c 'perl -cw -Ilib {} 2>&1 || echo "FAIL: {}"' \
  > /tmp/baseline-syntax-check.txt

# Count ampersand instances before transformation
grep -r '&\w\+(' --include='*.pl' --include='*.pm' --include='*.t' \
  . 2>/dev/null | wc -l > /tmp/baseline-ampersand-count.txt
```

### Phase 2: Transform Test Files First (Lowest Risk)

```bash
# Find all test files
find t/ -name '*.t' > /tmp/test-files.txt

# Create backup
tar czf /tmp/csf-tests-backup-$(date +%Y%m%d-%H%M%S).tar.gz t/

# Transform test files - Iteration 1: Remove & from function calls with parens
find t/ -name '*.t' | while read file; do
  perl -i.bak -pe 's/(?<!\\)(?<!goto\s)&(\w+)\s*\(/$1(/g' "$file"
done

# Transform test files - Iteration 2: Check if more transformations needed
# (Run iteration 1 again to handle nested cases)
find t/ -name '*.t' | while read file; do
  perl -i -pe 's/(?<!\\)(?<!goto\s)&(\w+)\s*\(/$1(/g' "$file"
done

# Validate syntax of all transformed test files
find t/ -name '*.t' | xargs -I {} perl -cw -Ilib {} 2>&1 | tee /tmp/tests-syntax-check.txt

# Run test suite
make test | tee /tmp/tests-after-transformation.txt

# Check exit code
if [ $? -eq 0 ]; then
  echo "✅ Test files transformation PASSED"
  # Remove backup files
  find t/ -name '*.bak' -delete
else
  echo "❌ Test files transformation FAILED - reviewing errors"
  exit 1
fi
```

### Phase 3: Transform Library Modules

```bash
# Find all module files
find lib/ConfigServer/ -name '*.pm' > /tmp/module-files.txt

# Create backup
tar czf /tmp/csf-lib-backup-$(date +%Y%m%d-%H%M%S).tar.gz lib/

# Transform modules - Iteration 1
find lib/ConfigServer/ -name '*.pm' | while read file; do
  perl -i.bak -pe 's/(?<!\\)(?<!goto\s)&(\w+)\s*\(/$1(/g' "$file"
done

# Transform modules - Iteration 2 (nested calls)
find lib/ConfigServer/ -name '*.pm' | while read file; do
  perl -i -pe 's/(?<!\\)(?<!goto\s)&(\w+)\s*\(/$1(/g' "$file"
done

# Validate syntax
find lib/ConfigServer/ -name '*.pm' | xargs -I {} perl -cw -Ilib {} 2>&1 | tee /tmp/modules-syntax-check.txt

# Run test suite
make test | tee /tmp/modules-after-transformation.txt

# Check exit code
if [ $? -eq 0 ]; then
  echo "✅ Module files transformation PASSED"
  find lib/ConfigServer/ -name '*.bak' -delete
else
  echo "❌ Module files transformation FAILED"
  exit 1
fi
```

### Phase 4: Transform Root Scripts

```bash
# Find root-level Perl scripts
find . -maxdepth 1 -name '*.pl' > /tmp/root-scripts.txt

# Create backup
tar czf /tmp/csf-root-scripts-backup-$(date +%Y%m%d-%H%M%S).tar.gz *.pl

# Transform scripts - Iteration 1
find . -maxdepth 1 -name '*.pl' | while read file; do
  perl -i.bak -pe 's/(?<!\\)(?<!goto\s)&(\w+)\s*\(/$1(/g' "$file"
done

# Transform scripts - Iteration 2
find . -maxdepth 1 -name '*.pl' | while read file; do
  perl -i -pe 's/(?<!\\)(?<!goto\s)&(\w+)\s*\(/$1(/g' "$file"
done

# Validate syntax
find . -maxdepth 1 -name '*.pl' | xargs -I {} perl -cw -Ilib {} 2>&1 | tee /tmp/scripts-syntax-check.txt

# Run test suite
make test | tee /tmp/scripts-after-transformation.txt

if [ $? -eq 0 ]; then
  echo "✅ Root scripts transformation PASSED"
  find . -maxdepth 1 -name '*.bak' -delete
else
  echo "❌ Root scripts transformation FAILED"
  exit 1
fi
```

### Phase 5: Transform Utilities and CGI

```bash
# Transform bin/ utilities
find bin/ -name '*.pl' | while read file; do
  perl -i.bak -pe 's/(?<!\\)(?<!goto\s)&(\w+)\s*\(/$1(/g' "$file"
  perl -i -pe 's/(?<!\\)(?<!goto\s)&(\w+)\s*\(/$1(/g' "$file"
done

# Transform cpanel/ CGI scripts  
find cpanel/ -name '*.cgi' -o -name '*.pl' | while read file; do
  perl -i.bak -pe 's/(?<!\\)(?<!goto\s)&(\w+)\s*\(/$1(/g' "$file"
  perl -i -pe 's/(?<!\\)(?<!goto\s)&(\w+)\s*\(/$1(/g' "$file"
done

# Validate all
find bin/ cpanel/ \( -name '*.pl' -o -name '*.cgi' \) | xargs -I {} perl -cw -Ilib {} 2>&1

# Final test run
make test
```

### Phase 6: Final Validation

```bash
# Compare test results with baseline
make test > /tmp/final-test-results.txt 2>&1
echo $? > /tmp/final-exit-code.txt

# Verify test pass rates match
diff /tmp/baseline-exit-code.txt /tmp/final-exit-code.txt

# Count remaining ampersand function calls
grep -r '&\w\+(' --include='*.pl' --include='*.pm' --include='*.t' \
  . 2>/dev/null > /tmp/remaining-ampersands.txt

# Review remaining instances (should be only special cases)
cat /tmp/remaining-ampersands.txt | grep -v '\\&'  # Exclude \& references
cat /tmp/remaining-ampersands.txt | grep -v 'goto &'  # Exclude goto &

# Syntax check all Perl files one more time
find . -type f \( -name '*.pl' -o -name '*.pm' -o -name '*.t' \) \
  ! -path './etc/*' ! -path './.git/*' ! -path './tpl/*' \
  | xargs -I {} sh -c 'perl -cw -Ilib {} 2>&1 || echo "FAIL: {}"'
```

### Phase 7: Manual Review

**Sample files to review** (verify transformations look correct):

1. Review a test file: `t/ConfigServer-ServerStats.t`
2. Review a module: `lib/ConfigServer/URLGet.pm`
3. Review a script: `auto.pl`
4. Review a utility: `bin/csftest.pl`

**Check for**:
- No `&function()` patterns remain (except `\&ref` and `goto &sub`)
- String literals unchanged (`&nbsp;`, `&copy;`)
- Comments unchanged
- Code compiles cleanly
- Functions still called correctly

### Phase 8: Commit Changes

```bash
# Stage all changes
git add -A

# Create commit with proper message
git commit -m "Modernize Perl function call syntax

case CPANEL-XXXXX: Remove legacy ampersand prefix from all function calls.
Transform &function() to function() and &function to function() throughout
codebase per Constitution Section III Perl Standards Compliance.

Preserve special cases:
- Subroutine references: \\&sub
- Signal handlers: \$SIG{FOO} = \\&handler
- Tail call optimization: goto &sub

Validated with 100% test pass rate and full syntax check.

Changelog: Modernized Perl function call syntax by removing legacy
 ampersand prefixes, improving code readability and maintainability while
 maintaining full backward compatibility and test coverage."
```

## Troubleshooting

### Issue: Tests fail after transformation

**Solution**:
1. Review failed test output: `cat /tmp/*-after-transformation.txt`
2. Identify which file caused failure
3. Restore from backup: `cp <file>.bak <file>`
4. Manual review that specific file for edge cases
5. Apply targeted transformation or manual fix

### Issue: Syntax errors after transformation

**Solution**:
1. Check syntax output: `cat /tmp/*-syntax-check.txt`
2. Find failing file
3. Restore from backup
4. Review for false positive transformations (e.g., string literals)
5. Manually edit or adjust regex pattern

### Issue: Too many ampersands remain

**Solution**:
1. Review `/tmp/remaining-ampersands.txt`
2. Filter out legitimate special cases
3. If function calls remain, run additional iteration
4. May indicate nested calls needing more passes

## Success Criteria Verification

| Criterion | Verification Command | Expected Result |
|-----------|---------------------|-----------------|
| SC-001: Zero legacy patterns | `grep -r '&\w\+(' . \| grep -v '\\&' \| grep -v 'goto &'` | Empty or only false positives |
| SC-002: 100% test pass | `make test; echo $?` | Exit code 0 |
| SC-003: All files pass syntax | `find . -name '*.pl' ... \| xargs perl -cw` | All files "OK" |
| SC-004: No functionality changes | Compare before/after test results | Identical output |
| SC-005: Only special cases remain | Manual review of grep results | Only `\&`, `goto &`, strings |

## Rollback Plan

If critical issues discovered:

```bash
# Full rollback
git reset --hard HEAD~1

# Partial rollback (specific file)
git checkout HEAD -- <file>

# Restore from backup tarball
tar xzf /tmp/csf-<category>-backup-<timestamp>.tar.gz
```

## Next Steps

After successful transformation:
1. Push feature branch to remote
2. Create pull request
3. Request code review
4. Merge to main branch after approval
5. Monitor production for any edge cases

## Time Estimate

- **Phase 1** (Baseline): 5 minutes
- **Phase 2** (Test files): 10 minutes
- **Phase 3** (Modules): 15 minutes  
- **Phase 4** (Scripts): 10 minutes
- **Phase 5** (Utilities): 5 minutes
- **Phase 6** (Validation): 10 minutes
- **Phase 7** (Manual review): 15 minutes
- **Phase 8** (Commit): 5 minutes

**Total**: ~75 minutes (1.25 hours)

## References

- [Specification](spec.md)
- [Research](research.md)
- [CSF Constitution](.specify/memory/constitution.md) - Section III: Perl Standards
