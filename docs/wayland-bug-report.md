# Bug: npm linux-x64 build missing `managed-cli-shims/officecli` — all agent backends fail to start

**Version:** getwayland v0.9.6-rc.1, installed via `npm i -g getwayland`
**Platform:** Ubuntu 24.04, x86_64, kernel 6.17
**Install path:** /usr/local/lib/node_modules/getwayland

## Symptom
Any chat message fails silently in the UI. Server log:

```
error: Wayland managed OfficeCLI fallback guard is unavailable
    at getManagedOfficeCliShimDir (dist-server/server.mjs:41667:27)
    at getBundledNpmBinDirs (server.mjs:41674:19)
    at getEnhancedEnv (server.mjs:41907:29)
    at new ForkTask (server.mjs:870791:35)
    at new BaseAgentManager (server.mjs:870933:9)
    at new _GeminiAgentManager (server.mjs:887064:9)
[conversationBridge] sendMessage: failed to get/build task
```

Because the throw is in `BaseAgentManager`, this affects every fork-based
backend, not just gemini.

## Cause
`getManagedOfficeCliShimDir()` resolves:

```js
const resourcesRoot = paths.isPackaged()
  ? process.resourcesPath
  : path.join(process.cwd(), "resources");
```

`resolveManagedOfficeCliShimDir()` then requires
`<resourcesRoot>/managed-cli-shims/officecli` to exist, be a regular
non-symlink file, be executable, and match
`sha256:b77af087b9ce061bd26957e387b6dc56491ef894409e52317d11692a63ac327f`.

Two problems on an npm install:

1. `isPackaged()` is false, so resourcesRoot is `process.cwd()/resources` —
   whatever directory the user launched from. Not a stable location.
2. `managed-cli-shims/` is not in the npm payload at all:

```
$ ls /usr/local/lib/node_modules/getwayland/payload/resources
bundled-wayland-core

$ find /usr/local/lib/node_modules/getwayland \
    \( -name "officecli*" -o -name "managed-cli-shims" \)
# only skill folders (officecli-docx, officecli-pptx, ...) - no shim binary
```

Because the guard is SHA-pinned, there is no user-side workaround.

## Other linux-x64 gaps seen in the same session
- `ConstitutionFsTransactionError: No packaged Constitution filesystem
  authority exists for linux-x64` -> `/api/constitution` returns 503
- `MCP detection is not supported for backend "wnano"`
- `wayland setup` tries `sudo apt install libasound2` and continues silently
  when sudo auth fails

## Suggested fix
Ship `managed-cli-shims/` in the npm payload, and resolve resourcesRoot from
the module directory (e.g. `__dirname`-relative) rather than `process.cwd()`
for non-packaged installs.
