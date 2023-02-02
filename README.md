# TFM Proxy Loader

A custom loader for the Transformice client which connects to a local proxy.

## Building

To build, you should use the [asconfig.json](https://github.com/friedkeenan/tfm-proxy-loader/blob/main/asconfig.json) file to compile the `TFMProxyLoader.swf` file. This can be done with [vscode-as3mxml](https://github.com/BowlerHatLLC/vscode-as3mxml) or [asconfigc](https://www.npmjs.com/package/asconfigc).

By default, you must have an `.swc` file of [FRESteamWorks](https://github.com/Ventero/FRESteamWorks) in the `lib` folder in order to compile. This is needed so that the loader can initialize the Steam info that Transformice uses. If you wish to forgo this Steam info initialization, you may build without it by changing the value of the `CONFIG::steam` define to `false`.

If you wish to save yourself the hassle, then there is also a pre-built SWF (with Steam enabled) in the [releases](https://github.com/friedkeenan/tfm-proxy-loader/releases) of this repo.

## Usage

To use this loader, simply open the local files for the Steam version of the game and replace the contained `Transformice.swf` with the `TFMProxyLoader.swf` (renaming it to `Transformice.swf`). By default, the game will try to connect to `localhost` on port `11801`, so you should run a proxy listening there, for instance a proxy from [caseus](https://github.com/friedkeenan/caseus). Then, you should just launch the game normally, and it will connect to the proxy as if connecting to the normal server. From there the proxy can do whatever it wants.

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

## Main Server Info

The loader will also send an extension packet for the main server info, i.e. its address and ports. This packet is sent before the handshake packet. It has the following format:

- Its ID is the string `"main_server_info"`.
- Its body starts with a string for the address for which server the client would normally connect to.
- The rest of the body is an array of unsigned shorts, read until the end of the data, each short being a port the client could've normally connected to.
    - These ports unfortunately will not include the port that the client actually did try to connect to, as the client does not keep track of it. Thus proxies should be able to handle when they receive *no* ports, such as having a list of fallback ports. This could happen if for whatever reason the game would only try to connect to one port.