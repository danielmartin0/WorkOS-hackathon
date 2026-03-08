## Factorio modding practices

The following information will help you develop Factorio mods in this directory.

* Never use goto statements in Lua.
* Prefer the early return pattern `if not (entity and entity.valid) then` over `if not entity or not entity.valid then`.
* `require` statements should be placed at the top of the file.
* If the mod in question uses the pattern for Public function exports of 'local function foo' followed by 'Public.foo = foo', please follow that pattern.
* We're using the Factorio 2.0 API. For example, you should use the 'storage' object instead of the 'global' object to store game data.

## Firing RCON commands at the game

In order to make something happen in the game, such as creating enemies near the player, you should execute our RCON script, which is in our npm project in the `mod/rcon-script` directory. In that directory, you can execute the script like so: `npx tsx test-rcon.ts '/silent-command for i=1,3 do game.surfaces["nauvis"].create_entity{name="small-biter", position={x=i,y=0}, force=game.forces.enemy} end'`

## Generating and saving new images

If you're asked to generate graphics for the warehouse, you should always use Google Gemini to generate thr ee options, slightly different to each other. These should all be created in parallel if possible. Each image should be 260x260 pixels, png with a transparent background, and overall it should be in the Factorio style but matching what the user asked for. Once you have all three images, you should save them the working directory as `image1.png`, `image2.png`, and `image3.png`. (There will be existing images there that you should overwrite.)