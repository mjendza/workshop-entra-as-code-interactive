// Single description of the workshop structure, shared by scripts/prepare.mjs (page frontmatter),
// .vitepress/config.mts (sidebar + nav) and the theme components (home page, path pages, stage header).
// Order mirrors .github/workflows/create-workshop-issues.yml and the README roadmap - keep them in sync.
//
// Stage fields: dir (doc/<dir>), num (label in sidebar), short (sidebar title),
//   license, tenantWide (changes tenant-wide singleton policy), preview: 'preview' | 'private'.

const s = (dir, num, short, extra = {}) => ({ dir, num, short, ...extra })

export const TEMPLATE_URL =
  'https://github.com/new?template_owner=mjendza&template_name=workshop-entra-as-code-interactive&owner=%40me&name=workshop-entra-as-code&description=Workshop:+Entra+ID+as+Code&visibility=public'
export const REPO_URL = 'https://github.com/mjendza/workshop-entra-as-code-interactive'

export const paths = [
  {
    key: 'workforce',
    accent: 'wf',
    n: 1,
    name: 'Workforce',
    prefix: 'Stage',
    tenant: 'Microsoft Entra ID (enterprise)',
    stagesLabel: '00 – 21 + Cleanup + Next Steps',
    audience: 'Cloud engineers, identity architects, SecOps and DevOps engineers',
    summary: 'Manage Microsoft Entra ID (enterprise) with Terraform and Microsoft Graph, from SSO and service principals to Conditional Access, PIM and tenant hardening.',
    tags: ['SSO', 'Conditional Access', 'PIM', 'Maester'],
    needs: ['A sandbox Entra ID tenant', 'Entra ID P1 or P2 licenses, depending on the stage', 'Security Defaults disabled'],
    licenseSummary: 'P1 / P2',
    groups: [
      { name: 'Foundations & Identities', items: [s('stage-00', '00', 'Prerequisites'), s('stage-01', '01', 'SSO Application'), s('stage-02', '02', 'Service Principal'), s('stage-03', '03', 'Workload Identity Federation')] },
      { name: 'Access Governance & Zero Trust', items: [s('stage-04', '04', 'Conditional Access', { license: 'Entra ID P1' }), s('stage-05', '05', 'Access Package', { license: 'Entra ID P2' }), s('stage-06', '06', 'PIM', { license: 'Entra ID P2' })] },
      { name: 'Tenant Hardening & Modern Identities', items: [s('stage-07', '07', 'Tenant Security Hardening', { tenantWide: true }), s('stage-08', '08', 'Agent Identity', { preview: 'preview' })] },
      { name: 'Security Posture & AI Operations', items: [s('stage-09', '09', 'Maester'), s('stage-10', '10', 'EntraExporter'), s('stage-11', '11', 'Zero Trust Assessment'), s('stage-12', '12', 'Configuration Drift'), s('stage-13', '13', 'Lokka MCP')] },
      { name: 'Application Security & Automation', items: [s('stage-14', '14', 'SPA SSO'), s('stage-15', '15', 'App Roles'), s('stage-16', '16', 'Certificate Auth'), s('stage-17', '17', 'CI/CD Pipelines')] },
      { name: 'Advanced Operations & High Assurance', items: [s('stage-18', '18', 'Secret Monitoring'), s('stage-19', '19', 'Temporary Access Pass', { tenantWide: true }), s('stage-20', '20', 'High Assurance', { license: 'Entra ID P1', tenantWide: true, preview: 'preview' }), s('stage-21', '21', 'App Role PIM', { license: 'ID Governance', preview: 'private' })] },
      { name: 'Disassembly & Bonus', items: [s('stage-cleanup', '—', 'Cleanup'), s('stage-next', '—', 'Next Steps')] }
    ]
  },
  {
    key: 'external',
    accent: 'ext',
    n: 2,
    name: 'External ID',
    prefix: 'Ext',
    tenant: 'Entra External ID (CIAM)',
    stagesLabel: 'Ext-00 – Ext-05',
    audience: 'App developers, CIAM engineers and product teams',
    summary: 'Customer identity in a dedicated CIAM tenant: Native Authentication API, Pester tests, SPA + API SSO with user flows, passwordless + SMS MFA, sign-up attributes and token enrichment.',
    tags: ['Native Auth API', 'Pester tests', 'Passwordless + SMS MFA', 'Token enrichment'],
    needs: ['An Entra External ID (CIAM) tenant', 'A dedicated CIAM service principal (Ext-00)', 'Pester 5+ for the automated tests'],
    licenseSummary: 'Free trial',
    groups: [
      { name: 'External ID (CIAM)', items: [s('external-00', '00', 'Prerequisites'), s('external-01', '01', 'Native Authentication'), s('external-02', '02', 'SSO for CustomerHelpdesk'), s('external-03', '03', 'Passwordless + MFA (SMS)'), s('external-04', '04', 'Sign-up Attributes'), s('external-05', '05', 'Profile Sync + Token Enrichment')] }
    ]
  },
  {
    key: 'verified-id',
    accent: 'vc',
    n: 3,
    name: 'Verified ID',
    prefix: 'VC',
    tenant: 'Entra ID + Azure subscription',
    stagesLabel: 'VC-00 – VC-01',
    audience: 'Trust architects and decentralized identity engineers',
    summary: 'Decentralized identity: onboard your tenant to Verified ID, keep DID signing keys in Azure Key Vault and declare W3C Verifiable Credential contracts with the mjendza/verifiedid provider.',
    tags: ['DID authority', 'Key Vault keys', 'Verifiable Credentials'],
    needs: ['An Entra ID tenant', 'An Azure subscription (Key Vault holds the signing keys)'],
    licenseSummary: 'Azure sub',
    groups: [
      { name: 'Verified ID', items: [s('vc-00', '00', 'Tenant Onboarding'), s('vc-01', '01', 'Register VC Contract')] }
    ]
  }
]

/** Flat list of every stage with its path, phase and position. */
export function allStages() {
  return paths.flatMap(p => {
    const items = p.groups.flatMap(g => g.items.map(it => ({ ...it, phase: g.name })))
    const lastNum = items.filter(it => /^\d+$/.test(it.num)).at(-1)?.num
    return items.map((it, index) => ({ ...it, path: p.key, index, total: items.length, lastNum }))
  })
}

export function phaseRange(group) {
  const nums = group.items.map(it => it.num).filter(n => /^\d+$/.test(n))
  if (!nums.length) return String(group.items.length)
  return nums.length === 1 ? nums[0] : `${nums[0]}–${nums.at(-1)}`
}
