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
      "views": ["{{view}}"]
    },
    "client.view": [
      {
        "slot": "{{slot}}",
        "view": "{{view}}",
        "title": "{{name}}",
        "icon": "square.stack.3d.up",
        "priority": 40,
        "render": "native"
      }
    ],
    "client.panel": {
      "views": [
        { "view": "{{view}}", "entry": "Panels/Main.swift", "apiVersion": 1 }
      ]
    },
    "client.command": {
      "id": "{{command}}",
      "title": "打开{{name}}"
    }
  }
}
