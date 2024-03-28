package {
    import flash.display.Sprite;
    import flash.events.KeyboardEvent;
    import flash.net.SharedObject;
    import flash.utils.Dictionary;
    import loaders.TransformiceLoader;
    import loaders.DeadMazeLoader;
    import loaders.BouboumLoader;
    import loaders.NekodancerLoader;
    import loaders.FortoresseLoader;

    public class TFMProxyLoader extends Sprite {
        private static const BUTTON_PADDING: * = 30;

        private static const GAME_TO_LOADER: * = new Dictionary();

        {
            GAME_TO_LOADER["bouboum"]      = BouboumLoader;
            GAME_TO_LOADER["deadmaze"]     = DeadMazeLoader;
            GAME_TO_LOADER["fortoresse"]   = FortoresseLoader;
            GAME_TO_LOADER["nekodancer"]   = NekodancerLoader;
            GAME_TO_LOADER["transformice"] = TransformiceLoader;
        }

        public function TFMProxyLoader() {
            super();

            this.setup_buttons();

            this.stage.addEventListener(KeyboardEvent.KEY_DOWN, this.load_last_game);
        }

        private function shared_data() : SharedObject {
            return SharedObject.getLocal("TFMProxyLoader");
        }

        private function game_key(game_loader: Class) : String {
            for (var key: * in GAME_TO_LOADER) {
                if (game_loader == GAME_TO_LOADER[key]) {
                    return key;
                }
            }

            return null;
        }

        private function set_last_loaded_game(game_loader: Class) : void {
            var shared: * = this.shared_data();

            shared.data.last_game = this.game_key(game_loader);

            shared.flush();
        }

        private function load_last_game(event: KeyboardEvent) : void {
            /* Ignore key presses that aren't 'Enter'. */
            if (event.keyCode != 13) {
                return;
            }

            var shared: * = this.shared_data();

            if (shared.data.last_game != null) {
                this.load_game(GAME_TO_LOADER[shared.data.last_game]);
            }
        }

        private function setup_buttons() : void {
            var transformice: * = new GameButton(this, "Transformice", TransformiceLoader, 0, 75, 0x6A7495);

            var deadmaze:   * = new GameButton(this, "Dead Maze",  DeadMazeLoader,   transformice.width, 75, 0x000000);
            var bouboum:    * = new GameButton(this, "Bouboum",    BouboumLoader,    transformice.width, 75, 0x615F44);
            var nekodancer: * = new GameButton(this, "Nekodancer", NekodancerLoader, transformice.width, 75, 0x048895);
            var fortoresse: * = new GameButton(this, "Fortoresse", FortoresseLoader, transformice.width, 75, 0xB7B7B7);

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
            this.stage.removeEventListener(KeyboardEvent.KEY_DOWN, this.load_last_game);

            this.remove_children();
        }

        public function load_game(game_loader: Class) : void {
            this.set_last_loaded_game(game_loader);

            this.remove_gui();

            var loader: * = new game_loader();
            this.addChild(loader);

            loader.load_game();
        }
    }
}
