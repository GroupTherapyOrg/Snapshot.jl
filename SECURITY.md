# Security policy

Please report vulnerabilities privately through GitHub Security Advisories for
`GroupTherapyOrg/Snapshot.jl`. Do not include secrets or unpublished notebook
content in a public issue.

Snapshot.jl supports the current Julia 1.12-compatible release line. Security
fixes are made on the default branch and released as soon as practical.

## Trust model

- Exporting runs notebook code with the permissions of the Julia process.
  Snapshot.jl does not sandbox untrusted notebooks or their package build code.
- Run untrusted or community-supplied notebooks only in a disposable,
  network-restricted sandbox with no credentials and explicit CPU, memory,
  process, and filesystem limits.
- Generated HTML and scripts are author-controlled content. Serve them from an
  origin isolated from sessions, administration APIs, and other authors.
- Commit or checksum-lock compiler inputs and CI actions when reproducible
  publishing or provenance matters.
