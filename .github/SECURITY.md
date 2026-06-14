# Security Policy for PostCode

## Supported versions

PostCode releases through the [App Store](https://apps.apple.com/app/id6758260094), and security fixes land in the latest release. Please make sure you're on the current App Store version before reporting.

## Reporting a vulnerability

**Please do not report security issues in public GitHub issues.**

Report it privately through GitHub's [vulnerability reporting](https://github.com/mrtymcln/PostCode/security/advisories/new): open the repository's **Security** tab and click **Report a vulnerability**. It goes straight to the maintainer and stays private.

Please include:

- A description of the issue and its potential impact.
- Steps to reproduce, or a proof of concept.
- The app version and the device / OS you saw it on.

## What to expect

- I'll acknowledge your report as soon as I can, usually within a few days.
- I'll keep you posted on progress and tell you when a fix is released.
- Please give me a reasonable window to fix the issue before disclosing it publicly. I'm happy to credit you if you'd like.

## Scope

All calculations and conversions are performed on-device — no Internet connection required. The most relevant areas are therefore local data handling and anything that could crash or corrupt that state.
