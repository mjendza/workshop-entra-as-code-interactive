---
layout: home
title: Microsoft Entra as Code Workshop

hero:
  name: Entra as Code
  text: Identity, declared in Terraform
  tagline: A hands-on workshop for managing Microsoft Entra ID, External ID and Verified ID with Terraform, Microsoft Graph and modern IaC practices. Three independent paths — pick one or do all three.
  image:
    src: /logo.svg
    alt: Entra as Code
  actions:
    - theme: brand
      text: Copy the Workshop
      link: https://github.com/new?template_owner=mjendza&template_name=workshop-entra-as-code-interactive&owner=%40me&name=workshop-entra-as-code&description=Workshop:+Entra+ID+as+Code&visibility=public
    - theme: alt
      text: Read the Overview
      link: /overview
    - theme: alt
      text: Start with Stage 0
      link: /stage-00/

features:
  - icon: 🏢
    title: "Path 1: Workforce"
    details: "22 stages — SSO, workload identity federation, Conditional Access, PIM, tenant hardening, Maester, EntraExporter, drift detection, Lokka MCP, certificates, TAP, Verified ID step-up and App Role PIM."
    link: /stage-00/
    linkText: Stages 00 – 21
  - icon: 👥
    title: "Path 2: External ID"
    details: "Customer identity in a CIAM tenant — Native Authentication API, Pester tests, SPA + API SSO with dedicated user flows, passwordless + SMS MFA, sign-up attributes and token enrichment."
    link: /external-00/
    linkText: Ext-00 – 05
  - icon: 🪪
    title: "Path 3: Verified ID"
    details: "Decentralized identity — onboard your tenant's DID authority, Azure Key Vault signing keys and declarative W3C Verifiable Credential contracts via the mjendza/verifiedid provider."
    link: /vc-00/
    linkText: VC-00 – 01
  - icon: 📋
    title: Interactive mode with GitHub Issues
    details: "Copy the template and a GitHub Actions workflow creates one issue per stage — checklists, lab notes and stage links mapped to your own repository."
    link: /overview#-interactive-workshop-mode-powered-by-github-issues
    linkText: How it works
  - icon: 🧪
    title: Tested, not just deployed
    details: "Verify every change with Maester, Zero Trust Assessment, Pester and token inspection — and catch out-of-band portal drift."
    link: /stage-09/
    linkText: Security baselines
  - icon: ⚠️
    title: Use a sandbox tenant
    details: "Some stages change tenant-wide singleton policies. Use a developer or trial tenant, never production."
    link: /overview#️-important-risks-warnings--safety-guidelines
    linkText: Risks & warnings
---
