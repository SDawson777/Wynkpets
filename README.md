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
    Services/
      DataService.luau        ← DataStore save/load with session lock + retries
      MiningService.luau      ← Rock hits, ore drops, auto-sell loop
      PetService.luau         ← Egg hatching, equip/unequip, auto-hatch loop
      ShopService.luau        ← Shop purchases, world unlocks, gamepass grants
      RebirthService.luau     ← Rebirth validation and stat reset
      QuestService.luau       ← Quest/achievement tracking + daily rewards
      TradeService.luau       ← P2P pet trading
      EventService.luau       ← Limited-time event framework + admin commands
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

## 🛠 Setup (Rojo Workflow)

1. Install [Rojo](https://rojo.space/) (VS Code extension + CLI)
2. Install [Roblox Studio](https://create.roblox.com/docs/studio/setting-up-roblox-studio)
3. Clone this repo and open the workspace folder
4. In a terminal: `rojo serve`
5. In Roblox Studio: connect via the Rojo plugin → **Connect**
6. Place rocks in the Workspace and tag them with a `RockId` attribute matching `MiningConfig.Rocks[].id`

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

## 🚀 Launching Your MVP

1. Publish the game to Roblox
2. Create gamepasses/dev products on the Creator Hub and update `assetId` values in `GamepassConfig.luau`
3. Build and publish rock models in Studio, setting `RockId` attributes to match `MiningConfig`
4. Set admin `UserIds` in `EventService.luau` → `ADMIN_USER_IDS`
5. Balance economy parameters in `EconomyConfig.luau` and `MiningConfig.luau`

---

## 📝 License

MIT — see [LICENSE](LICENSE) for details.
