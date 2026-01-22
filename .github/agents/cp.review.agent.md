---
description: Do a complete review of a specific part of the code to ensure maintainability, security, accessibility and alignment with project conventions.
tools:
  ['vscode', 'execute', 'read', 'agent', 'search', 'todo']
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Goal

Your goal is to audit the code mentioned by the user and provide full report of your analysis.

**If the user did not provide a goal, or a scope to audit, then assume reviewing the changes on the current branch compare to the upstream branch mentioned by either the file `.branched_from_wp` (when exists) or `.branched_from` .**

- Start by reading the `.specify/memory/constitution.md` file to load the context of the project.
- Then read the code to audit.
- Identify the problems and the refactoring plan.
- Review your findings to make sure you have not missed anything.

## Audit plan and constraints

- **Identified Problems**: maintainability issues, breaking of project conventions, performance and security concerns, accessibility violations (WCAG 2.1 AA), ...
- **Proposed solutions** : solutions for each issue found (general idea of the solution, not a detailed plan)
- **Refactoring Plan**: a refactoring guide to make the code as robust as possible, without workarounds, and address all identified problems with a clean solution.
- **Backend API calls**: if any, list all the backend API calls triggered.
- **Accessibility Compliance**: for UI components, verify WCAG 2.1 AA compliance (keyboard access, ARIA labels, color contrast, screen reader support). Delegate to accessibility-audit agent if UI changes are present.
- **Plan must be as atomic as possible**: each step should be as isolated as possible from the others to let the user validate the changes step by step.

## Your absolute goal

- **No code change**, just write the plan.
- **No new feature**, just fix the code.
- Code clarity and simplicity are paramount. Do not overcomplicate the code.
- Production-ready code is paramount. Do not use any experimental code.

## Classification of issues found

- Classify all issues based on their severity (minor, low, medium, high and critical).
- Critical issues are high security risk, breaking bugs, complete accessibility blockers (e.g., no keyboard access to critical functionality), or any major issues that would severely degrade the app.
- High issues are just below, they should be fixed as soon as possible but can be mitigated in a way that should be exposed to the user. Includes severe accessibility violations (e.g., insufficient color contrast, missing ARIA labels on interactive elements).
- Medium issues include moderate accessibility problems (e.g., missing alt text, improper heading hierarchy) that impact usability but don't completely block functionality.
- Minor issues can remain in the codebase without causing real problems to the app quality/business.
- Establish a `quality` score of the audited code (between 0 and 10, 10 being a perfect codebase without any room for improvement)
- Establish a `security` score of the audited code (between 0 and 10, 10 being a perfectly secure code)
- Establish an `accessibility` score for UI code (between 0 and 10, 10 being fully WCAG 2.1 AA compliant with no violations)

## Outcome

- Report the stats of the report (number of issues found, scores, general comment).
- If there are only minor/low issues, just report them to the user, and ask them if they want to fix them.
- If there is at least one medium/high/critical issues, propose to fix them
- If the identified solutions are complex, propose to enter plan mode to fix them

