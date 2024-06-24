package loaders {
    import flash.display.Sprite;
    import flash.system.ApplicationDomain;
    import flash.desktop.NativeApplication;
    import flash.events.Event;
    import flash.net.URLLoader;
    import flash.net.URLRequest;
    import flash.system.Security;
    import flash.display.Loader;
    import flash.net.Socket;
    import flash.system.LoaderContext;
    import flash.display.DisplayObjectContainer;
    import flash.system.Capabilities;
    import flash.utils.describeType;
    import flash.utils.ByteArray;
    import org.as3commons.bytecode.emit.IAbcBuilder;
    import org.as3commons.bytecode.emit.IPackageBuilder;
    import org.as3commons.bytecode.emit.IClassBuilder;
    import org.as3commons.bytecode.abc.QualifiedName;
    import org.as3commons.bytecode.abc.LNamespace;
    import org.as3commons.bytecode.abc.enum.NamespaceKind;
    import org.as3commons.bytecode.emit.impl.AbcBuilder;
    import org.as3commons.bytecode.emit.ICtorBuilder;
    import org.as3commons.bytecode.abc.enum.Opcode;
    import org.as3commons.bytecode.emit.IAccessorBuilder;
    import org.as3commons.reflect.AccessorAccess;
    import org.as3commons.bytecode.emit.IMethodBuilder;
    import org.as3commons.bytecode.emit.event.AccessorBuilderEvent;
    import org.as3commons.bytecode.emit.impl.MethodBuilder;
    import org.as3commons.bytecode.emit.enum.MemberVisibility;
    import org.as3commons.bytecode.abc.Op;

    public class GameLoader extends Sprite {
        private static var PROXY_INFO:      String = "localhost:11801";
        private static var POLICY_FILE_URL: String = "xmlsocket://localhost:10801"

        private var game_url: String;

        private var final_loader: Loader;

        private var logging_class_info: *;

        private var socket_wrapper_class: Class = null;

        protected var socket_prop_name: String;
        protected var connection_class_info: *;

        private var main_connection: *;
        private var main_socket: Socket;

        private var main_address: String;
        private var main_ports:   Array = new Array();

        private var steamworks: Object = null;
        private var steam_okay: Boolean;

        public function GameLoader(game_url: String) {
            super();

            this.game_url = game_url;
        }

        public function load_game() : void {
            Security.loadPolicyFile(POLICY_FILE_URL);

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

            loader.load(new URLRequest(this.game_url));
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

        private function game() : Loader {
            return (this.final_loader.content as DisplayObjectContainer).getChildAt(0) as Loader;
        }

        private function game_domain() : ApplicationDomain {
            return this.game().contentLoaderInfo.applicationDomain;
        }

        protected function document() : * {
            return this.game().getChildAt(0);
        }

        private function init_steam_info(event: Event) : void {
            var game: * = this.game();

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
            var game: * = this.game();

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

        private static function has_security_error_method(description: XML) : Boolean {
            for each (var method: * in description.elements("factory").elements("method")) {
                var params: * = method.elements("parameter");
                if (params.length() != 1) {
                    continue;
                }

                if (params[0].attribute("type") != "flash.events::SecurityErrorEvent") {
                    continue;
                }

                return true;
            }

            return false;
        }

        protected function build_wrapper_socket(domain: ApplicationDomain, parent_name: String) : void {
            var abc: IAbcBuilder = new AbcBuilder();
            var pkg: IPackageBuilder = abc.definePackage("");

            var cls: IClassBuilder = pkg.defineClass("SocketWrapper", parent_name);

            cls.defineProperty("wrapped",                   "flash.net::Socket");
            cls.defineProperty("handshake_sent",            "Boolean");
            cls.defineProperty("before_handshake_callback", "Function");

            var blank_namespace: * = new LNamespace(NamespaceKind.PACKAGE_NAMESPACE, "");

            var wrapped:                   * = new QualifiedName("wrapped",                    blank_namespace);
            var handshake_sent:            * = new QualifiedName("handshake_sent",             blank_namespace);
            var before_handshake_callback: * = new QualifiedName("before_handshake_callback",  blank_namespace);

            var socket_connected:  * = new QualifiedName("connected",  blank_namespace);
            var socket_writeBytes: * = new QualifiedName("writeBytes", blank_namespace);

            var constructor: ICtorBuilder = cls.defineConstructor();

            constructor.defineArgument("flash.net::Socket");
            constructor.defineArgument("Function");

            /* Assign 'wrapped', 'handshake_sent', and 'before_handshake_callback'. */
            constructor
                .addOpcode(Opcode.getlocal_0)
                .addOpcode(Opcode.pushscope)
                .addOpcode(Opcode.getlocal_0)
                .addOpcode(Opcode.constructsuper, [0])
                .addOpcode(Opcode.getlocal_0)
                .addOpcode(Opcode.getlocal_1)
                .addOpcode(Opcode.setproperty,    [wrapped])
                .addOpcode(Opcode.getlocal_0)
                .addOpcode(Opcode.pushfalse)
                .addOpcode(Opcode.setproperty,    [handshake_sent])
                .addOpcode(Opcode.getlocal_0)
                .addOpcode(Opcode.getlocal_2)
                .addOpcode(Opcode.setproperty,    [before_handshake_callback])
                .addOpcode(Opcode.returnvoid);

            /* NOTE: We only override what we *absolutely* need to. */

            var connected: IAccessorBuilder = cls.defineAccessor("connected", "Boolean");

            connected.access = AccessorAccess.READ_ONLY;
            connected.createPrivateProperty = false;

            connected.addEventListener(AccessorBuilderEvent.BUILD_GETTER, function (event: AccessorBuilderEvent) : void {
                var method: IMethodBuilder = new MethodBuilder("connected");

                method.isOverride = true;
                method.visibility = MemberVisibility.PUBLIC;
                method.returnType = "Boolean";

                /* Forward to wrapped 'connected'. */
                method
                    .addOpcode(Opcode.getlocal_0)
                    .addOpcode(Opcode.pushscope)
                    .addOpcode(Opcode.getlocal_0)
                    .addOpcode(Opcode.getproperty, [wrapped])
                    .addOpcode(Opcode.getproperty, [socket_connected])
                    .addOpcode(Opcode.returnvalue);

                event.builder = method;
            });

            var writeBytes: IMethodBuilder = cls.defineMethod("writeBytes");

            writeBytes.isOverride = true;

            writeBytes.defineArgument("flash.utils::ByteArray");
            writeBytes.defineArgument("uint", true, 0);
            writeBytes.defineArgument("uint", true, 0);

            /*
                Call 'before_handshake_callback' if we have not sent
                the handshake, then forward onto wrapped 'writeBytes'.
            */
            var iftrue: * = new Op(Opcode.iftrue, [0]);
            writeBytes
                .addOpcode(Opcode.getlocal_0)
                .addOpcode(Opcode.pushscope)
                .addOpcode(Opcode.getlocal_0)
                .addOpcode(Opcode.getproperty,  [handshake_sent])
                .addOp(iftrue)
                .addOpcode(Opcode.getlocal_0)
                .addOpcode(Opcode.pushtrue)
                .addOpcode(Opcode.setproperty,  [handshake_sent])
                .addOpcode(Opcode.getlocal_0)
                .addOpcode(Opcode.callpropvoid, [before_handshake_callback, 0])
                .defineJump(iftrue, new Op(Opcode.getlocal_0))
                .addOpcode(Opcode.getproperty,  [wrapped])
                .addOpcode(Opcode.getlocal_1)
                .addOpcode(Opcode.getlocal_2)
                .addOpcode(Opcode.getlocal_3)
                .addOpcode(Opcode.callpropvoid, [socket_writeBytes, 3])
                .addOpcode(Opcode.returnvoid);

            abc.addEventListener(Event.COMPLETE, this.loaded_socket_wrapper);
            abc.buildAndLoad(domain, domain);
        }

        private function loaded_socket_wrapper(event: Event) : void {
            this.socket_wrapper_class = this.game_domain().getDefinition("SocketWrapper") as Class;
        }

        protected function process_connection_info(domain: ApplicationDomain, description: XML) : void {
            for each (var variable: * in description.elements("factory").elements("variable")) {
                if (variable.attribute("type") == "flash.net::Socket") {
                    this.socket_prop_name = variable.attribute("name");

                    this.build_wrapper_socket(domain, "flash.net::Socket");

                    return;
                }
            }
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
            var game: * = this.game();

            if (game.numChildren == 0) {
                return;
            }

            this.removeEventListener(Event.ENTER_FRAME, this.get_connection_class_info);

            var domain: * = game.contentLoaderInfo.applicationDomain;
            for each(var class_name: String in domain.getQualifiedDefinitionNames()) {
                /*
                    The connection class is the only one that only
                    inherits from 'Object', doesn't implement any
                    interface, and has a method which accepts a
                    'SecurityErrorEvent'.
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

                if (!has_security_error_method(description)) {
                    continue;
                }

                this.process_connection_info(domain, description);

                var possible_ports_prop_names: * = get_possible_ports_properties(description);
                var instance_names:            * = get_connection_instance_names(description);

                this.connection_class_info = {
                    klass:                     klass,
                    possible_ports_prop_names: possible_ports_prop_names,
                    instance_names:            instance_names
                };

                this.addEventListener(Event.ENTER_FRAME, this.try_replace_connection);

                return;
            }
        }

        private function get_packet_key_sources() : Array {
            var document: * = this.document();

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

        protected function auth_key_return() : String {
            return "int";
        }

        private function get_auth_key() : int {
            var document: * = this.document();

            var auth_key_return: * = this.auth_key_return();

            var description: * = describeType(document);
            for each (var method: * in description.elements("method")) {
                /*
                    The method that ciphers the auth token is the only
                    one in the document class that is non-static, takes
                    no parameters, and returns our return type.
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

        protected function get_connection_socket(instance: *) : Socket {
            return instance[this.socket_prop_name];
        }

        protected function set_connection_socket(instance: *, socket: Socket) : void {
            instance[this.socket_prop_name] = socket;
        }

        protected function reset_socket_state() : void {
            /* Stub implementation. */
        }

        protected function get_connected_address(instance: *) : String {
            var description: * = describeType(instance);

            for each (var variable: * in description.elements("variable")) {
                /*
                    NOTE: There are multiple non-static String
                    properties, but they hold the same value.
                */

                if (variable.attribute("type") == "String") {
                    return instance[variable.attribute("name")];
                }
            }

            return null;
        }

        protected function create_connection(address_info: String) : * {
            var klass: Class = this.connection_class_info.klass;

            return new klass(address_info, false);
        }

        private function try_replace_connection(event: Event) : void {
            if (this.socket_wrapper_class == null) {
                return;
            }

            var klass: * = this.connection_class_info.klass;

            var closed_socket: * = false;
            for each (var name: * in this.connection_class_info.instance_names) {
                var instance: * = klass[name];
                if (instance == null) {
                    return;
                }

                if (!closed_socket) {
                    var socket: * = this.get_connection_socket(instance);

                    this.main_address = this.get_connected_address(instance);

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

                    try {
                        socket.close()
                    } catch (e: Error) {
                        /* ... */
                    }

                    instance.reset();
                    this.reset_socket_state();

                    closed_socket = true;
                }

                klass[name] = null;
            }

            this.main_connection = this.create_connection(PROXY_INFO);
            this.main_socket     = this.get_connection_socket(this.main_connection);

            this.set_connection_socket(this.main_connection, new this.socket_wrapper_class(this.main_socket, this.before_handshake));

            this.removeEventListener(Event.ENTER_FRAME, this.try_replace_connection);
        }
    }
}
