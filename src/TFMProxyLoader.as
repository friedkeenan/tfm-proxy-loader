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
    import flash.net.Socket;
    import flash.utils.ByteArray;

    /*
        NOTE: We always import 'NativeApplication'
        even though it is only available for AIR
        applications because it actually only would
        cause an issue if it gets *used* on non-AIR
        applications.
    */
    import flash.desktop.NativeApplication;
    import flash.system.Capabilities;
    import flash.events.KeyboardEvent;
    import flash.net.SharedObject;
    import flash.system.Security;

    public class TFMProxyLoader extends Sprite {
        private static const BUTTON_PADDING: * = 30;

        private static var PROXY_INFO:      String = "localhost:11801";
        private static var POLICY_FILE_URL: String = "xmlsocket://localhost:10801"

        private var final_loader: Loader;

        private var logging_class_info: *;
        private var connection_class_info: *;

        /* NOTE: Only used for Transformice. */
        private static const SOCKET_KEY_NAME: String = "posSocket";
        private var socket_dict_name: String = null;

        private var main_connection: *;
        private var main_socket: Socket;

        private var main_address: String;
        private var main_ports:   Array = new Array();

        private var steamworks: Object = null;
        private var steam_okay: Boolean;

        private var is_transformice: Boolean = false;

        public function TFMProxyLoader() {
            super();

            Security.loadPolicyFile(POLICY_FILE_URL);

            this.setup_buttons();

            this.stage.addEventListener(KeyboardEvent.KEY_DOWN, this.load_last_game_url);
        }

        public function shared_data() : SharedObject {
            return SharedObject.getLocal("TFMProxyLoader");
        }

        private function load_last_game_url(event: KeyboardEvent) : void {
            /* Ignore key presses that aren't 'Enter'. */
            if (event.keyCode != 13) {
                return;
            }

            var shared: * = this.shared_data();

            if (shared.data.last_game_url != null) {
                this.load_game(shared.data.last_game_url);
            }
        }

        private function setup_buttons() : void {
            var transformice: * = new GameButton(this, "Transformice", "http://www.transformice.com/Transformice.swf", 0, 75, 0x6A7495);

            var deadmaze:   * = new GameButton(this, "Dead Maze",  "http://www.deadmaze.com/alpha/deadmeat.swf", transformice.width, 75, 0x000000);
            var bouboum:    * = new GameButton(this, "Bouboum",    "http://www.bouboum.com/Transformice.swf",    transformice.width, 75, 0x615F44);
            var nekodancer: * = new GameButton(this, "Nekodancer", "http://www.nekodancer.com/Transformice.swf", transformice.width, 75, 0x048895);

            var fortoresse: * = new GameButton(
                this,
                "Fortoresse",
                "http://data.atelier801.com/x_forteresse/Transformice.swf",
                transformice.width,
                75,
                0xB7B7B7
            );

            this.addChild(transformice);
            this.addChild(deadmaze);
            this.addChild(bouboum);
            this.addChild(nekodancer);
            this.addChild(fortoresse);

            transformice.x = (this.stage.stageWidth  - transformice.width)  / 2;
            transformice.y = (this.stage.stageHeight - transformice.height) / 2;

            deadmaze.x = BUTTON_PADDING;
            deadmaze.y = BUTTON_PADDING;

            bouboum.x = this.stage.stageWidth - bouboum.width - BUTTON_PADDING;
            bouboum.y = BUTTON_PADDING;

            nekodancer.x = BUTTON_PADDING;
            nekodancer.y = this.stage.stageHeight - nekodancer.height - BUTTON_PADDING;

            fortoresse.x = this.stage.stageWidth - fortoresse.width - BUTTON_PADDING;
            fortoresse.y = this.stage.stageHeight - fortoresse.height - BUTTON_PADDING;
        }

        private function remove_children() : void {
            while (this.numChildren > 0) {
                this.removeChildAt(0);
            }
        }

        private function remove_gui() : void {
            this.stage.removeEventListener(KeyboardEvent.KEY_DOWN, this.load_last_game_url);

            this.remove_children();
        }

        public function load_game(url: String) : void {
            this.remove_gui();

            /*
                This is hacky and I don't like it but more
                elegant solutions aren't worth the effort.
            */
            this.is_transformice = url.indexOf("transformice.com") != -1;

            var steamworks_class: Class = null;
            try {
                /*
                    The Steam version of the game uses the
                    'FRESteamWorks' library to handle Steam
                    integration. We do a runtime check to
                    detect whether it is available to us so
                    that we can use the same loader for both
                    Steam and non-Steam environments.
                */
                steamworks_class = ApplicationDomain.currentDomain.getDefinition("com.amanitadesign.steam::FRESteamWorks") as Class;
            } catch (error: ReferenceError) {
                /* ... */
            }

            if (steamworks_class != null) {
                NativeApplication.nativeApplication.addEventListener(Event.EXITING, this.cleanup_steam);

                try {
                    this.steamworks = new steamworks_class();
                    this.steam_okay = this.steamworks.init();
                } catch (error: Error) {
                    /* ... */
                }
            }

            var loader: * = new URLLoader();
            loader.dataFormat = "binary";

            loader.addEventListener(Event.COMPLETE, this.game_data_loaded);

            loader.load(new URLRequest(url));
        }

        private function cleanup_steam(event: Event) : void {
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
            if (this.steamworks != null) {
                this.addEventListener(Event.ENTER_FRAME, this.init_steam_info);
            }

            this.addEventListener(Event.ENTER_FRAME, this.get_logging_class_info);
            this.addEventListener(Event.ENTER_FRAME, this.get_connection_class_info);
        }

        private function game_domain() : ApplicationDomain {
            var game: * = (this.final_loader.content as DisplayObjectContainer).getChildAt(0) as Loader;

            return game.contentLoaderInfo.applicationDomain;
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

        private static function is_logging_class(klass: Class, description: XML) : Boolean {
            /*
                The logging class is the only class which inherits
                from 'Sprite' and has a static string variable with
                certain font names.
            */

            var extending: * = description.elements("factory").elements("extendsClass");
            if (extending.length() <= 0) {
                return false;
            }

            if (extending[0].attribute("type") != "flash.display::Sprite") {
                return false;
            }

            var expected_font_name: * = "Lucida Console";
            if (Capabilities.os.toLowerCase().indexOf("linux") != -1) {
                expected_font_name = "Liberation Mono";
            } else if (Capabilities.os.indexOf("Mac") != -1) {
                expected_font_name = "Courier New";
            }

            for each (var variable :* in description.elements("variable")) {
                if (variable.attribute("type") != "String") {
                    continue;
                }

                var object: * = klass[variable.attribute("name")];
                if (object == expected_font_name) {
                    return true;
                }
            }

            return false;
        }

        private static function get_logging_instance_prop_name(klass: Class, description: XML) : String {
            var class_name: * = description.attribute("name");

            for each (var variable: * in description.elements("variable")) {
                if (variable.attribute("type") == class_name) {
                    return variable.attribute("name");
                }
            }

            return null;
        }

        private static function get_logging_message_prop_name(klass: Class, description: XML) : String {
            for each (var variable: * in description.elements("factory").elements("variable")) {
                if (variable.attribute("type") == "String") {
                    return variable.attribute("name");
                }
            }

            return null;
        }

        private function get_logging_class_info(event: Event) : void {
            var game: * = (this.final_loader.content as DisplayObjectContainer).getChildAt(0) as Loader;

            if (game.numChildren == 0) {
                return;
            }

            this.removeEventListener(Event.ENTER_FRAME, this.get_logging_class_info);

            var domain: * = game.contentLoaderInfo.applicationDomain;
            for each(var class_name: String in domain.getQualifiedDefinitionNames()) {
                var klass: * = domain.getDefinition(class_name);
                if (klass == null || klass == undefined) {
                    continue;
                }

                if (klass.constructor != Class) {
                    continue;
                }

                var description: * = describeType(klass);

                if (!is_logging_class(klass, description)) {
                    continue;
                }

                this.logging_class_info = {
                    klass:              klass,
                    instance_prop_name: get_logging_instance_prop_name(klass, description),
                    message_prop_name:  get_logging_message_prop_name(klass, description)
                };

                return;
            }
        }

        private static function is_socket_class(klass: Class) : Boolean {
            if (klass == Socket) {
                return true;
            }

            /*
                Transformice wraps their socket in a dummy
                user-defined class which inherits from 'Socket'.
            */

            var description: * = describeType(klass);

            for each (var parent: * in description.elements("factory").elements("extendsClass")) {
                if (parent.attribute("type") == "flash.net::Socket") {
                    return true;
                }
            }

            return false;
        }

        private function process_socket_class(klass: Class) : void {
            if (!this.is_transformice) {
                return;
            }

            var description: * = describeType(klass);

            for each (var variable: * in description.elements("factory").elements("variable")) {
                if (variable.attribute("name") != SOCKET_KEY_NAME) {
                    this.socket_dict_name = variable.attribute("name");

                    break;
                }
            }
        }

        private function get_socket_property(domain: ApplicationDomain, description: XML) : String {
            for each (var variable: * in description.elements("factory").elements("variable")) {
                try {
                    var variable_type: * = domain.getDefinition(variable.attribute("type"));
                } catch (ReferenceError) {
                    return null;
                }

                if (!is_socket_class(variable_type)) {
                    continue;
                }

                this.process_socket_class(variable_type);

                return variable.attribute("name");
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

        private static function get_address_property(description: XML) : String {
            for each (var variable: * in description.elements("factory").elements("variable")) {
                /*
                    NOTE: There are two non-static properties which
                    are strings, but they both hold the same value.
                */
                if (variable.attribute("type") == "String") {
                    return variable.attribute("name");
                }
            }

            return null;
        }

        private static function get_possible_ports_properties(description: XML) : Array {
            var possible_names: * = new Array();

            for each (var variable: * in description.elements("factory").elements("variable")) {
                if (variable.attribute("type") == "Array") {
                    possible_names.push(variable.attribute("name"));
                }
            }

            return possible_names;
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
                if (klass == null || klass == undefined) {
                    continue;
                }

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

                var socket_prop_name: String = this.get_socket_property(domain, description);
                if (socket_prop_name == null) {
                    continue;
                }

                var address_prop_name:         * = get_address_property(description);
                var possible_ports_prop_names: * = get_possible_ports_properties(description);
                var instance_names:            * = get_connection_instance_names(description);

                this.connection_class_info = {
                    klass:                     klass,
                    socket_prop_name:          socket_prop_name,
                    address_prop_name:         address_prop_name,
                    possible_ports_prop_names: possible_ports_prop_names,
                    instance_names:            instance_names
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

        private function get_auth_key() : int {
            var game:     * = (this.final_loader.content as DisplayObjectContainer).getChildAt(0) as Loader;
            var document: * = game.getChildAt(0);

            var auth_key_return: * = this.is_transformice ? "*" : "int";

            var description: * = describeType(document);
            for each (var method: * in description.elements("method")) {
                /*
                    The method that ciphers the auth token is the only
                    one in the document class that is non-static, takes
                    no parameters, and returns 'int'.
                */

                if (method.attribute("returnType") != auth_key_return) {
                    continue;
                }

                if (method.elements("parameter").length() != 0) {
                    continue;
                }

                var cipher_method: * = document[method.attribute("name")];
                if (cipher_method == null) {
                    continue;
                }

                /*
                    NOTE: At this point, the auth token is still '0',
                    and since ciphering the auth token is equivalent
                    to a single XOR, and since '0 ^ key == key', we
                    can get the auth key simply by calling the method.
                */
                var auth_key: * = cipher_method.call(document);
                if (auth_key.constructor != Number) {
                    continue;
                }

                /*
                    Transformice has a method with the same signature
                    as the auth key method but which just returns '0'.
                */
                if (auth_key == 0) {
                    continue;
                }

                return auth_key;
            }

            return null;
        }

        private function send_packet(packet_data: ByteArray) : void {
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

                NOTE: We could use the game's own
                send packet method, however that would
                require identifying more things and
                a more  funny business than this does.

                But if we *were* to use the game's send
                packet method then we would be able to
                write an accurate fingerprint. That
                doesn't matter though because these packets
                should never be forwarded on to the server.
            */
            external_data.writeByte(0);

            this.main_socket.writeBytes(external_data);
            this.main_socket.writeBytes(packet_data);
            this.main_socket.flush();
        }

        private function send_packet_key_sources() : void {
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

            this.send_packet(packet_data);
        }

        private function send_auth_key() : void {
            var auth_key: * = get_auth_key();

            var packet_data: * = new ByteArray();

            /* Parent ID. */
            packet_data.writeByte(0xFF);
            packet_data.writeByte(0xFF);

            /* Extension ID. */
            packet_data.writeUTF("auth_key");

            packet_data.writeInt(auth_key);

            this.send_packet(packet_data);
        }

        private function send_main_server_info() : void {
            var packet_data: * = new ByteArray();

            /* Parent ID. */
            packet_data.writeByte(0xFF);
            packet_data.writeByte(0xFF);

            /* Extension ID. */
            packet_data.writeUTF("main_server_info");

            packet_data.writeUTF(this.main_address);

            for (var i: * = 0; i < this.main_ports.length; ++i) {
                /*
                    NOTE: Consumers of this packet
                    should read the ports as unsigned.

                    Also note that these ports will be missing the
                    port that the client actually tried to connect
                    to. As far as I can tell, there's no way to
                    recover this port without letting the client
                    connect to the real server, which would send
                    the handshake packet, which is undesirable.
                    Therefore proxies should be able to handle
                    when there are no ports sent.
                */
                packet_data.writeShort(this.main_ports[i]);
            }

            this.send_packet(packet_data);
        }

        private function before_handshake() : void {
            /* Unwrap the socket. */
            this.set_connection_socket(this.main_connection, this.main_socket);

            this.send_packet_key_sources();
            this.send_auth_key();
            this.send_main_server_info();
        }

        private function get_connection_socket(instance: *) : Socket {
            if (this.is_transformice) {
                var adaptor: * = instance[this.connection_class_info.socket_prop_name];

                return adaptor[this.socket_dict_name][adaptor[SOCKET_KEY_NAME]];
            }

            return instance[this.connection_class_info.socket_prop_name];
        }

        private function set_connection_socket(instance: *, socket: Socket) : void {
            if (this.is_transformice) {
                var adaptor: * = instance[this.connection_class_info.socket_prop_name];

                adaptor[this.socket_dict_name][adaptor[SOCKET_KEY_NAME]] = socket;
            } else {
                instance[this.connection_class_info.socket_prop_name] = socket;
            }
        }

        private function try_replace_connection(event: Event) : void {
            var klass:             * = this.connection_class_info.klass;
            var address_prop_name: * = this.connection_class_info.address_prop_name;

            var closed_socket: * = false;
            for each (var name: * in this.connection_class_info.instance_names) {
                var instance: * = klass[name];
                if (instance == null) {
                    return;
                }

                if (!closed_socket) {
                    var socket: * = this.get_connection_socket(instance);

                    this.main_address = instance[address_prop_name];

                    for each (var ports_name: * in this.connection_class_info.possible_ports_prop_names) {
                        var possible_ports: * = instance[ports_name];
                        if (possible_ports.length <= 0 || possible_ports[0] == null) {
                            continue;
                        }

                        for each (var port: * in possible_ports) {
                            this.main_ports.push(port)
                        }

                        break;
                    }

                    var logging_instance: * = this.logging_class_info.klass[this.logging_class_info.instance_prop_name];

                    var message: * = logging_instance[this.logging_class_info.message_prop_name];

                    var used_port: * = parseInt(message.substring(message.lastIndexOf("(") + 1, message.lastIndexOf(")")));
                    this.main_ports.push(used_port);

                    socket.close();
                    instance.reset();

                    closed_socket = true;
                }

                klass[name] = null;
            }

            this.main_connection = new klass(PROXY_INFO, false);
            this.main_socket     = this.get_connection_socket(this.main_connection);

            this.set_connection_socket(this.main_connection, new SocketWrapper(this.main_socket, this.before_handshake));

            this.removeEventListener(Event.ENTER_FRAME, this.try_replace_connection);
        }
    }
}
