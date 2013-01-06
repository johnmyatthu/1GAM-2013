## Maps and Tile Sets

Only the layer named "Collision" will be used for the map's collision information.


There are several tile properties you can set depending on the behavior you want from the tile.
You can convert a tile to an entity at runtime by giving it a "classname" or simply give it special tile properties.

## Entities

You can turn a tile into a class by specifying a property with the key: "classname"
and the value as one of the following entity classes. The original tile will not be drawn after conversion to an entity.

### Entity classes:

* **info\_player\_spawn** - *the player's starting location*

		no properties

* **func\_spawn** - *spawn an entity at this tile*

		spawn_class: The classname of the entity to spawn
		spawn_time: The delay (in seconds) between entity spawns
		max_entities: The maximum number of entities to spawn from this. -1 is infinite.

* **func\_target** - *The target which enemies will try to attack on spawn*

		no properties

## Special Tile Properties

Tiles can have special properties without being converted to an entity at runtime. Tiles on the Collision layer can have these additional properties.

**walkable** - *allows enemies to ignore tile in paths*, "true" or "false"