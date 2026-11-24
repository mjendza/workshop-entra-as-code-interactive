import DefaultTheme from 'vitepress/theme'
import { h } from 'vue'
import type { Theme } from 'vitepress'
import StageHeader from './StageHeader.vue'
import HomePage from './HomePage.vue'
import PathPage from './PathPage.vue'
import './custom.css'

export default {
  extends: DefaultTheme,
  Layout: () => h(DefaultTheme.Layout, null, {
    'doc-before': () => h(StageHeader)
  }),
  enhanceApp({ app }) {
    app.component('HomePage', HomePage)
    app.component('PathPage', PathPage)
  }
} satisfies Theme
