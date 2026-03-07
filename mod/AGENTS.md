## Factorio mods

The following information will help you develop Factorio mods in this directory.

### Lua Coding Standards

* Never use goto statements in Lua.
* Prefer the early return pattern `if not (entity and entity.valid) then` over `if not entity or not entity.valid then`.
* `require` statements should be placed at the top of the file.
* If the mod in question uses the pattern for Public function exports of 'local function foo' followed by 'Public.foo = foo', please follow that pattern.

### Factorio Modding Practices

* We're using the Factorio 2.0 API. For example, you should use the 'storage' object instead of the 'global' object to store game data.
* The Factorio API documentation is available at https://lua-api.factorio.com/latest/.
* When adding entries for entities, recipes or other game objects to the locale file, you should usually avoid giving them descriptions.

## Environment

* For examples, you can look at the code of existing mods inside `/Applications/factorio-modding.app`. In particular, the 'Portals mod' is at `/Applications/factorio-modding.app/Contents/mods/The-Portals-Mod`.
* If I ask you to pull in a pre-existing external asset from our assets library, that is located in `/Users/danielmartin/Dev/Git-External/factorio_free_graphics_for_modders`.
* If you want to look at base game Lua code, you can find it in `/Users/danielmartin/Dev/Git-External/factorio-data`.