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