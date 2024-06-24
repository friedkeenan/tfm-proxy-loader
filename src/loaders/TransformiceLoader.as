package loaders {
    import flash.net.Socket;
    import flash.utils.describeType;
    import flash.system.ApplicationDomain;
    import flash.utils.getQualifiedClassName;
    import flash.utils.Dictionary;

    public class TransformiceLoader extends GameLoader {
        private var create_connection_method_name: String;
        private var socket_dict_name: String;

        public function TransformiceLoader() {
            super("http://www.transformice.com/Transformice.swf");
        }

        private function get_socket_prop_name(description: XML, type_name: String) : void {
            for each (var variable: * in description.elements("variable")) {
                if (variable.attribute("type") == type_name) {
                    this.socket_prop_name = variable.attribute("name");

                    return;
                }
            }
        }

        private function call_socket_method(domain: ApplicationDomain, description: XML, key: int) : Socket {
            var document: * = this.document();

            for each (var method: * in description.elements("method")) {
                if (method.elements("parameter").length() != 0) {
                    continue;
                }

                if (method.attribute("returnType") != "*") {
                    continue;
                }

                try {
                    return document[method.attribute("name")](key);
                } catch (error: Error) {
                    /* ... */
                }
            }

            return null;
        }

        private function get_create_connection_method_name(description: XML) : void {
            for each (var method: * in description.elements("factory").elements("method")) {
                var parameters: * = method.elements("parameter");
                if (parameters.length() != 3) {
                    continue;
                }

                if (parameters[0].attribute("type") != "String") {
                    continue;
                }

                this.create_connection_method_name = method.attribute("name");

                return;
            }
        }

        protected override function process_connection_info(domain: ApplicationDomain, description: XML) : void {
            this.get_create_connection_method_name(description);

            var document: * = this.document();
            var document_description: * = describeType(document);

            /* Load a socket into the dictionary. */
            var real_socket: * = this.call_socket_method(domain, document_description, -1);

            var socket_type_name: * = getQualifiedClassName(real_socket);
            this.build_wrapper_socket(domain, socket_type_name);

            for each (var variable: * in document_description.elements("variable")) {
                if (variable.attribute("type") != "flash.utils::Dictionary") {
                    continue;
                }

                var dictionary: * = document[variable.attribute("name")];

                if (dictionary == null) {
                    continue;
                }

                var maybe_socket: * = dictionary[-1];
                if (maybe_socket == null) {
                    continue;
                }

                if (maybe_socket is Socket) {
                    delete dictionary[-1];

                    this.socket_dict_name = variable.attribute("name");

                    this.get_socket_prop_name(describeType(maybe_socket), socket_type_name);

                    return;
                }
            }
        }

        private static function set_all_strings(instance: *, value: String) : void {
            var description: * = describeType(instance);

            for each (var variable: * in description.elements("variable")) {
                if (variable.attribute("type") != "String") {
                    continue;
                }

                instance[variable.attribute("name")] = value;
            }
        }

        protected override function get_connected_address(instance: *) : String {
            var description: * = describeType(instance);

            for each (var variable: * in description.elements("variable")) {
                if (variable.attribute("type") != "String") {
                    continue;
                }

                var value: * = instance[variable.attribute("name")];

                if (value != "_nfs_801") {
                    return value;
                }
            }

            return null;
        }

        protected override function create_connection(address_info: String) : * {
            var klass: * = this.connection_class_info.klass;

            var instance: * = new klass();

            set_all_strings(instance, "_nfs_801");

            instance[this.create_connection_method_name](address_info, false);

            return instance;
        }

        protected override function get_connection_socket(instance: *) : Socket {
            for each (var socket: * in this.document()[this.socket_dict_name]) {
                return socket[this.socket_prop_name];
            }

            return null;
        }

        protected override function set_connection_socket(instance: *, socket: Socket) : void {
            var dictionary: * = this.document()[this.socket_dict_name];

            for (var key: * in dictionary) {
                dictionary[key][this.socket_prop_name] = socket;

                return;
            }
        }

        protected override function reset_socket_state() : void {
            this.document()[this.socket_dict_name] = new Dictionary();
        }

        protected override function auth_key_return() : String {
            return "*";
        }
    }
}
