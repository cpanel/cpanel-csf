# Commit Message Standards for cPanel & WHM

**MANDATORY: When asked to generate, create, or write a commit message, ALWAYS follow these standards.**

Commit messages allow developers to communicate changes to the code to the many teams at cPanel. Proper commit messages save substantial time for anyone that needs to understand what a commit contains and changes.

Good commit messages should answer several questions:
- What does this change do?
- What problem does this change address?
- Why was the problem fixed this way?
- What other solutions were rejected, if any, and why?
- What potential gotchas should developers be aware of in the future?
- Where do I look for more information?

## Formatting Guidelines

1. **First line**: Start with a short summary (50 characters or less). Many git commands only show the first line of a commit message.
   - **Note**: The first line should NOT contain a case number.
   - Use imperative mood (e.g., "Fix issue" not "Fixed issue" or "Fixes issue").

2. **Second line**: Leave blank.

3. **Third line**: Start in the format `Case CPANEL-1234:` and describe the commit fully in a short paragraph. You may add additional paragraphs to provide additional information.
   - **Extract the case number** from the current branch name or user's prompt.
   - If the "short summary" is truly self-explanatory and requires no further verbiage, then use a short commit message.
   - If you fix multiple bugs in a single commit, use multiple paragraphs to explain the distinct changes.

4. **Changelog trailer**: After your description, skip a line, and add a changelog entry trailer starting with `Changelog:`
   - The build system automatically generates the changelog with the contents of this trailer, so describe the user-visible change here if there is one.
   - If your commit should not appear in the changelog (e.g., because it is a cleanup or development tool change), provide an empty changelog trailer (just `Changelog:`).
   - If your changelog entry needs to be longer than one line, indent subsequent lines with at least one space.

5. **CVE fixes**: If your change fixes a CVE (say, in an upstream commit for an RPM), add a `Fixes` trailer with the CVE.
   - For example: `Fixes: CVE-2018-12345`

## Composition Guidelines

- **Wrap lines**: Maximum of 80 characters per line, but prefer 72 characters per line.
- **Use punctuation**: End sentences with punctuation.
- **Imperative mood**: Write as if giving the codebase a command. For example, write "Make xyzzy do frotz." and not "[this patch] makes xyzzy do frotz." or "[I] changed xyzzy to do frotz."
- **Avoid questions**: If you have a question about a change, don't include it in the commit message.
- **Unicode**: You may use normal Unicode in your commit messages (in UTF-8).
- **Multiple commits per case**: Each commit should contain an atomic change that provides its own standalone value. The code should function and pass all tests at each stage.
- **Unique messages**: Each commit should have its own unique message summarizing the contents of the individual commit and how it relates to the overall case.
- **Multiple cases**: If you need to specify multiple cases for the same logical change, add additional stanzas in the form `Case CPANEL-4567:`.

## Examples

**Example 1:**
```
Fix NameServer::Conf::BIND memory cache

Case CPANEL-1234: Use memory cache in Cpanel::NameServer::Conf::BIND only when
the load time of the memory cache is at least one second after the mtime of
the named.conf file. This prevents reuse of a bad memory cache when multiple
processes are accessing named.conf simultaneously.

Changelog: Avoid reuse of bad memory cache for BIND Nameserver configuration
```

**Example 2:**
```
Fix File Manager JavaScript

Case CPANEL-2345: Switch to function calls in the file manager JavaScript for
the right click menu. Fixes an invalid baseurl parameter passed to wysiwygpro
editor that results in preview button loading the wrong URL.

Changelog: Fix File Manager JavaScript
```

**Example 3:**
```
Add example commit messages

Case CPANEL-3456: Add examples to commit message guidelines in LinuxDev wiki.
The examples clarify how commit messages should be styled for consistency.

Changelog:
```

## Commit Message Generation Workflow

When generating a commit message:

1. **Extract the case number** from the current branch name (check git branch) or from the user's description.
   - **JIRA case format**: The full JIRA case number follows the format `PROJECT-1234` (e.g., `CPANEL-1234`, `WPX-1234`)
   - **Branch name patterns**: Branch names often abbreviate the project prefix:
     - `cp1234`, `cp-1234`, `cp1234-topic`, `cp-1234-topic` → represents `CPANEL-1234`
     - `wp-1234`, `wpx-1234`, `wpx-1234-topic` → represents `WPX-1234`
   - **Conversion rules**:
     - `cp` prefix → expand to `CPANEL-`
     - `wp` or `wpx` prefix → expand to `WPX-`
     - Extract the numeric portion and construct the full JIRA case number
   - **When in doubt**: Ask the user for the JIRA case number explicitly

2. **Summarize the change** in imperative mood (≤50 characters) for the first line.
3. **Add blank line** for the second line.
4. **Write the case line** starting with `Case PROJECT-XXXXX:` (using the full JIRA case number) followed by a detailed description of what changed and why.
5. **Determine if changelog-worthy**: If the change is customer-visible, write a `Changelog:` entry describing the user-facing benefit. If it's internal-only (tests, refactoring, etc.), use empty `Changelog:`.
6. **Verify format**: Ensure lines wrap at 72-80 characters, imperative mood is used, and all required elements are present.
