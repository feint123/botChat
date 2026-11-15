{
  "schemaVersion": 2,
  "id": "{{id}}",
  "name": "{{name}}",
  "version": "{{version}}",
  "minAppVersion": "{{minAppVersion}}",
  "trust": "sandboxed",
  "activationEvents": ["onTool:{{toolFull}}"],
  "permissions": {},
  "capabilities": {
    "server.tool": {
      "entry": "tools.py",
      "tools": ["{{tool}}"]
    }
  }
}
