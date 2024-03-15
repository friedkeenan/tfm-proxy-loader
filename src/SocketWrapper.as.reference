package {
    import flash.net.Socket;
    import flash.utils.ByteArray;

    public class SocketWrapper extends Socket {
        /*
            NOTE: This class serves as a reference for what
            the generated wrapper socket class looks like.
        */

        private var wrapped: Socket;

        private var handshake_sent: Boolean = false;
        private var before_handshake_callback: Function;

        public function SocketWrapper(wrapped: Socket, before_handshake_callback: Function) {
            this.wrapped = wrapped;

            this.before_handshake_callback = before_handshake_callback;
        }

        /*
            NOTE: We only override what is necessary to override. */

        public override function get connected() : Boolean {
            return this.wrapped.connected;
        }

        public override function writeBytes(bytes: ByteArray, offset: uint = 0, length: uint = 0) : void {
            if (!this.handshake_sent) {
                this.handshake_sent = true;

                this.before_handshake_callback();
            }

            this.wrapped.writeBytes(bytes, offset, length);
        }
    }
}
