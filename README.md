# TFM Proxy Loader

A custom loader for Transformice and other Atelier 801 games which forces the client to connect to a local proxy.

## Building

To build, you should use the [asconfig.json](https://github.com/friedkeenan/tfm-proxy-loader/blob/main/asconfig.json) file to compile the `TFMProxyLoader.swf` file. This can be done with [vscode-as3mxml](https://github.com/BowlerHatLLC/vscode-as3mxml) or [asconfigc](https://www.npmjs.com/package/asconfigc).

If you wish to save yourself the hassle, then there is also a pre-built SWF in the [releases](https://github.com/friedkeenan/tfm-proxy-loader/releases) of this repo.

## Usage

To use this loader, you need to load the `TFMProxyLoader.swf` file. If you're using the Steam version of Transformice, this means you should open the local files for the game and replace the contained `Transformice.swf` file with the `TFMProxyLoader.swf` one (renaming it to `Transformice.swf`).

Upon loading, there will be buttons for the following games:

- Transformice
- Dead Maze
- Bouboum
- Nekodancer
- Fortoresse

Clicking a button will load that game and make it connect to `localhost` on port `11801`. You should run a proxy listening there, for instance a proxy from [caseus](https://github.com/friedkeenan/caseus). The game will launch normally, and it will connect to the proxy as if connecting to the normal server.

Additionally, pressing the 'Enter' key will load the game which was last loaded, allowing you to circumvent any mouse presses.

## Dealing with Flash's Security Measures

If you run the loader in an AIR runtime, like the Steam version of Transformice does, then you can skip this section. Otherwise, there are additional security-related things to fuss about with.

When not running in an AIR runtime, the loader will require a policy file for the domain of the game being loaded. All games have this (for instance, Transformice's: https://www.transformice.com/crossdomain.xml), *except* for Fortoresse, causing it to fail to load. Additionally every game will request a socket policy file for `localhost:11801` (following the normal flow of trying port `843` first and then trying the destination port, `11801`).

If you're using the standalone projector and running the loader from a file however, you can disable all that behavior. You can place a file at the corresponding location for your platform:

- Windows: `%AppData%/Macromedia/Flash Player/#Security/FlashPlayerTrust/TFMProxyLoader.cfg`
- MacOS: `~/Library/Preferences/Macromedia/Flash Player/#Security/FlashPlayerTrust/TFMProxyLoader.cfg`
- Linux: `~/.macromedia/Flash_Player/#Security/FlashPlayerTrust/TFMProxyLoader.cfg`

The file's contents should be the path of the directory which contains the proxy loader, so for instance if the loader's path is `/path/to/TFMProxyLoader.swf`, then the contents of the config file at the above location should be `/path/to`.

This will allow Fortoresse to load and stop all the games from requesting a socket policy file. If you know any other way to accomplish this, please let me know.

## The Handshake Packet

The proxy loader has a different size than the various vanilla loaders do. This is of note, because the handshake packet includes the value of `stage.loaderInfo.bytes.length`, corresponding to the uncompressed size of the original loader SWF, and if the server receives an unexpected value for this field, then it will close the connection and the game will display an "Incorrect version" message. Therefore the proxy which the loader connects to should take care to replace this value with a valid size.

## Extension Packets

The loader sends certain custom packets which are not included in the vanilla protocol. These packets are called "extension" packets and have the following format:

- Their ID is `(255, 255)`. This seems to be safe from the vanilla protocol.
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
