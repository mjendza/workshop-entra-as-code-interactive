<script setup lang="ts">
import { withBase } from 'vitepress'
import { paths, TEMPLATE_URL, REPO_URL } from '../../workshop.mjs'
import { icon } from './icons.mjs'
import Flow from './Flow.vue'

const stageCount = paths.reduce((n, p) => n + p.groups.reduce((m, g) => m + g.items.length, 0), 0)
const cards = paths.map(p => {
  const items = p.groups.flatMap(g => g.items)
  return { ...p, count: items.length, first: items[0], phases: p.groups.length }
})
const startLabel = (p: any) => `Start ${p.name} · ${p.prefix === 'Stage' ? 'Stage' : p.prefix + '-'}${p.prefix === 'Stage' ? ' ' : ''}${p.first.num}`

// Hero illustration: a stage issue as it appears in the participant's own repo.
const tasks = [
  ['Eligible role assignment created', true],
  ['Activation settings reviewed', true],
  ['terraform apply completes without errors', false],
  ['Role activated once in the portal', false]
] as const
</script>

<template>
  <div class="ec-home">
    <!-- HERO -->
    <section class="ec-hero">
      <div class="ec-hero__grid" aria-hidden="true" />
      <div class="ec-wrap ec-hero__inner">
        <div class="ec-hero__copy">
          <div class="ec-eyebrow"><span class="ec-eyebrow__dot" aria-hidden="true" />FREE · OPEN SOURCE · HANDS-ON</div>
          <h1 class="ec-display">Entra <span class="ec-display__as">as</span> Code</h1>
          <p class="ec-tagline">Identity, declared in Terraform.</p>
          <p class="ec-lead">
            A hands-on workshop for managing Microsoft cloud identity declaratively with Terraform and Microsoft Graph.
            Pick one of three independent paths. Copy the template and every stage becomes a tracked GitHub Issue in your own repo.
          </p>
          <div class="ec-actions">
            <a class="ec-btn" :href="TEMPLATE_URL" target="_blank" rel="noopener"><span v-html="icon('fork', 18)" />Copy the Workshop</a>
            <a class="ec-btn ec-btn--ghost" :href="withBase('/overview')">Read the Overview</a>
            <a class="ec-textlink" :href="withBase('/stage-00/')">Start with Stage 0 <span v-html="icon('arrow', 16)" /></a>
          </div>
          <p class="ec-fine">Creates your own copy of the repo. A GitHub Action then opens one issue per stage, each with its checklist. MIT licensed.</p>
          <dl class="ec-stats">
            <div><dt>3</dt><dd>independent paths</dd></div>
            <div><dt>{{ stageCount }}</dt><dd>guided stages</dd></div>
            <div><dt>1:1</dt><dd>stage to GitHub issue</dd></div>
          </dl>
        </div>

        <div class="ec-hero__visual" aria-hidden="true">
          <div class="ec-code-card">
            <div class="ec-code-card__bar"><span>pim.tf</span><span class="ec-lang">HCL</span></div>
            <pre class="ec-code-card__body"><span class="tk-c"># Eligible, not permanent: activated just in time</span>
<span class="tk-k">resource</span> <span class="tk-s">"azuread_group"</span> <span class="tk-s">"pim_helpdesk"</span> {
  <span class="tk-a">display_name    </span> = <span class="tk-s">"TF.Demo.${var.name}-PIM.Helpdesk"</span>
  <span class="tk-a">security_enabled</span> = <span class="tk-t">true</span>
}</pre>
            <div class="ec-code-card__term">
              <div><span class="tk-k">$</span> terraform apply</div>
              <div class="tk-s">Apply complete! Resources: 1 added, 0 changed, 0 destroyed.</div>
            </div>
          </div>
          <div class="ec-issue-card">
            <div class="ec-issue-card__head">
              <span class="ec-c-wf" v-html="icon('issue', 20)" />
              <div class="ec-issue-card__title">
                <div>Stage 6: Privileged Identity Management (PIM)</div>
                <div class="ec-mono-sm">your-account/workshop-entra-as-code</div>
              </div>
              <span class="ec-pill">#7 · Open</span>
            </div>
            <ul class="ec-issue-card__tasks">
              <li v-for="[text, done] in tasks" :key="text" :class="{ done }"><span class="ec-box">{{ done ? '✓' : '' }}</span>{{ text }}</li>
            </ul>
            <div class="ec-issue-card__progress"><span class="ec-bar"><span style="width: 50%" /></span>2 of 4 done</div>
          </div>
        </div>
      </div>
    </section>

    <!-- PICK YOUR PATH -->
    <section class="ec-wrap ec-section">
      <div class="ec-section__head">
        <span class="ec-kicker">PATHS</span>
        <h2>Pick your path</h2>
        <p>Three independent paths. Do one, or all three, in any order. Nothing in one path is a prerequisite for another.</p>
      </div>
      <div class="ec-cards">
        <article v-for="p in cards" :key="p.key" class="ec-path-card" :class="`ec-accent-${p.accent}`">
          <div class="ec-path-card__head">
            <span class="ec-path-card__icon" v-html="icon(p.accent, 24)" />
            <div>
              <span class="ec-kicker">PATH {{ p.n }}</span>
              <h3>{{ p.name }}</h3>
            </div>
          </div>
          <div class="ec-path-card__count"><span>{{ p.count }}</span>pages{{ p.phases > 1 ? ` · ${p.phases} phases` : '' }}</div>
          <dl class="ec-path-card__facts">
            <div><dt>TENANT</dt><dd>{{ p.tenant }}</dd></div>
            <div><dt>STAGES</dt><dd class="ec-mono">{{ p.stagesLabel }}</dd></div>
            <div><dt>FOR</dt><dd class="ec-muted">{{ p.audience }}</dd></div>
          </dl>
          <div class="ec-tags"><span v-for="t in p.tags" :key="t">{{ t }}</span></div>
          <div class="ec-path-card__links">
            <a :href="withBase(`/${p.first.dir}/`)" class="ec-path-card__cta"><span>{{ startLabel(p) }}</span><span v-html="icon('arrow', 18)" /></a>
            <a :href="withBase(`/paths/${p.key}`)" class="ec-path-card__roadmap">View roadmap</a>
          </div>
        </article>
      </div>
    </section>

    <!-- HOW INTERACTIVE MODE WORKS -->
    <section class="ec-wrap ec-section">
      <div class="ec-section__head">
        <span class="ec-kicker">INTERACTIVE MODE</span>
        <h2>Your copy, your issues, your pace</h2>
        <p>This site is the reference. The work happens in your own repo, one GitHub issue per stage.</p>
      </div>
      <Flow />
    </section>

    <!-- PREREQUISITES -->
    <section class="ec-band">
      <div class="ec-wrap ec-band__inner">
        <div class="ec-section__head">
          <span class="ec-kicker">PREREQUISITES</span>
          <h2>What you need, at a glance</h2>
        </div>
        <div class="ec-cards ec-cards--sm">
          <div v-for="p in paths" :key="p.key" class="ec-need" :class="`ec-accent-${p.accent}`">
            <div class="ec-need__title"><span v-html="icon(p.accent, 20)" />{{ p.name }}</div>
            <div v-for="n in p.needs" :key="n" class="ec-need__item"><span aria-hidden="true">✓</span>{{ n }}</div>
          </div>
        </div>
        <div class="ec-tools">
          <span class="ec-kicker">TOOLS</span>
          <span>Terraform ≥ 1.0</span><span>Git</span><span>PowerShell 7+</span><span>VS Code</span>
        </div>
      </div>
    </section>

    <!-- SAFETY -->
    <section class="ec-wrap ec-section ec-section--tight">
      <div class="ec-safety">
        <span class="ec-safety__icon" v-html="icon('octagon', 32)" />
        <div>
          <div class="ec-kicker ec-kicker--caution">CAUTION · SANDBOX ONLY</div>
          <h3>Use a sandbox or dev tenant. Never production.</h3>
          <p>
            Some stages change tenant-wide singleton policies (Stages 7, 19 and 20). Those stages carry a
            <b>Tenant-wide</b> badge in the sidebar and at the top of the page, so you can see the blast radius before you apply.
          </p>
          <a :href="withBase('/overview#️-important-risks-warnings--safety-guidelines')" class="ec-textlink ec-textlink--caution">Read the risks in the Overview</a>
        </div>
      </div>
    </section>

    <!-- CLOSING CTA -->
    <section class="ec-wrap ec-section">
      <div class="ec-closing">
        <div>
          <h2>Your first issue is one click away.</h2>
          <p>Copy the template, wait a minute for the Action to open the issues, and start with Stage 0.</p>
        </div>
        <a class="ec-btn" :href="TEMPLATE_URL" target="_blank" rel="noopener"><span v-html="icon('fork', 18)" />Copy the Workshop</a>
      </div>
    </section>

    <footer class="ec-footer">
      <div class="ec-wrap ec-footer__inner">
        <div class="ec-footer__brand">
          <div class="ec-footer__name"><img :src="withBase('/logo.svg')" alt="" width="24" height="24" />Entra as Code</div>
          <p>A community workshop by Mateusz Jendza. Not affiliated with or endorsed by Microsoft. Released under the MIT License.</p>
        </div>
        <nav aria-label="Footer" class="ec-footer__links">
          <a :href="withBase('/overview')">Overview</a>
          <a v-for="p in paths" :key="p.key" :href="withBase(`/paths/${p.key}`)">{{ p.name }}</a>
          <a :href="REPO_URL" target="_blank" rel="noopener">GitHub</a>
        </nav>
      </div>
    </footer>
  </div>
</template>
