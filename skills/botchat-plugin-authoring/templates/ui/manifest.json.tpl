{
  "schemaVersion": 2,
  "id": "{{id}}",
  "name": "{{name}}",
  "version": "{{version}}",
  "minAppVersion": "{{minAppVersion}}",
  "trust": "sandboxed",
  "activationEvents": [
    "onStartup",
    "onSlot:{{slot}}:{{view}}",
    "onCommand:{{command}}"
  ],
  "permissions": {},
  "capabilities": {
    "server.ui": {
      "entry": "plugin.py",
      "views": ["{{view}}", "settings"]
    },
    "client.view": [
      {
        "slot": "{{slot}}",
        "view": "{{view}}",
        "title": "{{name}}",
        "icon": "square.grid.2x2",
        "priority": 50
      },
      {
        "slot": "settings.section",
        "view": "settings",
        "title": "{{name}}设置"
      }
    ],
    "client.command": {
      "id": "{{command}}",
      "title": "打开{{name}}"
    }
  }
}
