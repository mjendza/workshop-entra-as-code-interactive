<script setup lang="ts">
import { computed } from 'vue'
import { useData, withBase } from 'vitepress'
import { paths, TEMPLATE_URL } from '../../workshop.mjs'
import { icon } from './icons.mjs'

// Rendered in the `doc-before` slot. Stage pages carry `stage` frontmatter written by prepare.mjs;
// other doc pages (overview) only get the template banner.
const { frontmatter } = useData()
const st = computed(() => frontmatter.value.stage)
const path = computed(() => st.value && paths.find(p => p.key === st.value.path))
const isNumbered = computed(() => st.value && /^\d+$/.test(st.value.num))
const counter = computed(() => {
  if (!st.value) return ''
  return isNumbered.value
    ? `${path.value.prefix} ${st.value.num} of ${st.value.lastNum}`.toUpperCase()
    : st.value.short.toUpperCase()
})
const crumb = computed(() => (isNumbered.value ? `${path.value.prefix} ${Number(st.value.num)}` : st.value?.short))
const ticks = computed(() => (st.value ? Array.from({ length: st.value.total }, (_, i) => i <= st.value.index) : []))
const showBanner = computed(() => frontmatter.value.source && frontmatter.value.layout !== 'page')
</script>

<template>
  <div v-if="showBanner" class="ec-banner">
    <span class="ec-banner__icon" v-html="icon('fork', 20)" />
    <span class="ec-banner__text">Doing this in your own repo? <b>Copy the workshop</b> and every stage becomes a tracked GitHub issue.</span>
    <a class="ec-btn ec-btn--sm" :href="TEMPLATE_URL" target="_blank" rel="noopener">Copy the Workshop</a>
  </div>

  <header v-if="st && path" class="ec-stage-header" :class="`ec-accent-${path.accent}`">
    <nav aria-label="Breadcrumb" class="ec-crumbs">
      <a :href="withBase(`/paths/${path.key}`)" class="ec-c-path">{{ path.name }}</a><span aria-hidden="true">›</span>
      <span>{{ st.phase }}</span><span aria-hidden="true">›</span>
      <span class="ec-crumbs__here">{{ crumb }}</span>
    </nav>

    <div class="ec-stage-header__row">
      <span class="ec-chip-path"><span v-html="icon(path.accent, 14)" />{{ path.name.toUpperCase() }}</span>
      <span class="ec-counter">{{ counter }}</span>
    </div>
    <div class="ec-ticks" role="img" :aria-label="`Progress: page ${st.index + 1} of ${st.total} in ${path.name}`">
      <span v-for="(on, i) in ticks" :key="i" :class="{ on }" />
    </div>

    <h1 class="ec-stage-title">{{ frontmatter.title }}</h1>

    <div class="ec-meta">
      <span v-if="st.time" class="ec-meta__chip"><span v-html="icon('clock', 14)" /><span class="ec-meta__k">TIME</span>{{ st.time }}</span>
      <span v-if="st.license" class="ec-meta__chip"><span v-html="icon('key', 14)" /><span class="ec-meta__k">LICENSE</span>{{ st.license }}</span>
      <span v-if="st.tenantWide" class="ec-meta__chip ec-meta__chip--caution"><span v-html="icon('shieldAlert', 14)" /><span class="ec-meta__k">TENANT-WIDE</span>Sandbox only</span>
      <span v-if="st.preview === 'preview'" class="ec-meta__chip ec-meta__chip--warn"><span v-html="icon('flask', 14)" /><span class="ec-meta__k">STATUS</span>Preview</span>
      <span v-if="st.preview === 'private'" class="ec-meta__chip ec-meta__chip--important"><span v-html="icon('flask', 14)" /><span class="ec-meta__k">STATUS</span>Private preview</span>
    </div>
  </header>
</template>
