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

### Development Practices
- **Temporary Files**: Use `./tmp/` directory in repository root instead of `/tmp` for all temporary files during development and testing. The `tmp/` directory is git-ignored and keeps temporary files contained within the project structure.

## Development Tools

### JIRA Command-Line Tool

The cPanel repository includes a comprehensive JIRA CLI tool for interacting with WebPros JIRA.

**Location**: `/usr/local/cpanel/build-tools/jira`

#### Setup Authentication

First-time setup (one-time):
```bash
cd /usr/local/cpanel
build-tools/setup-jira
```

This will guide you through authenticating to `webpros.atlassian.net` using your JIRA credentials. Authentication is stored in `/root/.config/cPanel/oauth-webpros` and shared with other build-tools that access JIRA.

#### Available Operations

The tool accepts JSON-RPC commands via stdin. Here are the key operations:

**Get Issue Details**:
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"getJiraIssue","arguments":{"issueKey":"CPANEL-12345"}}}' | /usr/local/cpanel/build-tools/jira
```

**Add Comment** (supports markdown):
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"addJiraComment","arguments":{"issueKey":"CPANEL-12345","comment":"## Analysis\n\nRoot cause identified..."}}}' | /usr/local/cpanel/build-tools/jira
```

**Search Issues** (JQL):
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"searchJiraIssues","arguments":{"jql":"project = CPANEL AND status = \"In Progress\"","maxResults":10}}}' | /usr/local/cpanel/build-tools/jira
```

**Update Issue Fields**:
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"updateJiraIssue","arguments":{"issueKey":"CPANEL-12345","fields":{"customfield_10825":["AI-Resolved"]}}}}' | /usr/local/cpanel/build-tools/jira
```

**Get Available Transitions**:
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"getJiraTransitions","arguments":{"issueKey":"CPANEL-12345"}}}' | /usr/local/cpanel/build-tools/jira
```

**Transition Issue**:
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"transitionJiraIssue","arguments":{"issueKey":"CPANEL-12345","transitionName":"In Progress"}}}' | /usr/local/cpanel/build-tools/jira
```

#### Complete Tool List

View all available tools:
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | /usr/local/cpanel/build-tools/jira | jq -r '.tools[] | .name'
```

Available operations include:
- `getJiraIssue` - Get full issue details (description, comments, links, attachments, status)
- `addJiraComment` - Add comment with markdown support
- `updateJiraIssue` - Update any issue field
- `updateJiraDescription` - Update description with markdown
- `addCommentReply` - Reply to specific comment (threaded)
- `searchJiraIssues` - Search via JQL queries
- `getJiraIssueLinks` - Get all linked issues, subtasks, and parent (if applicable)
- `addJiraIssueLink` - Create issue relationship (Relates, Blocks, Duplicate, etc.)
- `removeJiraIssueLink` - Remove issue link
- `transitionJiraIssue` - Change issue status
- `getJiraTransitions` - Get available status transitions
- `getJiraWatchers` - Get watchers list
- `addJiraWatcher` - Add watcher
- `getJiraAttachments` - Get attachments list

#### Practical Examples

**Get issue with comments**:
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"getJiraIssue","arguments":{"issueKey":"CPANEL-47033"}}}' | /usr/local/cpanel/build-tools/jira | jq -r '.content[0].text' | jq '.fields | {summary, status: .status.name, comments: .comment.comments | length}'
```

**Add root cause analysis comment**:
```bash
cat > ./tmp/jira-comment.json << 'EOF'
{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"addJiraComment","arguments":{"issueKey":"CPANEL-47033","comment":"## Root Cause\n\nThe issue was caused by...\n\n```perl\nuse constant foo => 'bar';\n```\n\n**Fix**: Changed X to Y"}}}
EOF
cat ./tmp/jira-comment.json | /usr/local/cpanel/build-tools/jira
```

**Search for your in-progress tickets**:
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"searchJiraIssues","arguments":{"jql":"assignee = currentUser() AND status = \"In Progress\""}}}' | /usr/local/cpanel/build-tools/jira | jq -r '.content[0].text' | jq '.issues[] | {key, summary: .fields.summary}'
```

**Add AI-Resolved keyword** (for human review):
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"updateJiraIssue","arguments":{"issueKey":"CPANEL-47033","fields":{"customfield_10825":["AI-Resolved"]}}}}' | /usr/local/cpanel/build-tools/jira
```

#### Integration with AI Workflows

The JIRA tool can be used by AI agents for:
- Fetching ticket details and context
- Posting resolution comments
- Linking related cases
- Updating ticket status
- Adding AI-Resolved keywords for human review

For complete documentation, see `/usr/local/cpanel/.github/QUICK-REFERENCE.md`.

## Getting Help

When working with any file in this repository, simply describe what you want to accomplish. The AI will automatically:

1. **Scan file patterns** mentioned in your request
2. **Load relevant instruction files** using the read_file tool
3. **Apply appropriate coding standards** and conventions from those files
4. **Provide solutions** that follow cPanel & WHM best practices
5. **Ensure compliance** with security, accessibility, and performance requirements

**The AI is required to load and apply instruction files before responding to any code-related request.**

The instruction files are regularly updated to reflect the latest standards and practices. This automated system ensures you always get the most current and appropriate guidance for your specific development context.
