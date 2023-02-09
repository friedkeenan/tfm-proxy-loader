package {
    import flash.net.Socket;
    import flash.utils.ByteArray;

    public class SocketWrapper extends Socket {
        private var wrapped: Socket;

        private var handshake_sent: Boolean = false;
        private var before_handshake_callback: Function;

        public function SocketWrapper(wrapped: Socket, before_handshake_callback: Function) {
            this.wrapped = wrapped;

            this.before_handshake_callback = before_handshake_callback;
        }

        /*
            NOTE: We only override what is actually used by the game.

            We could just override a subset of these things because we
            end up unwrapping the socket later, but I'll leave all of
            them in case we ever want to do more.
        */

        public override function get connected() : Boolean {
            return this.wrapped.connected;
        }

        public override function close() : void {
            this.wrapped.close();
        }

        public override function removeEventListener(type: String, listener: Function, useCapture: Boolean = false) : void {
            this.wrapped.removeEventListener(type, listener, useCapture);
        }

        public override function set endian(type: String) : void {
            this.wrapped.endian = type;
        }

        public override function addEventListener(type: String, listener: Function, useCapture: Boolean = false, priority: int = 0, useWeakReference: Boolean = false) : void {
            this.wrapped.addEventListener(type, listener, useCapture, priority, useWeakReference)
        }

        public override function connect(host: String, port: int) : void {
            this.wrapped.connect(host, port);
        }

        public override function writeBytes(bytes: ByteArray, offset: uint = 0, length: uint = 0) : void {
            if (!this.handshake_sent) {
                this.handshake_sent = true;

                this.before_handshake_callback();
            }

            this.wrapped.writeBytes(bytes, offset, length);
        }

        public override function flush() : void {
            this.wrapped.flush();
        }

        public override function get bytesAvailable() : uint {
            return this.wrapped.bytesAvailable;
        }

        public override function readByte() : int {
            return this.wrapped.readByte();
        }

        public override function readBytes(bytes: ByteArray, offset: uint = 0, length: uint = 0) : void {
            this.wrapped.readBytes(bytes, offset, length);
        }

        public override function writeByte(value: int) : void {
            this.wrapped.writeByte(value);
        }

        public override function writeShort(value: int) : void {
            this.wrapped.writeShort(value);
        }
    }
}