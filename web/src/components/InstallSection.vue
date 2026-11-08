<script setup>
import { ref, onUnmounted } from 'vue'
import { APP_VERSION, DMG_URL, RELEASES_URL } from '../lib/release.js'
import appIcon from '../assets/app-icon.webp'
import stickerCheer from '../assets/sticker-1.webp'
import stickerWow from '../assets/sticker-4.webp'
import stickerHype from '../assets/sticker-9.webp'

// 首次放行用的唯一一条命令；执行位置写死在文案里，避免用户不知道在哪跑
const CMD = 'sudo xattr -dr com.apple.quarantine /Applications/botChat.app'
const copied = ref(false)
let timer = null

async function copyCmd () {
  try {
    await navigator.clipboard.writeText(CMD)
  } catch {
    const ta = document.createElement('textarea')
    ta.value = CMD
    ta.style.position = 'fixed'
    ta.style.opacity = '0'
    document.body.appendChild(ta)
    ta.select()
    document.execCommand('copy')
    ta.remove()
  }
  copied.value = true
  clearTimeout(timer)
  timer = setTimeout(() => { copied.value = false }, 1600)
}

onUnmounted(() => clearTimeout(timer))
</script>

<template>
  <section class="install" id="install">
    <div class="wrap">
      <p class="kicker">INSTALL</p>
      <h2>下载即用。</h2>
      <p class="lead">内置 Python / FastAPI 服务随 botChat.app 一起启动，无需自己跑后端。</p>
      <div class="dl-card rv">
        <img class="dl-icon" :src="appIcon" width="96" height="96" alt="botChat 应用图标" loading="lazy" decoding="async">
        <div class="dl-main">
          <p class="dl-name">botChat<span class="dl-ver">v{{ APP_VERSION }}</span></p>
          <p class="dl-meta">macOS 26 及以上（建议 26.1+）· Apple Silicon（arm64）· 当前版本 {{ APP_VERSION }}</p>
          <div class="btns">
            <a class="btn btn-p" :href="DMG_URL"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 4v11m0 0 4-4m-4 4-4-4M5 20h14"/></svg>下载 macOS 版<span class="btn-ver">v{{ APP_VERSION }}</span></a>
            <a class="btn btn-s" :href="RELEASES_URL">历史版本</a>
          </div>
        </div>
        <div class="dl-stickers" aria-hidden="true">
          <img class="sticker" :src="stickerCheer" alt="" loading="lazy" decoding="async" width="86" height="76">
          <img class="sticker" :src="stickerWow" alt="" loading="lazy" decoding="async" width="86" height="80">
          <img class="sticker" :src="stickerHype" alt="" loading="lazy" decoding="async" width="86" height="85">
        </div>
      </div>
      <p class="sys">下载文件为 botChat-{{ APP_VERSION }}.dmg；之后的版本升级由应用内自动完成（Sparkle），无需再次手动下载。</p>
      <div class="firstrun rv">
        <p class="fr-t">首次打开被 macOS 拦下</p>
        <p class="fr-d">未签名版本第一次双击，系统会提示无法验证开发者。下面两步任选一步，做一次就好。</p>
        <div class="fr-step">
          <span class="n">01</span>
          <div class="fr-body">
            <p>在<kbd>访达</kbd>的<kbd>应用程序</kbd>里找到 botChat，右键点<kbd>打开</kbd>，弹出的对话框里再确认一次。</p>
          </div>
        </div>
        <div class="fr-step">
          <span class="n">02</span>
          <div class="fr-body">
            <p>习惯用<kbd>终端</kbd>的话，粘贴下面这行回车。系统会要一次开机密码，输入时不显示字符，属正常。</p>
            <div class="cmd">
              <code>{{ CMD }}</code>
              <button class="cmd-cp" type="button" :data-done="copied" @click="copyCmd">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="8.5" y="8.5" width="11" height="11" rx="2.5"/><path d="M15.5 5.5v-1A1.5 1.5 0 0 0 14 3H6.5A1.5 1.5 0 0 0 5 4.5V14a1.5 1.5 0 0 0 1.5 1.5h1"/></svg>{{ copied ? '已复制' : '复制' }}</button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
