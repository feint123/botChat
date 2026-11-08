// 版本号来源：vite.config.js 在构建时读取仓库根 appcast.xml 并注入这三个常量。
// 改版本号只需改 appcast.xml，不要在这里硬编码。

export const APP_VERSION = __APP_VERSION__
export const APP_BUILD = __APP_BUILD__
export const DMG_URL = __DMG_URL__

export const RELEASES_URL = 'https://github.com/feint123/botChat/releases'
