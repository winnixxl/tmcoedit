**CAUTION**

This is a very early developement version. It can break your map or crash your game. Save your work frequently while editing maps and keep backups (for example by saving it under a different name).

**CAUTION**

# TMCoEdit
An Openplanet for Trackmania 2020 plugin that enables multiple players to edit the same map

This software consists of 2 components:

## The server
This program runs on the internet or local network, where all people editing can reach it. It receives and stores the data from the plugin. Then it sends a response which includes the changes other people have made to the map. This allows the plugin to synchronize the blocks between all mappers connected to the same session (With a little bit of delay).

## The plugin
This runs on your PC as an [Openplanet](https://openplanet.nl/) plugin. It checks every few seconds which blocks have been placed and deleted. It is also able to place blocks while you are editing a map. The collected data with the changed blocks and their locations is sent to the server via HTTP.

### In-game menu

- Player (read-only): randomly generated hexadecimal ID so the server can track which player placed which blocks
- Block Number (read-only): counts all added and removed blocks
- Server Address: e.g . http://localhost:8180 or http://coedit-server.my.domain
- Session: Players who enter the same session will be able to collaborate (also functions as the Password)
- Interval: Delay in seconds between requests to the server
- Log Level: 0 - only critical errors; 1 - all errors; 2 - all log messages
- Allow Ghost Blocks: if a new block overlaps with an old block place a ghost block instead of removing the old block
- Aggrssive Removal: Remove the Block even if it has an unexpected block name or direction

# Installation

## Server

1. install Python with the packages flask, flask-restful, sqlite3
2. run `python server/main.py`
3. make sure the firewall allows inbound connections (default port is 8180)

## Plugin

1. install Openplanet
2. copy `Plugin_CoEditor.as` to `C:\Users\<Your Username>\OpenplanetNext\Scripts\`
3. open the map editor in Trackmania 2020
4. in the Openplanet menu click "Scripts" and enter the server address and a **secret(!)** session
5. send the session to your friends, so you can build maps together

# TODO
- create ingame menu with its own proper window
- support for blocks placed in free mode
- support for items
- support for custom blocks and items
- HTTPS support
