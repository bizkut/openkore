# aiPlayer - AI-Driven Autonomous Leveling for OpenKore

`aiPlayer` is a revolutionary plugin for OpenKore that uses Large Language Models (LLMs) to make strategic, human-like decisions in Ragnarok Online. Unlike traditional bot scripts that follow rigid logic, `aiPlayer` can adapt to new situations, manage resources intelligently, and pursue long-term goals like autonomous leveling.

## 🚀 Key Features

*   **LLM-Powered Intelligence**: Uses models like **Gemini 3 Flash** via OpenRouter for high-level decision-making.
*   **Autonomous Leveling**: Strategic planning for hunting monsters, choosing leveling zones, and prioritizing tasks.
*   **Intelligent Resource Management**: Automatically decides when to restock, use storage, or sell junk items based on weight and supply levels.
*   **Smart Quest Handling**: Identifies quest objectives and prioritizes NPC interactions.
*   **Hybrid AI Logic**: Routine tasks (healing, basic combat, looting) are handled internally by OpenKore to save API costs, while the LLM is called for complex strategic shifts.
*   **Comprehensive Toolset**: 15 custom tools for map navigation, Kafra services, combat strategy, and more.

## 🛠️ Installation & Setup

### 1. Plugin Installation
Copy the `aiPlayer` folder into your OpenKore `plugins` directory.

### 2. XKore Setup (for Landverse/Modern Servers)
To bypass modern anti-cheats (like Gepard Shield 3.0 on Landverse), follow these steps:
1.  Set `XKore 1` in your `control/config.txt`.
2.  Use the provided `NetRedirect.dll` (renamed as instructed by the community for your specific server).
3.  Ensure your `servers.txt` has the correct Landverse/uaRO configuration.

### 3. Configuration
Rename `aiPlayer.txt` to `config.txt` (or copy its contents into your main `control/config.txt`).
**Essential Settings:**
```text
aiPlayer_enabled 1
aiPlayer_apiKey your_openrouter_api_key_here
aiPlayer_model google/gemini-3-flash-preview
aiPlayer_apiUrl https://openrouter.ai/api/v1/chat/completions
```

## 🎮 Available AI Actions (Tools)

The LLM can trigger 15 distinct actions:
1.  `attack_monster`: Engage a specific target.
2.  `move_to`: Navigate within a map.
3.  `go_to_map`: Use world-map navigation.
4.  `use_skill`: Strategic skill usage.
5.  `talk_to_npc`: Interact with quests/shops.
6.  `buy_items` / `sell_items`: Manage supplies.
7.  `use_storage`: Deposit loot.
8.  `use_kafra`: Teleport or access storage services.
9.  `change_leveling_zone`: Find more efficient hunting grounds.
10. ...and more!

## 📜 Console Commands

*   `aiplayer on/off`: Toggle the plugin.
*   `aiplayer status`: View current AI state and model info.
*   `aiplayer decide`: Force an immediate LLM strategic review.

## 🧪 Requirements

*   **OpenKore**: Latest master branch recommended.
*   **API Key**: An [OpenRouter](https://openrouter.ai/) account with credits (Gemini 3 Flash is very cost-effective).

---
*Created with love for the OpenKore community.*
