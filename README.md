# TMCoEdit
An Openplanet plugin that enables multiple people to edit the same Trackmania Map

This software consists of 2 components:

## The Plugin
This runs on your PC as an [Openplanet](https://openplanet.nl/) plugin. It checks every few seconds which blocks have been placed and deleted. It is also able to place blocks while you are editing a map. The collected data with the changed blocks and their locations is sent to

## The server
This program runs on the internet, where all people editing can reach it. It receives and stores the data from the plugin. Then it sends a response which includes the changes other people have made to the map. This allows the plugin to synchronize the blocks between all mappers connected to the same session (With a little bit of delay).
