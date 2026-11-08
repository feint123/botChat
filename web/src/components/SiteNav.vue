<script setup>
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
      <div class="brand"><span class="mark" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="5" cy="12" r="2.2" /><circle cx="12.5" cy="5.5" r="2.2" /><circle cx="12.5" cy="18.5" r="2.2" /><circle cx="19.5" cy="12" r="2.2" /><path d="M7 12h3.2M10.6 6.6 7.4 10.4M10.6 17.4 7.4 13.6M14.5 6.4c1.8 1.4 2.7 3.2 3 5.6M14.5 17.6c1.8-1.4 2.7-3.2 3-5.6" /></svg></span>botChat</div>
      <nav aria-label="站内导航"><a v-for="l in links" :key="l.href" :href="l.href">{{ l.label }}</a></nav>
    </div>
  </header>
</template>
