// 版本号来源：vite.config.js 在构建时读取仓库根 appcast.xml 并注入这三个常量。
// 改版本号只需改 appcast.xml，不要在这里硬编码。

export const APP_VERSION = __APP_VERSION__
export const APP_BUILD = __APP_BUILD__
export const DMG_URL = __DMG_URL__

export const RELEASES_URL = 'https://github.com/feint123/botChat/releases'

// 更新日志同样在构建期从 notes/*.html 解析注入，页面不硬编码任何版本条目。
// RELEASES：最近几个版本（含主线一句 + 分组条目）
// RELEASE_ARCHIVE：更早版本的版本号 / 日期 / 详情链接
export const RELEASES = __RELEASES__
export const RELEASE_ARCHIVE = __RELEASE_ARCHIVE__

// 插件开发文档页（与本页同为 Pages 下的静态页）
export const PLUGINS_DOC_URL = './plugins.html'
