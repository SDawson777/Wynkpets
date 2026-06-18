# Wynkpets 🐾

A **Roblox Pet Simulator** — hatch eggs, collect pets, unlock zones, rebirth for multipliers, and compete for the rarest pets.

## Quick Start

### Prerequisites
- [Roblox Studio](https://create.roblox.com/)
- [Rojo](https://rojo.space/) (VS Code extension or CLI)

### Setup
```bash
# 1. Clone the repo
git clone https://github.com/SDawson777/Wynkpets.git
cd Wynkpets

# 2. Install Rojo CLI (if not using the VS Code extension)
aftman install

# 3. Start Rojo dev server
rojo serve

# 4. In Roblox Studio, connect via the Rojo plugin
```

## Architecture

```
src/
├── shared/              → ReplicatedStorage
│   ├── Types.luau           Type definitions
│   ├── Network.luau         Centralized RemoteEvent system
│   ├── Configs/             Game data (pets, eggs, zones, shop, rebirth, quests)
│   └── Utils/               NumberFormat, TableUtil
├── server/              → ServerScriptService
│   ├── init.server.luau     Boot script (loads all services)
│   └── Services/            12 server services
│       ├── DataService          DataStore persistence, auto-save, retry
│       ├── CurrencyService      Coins/Gems with multiplier stacking
│       ├── PetService           Inventory, equip/unequip, pet index
│       ├── EggService           Weighted hatching, golden/rainbow variants
│       ├── ZoneService          Zone unlock & teleport
│       ├── RebirthService       Prestige system
│       ├── GamepassService      MarketplaceService integration
│       ├── ShopService          Dev product processing, boosts
│       ├── RewardService        Login streaks, daily quests
│       ├── AdminService         Debug commands (gated by ADMIN_IDS)
│       ├── AntiExploitService   Rate limiting, speed checks
│       └── CoinSpawnerService   World coin spawning & collection
├── client/              → StarterPlayerScripts
│   ├── init.client.luau     Boot script (loads all controllers)
│   └── Controllers/         5 client controllers
│       ├── CurrencyController   Local currency tracking
│       ├── PetController        Visual pet models orbiting player
│       ├── HatchController      Hatch animation & result display
│       ├── ZoneController       Zone state tracking
│       └── ShopController       Purchase request helpers
└── gui/                 → StarterGui
    ├── MainHUD              Currency display, side menu, notifications
    ├── ShopGui              Gamepasses & dev products (tabbed)
    ├── EggGui               Egg selection with hatch chances
    ├── PetInventoryGui      Pet grid with equip/sort
    ├── RebirthGui           Prestige progression & confirm
    ├── ZoneGui              Zone list with teleport/unlock
    └── QuestGui             Daily quests & login streak
```

All game logic is **server-authoritative**. The client sends requests via `Network.FireServer()`, the server validates and responds.

## Game Content (MVP)

| Category | Count | Details |
|----------|-------|---------|
| Zones | 3 | Starter Meadow (free), Forest Grove (1K), Crystal Caves (25K) |
| Eggs | 6 | 2 per zone, 100–250K coins |
| Pets | 31 | Common → Secret rarity, Golden & Rainbow variants |
| Gamepasses | 5 | 2x Coins, 2x Gems, Auto Hatch, Triple Hatch, VIP |
| Dev Products | 3 | Luck Boost, Coin Boost, Starter Pack |
| Rebirth Tiers | 10 | 1.5x → 20x multiplier, +1 → +5 equip slots |
| Daily Quests | 6 types | 3 assigned per day, 7-day login streak |

## Adding Content

### New Pet
Add an entry to `src/shared/Configs/PetConfig.luau`:
```lua
{ Id = "my_pet", Name = "My Pet", Rarity = "Epic", Power = 100, Zone = "starter_meadow", Description = "A cool pet" },
```
Then add it to an egg's `Pets` table in `EggConfig.luau` with a `Weight`.

### New Egg
Add to `src/shared/Configs/EggConfig.luau`:
```lua
{ Id = "new_egg", Name = "New Egg", Zone = "starter_meadow", Cost = 500, Currency = "Coins", Pets = { ... } },
```

### New Zone
Add to `src/shared/Configs/ZoneConfig.luau` with `Id`, `Name`, `UnlockCost`, `SpawnPosition`, `CoinMultiplier`, `Color`, `Description`.

### New Gamepass / Dev Product
Add to `GamepassConfig.luau` or `DevProductConfig.luau`. Replace `ProductId = 0` with the real Roblox asset ID after publishing.

## Placeholder IDs

Before publishing, replace all `ProductId = 0` values:
- `src/shared/Configs/GamepassConfig.luau` — 5 gamepass IDs
- `src/shared/Configs/DevProductConfig.luau` — 3 dev product IDs
- `src/server/Services/AdminService.luau` — `ADMIN_IDS` table with your Roblox user IDs

## Admin Commands

Chat commands (requires your user ID in `ADMIN_IDS`):

| Command | Description |
|---------|-------------|
| `/addcoins [amount]` | Add coins |
| `/addgems [amount]` | Add gems |
| `/setcoins [amount]` | Set exact coins |
| `/givepet [petId]` | Give yourself a pet |
| `/unlockall` | Unlock all zones |
| `/resetdata` | Reset your player data |
| `/givegamepass [id]` | Grant a gamepass |
| `/setrebirth [level]` | Set rebirth level |
| `/boost [type] [seconds]` | Activate a boost |
| `/help` | List all commands |

## Tech Stack

- **Language:** Luau (Roblox)
- **Build Tool:** Rojo (filesystem → Roblox Studio sync)
- **Data:** DataStoreService with retry logic & auto-save (120s)
- **Pattern:** Service/Controller (server services, client controllers)
- **Network:** Centralized RemoteEvent/RemoteFunction system

## License

Private — all rights reserved.