# muhaddil_aidoctor

An AI Doctor/Ambulance script for FiveM that provides medical assistance when no EMS are available.

<!-- > [!IMPORTANT]
> This is an old script I made a long time ago. It doesn't feature a localization system (locales) or fancy modern code structures, but it is fully functional and works as intended. -->

## 🚑 Features

- **AI Paramedic & Ambulance**: Spawns an AI-controlled ambulance that drives to your location.
- **Medical Treatment**: The paramedic performs a CPR animation and stabilizes you on-site.
- **Hospital Transport**: Once stabilized, you are taken to the nearest hospital for full recovery.
- **Framework Support**: Exclusively designed for **Qbox (`qbx_core`)**.
- **Configurable**: Easily adjust the service price, EMS limit, driving speed, and hospital locations.
- **Integration**: Uses `ox_lib` for progress bars and notifications (optional).

## 📋 Requirements

- [ox_lib](https://github.com/CommunityOx/ox_lib)

- [qbx_core](https://github.com/Qbox-project/qbx_core)
- [oxmysql](https://github.com/CommunityOx/oxmysql)

## 🚀 Installation

1. Download the resource.
2. Extract it into your `resources` folder.
3. Add `ensure muhaddil_aidoctor` to your `server.cfg`.
4. Configure the settings in `config.lua` to match your server's needs.

## 🎮 Usage

When a player is dead or in a "last stand" state, they can use the following command:

```bash
/aidoctor
```

### Conditions:

- The player must be dead.
- The number of online EMS must be below the limit defined in `Config.EMS`.
- The player must have enough money to pay for the service (`Config.Price`).

## ⚙️ Configuration

You can customize the script in `config.lua`:

Config.FrameWork = "qbx"           -- "qbx"
Config.UseOXNotifications = true    -- Use ox_lib notifications
Config.EMS = 2                      -- Max EMS online to allow AI service
Config.Price = 2000                 -- Price of the service
Config.DriveSpeedLevel = 55.0       -- Speed of the AI ambulance
```

## 🛠️ Exports

The script provides some exports for integration with other resources:

- `exports['muhaddil_aidoctor']:CallAIDoctor()`: Triggers the AI doctor service.
- `exports['muhaddil_aidoctor']:IsServiceActive()`: Returns if a service is currently in progress.
- `exports['muhaddil_aidoctor']:CancelService()`: Cancels the current service and cleans up entities.

---
