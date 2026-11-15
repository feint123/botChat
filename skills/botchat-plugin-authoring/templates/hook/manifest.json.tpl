{
  "schemaVersion": 2,
  "id": "{{id}}",
  "name": "{{name}}",
  "version": "{{version}}",
  "minAppVersion": "{{minAppVersion}}",
  "trust": "sandboxed",
  "activationEvents": [],
  "permissions": {},
  "capabilities": {
    "server.hook": {
      "entry": "hooks.py",
      "events": ["pre_model"],
      "priority": 100
    }
  }
}
