import { ref } from 'vue'

// 原 index.html L337-L342 复制逻辑：brew 三行命令 + 1600ms 文案回落 + execCommand fallback
export const BREW_TXT = 'brew tap feint123/tap\nbrew trust feint123/tap\nbrew install --cask botchat'

export function useCopy (text = BREW_TXT, resetMs = 1600) {
  const label = ref('复制')
  let busy = false
  let timer = 0

  function ok () {
    label.value = '已复制'
    busy = true
    clearTimeout(timer)
    timer = setTimeout(() => {
      label.value = '复制'
      busy = false
    }, resetMs)
  }

  function fallback () {
    const t = document.createElement('textarea')
    t.value = text
    t.setAttribute('readonly', '')
    t.style.position = 'fixed'
    t.style.opacity = '0'
    document.body.appendChild(t)
    t.select()
    try {
      document.execCommand('copy')
      ok()
    } catch (e) {
      label.value = '复制失败'
    }
    document.body.removeChild(t)
  }

  function copy () {
    if (busy) return
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(ok, fallback)
    } else {
      fallback()
    }
  }

  return { label, copy }
}
