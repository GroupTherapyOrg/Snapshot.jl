# Security policy

Please report vulnerabilities privately through GitHub Security Advisories for
`GroupTherapyOrg/Snapshot.jl`. Do not include secrets or unpublished notebook
content in a public issue.

Snapshot.jl is currently an unreleased, pre-registration package supporting
Julia 1.12. During this test phase, security fixes are made on the default branch;
once registered, supported release lines and security releases will be documented
here explicitly.

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

`snapshot.show` is a separately operated hosting service. Package vulnerability
reports belong here; service-specific reports should use the private reporting
channel published by that service and must not include user content in a public
issue.
