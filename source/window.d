import gtk.Widget;
import gtk.MainWindow;
import gtk.VBox;
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
		
		auto toolbar = new Toolbar();
		toolbar.setIconSize(IconSize.SMALL_TOOLBAR);

		auto butReload = new ToolButton(null, "Reload file");
		butReload.setIconName("view-refresh-symbolic");
		butReload.setTooltipText("Reload file");
		butReload.addOnClicked((MenuItem){ReloadFile();});
		toolbar.insert(butReload);

		auto consoleWrap = new ScrolledWindow(PolicyType.EXTERNAL, PolicyType.ALWAYS);
		consoleWrap.setMinContentHeight(100);
		console = new TextView;
		console.setEditable(false);
		console.setCursorVisible(false);
		console.setLeftMargin(5);
		console.setWrapMode(WrapMode.NONE);
		consoleWrap.add(console);

		sceneContainer = new VBox(false, 0);
		sceneContainer.packStart(toolbar, false, true, 0);
		sceneContainer.packEnd(consoleWrap, true, true, 5);
		add(sceneContainer);

		setIcon(new Pixbuf(RES_XPM_ICON));


		win = this;
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
					sceneContainer.packStart(newScene.container, false, false, 0);

					setTitle(scene.name);
					setDefaultSize(scene.size.x, scene.size.y);

					scene.container.showAll();
				}
			}
		}


		void Display(){
			with(win){
				showAll();
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
	VBox sceneContainer;
	UIScene scene;
	TextView console;
	bool consoleEmpty = true;
	


}