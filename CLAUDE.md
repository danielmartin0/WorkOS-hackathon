## Factorio mods

The following information will help you develop Factorio mods in this repo.

### Lua Coding Standards

* Never use goto statements in Lua.
* Prefer the early return pattern `if not (entity and entity.valid) then` over `if not entity or not entity.valid then`.
* `require` statements should be placed at the top of the file.
* If the mod in question uses the pattern for Public function exports of 'local function foo' followed by 'Public.foo = foo', please follow that pattern.

### Factorio Modding Practices

* The Factorio API documentation is available at https://lua-api.factorio.com/latest/.
* When adding entries for entities, recipes or other game objects to the locale file, you should usually avoid giving them descriptions.
* All event registrations (`script.on_event`) should happen in `scripts/events.lua`. Other script modules should export handler functions rather than registering events themselves.

### Environment

* Only launch Factorio when explicitly asked. The modding instance is at `/Applications/factorio-modding.app`.
* If I ask you to pull in a specific external asset, it is likely located in `/Users/danielmartin/Dev/Git-External/factorio_free_graphics_for_modders`. If you add one to our project, please update the CREDITS.md file.
* If you want to look at base game Lua code, you can find it in `/Users/danielmartin/Dev/Git-External/factorio-data`.