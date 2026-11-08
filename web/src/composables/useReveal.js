import { onScopeDispose } from 'vue'

// 滚动进场：原 index.html L346-L348 逻辑的组合函数版本
// 阈值 0.12、rootMargin '0px 0px -6% 0px'、无 IO 时直接加 in
export function useReveal (options = {}) {
  const { threshold = 0.12, rootMargin = '0px 0px -6% 0px', selector = '.rv' } = options
  let io = null

  function revealAll () {
    document.querySelectorAll(selector).forEach((el) => el.classList.add('in'))
  }

  function observe (root = document) {
    const els = root.querySelectorAll ? [...root.querySelectorAll(selector)] : []
    if (!('IntersectionObserver' in window)) {
      els.forEach((el) => el.classList.add('in'))
      return
    }
    io = new IntersectionObserver((entries) => {
      entries.forEach((e) => {
        if (e.isIntersecting) {
          e.target.classList.add('in')
          io.unobserve(e.target)
        }
      })
    }, { threshold, rootMargin })
    els.forEach((el) => io.observe(el))
  }

  function disconnect () {
    if (io) io.disconnect()
  }

  onScopeDispose(disconnect)
  return { observe, revealAll, disconnect }
}
