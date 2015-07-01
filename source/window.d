import gtk.Widget;
import gtk.MainWindow;
import gtk.VBox;
import gtk.Paned;
import gtk.Toolbar;
import gtk.ToolButton;
import gtk.TextView;
import gtk.ScrolledWindow;
import gdk.Pixbuf;

import node : UIScene;
import embedded;
import app : ReloadFile;

class Window : MainWindow {
	this() {
		super("");
		setIcon(new Pixbuf(RES_XPM_ICON));
		setDefaultSize(400, 500);
		
		auto toolbar = new Toolbar();
		toolbar.setIconSize(IconSize.SMALL_TOOLBAR);

		auto butReload = new ToolButton(null, "Reload file");
		butReload.setIconName("view-refresh-symbolic");
		butReload.setTooltipText("Reload file");
		butReload.addOnClicked((MenuItem){ReloadFile();});
		toolbar.insert(butReload);


		auto consoleWrap = new ScrolledWindow(PolicyType.EXTERNAL, PolicyType.ALWAYS);
		consoleWrap.setSizeRequest(-1, 100);
		console = new TextView;
		console.setEditable(false);
		console.setCursorVisible(false);
		console.setLeftMargin(5);
		console.setWrapMode(WrapMode.NONE);
		consoleWrap.add(console);

		sceneContainer = new ScrolledWindow(PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);

		auto paned = new Paned(Orientation.VERTICAL);
		paned.pack1(sceneContainer, true, true);
		paned.pack2(consoleWrap, false, true);
		

		mainContainer = new VBox(false, 0);
		mainContainer.packStart(toolbar, false, true, 0);
		mainContainer.packEnd(paned, true, true, 0);
		add(mainContainer);


		win = this;
		showAll();
	}


	static{
		__gshared Window win;
		

		void SetScene(UIScene newScene){
			with(win){
				if(scene !is null){
					scene.container.destroy();
					scene.destroy();
				}
				if(newScene !is null){
					scene = newScene;
					sceneContainer.add(scene.container);

					setTitle(scene.name);

					scene.container.showAll();
				}
			}
		}

		void AppendLog(in string msg){
			with(win){
				if(!consoleEmpty)
					console.appendText("\n");

				console.appendText(msg);
				consoleEmpty = false;
			}
		}
		void ClearLog(){
			with(win){
				console.getBuffer.setText("");
				consoleEmpty = true;
			}
		}
	}

private:
	VBox mainContainer;
	ScrolledWindow sceneContainer;
	UIScene scene;
	TextView console;
	bool consoleEmpty = true;
	


}