# TFM Proxy Loader

A custom loader for the Transformice client which connects to a local proxy.

## Building

To build, you should use the [asconfig.json](https://github.com/friedkeenan/tfm-proxy-loader/blob/main/asconfig.json) file to compile the `TFMProxyLoader.swf` file. This can be done with [vscode-as3mxml](https://github.com/BowlerHatLLC/vscode-as3mxml) or [asconfigc](https://www.npmjs.com/package/asconfigc).

If you wish to save yourself the hassle, then there is also a pre-built SWF in the [releases](https://github.com/friedkeenan/tfm-proxy-loader/releases) of this repo.

## Usage

To use this loader, simply replace the normal SWF you use for the game with the `TFMProxyLoader.swf` file. If using the Steam version of Transformice, this means opening the local files for the game and replacing the contained `Transformice.swf` file with the `TFMProxyLoader.swf` one (renaming it to `Transformice.swf`).

By default, the game will try to connect to `localhost` on port `11801`, so you should run a proxy listening there, for instance a proxy from [caseus](https://github.com/friedkeenan/caseus). Then, you should just launch the game normally, and it will connect to the proxy as if connecting to the normal server. From there the proxy can do whatever it wants.

It is recommended to run the loader as an AIR application (which the Steam version of the game does), because otherwise the game will request a socket policy file for `localhost:11801` (following the normal flow of trying port `843` first and then trying the destination port, `11801`). If you know a way of disabling this behavior please let me know.

## Extension Packets

The loader sends certain custom packets which are not included in the vanilla protocol. These packets are called "extension" packets and have the following format:

- Their ID is `(255, 255)`. This seems to be safe from the game.
- The packet body contains a nested packet.
    - The data starts with a string (in Actionscript think `writeUTF`/`readUTF`), representing the ID of the nested packet.
    - The rest of the data is the packet body of the nested packet, marshaled according to the nested ID.

This is similar to how tribulle/community platform packets are used by the game.

The fingerprint of extension packets will always be `0` and should be ignored in order to not desync the fingerprints of vanilla packets.

## Packet Key Sources

The loader will send an extension packet containing the packet key sources to the proxy so that the proxy can decipher (and re-cipher) certain packets. This packet is sent before any other packets. It has the following format:

- Its ID is the string `"packet_key_sources"`.
- Its body is an array of unsigned bytes, read until the end of the data, each byte being a source number from the packet key sources.

## Auth Key

After sending the packet key sources, the loader will send an extension packet containing the "auth key" used for the login packet. It has the following format:

- Its ID is the string `"auth_key"`.
- Its body is a single int, corresponding to the value of the auth key.

## Main Server Info

The loader will also send an extension packet for the main server info, i.e. its address and ports. This packet is sent before the handshake packet. It has the following format:

- Its ID is the string `"main_server_info"`.
- Its body starts with a string for the address for which server the client would normally connect to.
- The rest of the body is an array of unsigned shorts, read until the end of the data, each short being a port that the client could've normally connected to.
