# BM System - Black Market / Underground Economy

BM System is a standalone FiveM black market resource built around a hidden dealer NPC, ox_target interaction, ox_lib menus, ox_inventory item handling, dynamic stock/pricing, player reputation, player-to-player trading, police detection, and optional dispatch alerts.

The dealer can rotate between hidden locations, appear only during configured hours, and show trust-based English dialogue based on each player's street cred.

## Dependencies

- ox_lib
- ox_target
- ox_inventory

Optional integrations:

- qbx_core for real job data when available
- ps-dispatch, cd_dispatch, or core_dispatch for dispatch alerts

## Installation

1. Place the resource folder in your server resources directory.

   Example:

   ```cfg
   resources/[standalone]/bm-system
   ```

2. Make sure the dependencies start before this resource.

   ```cfg
   ensure ox_lib
   ensure ox_target
   ensure ox_inventory
   ensure bm-system
   ```

3. Add the custom items used by this resource to `ox_inventory`.

   Required custom item names:

   ```txt
   weed_bag
   cocaine
   meth
   oxy
   stolen_phone
   stolen_jewelry
   stolen_laptop
   stolen_watch
   lockpick
   armor
   radio
   black_money
   money
   ```

   Weapon items such as `WEAPON_PISTOL`, `WEAPON_SMG`, `WEAPON_CARBINERIFLE`, `WEAPON_KNIFE`, and `WEAPON_BAT` must also be supported by your inventory setup.

4. Restart the server or run:

   ```cfg
   restart bm-system
   ```

5. Test the dealer from in-game with ox_target by walking near the active dealer location and selecting `Speak to Dealer`.

## Config Options

All main settings are inside `config.lua`.

### `Config.BlackMarket`

Controls dealer NPC behavior.

- `coords`: fallback fixed dealer location
- `locations`: random hidden dealer locations
- `npcModel`: dealer ped model
- `targetDistance`: ox_target interaction distance
- `serverValidationDistance`: server-side anti-cheat distance for buy/sell events
- `npc.alpha`: ped visibility
- `npc.scenario`: idle scenario used by the dealer
- `blip.enabled`: keep this `false` if the dealer should stay hidden

### `Config.DealerSchedule`

Controls when the dealer is available.

- `enabled`: enable or disable schedule checks
- `useServerTime`: use real server hour when `true`
- `checkInterval`: how often the server checks dealer state
- `rotationInterval`: how often the dealer moves while open
- `openHours`: allowed dealer hours
- `closedMessage`: message shown when dealer is unavailable
- `timeModifiers`: price and stock changes based on time windows

### `Config.Props`

Controls visual props used during dealer and trading interactions.

- `enabled`: enable or disable all prop visuals
- `loadTimeout`: max time to wait for a prop model
- `progress`: ox_lib progress bar settings during prop loading
- `shopCrate`: wooden crate shown near the dealer when the shop opens
- `purchase`: category-specific ground props during purchase animation
- `tradeBag`: duffle bag attached to the player's right hand during P2P trades

### `Config.DealerDialogue`

Controls the English trust dialogue shown inside the main dealer menu.

- `enabled`: enable or disable dealer dialogue
- `showInMainMenu`: show the dialogue as the first menu line
- `fallbackLine`: default dealer line
- `noStockLine`: line shown when there is no stock
- `levels`: dialogue lines unlocked by street cred level

### `Config.Items`

Defines black market items.

- `name`: ox_inventory item name
- `label`: display label
- `category`: `weapons`, `drugs`, `stolen`, or `contraband`
- `basePrice`, `minPrice`, `maxPrice`: pricing range
- `baseStock`, `minStock`, `maxStock`: stock range
- `requiredCred`: required street cred
- `priceVariance`: random price fluctuation amount

### `Config.Stock`

Controls stock resets and price updates.

- `resetInterval`: stock reset time in minutes
- `priceUpdateInterval`: price update time in minutes
- `demandMultiplier`: price increase when stock is low
- `supplyMultiplier`: price decrease when stock is high

### `Config.Reputation`

Controls player street cred.

- `maxCred`: maximum reputation
- `startingCred`: starting reputation
- `purchaseGain`: cred gained by category
- `tradeGain`: cred gained after successful trades
- `priceModifiers`: discount levels based on cred

Reputation is saved as JSON in `data/players`.

### `Config.Police`

Controls police detection during player trades.

- `alertRadius`: detection radius
- `checkInterval`: detection check speed
- `requireOnDuty`: require police to be on duty
- `policeJobs`: job names counted as police
- `policeJobTypes`: job types counted as police
- `messages`: TextUI and notification messages

### `Config.Dispatch`

Controls optional dispatch alerts.

- `enabled`: enable or disable dispatch
- `provider`: `auto`, `ps-dispatch`, `cd_dispatch`, `core_dispatch`, `custom`, or `none`
- `cooldown`: seconds between dispatch alerts
- `locationFuzzRadius`: sends a nearby area instead of exact dealer coords
- `jobs` and `jobTypes`: police recipients
- `alerts.purchase`: chance and message for purchases
- `alerts.trade`: chance and message for trades

### `Config.Disguise`

Controls fake job display near the dealer.

- `enabled`: enable or disable disguise
- `radius`: range around the dealer
- `graceDistance`: server-side tolerance
- `fakeJob`: fake job data shown through the export/statebag

### `Config.Trading`

Controls player-to-player trading.

- `maxDistance`: max distance between traders
- `distanceGrace`: server-side tolerance
- `cooldown`: cooldown after completed/cancelled trades
- `requestCooldown`: cooldown between outgoing requests
- `confirmTimeout`: confirmation timeout
- `maxItemsPerTrade`: max item entries in one trade
- `logFile`: trade log filename

## Features

- Hidden dealer NPC with ox_target interaction
- Random dealer locations
- Dealer schedule with night-time availability
- Time-based stock and price modifiers
- ox_lib context menus and notifications
- Dynamic pricing based on stock supply and demand
- Stock resets and price updates
- Street cred reputation system
- Reputation-based price discounts
- English dealer trust dialogue based on street cred
- Shop crate prop near the dealer when browsing stock
- Weapon briefcase and metal stash props during purchase animations
- Duffle bag hand prop during P2P trades with drop cleanup on completion
- Player-to-player trading with dual confirmation
- Trade cooldowns to prevent spam
- Server-side distance validation for purchases, sales, and trades
- Police job detection during trades
- Optional dispatch alerts for purchases and trades
- Fake job disguise state near the black market
- JSON persistence for player reputation and standalone job data
- Purchase, trade, stock, and exploit-attempt logging

## Commands

Server/admin commands:

```txt
bm_dealer_status
bm_dealer_rotate
blackmarket_setcred [playerId] [0-100]
blackmarket_setjob [playerId] [jobName]
```

In-game test/admin command:

```txt
bm_testdispatch purchase
bm_testdispatch trade
```

Player commands:

```txt
blackmarket
mycred
```

## Testing Checklist

- Confirm `ox_lib`, `ox_target`, and `ox_inventory` are started before `bm-system`.
- Confirm all custom items exist in ox_inventory.
- Use `bm_dealer_status` to check if the dealer is currently open.
- Temporarily disable `Config.DealerSchedule.enabled` if you want to test during daytime.
- Set dispatch alert chance to `100` and cooldown to `0` for dispatch testing.
- Test buying with both `money` and `black_money`.
- Test locked items with low street cred.
- Test player trading with two players near each other.
- Test remote exploit protection by triggering buy/trade events away from the dealer.

## Credits

Created for FiveM roleplay servers using the Overextended ecosystem.

Resource author: BLDR

Core dependencies:

- ox_lib by Overextended

- ox_target by Overextended
- ox_inventory by Overextended

Preview: https://r2.fivemanage.com/P7y9eTE8cCknS7gpxfED8/bm-system.mp4
Propr Preview: https://r2.fivemanage.com/P7y9eTE8cCknS7gpxfED8/bm-system_props.mp4
