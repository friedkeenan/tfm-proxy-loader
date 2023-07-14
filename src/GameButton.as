package {
    import flash.events.Event;
    import flash.events.MouseEvent;
    import flash.filters.GlowFilter;
    import flash.display.Sprite;
    import flash.text.TextField;
    import flash.text.TextFieldAutoSize;
    import flash.text.TextFormat;

    public class GameButton extends Sprite {
        private static const GLOW: * = new GlowFilter(0xFFFFFF, 1.0, 15.0, 15.0);

        private var proxy_loader: TFMProxyLoader;
        private var url: String;

        public function GameButton(proxy_loader: TFMProxyLoader, name: String, url: String, width: uint, height: uint, color: uint) {
            super();

            this.proxy_loader = proxy_loader;
            this.url = url;

            var label_format: * = new TextFormat();
            label_format.size = 24;
            label_format.color = 0xFFFFFF;

            var label: * = new TextField();

            label.selectable = false;
            label.autoSize = TextFieldAutoSize.LEFT;
            label.defaultTextFormat = label_format;
            label.text = name;

            if (width <= 0) {
                width = label.width + 20;
            }

            this.graphics.beginFill(color);
            this.graphics.drawRoundRect(0, 0, width, height, 15);
            this.graphics.endFill();

            this.addChild(label);

            label.x = (width - label.width) / 2;
            label.y = (height - label.height) / 2;

            this.addEventListener(MouseEvent.MOUSE_OVER, this.start_glow);
            this.addEventListener(MouseEvent.MOUSE_OUT, this.stop_glow);

            this.addEventListener(MouseEvent.MOUSE_DOWN, this.load_game);
        }

        private function start_glow(event: Event) : void {
            this.filters = [GLOW];
        }

        private function stop_glow(event: Event) : void {
            this.filters = [];
        }

        private function load_game(event: Event) : void {
            var shared: * = this.proxy_loader.shared_data();

            shared.data.last_game_url = this.url;

            shared.flush();

            this.proxy_loader.load_game(this.url);
        }
    }
}
