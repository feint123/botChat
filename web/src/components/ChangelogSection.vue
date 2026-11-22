<script setup>
import { ref } from 'vue'
import { RELEASES, RELEASE_ARCHIVE } from '../lib/release.js'

// 日期来源是 appcast 的 RFC822 字符串，这里只做展示格式化；无有效日期时留空，不编造。
function fmtDate (raw) {
  if (!raw) return ''
  const d = new Date(raw)
  if (Number.isNaN(d.getTime())) return ''
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

// 默认只展开最近一版，其余折叠，避免页面被长列表撑散
const openVersion = ref(RELEASES[0]?.version ?? '')
function toggle (v) {
  openVersion.value = openVersion.value === v ? '' : v
}

const archiveOpen = ref(false)
</script>

<template>
  <section class="block" id="changelog">
    <div class="wrap">
      <p class="kicker">CHANGELOG</p>
      <h2>最近改了什么。</h2>
      <p class="lead rv">版本条目与升级源同源，取自发版记录；点版本号可展开，点日期可看完整说明。</p>

      <div class="cl rv">
        <article v-for="(r, i) in RELEASES" :key="r.version" class="cl-item" :class="{ open: openVersion === r.version }">
          <button class="cl-hd" type="button" :aria-expanded="openVersion === r.version" @click="toggle(r.version)">
            <span class="cl-ver">v{{ r.version }}</span>
            <span v-if="i === 0" class="cl-latest">最新</span>
            <span class="cl-date">{{ fmtDate(r.date) }}</span>
            <svg class="cl-chev" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 6l6 6-6 6"/></svg>
          </button>

          <div v-show="openVersion === r.version" class="cl-body">
            <p v-if="r.headline" class="cl-lead">{{ r.headline }}</p>
            <div v-for="s in r.sections" :key="s.title" class="cl-sec">
              <p class="cl-sec-t">{{ s.title }}</p>
              <ul>
                <li v-for="(it, k) in s.items" :key="k">{{ it }}</li>
              </ul>
              <p v-if="s.more" class="cl-more">另有 {{ s.more }} 条，见完整说明</p>
            </div>
            <a class="cl-link" :href="r.url">查看完整说明 →</a>
          </div>
        </article>
      </div>

      <div v-if="RELEASE_ARCHIVE.length" class="cl-archive rv">
        <button class="cl-arc-t" type="button" :aria-expanded="archiveOpen" @click="archiveOpen = !archiveOpen">
          更早的版本（{{ RELEASE_ARCHIVE.length }}）<span>{{ archiveOpen ? '收起' : '展开' }}</span>
        </button>
        <div v-show="archiveOpen" class="cl-arc-list">
          <a v-for="a in RELEASE_ARCHIVE" :key="a.version" :href="a.url">v{{ a.version }}<span v-if="a.date">{{ fmtDate(a.date) }}</span></a>
        </div>
      </div>
    </div>
  </section>
</template>
