<script setup lang="ts">
import { icon } from './icons.mjs'

const steps = [
  ['fork', 'Copy the template', 'Click Copy the Workshop. GitHub creates your own repo.'],
  ['zap', 'Actions creates issues', 'A GitHub Action opens one issue per stage, each with its checklist.'],
  ['issue', 'Open a stage issue', 'Pick a path, open the issue for your stage and keep this site beside it.'],
  ['terminal', 'Write Terraform and apply', 'Follow the steps, write the config, run <code>terraform apply</code>.'],
  ['check', 'Tick checkboxes and close', 'Check off the verification list, then close the issue.'],
  ['repeat', 'Next stage', 'Links inside the issue point at your own next stage issue.']
]
</script>

<template>
  <div class="ec-flow">
    <ol class="ec-flow__steps">
      <template v-for="([ic, title, text], i) in steps" :key="title">
        <li class="ec-flow__step">
          <div class="ec-flow__top">
            <span class="ec-flow__icon" v-html="icon(ic, 24)" />
            <span class="ec-flow__n">{{ String(i + 1).padStart(2, '0') }}</span>
          </div>
          <div class="ec-flow__title">{{ title }}</div>
          <div class="ec-flow__text" v-html="text" />
        </li>
        <li v-if="i < steps.length - 1" class="ec-flow__arrow" aria-hidden="true" v-html="icon('arrow', 18)" />
      </template>
    </ol>
    <div class="ec-flow__repeat"><span aria-hidden="true" />REPEAT STEPS 3 TO 6 FOR EVERY STAGE IN YOUR PATH</div>
  </div>
</template>
