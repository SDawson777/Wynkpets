# Wynkpets — Crystal Pets Simulator

> **Repository name:** `Wynkpets` | **Game working title:** `Crystal Pets Simulator` | **Rojo project name:** `CrystalPetsSimulator`

A top-revenue-oriented **Pet + Mining Simulator** for Roblox, built in Luau using the [Rojo](https://rojo.space/) workflow.

---

## 🎮 Game Overview

**Working title:** Crystal Pets Simulator  
**Platform:** Roblox (Luau)  
**Genre:** Simulator (Pet + Mining)

### Core Loop
1. **Mine** crystals and ores by clicking rocks
2. **Sell** ores for coins
3. **Hatch** eggs with coins or gems to get pets
4. **Equip** pets for permanent multiplier bonuses
5. **Unlock** new worlds with rarer ores and pets
6. **Rebirth** to reset progress for permanent prestige bonuses

---

## 📁 Project Structure

```
default.project.json          ← Rojo project config (maps src/ → Roblox tree)
aftman.toml                   ← Tool version lock (rojo, selene, stylua, wally)
selene.toml                   ← Luau linter config
stylua.toml                   ← Luau code formatter config
src/
  shared/
    Config/
      EconomyConfig.luau      ← Currency values, ore prices, rebirth costs
      MiningConfig.luau       ← Tools, rocks, HP, ore tables, swing cooldown
      PetConfig.luau          ← 30 pets, 8 rarities, slot limits
      EggConfig.luau          ← 8 eggs, hatch pools, costs, auto-hatch config
      WorldConfig.luau        ← 3 worlds, unlock costs, rebirth requirements
      GamepassConfig.luau     ← 8 gamepasses + dev products (consumables)
      ShopConfig.luau         ← In-game shop items, daily rewards
      QuestConfig.luau        ← Daily / weekly quests + achievements
      RemoteConfig.luau       ← All RemoteEvent / RemoteFunction names
    Modules/
      DataTemplate.luau       ← Default player save-data schema
      WeightedRandom.luau     ← Weighted-random picker (eggs, ore drops)
      FormatNumber.luau       ← K/M/B/T number formatting
      MultiplierUtil.luau     ← Calculates effective coin/mine/luck mults
  server/
    init.server.luau          ← Bootstrap: create remotes, load services
    MapSetup.server.luau      ← Procedural world geometry (rocks, zones, pads)
    Services/
      DataService.luau        ← DataStore save/load with session lock + retries
      MiningService.luau      ← Rock hits, ore drops, auto-sell loop
      PetService.luau         ← Egg hatching, equip/unequip, auto-hatch loop
      ShopService.luau        ← Shop purchases, world unlocks, gamepass grants
      RebirthService.luau     ← Rebirth validation and stat reset
      QuestService.luau       ← Quest/achievement tracking + daily rewards
      TradeService.luau       ← P2P pet trading
      EventService.luau       ← Limited-time event framework + admin commands
      LeaderboardService.luau ← OrderedDataStore leaderboards + leaderstats panel
  client/
    init.client.luau          ← Bootstrap: wait for remotes, load controllers
    Controllers/
      ClientData.luau         ← Client-side data cache (synced from server)
      UIController.luau       ← HUD (coins, gems, sell button, notifications)
      MiningController.luau   ← Click/tap → MineRock remote + client prediction
      PetController.luau      ← Pet inventory GUI + egg hatch GUI
      ShopController.luau     ← Shop GUI, rebirth GUI, quest/achievement GUI
```

---

## 🛠 Getting Started

### Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| [Rojo](https://rojo.space/) | Sync code → Studio | `aftman install` |
| [Roblox Studio](https://create.roblox.com/docs/studio/setting-up-roblox-studio) | Game editor | From Roblox website |
| [aftman](https://github.com/LPGhatguy/aftman) | Tool version manager | See aftman README |

### Workflow

```bash
# 1. Install all tools (Rojo, Selene, StyLua, Wally) at pinned versions
aftman install

# 2. Start the Rojo dev server
rojo serve

# 3. In Roblox Studio, open the Rojo plugin and click Connect
#    Your code syncs live — save any .luau file to see it update instantly.

# 4. Hit Play (F5) in Studio to test.
#    MapSetup.server.luau auto-generates the full map on run — no manual asset placement needed.
```

### Linting & Formatting

```bash
# Lint all Luau files
selene src/

# Auto-format all Luau files
stylua src/
```

### Building a Place File

```bash
# Builds a .rbxlx place file (useful for CI or sharing)
rojo build --output game.rbxlx

# game.rbxlx is in .gitignore — commit the source, not the binary.
```

---

## 💰 Economy at a Glance

| Ore         | Coins / unit |
|-------------|-------------|
| Coal        | 1           |
| Copper      | 3           |
| Iron        | 8           |
| Gold        | 55          |
| Diamond     | 150         |
| Crystal     | 40,000      |
| Starstone   | 100,000     |

**Rebirth cost formula:** `1,000,000 × 5^n` (n = current rebirth count)

---

## 🐾 Pet Rarities & Multipliers

| Rarity    | Approx. Chance | Coin Mult | Mine Mult |
|-----------|----------------|-----------|-----------|
| Common    | ~55%           | +0.05×    | +0.05×    |
| Uncommon  | ~28%           | +0.12×    | +0.12×    |
| Rare      | ~11%           | +0.30×    | +0.30×    |
| Epic      | ~4.4%          | +0.75×    | +0.75×    |
| Legendary | ~1.1%          | +2.00×    | +2.00×    |
| Mythic    | ~0.28%         | +5.00×    | +5.00×    |
| Divine    | ~0.06%         | +15.00×   | +15.00×   |
| Secret    | ~0.01%         | +50.00×   | +50.00×   |

---

## 🥚 Eggs (MVP: 8)

| Egg         | Cost         | World |
|-------------|-------------|-------|
| Starter Egg | 500 🪙      | 1     |
| Mine Egg    | 5,000 🪙    | 1     |
| Crystal Egg | 100,000 🪙  | 2     |
| Gem Egg     | 1,000,000 🪙| 2     |
| Void Egg    | 100 💎      | 3     |
| Premium Egg | 250 💎      | Any   |
| Event Egg   | 50 tokens   | Any   |
| Mythic Egg  | 500 💎      | 3     |

---

## 🎫 Gamepasses (8)

| Pass             | Robux | Effect                           |
|------------------|-------|----------------------------------|
| 2× Coins         | 199   | +1× coin multiplier (permanent)  |
| 2× Mining        | 199   | +1× mine multiplier (permanent)  |
| Extra Pet Slots  | 299   | +3 equip slots (max 6)           |
| Auto-Sell        | 149   | Sell ores automatically          |
| Auto-Hatch       | 149   | Auto-hatch eggs                  |
| VIP              | 499   | +10% all gains + VIP zone        |
| Speed Boost      | 99    | +25% mining speed                |
| Max Luck         | 399   | +2× hatch luck                   |

---

## 🌍 Worlds (MVP: 3)

| World             | Unlock Cost | Rebirth Gate | Ores                       |
|-------------------|-------------|--------------|----------------------------|
| Starter Mine      | Free        | 0            | Coal, Copper, Iron         |
| Crystal Caverns   | 1M 🪙       | 1            | Silver, Gold, Diamond, Emerald, Ruby |
| Starstone Abyss   | 500 💎      | 3            | Crystal, Amethyst, Obsidian, Sapphire, Starstone |

---

## 🔒 Anti-Exploit Architecture

- **Server-authoritative**: all currency, pets, and progression are only ever modified server-side
- **Timing validation**: `MiningService` checks swing interval server-side (50 ms tolerance for latency)
- **Input validation**: all `OnServerEvent` handlers validate argument types before processing
- **DataStore retries**: exponential backoff (up to 3 attempts) on save/load failures
- **Session lock pattern**: data is loaded per-session; no cross-server duplication

---

## 🏆 Leaderboards

`LeaderboardService` maintains three `OrderedDataStore` boards and Roblox's built-in `leaderstats` panel:

| Board       | Metric                    |
|-------------|---------------------------|
| MostCoins   | Lifetime coins earned     |
| MostRebirths| Total rebirths completed  |
| MostPets    | Total eggs hatched        |

The `leaderstats` folder (Coins, Rebirths, Pets) is created on every player join so they appear automatically in the Roblox player list.

---

## 🗺 Procedural Map

`MapSetup.server.luau` runs at game start and generates the entire playable world:

| Zone             | X range     | Rocks                         | Special pads         |
|------------------|-------------|-------------------------------|----------------------|
| Spawn Island     | X = -380    | —                             | Portal → World 1     |
| Starter Mine     | X = -200→-50| Coal & Copper rocks (3×5=15)  | Sell, Eggs, Rebirth  |
| Crystal Caverns  | X = 50→200  | Silver & Gemstone rocks (3×5=15)| Sell, Eggs         |
| Starstone Abyss  | X = 300→500 | Crystal & Starstone rocks (4×6=24)| Sell, Eggs      |

No manual Studio work is needed — rock nodes are spawned with `RockId` attributes pre-set.

---

## 🚀 Launching Your MVP

```bash
# Step 1 – install tools
aftman install

# Step 2 – sync to Studio
rojo serve
# Then connect in Studio → run with F5 to test immediately

# Step 3 – publish
# File → Publish to Roblox in Studio
```

**Pre-launch checklist:**
- [ ] Create gamepasses/dev products on Creator Hub, update `assetId` in `GamepassConfig.luau`
- [ ] Add your Roblox `UserId` to `ADMIN_USER_IDS` in `EventService.luau`
- [ ] Review economy values in `EconomyConfig.luau` and `MiningConfig.luau`
- [ ] Set `DataStoreName` in `DataService.luau` if you want a clean slate

---

## 📝 License

MIT — see [LICENSE](LICENSE) for details.
