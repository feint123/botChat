<script setup>
import appIcon from '../assets/app-icon.webp'

const links = [
  { href: '#caps', label: '能力' },
  { href: '#flow', label: '工作流' },
  { href: '#install', label: '安装' },
  { href: 'https://github.com/feint123/botChat', label: 'GitHub', external: true },
]
</script>

<template>
  <header class="nav">
    <div class="wrap">
      <div class="brand"><span class="mark" aria-hidden="true"><img :src="appIcon" alt="" width="40" height="40" decoding="async"></span>botChat</div>
      <nav aria-label="站内导航"><a v-for="l in links" :key="l.href" :href="l.href">{{ l.label }}</a></nav>
    </div>
  </header>
</template>
