# VC-00: Prerequisites — Onboard Your Tenant to Microsoft Entra Verified ID

This is the one-time, tenant-level onboarding step for the **Verified ID** path. Before
[VC-01](../vc-01/README.md) can create a Verifiable Credential contract through Terraform, your
tenant needs an **authority** — a DID (Decentralized Identifier) that represents you as a
credential issuer. That onboarding is a manual portal wizard; there's no Terraform provider for it
(it's a one-time, click-through setup, not something you'd want to re-run).

This workshop uses the **Quick Setup** wizard rather than Advanced Setup. Quick Setup only needs a
verified custom domain on your tenant — it provisions everything else (signing keys, DID
registration, domain-ownership proof) for you, with no Azure Key Vault to create and no DID
configuration JSON to host yourself.

For background on why this exists and what you can eventually build with it, see the "On my own"
section of [mjendza.net — Entra Verified ID](https://mjendza.net/post/entra-verified-id/#on-my-own),
and once you've completed this path (VC-00 + VC-01), the dedicated
[workshop-verified-id](https://github.com/mjendza/workshop-verified-id) developer workshop for
next steps — actually issuing, presenting, and verifying the credential you created here from a
real app.

## Goals
- Confirm your tenant has a verified custom domain — Quick Setup's only hard requirement.
- Run the Quick Setup wizard to onboard Verified ID with a single **Get started** click: it
  manages the signing key, registers your DID, and verifies domain ownership for you.
- End up with a default Verified Workplace Credential ready to edit in [VC-01](../vc-01/README.md).

## ⏱️ Estimated Time: 5-10 minutes

## Prerequisites Checklist
Before starting, please ensure you have the following:
- [ ] The **Authentication Policy Administrator** role in the target tenant (Global Administrator
      also works, but is broader than needed). If you'll also register applications against
      Verified ID, you'll additionally need **Application Administrator**.
- [ ] A **verified custom domain** on the tenant (e.g. `contoso.com`) — see
      [Add your custom domain name to your tenant](https://learn.microsoft.com/entra/fundamentals/add-custom-domain)
      if you don't have one yet. Quick Setup uses this domain for domain-ownership verification;
      without one, the wizard falls back to the Advanced Setup experience instead.
- [ ] Your tenant is Entra ID Workforce tenant or Entra External ID.

> **Not required for Quick Setup:** an Azure subscription, an Azure Key Vault, or uploading a DID
> configuration JSON file. Quick Setup uses a Microsoft-managed shared signing key and verifies
> domain ownership against the custom domain already registered on your tenant — both steps you'd
> otherwise have to do yourself under Advanced Setup.

## Steps to Onboard the Tenant

1. **Open Verified ID setup**
   - [Microsoft Entra admin center](https://entra.microsoft.com) → **Verified ID** → **Setup** tab.

2. **Run Quick Setup**
   - Select **Get started**.
   - If your tenant has multiple custom domains registered, pick the one you want Verified ID to
     use.
   - That's it — the wizard provisions the signing key, registers your DID, and verifies domain
     ownership in one step.

3. **Confirm the default credential**
   - Once setup completes, you'll see a default **Verified Workplace Credential** (`VerifiedEmployee`)
     available to edit and offer to your tenant's users via their MyAccount page.

## Verification
- [ ] Verified ID → **Setup** shows the quick setup as complete (no outstanding steps).
- [ ] A default Verified Workplace Credential is visible and available to edit.
- [ ] I am ready to proceed to [VC-01: Verified ID](../vc-01/README.md).

## Troubleshooting
| Issue | Solution |
|-------|----------|
| Wizard shows Advanced Setup instead of a **Get started** button | Your tenant has no verified custom domain. Register and verify one first — see [Add your custom domain name to your tenant](https://learn.microsoft.com/entra/fundamentals/add-custom-domain) — then reload the Setup tab. |
| **Get started** button is missing entirely | You're in an EDU tenant (Quick Setup isn't supported there), or you lack the Authentication Policy Administrator role. |
| `terraform apply` in VC-01 fails on `value[0].id` / empty authorities list | This stage hasn't been completed yet. The Admin API has nothing to list until Quick Setup finishes here. |

---

## Stage Completion Checklist
- [ ] I have a verified custom domain registered on my tenant.
- [ ] I have run Quick Setup (Verified ID → Setup → Get started) to completion.
- [ ] I see a default Verified Workplace Credential `VerifiedEmployee` available to edit.
- [ ] I am ready to proceed to [VC-01: Verified ID](../vc-01/README.md).

> **Tip:** Make sure to check all of the boxes above before closing this issue and proceeding!

> **Report Issues:** Did you encounter a bug or need clarification? [Report the issue here](https://github.com/mjendza/workshop-entra-as-code-interactive/issues).

---
**Navigation:** [Next → VC-01: Verified ID](../vc-01/README.md)
