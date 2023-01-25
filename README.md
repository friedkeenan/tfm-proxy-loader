# TFM Proxy Loader

A custom loader for the Transformice client which connects to a local proxy.

## Building

To build, you should use the [asconfig.json](https://github.com/friedkeenan/tfm-proxy-loader/blob/main/asconfig.json) file to compile the `TFMProxyLoader.swf` file. This can be done with [vscode-as3mxml](https://github.com/BowlerHatLLC/vscode-as3mxml) or [asconfigc](https://www.npmjs.com/package/asconfigc).

You must have an `.swc` file of [FRESteamWorks](https://github.com/Ventero/FRESteamWorks) in a folder named `lib` in order to compile. This is needed so that the loader can initialize the Steam info that Transformice uses.

If you wish to save yourself the hassle, then there is also a pre-built SWF in the [releases](https://github.com/friedkeenan/tfm-proxy-loader/releases) of this repo.

## Usage

To use this loader, simply open the local files for the Steam version of the game and replace the contained `Transformice.swf` with the `TFMProxyLoader.swf` (renaming it to `Transformice.swf`). By default, the game will try to connect to `localhost` on port `11801`, so you should run a proxy listening there, for instance a proxy from [caseus](https://github.com/friedkeenan/caseus). Then, you should just launch the game normally, and it will connect to the proxy as if connecting to the normal server. From there the proxy can do whatever it wants.

## Packet Key Sources

The loader will send a special packet containing the packet key sources to the proxy so that the proxy can decipher (and re-cipher) certain packets. This packet is sent after the handshake packet; I could not reasonably have it sent before the handshake packet, but it should be fine since the handshake packet is not ciphered. The sent packet is an "extension packet", a custom packet not found in the vanilla protocol. These packets have the following format:

- Their ID is `(255, 255)`. This seems to be safe from the game.
- The packet body contains a nested packet.
    - The data starts with a string (in Actionscript think `writeUTF`/`readUTF`), representing the ID of the nested packet.
    - The rest of the data is the packet body of the nested packet, marshaled according to the nested ID.

This is similar to how tribulle/community platform packets are used by the game.

Therefore, the packet containing the packet key sources will look like such:

- Its ID will be `(255, 255)`.
- Its fingerprint will be `0`. This is done to not desync the fingerprints of vanilla packets.
- The packet body will start with a string whose value is `"packet_key_sources"`, the ID of the packet key sources extension packet.
- The rest of the data is an array of unsigned bytes, read until the end of the data, each byte being a source number from the packet key sources.