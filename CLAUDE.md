# Color Clash: Rising Tides

## What This Game Is

A multiplayer Roblox elimination game. Players stand on individual pillars above an ocean. Each round, a random color flashes on a giant screen for 5 seconds. Players must recreate the color from memory using Hue, Saturation, and Brightness sliders. Their score (0–10) determines how much their pillar grows. The water rises every round. If the water reaches your pillar top, you're eliminated. Last player standing wins.

Think "Fall Guys meets a color memory challenge." Fast rounds, rising tension, satisfying skill expression, huge spectator energy.

## Game Loop

1. Lobby → players join, see arena, chat
2. Countdown → pillars spawn in a circle, players teleport on top
3. Round starts → color appears on giant screen for 5 seconds
4. Memory phase → color disappears, HSB sliders appear on screen
5. Players submit their guess within 15 seconds
6. Scoring → pillar grows based on accuracy (0–10 score × 2 studs)
7. Water rises → dramatic tween, tension builds
8. Elimination check → any pillar tops below water = player eliminated
9. Repeat from step 3 until 1 player remains
10. Winner celebration → confetti, announcement, rewards
11. Reset → new lobby, new game

## Tech Stack

- **Engine**: Roblox Studio
- **Language**: Luau (--!strict everywhere)
- **Project Management**: Rojo v7 (file-based workflow)
- **Version Control**: Git + GitHub
- **Editor**: VS Code with Roblox LSP + Selene

## Project Structure (Rojo)

```
src/
  server/                     → ServerScriptService
    GameManager.server.luau   — main game loop, round logic, water control
    PillarManager.luau        — pillar spawning, raising, elimination
    DataManager.luau          — player data persistence (coins, wins, skins)
    ShopManager.luau          — purchase validation, gamepass checks
  client/                     → StarterPlayer/StarterPlayerScripts
    UIController.client.luau  — entry point, initializes all UI screens
    ui/
      Components/             — reusable UI pieces (Slider, Button, Card, Toast, ProgressBar)
      Screens/                — full screens (HUD, Shop, Settings, Results, Lobby, GameOver)
      Util/                   — Theme.luau, UIHelper.luau, Animate.luau
  shared/                     → ReplicatedStorage
    GameConfig.luau           — all tunable game values (both sides read this)
    Types.luau                — shared type definitions
```

## Build & Test Commands

- `rojo serve` — start Rojo file sync
- Open `game.rbxl` in Studio → connect Rojo plugin
- Set `GameConfig.MIN_PLAYERS = 1` for solo testing
- F5 to playtest in Studio
- Test tab → Start (2+ players) for multiplayer testing

## Arena (Built in Studio, NOT in Rojo)

These are 3D objects managed in the .rbxl file:

- `Workspace/Arena/WaterPart` — the rising ocean (Material: Water, Anchored, CanCollide off)
- `Workspace/Arena/ColorScreen` — giant billboard with SurfaceGui showing target color
- `Workspace/Arena/Pillars/` — folder where pillar Parts spawn at runtime
- `Workspace/Arena/Lobby/` — pre-game area with spawn points

## Key Architecture Rules

- Server is authoritative for ALL game state: scores, pillar heights, water level, eliminations, currency, inventory
- Client only handles UI rendering, slider input, and visual effects
- Every RemoteEvent payload from client MUST be validated on server: typeof() checks, range clamping, rate limiting
- All UI is built from code in ModuleScripts — no manual Studio GUI building
- Use a shared Theme.luau for all colors, fonts, sizes, corner radii, and TweenInfos
- GameConfig.luau is the single source of truth for balance numbers — never hardcode values elsewhere
- RemoteEvents are created by the server on startup and placed in ReplicatedStorage/Events
- Use task.wait(), task.spawn(), task.delay() — NEVER the deprecated wait(), spawn(), delay()
- Wrap all DataStore calls in pcall() with retry logic
- Clean up player data and connections in Players.PlayerRemoving to prevent memory leaks

## Feature Roadmap & Priorities

### HIGH PRIORITY (build these first)

- **Lobby system for dead/waiting players** — eliminated players and those waiting for next game need a space to hang out, spectate, and interact
- **Better UI** — the current UI needs a full polish pass. Smooth animations, premium feel, responsive on mobile and desktop
- **Real-time color visibility** — players can see what color OTHER players are mixing in real time (adds pressure, strategy, and entertainment)
- **More nuanced scoring** — go beyond simple HSV distance. Factor in difficulty of the color, closeness in hue vs sat vs brightness with smarter weighting
- **Music system** — background music, round tension music, elimination stingers, winner fanfare
- **In-game currency** — custom coin/token system for earning and spending on cosmetics
- **In-game leaderboard screen** — live scoreboard during gameplay showing 1st place, 2nd place, etc. with current cumulative scores, pillar heights, and who's closest to drowning
- **Store/Shop** — full in-game shop for purchasing cosmetics with coins and Robux
- **All-time leaderboards** — persistent leaderboards with multiple categories: most wins, highest win ratio, longest win streak, highest single-round score, most games played
- **Server browser** — ability to join friends, browse servers, and hop between them in-game (like Death Ball's server system)
- **Better assets/graphics/scenery** — upgrade the arena visuals, water effects, skybox, lighting, pillar materials. Make it look like a real game not a prototype

### LOW PRIORITY (build after core is solid)

- **Ranked mode** — competitive matchmaking with ELO/rank tiers
- **2v2 / 3v3 mode** — team-based color matching where team scores combine. Teams share a pillar or adjacent pillars
- **Timing scoring** — faster submissions get a score multiplier. Submit in 3 seconds = 1.5x, 5 seconds = 1.2x, etc. Rewards confidence
- **Daily rewards** — login streak calendar, escalating rewards for consecutive days
- **Friend join notifications** — push notification when a friend joins, with invite button
- **Lobby activities** — obby course, mini-games, random fun stuff for players waiting between games so they don't leave
- **Trading system** — player-to-player trading of cosmetic items

### MONETIZATION (Micro-transactions)

All purchases are cosmetic or convenience. NEVER pay-to-win on core scoring/pillar mechanics.

**Cosmetic Items (coins or Robux):**
- Pillar skins — visual pillar themes (Lava, Ice, Neon, Galaxy, etc.)
- Emotes — expressions and dances usable in lobby and on pillar
- Winning animations — custom celebration when you win a game
- Auras — persistent particle effects around your character/pillar
- Slider skins — custom slider bar and knob appearances

**Packs (paid and unpaid):**
- Free packs earned through gameplay milestones
- Premium Robux packs with guaranteed rare cosmetics
- Seasonal/limited-time packs that rotate

**Power Items (Robux purchases, NOT pay-to-win on scoring but add chaos):**
- **Save Yourself** — gain an extra life if you get eliminated (1 per game max)
- **Slider Lock** — lock another player's sliders for a few seconds during guessing phase
- **Screen Distraction** — throw a brainrot meme/video overlay on another player's screen temporarily
- **Sound Distraction** — blast annoying brainrot audio at another player temporarily
- **"Need More Blocks?" popup** — when a player is close to drowning, show a Robux prompt to instantly raise their pillar. Predatory but hilarious and optional

**Engagement & Spending Incentives:**
- **VIP Award System** — tiered rewards for VIP gamepass holders (exclusive skins, early access to new items)
- **Roblox Spent Awards** — milestone rewards based on total Robux spent (bronze/silver/gold/diamond spender tiers with exclusive items)
- **Like & Join Incentives** — reward coins for liking the game, joining the Roblox group, following socials. "Join our group for 50 free coins!" popup on first play

### Monetization Rules for Development

- Core scoring and pillar growth are ALWAYS purely skill-based — no amount of money changes your score
- Power items (slider lock, distractions) are chaotic and fun, not dominant — they should make everyone laugh, not feel unfair
- The "Need More Blocks?" popup is deliberately meme-y and self-aware, not sneaky
- Free coin earn rate should feel rewarding but slow enough that buying coins feels worth it
- Always show cosmetic previews before purchase — players need to see how cool they'll look
- Limited-time items create urgency — rotate weekly, bring back seasonally
- Price anchoring: always highlight "best value" packs in the shop

## Player Data Schema (DataStore)

```lua
PlayerData = {
    -- Currency
    coins = 0,

    -- Stats
    totalWins = 0,
    totalGames = 0,
    bestScore = 0,
    currentStreak = 0,
    bestStreak = 0,
    totalRoundsPlayed = 0,
    totalPerfectScores = 0,

    -- Cosmetics Owned (lists of item IDs)
    ownedPillarSkins = {},
    ownedEmotes = {},
    ownedAuras = {},
    ownedWinAnimations = {},
    ownedSliderSkins = {},

    -- Cosmetics Equipped
    equippedPillarSkin = "default",
    equippedEmote = "none",
    equippedAura = "none",
    equippedWinAnimation = "default",
    equippedSliderSkin = "default",

    -- Power Items (consumables)
    extraLifeTokens = 0,
    sliderLockTokens = 0,
    screenDistractionTokens = 0,
    soundDistractionTokens = 0,

    -- Engagement
    dailyLoginDate = "",
    dailyLoginStreak = 0,
    dailyChallenges = {},
    totalRobuxSpent = 0,         -- for spending tier rewards
    hasLikedGame = false,
    hasJoinedGroup = false,

    -- Settings
    musicEnabled = true,
    sfxEnabled = true,
}
```

## Growth Strategy

- **Thumbnail & Icon**: Bright, colorful, shows pillars + water + dramatic elimination moment. Must pop in search results.
- **Game Title**: "Color Clash: Rising Tides" — clear, searchable, communicates the mechanic.
- **Description**: Lead with "Can you remember colors under pressure?" Hook the curiosity.
- **Social Features**: Server browser like Death Ball. Join friends easily. Party system.
- **YouTube/TikTok bait**: The distraction items (brainrot memes, audio) are inherently clippable. Players WILL record and post slider locks and "Need More Blocks?" moments. The chaos items are marketing.
- **Spectator energy**: Real-time color visibility means watching others guess is entertaining. Eliminated players stay engaged spectating.
- **Roblox Algorithm**: Optimize for session time and return rate. Short rounds (2-3 min per game) encourage "one more game." Lobby activities prevent players from leaving between games.
- **Community**: Roblox group with free coin reward for joining. Use group wall for update announcements.
- **Like incentive**: Reward coins for liking the game. Popup on first play: "Like for 25 free coins!"

## Difficulty Scaling (keeps games exciting)

- Rounds 1-3: Memorize time = 5 seconds (easy warmup, nobody eliminated early usually)
- Rounds 4-6: Memorize time = 4 seconds, water rises faster
- Rounds 7-9: Memorize time = 3 seconds, colors become more subtle (closer hues)
- Round 10+: Memorize time = 2 seconds, very similar colors, max pressure

## Visual Polish Priorities

1. Water looks gorgeous — reflections, foam, rising animation feels dramatic
2. Pillar rising animation — satisfying tween with a slight bounce at the top
3. Elimination splash — big dramatic water splash VFX when a pillar goes under
4. Winner celebration — camera zoom, confetti, gold particles, name on the big screen
5. UI feels premium — smooth animations, no janky transitions, everything has hover/press states
6. Color display screen — big, clean, the color is unmistakable during memorize phase
7. Slider interaction — buttery smooth dragging, live color preview updates instantly

## Current Development Phase

Phase 1: Core gameplay loop — pillars, sliders, scoring, water rising, elimination, basic lobby
Phase 2: UI overhaul — premium feel, animations, mobile-responsive, live leaderboard during games
Phase 3: Real-time color visibility (see other players mixing), nuanced scoring system, timing multiplier
Phase 4: Currency system, shop/store, pillar skins, emotes, auras, winning animations
Phase 5: Music system, sound design, better arena assets/graphics/scenery/skybox
Phase 6: Power items (slider lock, distractions, save yourself, "Need More Blocks?")
Phase 7: All-time leaderboards, server browser, friend join system
Phase 8: Daily rewards, lobby activities (obby, mini-games), trading system
Phase 9: Ranked mode, 2v2/3v3 team mode
Phase 10: Polish, thumbnails, marketing, like/join incentives, VIP tiers, spending awards, launch

## What Claude Should Always Do

- Write production-quality code — no placeholders, no shortcuts, no "add your logic here"
- Think about edge cases: what if a player leaves mid-round? What if they rejoin? What if they use a power item on a disconnected player?
- Consider mobile players: touch-friendly UI, responsive sizing
- Optimize for performance: cache references, minimize Instance creation during gameplay
- The chaos items (distractions, slider lock) should be FUNNY and meme-worthy, not tilting. They're content creation fuel.
- Make monetization feel natural, not predatory — the "Need More Blocks?" popup should be self-aware and humorous
- Every new feature should ask: "Does this make the game more fun?" and "Does this make players want to come back tomorrow?" and "Will someone clip this for TikTok?"
- When building the store/shop, always show item previews and make the UI feel premium
- Leaderboards and stats should make players feel competitive — always show how close they are to the next rank