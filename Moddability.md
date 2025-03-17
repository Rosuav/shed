Games sorted by how well they welcome modding
=============================================

The Good (Welcoming)
--------------------

These games openly welcome third party mods. They may offer event hooks or
other facilities, or maybe even have a first-party mod manager that helps you
enable and disable them.

* [Europa Universalis 4](https://www.paradoxplaza.com/europa-universalis-all/)
  - A lot of this is also true of other Paradox games eg
    [Cities: Skylines](https://www.paradoxplaza.com/games/?prefn1=pdx-brand&prefv1=Cities%3A%20Skylines)
    and [Surviving Mars](https://www.paradoxplaza.com/surviving-mars/SUSM01GSK-MASTER.html).
  - Lots of crucial numbers are defined in a Lua file and can easily be seen or
    changed.
  - Building attributes, idea costs, country and region data, etc, are all
    defined by simple text files that anyone can edit.
  - The Wiki has information even to the extent of creating new buildings and
    having them available in the GUI.
  - Some behaviours (eg the AI's choices on where to build forts) are too
    complicated to put into those files, but this fact is at least acknowledged.
  - If you edit any of these files, you get a simple cautionary note saying that
    achievements are disabled (perfectly reasonable), and then you're fully
    allowed to play with whatever balance-breaking changes you like.
  - Third-party mods can be found on the Steam Workshop and the game has a
    preloader that lets you enable and disable them.
- [Counter-Strike: Global Offensive](https://store.steampowered.com/app/730/CounterStrike_Global_Offensive/)
  - Also true of other Source games eg [Team Fortress 2](https://store.steampowered.com/app/440/Team_Fortress_2/)
  - This is a fundamentally multiplayer game, so the concept of game balance is
    extremely important. And yet Valve permit all manner of modding, either by
    running a custom server or by creating a custom map (or both). A lot of the
    power of custom servers is best made available via SourceMod and MetaMod,
    which are third party modding tools, but they are so highly respected that
    they can be considered part of the ecosystem.
  - The core game includes a number of tools aimed exclusively at those trying
    to interact with the game, such as Game State Integration, external config
    files, and a parseable demo replay format.
* [Factorio](https://factorio.com/)
  - Lua, Lua, Lua! Everything's done with Lua scripts. You can tweak anything
    you like.
  - Want to put a nuclear waste into a rocket and launch it? You can do that.
    And you can write an event that will fire when that happens.
  - You can download [the demo](https://factorio.com/download) and play with
    the Lua files right there. No need to get a special custom content creation
    tool or anything - all you need is a text editor.
* Entrepreneur
  - Lots of the key data comes from easily edited files. It's easy to mess with
    anything you like, although some things seem to be tied to the UI fairly
    closely.
  - The format of those files is rigid and fragile, but fortunately they are
    well-commented and you can easily just tweak things within the existing
    framework.
* Galactic Civilisations (series)
  - SO VERY moddable! You can mess around with basically everything.
  - Most of the edit files are XML, which means you probably want to get a tool
    to edit them with, but that's easy enough.
* [Satisfactory](https://www.satisfactorygame.com/)
  - Most of the work is done by the Unreal modular build system, which helps, but
    more importantly, there is a culture of welcome that makes even unofficial
    support so much more helpful. During the game's "Early Access" period, modding
    was not a priority of the devs, and yet there was a strong modding community
    already. (See below for my original writeup.)
  - Want to build a savefile editor? There's information on the [official wiki](https://satisfactory.wiki.gg/wiki/Save_files)
    about how to do it. This is no secret and the game publisher is happy for us
    to learn how to tinker with the game.

The Okay (Ignoring)
-------------------

While not specifically *welcoming* modders, these games do at least permit it.
They might simply ignore what you're doing, with no documentation or assistance
in figuring out what anything means.

* Satisfactory, during Early Access
  - Even back in Early Access, Satisfactory was non-hostile to modders. It was
    "you're on your own" for the most part, but even back then, things were good
    enough that I wrote the following (verb tenses unchanged from the original):
  - There IS some documentation on how to mod the game. The game itself doesn't
    really support modding - you have to basically hack it in. I'm hoping that,
    by the time the game's out of Early Access, there'll be enough tools that it
    can be promoted to the top category.
  - Making any sort of mod requires that you get the Coffee Stain Studios'
    modded version of the Unreal engine. And even though UE4 supports multiple
    platforms (kinda - it's pretty obvious that Epic don't put any effort into
    supporting Linux), the CSS patches don't work outside of Windows.
  - The game desperately needs the equivalent of SourceMod/MetaMod (see CS:GO).
    If there could be such a mod, and the ecosystem embraced it, then that mod
    could become the one and only thing that requires UE4, and every other mod
    is just text files that configure the metamod.
  - The devs DO notionally support modding. It just doesn't seem to be a high
    priority at the moment (which is unsurprising - they have a game to build,
    after all).
* Borderlands (1, 2, and Pre-Sequel)
  - There's basically no modding support. You can edit save files but even that
    isn't easy. The general feeling I get from the save file format is that it
    came about organically as a simple dump in the most convenient way for the
    game devs.
  - If you DO edit your save files, they load up just fine. You can even edit
    saves in multiplayer and it's fine with that. It probably doesn't much care
    what you do.
* Anno 1602
  - You can mess around a lot with the built-in scenario editor, but to change
    the island definitions, you need an external program. You can do a lot, but
    be careful, as you can crash the game. It doesn't really *support* modding,
    but it doesn't object to it either.

The Bad (Hostile)
-----------------

Some games are openly hostile towards modding. All you can do is edit your save
files and hope for the best. The vanilla experience is the only one the devs
have considered. Attempting to modify the game may see you branded as a cheater
(or worse), even if you're trying to run your own modded game among friends.

* Command & Conquer: Renegade
  - Like Borderlands above, there's no support for any modding, and the game
    isn't easy to even *read* the save files of, much less modify them. The
    multiplayer form of the game feels tacked on, and doesn't adequately keep
    itself alive with bots, so since there's no strong community support for
    modding, the game was probably doomed from release to having a limited
    life.
  - It's VERY easy, when editing save files, to do weird things that can crash
    the game. There's no info on what you can and can't do.
* Overwatch
  - As an esport-level game, it's going to survive fairly well. But it will
    die if its owners stop developing it. There's no way for the community to
    keep it alive.
* Valorant
  - Same as Overwatch. By not permitting custom maps, much less server-side
    modding, these games limit themselves to being nothing more than their
    creators design them to be. In contrast, TF2 and CS:GO have become more
    than Valve could ever have imagined.
