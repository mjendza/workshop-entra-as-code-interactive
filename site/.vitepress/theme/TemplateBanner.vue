<script setup lang="ts">
import { useData } from 'vitepress'
const { frontmatter } = useData()
const templateUrl =
  'https://github.com/new?template_owner=mjendza&template_name=workshop-entra-as-code-interactive&owner=%40me&name=workshop-entra-as-code&description=Workshop:+Entra+ID+as+Code&visibility=public'
</script>

<template>
  <div v-if="frontmatter.source && frontmatter.source !== 'README.md'" class="template-banner">
    <span class="template-banner__icon">📋</span>
    <span>
      Doing the workshop? <a :href="templateUrl" target="_blank" rel="noopener">Copy the template</a>
      — every stage becomes a GitHub Issue with its own checklist in your repository.
    </span>
  </div>
</template>
