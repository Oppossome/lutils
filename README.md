## About
LUtils is a powerful [glua](https://wiki.facepunch.com/gmod) development utility designed to streamline the debugging experience
- Commands to execute and evaluate in different contexts
- Support for [luadev](https://github.com/Metastruct/luadev) compatible development tools
- Dynamic multi-entity targeting
- [Human readable entity printing](https://camo.githubusercontent.com/ebab261822c78a5fc6e88e18e59242c9dbdce9fef8a1acc62ded71392093cdb7/68747470733a2f2f63646e2e646973636f72646170702e636f6d2f6174746163686d656e74732f3136343737393238363937313135343433332f3731343237353834383232333435373335302f756e6b6e6f776e2e706e67)

***It is extremely recommend to use this in conjunction with [EPOE](https://github.com/Metastruct/EPOE) in order to be able to see server prints***

## Usage

### Execution Commands
| Command | Context | Usage  |
| ------------ | ------------ | ------------ |
| !p `code` | Server | Executes code then prints result |
| !ps `code` | Shared | Executes code on both self and server then prints results |
| !pm `code` | Client  | Executes code on self then prints result |
| !psc `targets`, `code` | Clients  | Excutes code on targets then prints results |
| !l `code`| Server | Executes code |
| !ls `code` | Shared | Executes code on both self and server|
| !lm `code`| Client | Executes code on self |
| !lsc `targets`, `code` | Clients | Executes code on targets

###### Examples
- Print hooks table  
`!p hook.GetTable()`
- Print local branch  
`!pm BRANCH`

#### Execution Targets
| Targets  | Result  |
| ------------ | ------------ |
| #all | Targets every entity  |
| #us | Targets everyone within 1000 blocks of you  |
| #them | Same as above without yourself |
| `username` | Targets user with username |

###### Examples
- Force every player to say hello  
`!lsc #all, LocalPlayer():ConCommand("say hello")`
- Force timmy to say hello  
`!lsc timmy, LocalPlayer():ConCommand("say hello")`
- Print the current branch of every player  
`!psc #all, BRANCH`


### Tinylua

#### Execution Upvalues
| Target | Type | Result  |
| ------------ | ------------ | ------------ |
| me | [Player](https://wiki.facepunch.com/gmod/Player) | Selects user of command  |
| here | [Vector](https://wiki.facepunch.com/gmod/Vector) | Current Position|
| wep | [Weapon](https://wiki.facepunch.com/gmod/Weapon) | Current Weapon |
| veh | [Vehicle](https://wiki.facepunch.com/gmod/Vehicle) | Current Vehicle|
| dir | [Vector](https://wiki.facepunch.com/gmod/Vector) | Current [AimVector](https://wiki.facepunch.com/gmod/Player:GetAimVector)|
| trace | [TraceResult](https://wiki.facepunch.com/gmod/Structures/TraceResult)| Current EyeTrace|
| there |[Vector](https://wiki.facepunch.com/gmod/Vector) | TraceResult HitPos|
| this |[Entity](https://wiki.facepunch.com/gmod/Entity)| Currently targeted entity|
| `username` | [Player](https://wiki.facepunch.com/gmod/Player) | Player with the name|
| _`entityID` | [Entity](https://wiki.facepunch.com/gmod/Entity) |

###### Examples
- Kill your own player  
`!l me:Kill()`
- Print entity you are looking at  
`!p this`
- Kick timmy from the server  
`!l timmy:Kick()`
- Remove the entity with the ID 1072  
`!l SafeRemoveEntity(_1072)`

#### Multi-target Upvalues
This is more complex as it allows you to call methods on more than one entity simultaneously

| Target | Result  |
| ------------ | ------------ |
| all  | Every [player](https://wiki.facepunch.com/gmod/Player) |
| bots | Every bot player |
| humans | Every human player |
| props | Every prop |
| these | Every prop near you |
| those | Every prop near your target |
| us | Every player near you |
| them | Every player near you, that is not you |
| npcs | Every npc |
| allof(`entity`) | Targets every entity of the class passed into it |

###### Examples
- Kick every bot online  
`!l bots:Kick()`
- Force every npc to take a thousand damage from you  
`!l npcs:TakeDamage(1000, me)`
- Delete every weapon_crowbar  
`!l allof("weapon_crowbar"):Remove()`
- Delete every players active weapon  
`!l all:GetActiveWeapon():Remove()`

#### Advanced Tinylua
Tinylua objects are able to be manipulated for higher granularity

##### :filter(`function`) - Return wrapped table of those that fit the criteria
- Kick every admin with full function  
`all:filter(function(ply) ply:IsAdmin() end):Kick()`
- Kick every admin with function stub  
`all:filter('ply -> ply:IsAdmin()'):Kick()`

##### :map(`function`) - Return wrapped table of the results
- Get wrapped table of every active weapon  
`all:map('ply -> ply:GetActiveWeapon()')`

##### :set(`key`, `value`) - Set value on every entity in wrapped table
- Set both the variable a and b to true on every player  
`all:set("a", true):set("b", true)`

##### :keys() - Get wrapped value of only table keys
- Kill every player holding a crowbar  
`all:GetActiveWeapon():GetClass():filter('x -> x == "weapon_crowbar"):keys():Kill()`

##### :errors() - Return table of every error in prior tinylua call
- Get a table of every error caused by entities without physics objects  
`allof("*"):GetPhysicsObject():errors()`

##### :get() -- Return unwrapped table
- Get a normal table of players  
`all:get()`
