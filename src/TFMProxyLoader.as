package {
    import flash.display.Sprite;
    import flash.display.Loader;
    import flash.net.URLLoader;
    import flash.system.LoaderContext;
    import flash.system.ApplicationDomain;
    import flash.events.Event;
    import flash.net.URLRequest;
    import flash.utils.describeType;
    import flash.display.DisplayObjectContainer;
    import flash.desktop.NativeApplication;
    import flash.net.Socket;
    import com.amanitadesign.steam.FRESteamWorks;
    import flash.utils.ByteArray;

    public class TFMProxyLoader extends Sprite {
        private static var PROXY_INFO: String = "localhost:11801";

        private var final_loader: Loader;

        private var connection_class_info: *;

        private var steamworks: FRESteamWorks;
        private var steam_okay: Boolean;

        public function TFMProxyLoader() {
            super();

            NativeApplication.nativeApplication.addEventListener(Event.EXITING, this.game_exiting);

            try {
                this.steamworks = new FRESteamWorks();
                this.steam_okay = this.steamworks.init();
            } catch (error: Error) {
                /* ... */
            }

            var loader: * = new URLLoader();
            loader.dataFormat = "binary";

            var ctx: * = new LoaderContext();
            ctx.allowCodeImport = true;
            ctx.applicationDomain = ApplicationDomain.currentDomain;

            loader.addEventListener(Event.COMPLETE, this.game_data_loaded);

            loader.load(new URLRequest("http://www.transformice.com/Transformice.swf?d=" + new Date().getTime()));
        }

        private function game_exiting(event: Event) : void {
            if (this.steamworks != null) {
                this.steamworks.dispose();
            }
        }

        private function game_data_loaded(event: Event) : void {
            this.final_loader = new Loader();
            this.final_loader.contentLoaderInfo.addEventListener(Event.COMPLETE, this.game_code_loaded);

            var ctx: * = new LoaderContext();
            ctx.allowCodeImport = true;

            this.addChild(this.final_loader);
            this.final_loader.loadBytes(URLLoader(event.currentTarget).data, ctx);
        }

        private function game_code_loaded(event: Event) : void {
            this.addEventListener(Event.ENTER_FRAME, this.init_steam_info);

            this.addEventListener(Event.ENTER_FRAME, this.get_connection_class_info);
        }

        private function init_steam_info(event: Event) : void {
            var game: * = (this.final_loader.content as DisplayObjectContainer).getChildAt(0) as Loader;

            if (game.numChildren == 0) {
                return;
            }

            this.removeEventListener(Event.ENTER_FRAME, this.init_steam_info);

            var document: * = game.getChildAt(0);

            try {
                document.x_proxySteam.x_initialisation(this.steamworks);
            } catch (error: Error) {
                /* ... */
            }
        }

        private static function get_socket_property(description: XML) : String {
            for each (var variable: * in description.elements("factory").elements("variable")) {
                if (variable.attribute("type") == "flash.net::Socket") {
                    return variable.attribute("name");
                }
            }

            return null;
        }

        private static function get_connection_instance_names(description: XML) : Array {
            /*
                NOTE: We need to care about both instances because
                we don't necessarily know which is the one for the
                main connection and which for the satellite connection.
            */

            var connection_name: String = description.attribute("name");

            var names: * = new Array();
            for each (var variable: * in description.elements("variable")) {
                if (variable.attribute("type") == connection_name) {
                    names.push(variable.attribute("name"));
                }
            }

            return names;
        }

        private static function get_serverbound_packet_class_name(description: XML) : String {
            for each (var parameter: * in description.elements("factory").elements("constructor").elements("parameter")) {
                if (parameter.attribute("index") == 3) {
                    return parameter.attribute("type");
                }
            }

            return null;
        }

        private function get_serverbound_packet_info(klass: Class) : * {
            var buffer_prop_name: String = null;

            for each (var variable: * in describeType(klass).elements("factory").elements("variable")) {
                if (variable.attribute("type") == "flash.utils::ByteArray") {
                    buffer_prop_name = variable.attribute("name");

                    break;
                }
            }

            return {
                klass: klass,
                buffer_prop_name: buffer_prop_name
            }
        }

        private static function get_send_packet_method_name(description: XML, serverbound_name: String) : String {
            for each (var method: * in description.elements("factory").elements("method")) {
                var parameters: * = method.elements("parameter");
                if (parameters.length() != 1) {
                    continue;
                }

                for each (var parameter: * in parameters) {
                    if (parameter.attribute("type") == serverbound_name) {
                        return method.attribute("name");
                    }
                }
            }

            return null;
        }

        private function get_connection_class_info(event: Event) : void {
            var game: * = (this.final_loader.content as DisplayObjectContainer).getChildAt(0) as Loader;

            if (game.numChildren == 0) {
                return;
            }

            this.removeEventListener(Event.ENTER_FRAME, this.get_connection_class_info);

            var domain: * = game.contentLoaderInfo.applicationDomain;
            for each(var class_name: String in domain.getQualifiedDefinitionNames()) {
                /*
                    The connection class is the only one that only
                    inherits from 'Object', doesn't implement any
                    interface, and has a non-static 'Socket' property.
                */

                var klass: * = domain.getDefinition(class_name);
                if (klass.constructor != Class) {
                    continue;
                }

                var description: * = describeType(klass);

                if (description.elements("factory").elements("extendsClass").length() != 1) {
                    continue;
                }

                if (description.elements("factory").elements("implementsInterface").length() != 0) {
                    continue;
                }

                var socket_prop_name: String = get_socket_property(description);
                if (socket_prop_name == null) {
                    continue;
                }

                var instance_names: * = get_connection_instance_names(description);

                this.connection_class_info = {
                    klass: klass,
                    socket_prop_name: socket_prop_name,
                    instance_names: instance_names
                };

                this.addEventListener(Event.ENTER_FRAME, this.try_replace_connection);

                return;
            }
        }

        private function get_packet_key_sources() : Array {
            var game:     * = (this.final_loader.content as DisplayObjectContainer).getChildAt(0) as Loader;
            var document: * = game.getChildAt(0);

            var description: * = describeType(document);
            for each (var variable: * in description.elements("variable")) {
                /*
                    The key sources array is defined as an
                    'Object' but in fact holds an 'Array'.
                */

                if (variable.attribute("type") != "Object") {
                    continue;
                }

                var name: String = variable.attribute("name");

                var prop: * = document[name];
                if (prop == null) {
                    continue;
                }

                if (prop.constructor != Array) {
                    continue;
                }

                return prop;
            }

            return null;
        }

        private function try_replace_connection(event: Event) : void {
            var klass:            * = this.connection_class_info.klass;
            var socket_prop_name: * = this.connection_class_info.socket_prop_name;

            var closed_socket: * = false;
            for each (var name: * in this.connection_class_info.instance_names) {
                var instance: * = klass[name];
                if (instance == null) {
                    return;
                }

                if (!closed_socket) {
                    instance[socket_prop_name].close();

                    instance.reset();

                    closed_socket = true;
                }

                klass[name] = null;
            }

            var main_connection: * = new klass(PROXY_INFO, false);
            var socket: Socket   = main_connection[socket_prop_name];

            socket.addEventListener(Event.CONNECT, function (event: Event) : void {
                /* Send over the packet key sources to the proxy after the handshake packet. */

                var packet_key_sources: * = get_packet_key_sources();

                var packet_data: * = new ByteArray();

                /* Parent ID. */
                packet_data.writeByte(0xFF);
                packet_data.writeByte(0xFF);

                /* Extension ID. */
                packet_data.writeUTF("packet_key_sources");

                for each (var num: * in packet_key_sources) {
                    /*
                        NOTE: I've never seen a source number exceed the unsigned
                        byte range. Also even though we use `writeByte`, it will
                        correctly write unsigned bytes as well, and consumers of
                        this packet should interpret them as unsigned.
                    */
                    packet_data.writeByte(num);
                }

                var external_data: * = new ByteArray();

                /* Write packet length. */
                var length: * = int(packet_data.length);
                while (true) {
                    var to_write: * = (length & 0x7F);

                    length >>>= 7;
                    if (length != 0) {
                        to_write |= 0x80;
                    }

                    external_data.writeByte(to_write);

                    if (length == 0) {
                        break;
                    }
                }

                /*
                    Write dummy fingerprint.

                    NOTE: We can't just use the normal send
                    packet method because then the fingerprint
                    will get desynced and the server will
                    kick us. This could also be managed by
                    sending this packet before the handshake packet,
                    but because of the game registering their
                    connect listener with the maximum priority,
                    we would need to do stuff that's worse than
                    this to do that. This is the cleanest option.
                */
                external_data.writeByte(0);

                socket.writeBytes(external_data);
                socket.writeBytes(packet_data);
                socket.flush();
            });

            this.removeEventListener(Event.ENTER_FRAME, this.try_replace_connection);
        }
    }
}