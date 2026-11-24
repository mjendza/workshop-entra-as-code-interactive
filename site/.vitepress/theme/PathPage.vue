<script setup lang="ts">
import { computed } from 'vue'
import { withBase } from 'vitepress'
import { paths, phaseRange, TEMPLATE_URL } from '../../workshop.mjs'
import { icon } from './icons.mjs'

const props = defineProps<{ pathKey: string }>()
const p = computed(() => paths.find(x => x.key === props.pathKey)!)
const count = computed(() => p.value.groups.reduce((n, g) => n + g.items.length, 0))
const first = computed(() => p.value.groups[0].items[0])
const label = (num: string) => (num === '—' ? '—' : num)
</script>

<template>
  <div class="ec-home ec-pathpage" :class="`ec-accent-${p.accent}`">
    <section class="ec-hero ec-hero--path">
      <div class="ec-hero__grid" aria-hidden="true" />
      <div class="ec-wrap ec-pathpage__hero">
        <div class="ec-chip-path"><span v-html="icon(p.accent, 14)" />PATH {{ p.n }} OF 3</div>
        <h1 class="ec-display ec-display--path">{{ p.name }}</h1>
        <p class="ec-lead">{{ p.summary }} For: {{ p.audience }}.</p>
        <dl class="ec-stats">
          <div><dt>{{ count }}</dt><dd>pages</dd></div>
          <div v-if="p.groups.length > 1"><dt>{{ p.groups.length }}</dt><dd>phases</dd></div>
          <div><dt>{{ p.licenseSummary }}</dt><dd>{{ p.key === 'workforce' ? 'licenses, per stage' : 'to get started' }}</dd></div>
        </dl>
        <div class="ec-actions">
          <a class="ec-btn" :href="TEMPLATE_URL" target="_blank" rel="noopener"><span v-html="icon('fork', 18)" />Copy the Workshop</a>
          <a class="ec-btn ec-btn--ghost" :href="withBase(`/${first.dir}/`)">Read {{ p.prefix }} {{ first.num }}</a>
        </div>
        <div class="ec-tools">
          <span class="ec-kicker">YOU NEED</span>
          <span v-for="n in p.needs" :key="n">{{ n }}</span>
        </div>
      </div>
    </section>

    <section class="ec-wrap ec-section ec-section--roadmap">
      <div class="ec-roadmap__head">
        <div class="ec-section__head">
          <span class="ec-kicker">ROADMAP</span>
          <h2>{{ p.groups.length > 1 ? `${p.groups.length} phases, ${count} pages` : `${count} pages` }}</h2>
        </div>
        <div class="ec-legend">
          <span><span class="ec-tw" v-html="icon('shieldAlert', 15)" />Changes tenant-wide policy</span>
          <span><span class="ec-badge ec-badge--preview">Preview</span></span>
          <span><span class="ec-badge ec-badge--private">Private</span>Private preview</span>
        </div>
      </div>

      <ol class="ec-rail">
        <li v-for="(g, gi) in p.groups" :key="g.name" class="ec-rail__phase">
          <span class="ec-rail__dot" aria-hidden="true">{{ gi + 1 }}</span>
          <div class="ec-rail__body">
            <div class="ec-rail__title"><h3>{{ g.name }}</h3><span class="ec-count">{{ phaseRange(g) }}</span></div>
            <ul class="ec-rail__stages">
              <li v-for="it in g.items" :key="it.dir">
                <a :href="withBase(`/${it.dir}/`)">
                  <span class="ec-num">{{ label(it.num) }}</span>
                  <span class="ec-rail__name">{{ it.short }}</span>
                  <span v-if="it.license" class="ec-lic">{{ it.license }}</span>
                  <span v-if="it.tenantWide" class="ec-tw" role="img" aria-label="Changes tenant-wide policy" v-html="icon('shieldAlert', 15)" />
                  <span v-if="it.preview === 'preview'" class="ec-badge ec-badge--preview">Preview</span>
                  <span v-if="it.preview === 'private'" class="ec-badge ec-badge--private">Private</span>
                  <span class="ec-rail__go" v-html="icon('arrow', 16)" />
                </a>
              </li>
            </ul>
          </div>
        </li>
      </ol>
    </section>
  </div>
</template>
