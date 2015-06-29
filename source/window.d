import gtk.Widget;
import gtk.MainWindow;
import gtk.VBox;
import gtk.MenuBar;
import gtk.TextView;
import gtk.ScrolledWindow;
import gdk.Pixbuf;


import embedded;

class Window : MainWindow {
	this() {
		super("");
		
		auto menubar = new MenuBar();
		auto menu = menubar.append("Move console");

		auto consoleWrap = new ScrolledWindow(PolicyType.EXTERNAL, PolicyType.ALWAYS);
		consoleWrap.setMinContentHeight(100);
		console = new TextView;
		console.setEditable(false);
		console.setCursorVisible(false);
		console.setLeftMargin(5);
		console.setWrapMode(WrapMode.NONE);
		consoleWrap.add(console);

		guiContainer = new VBox(false, 0);
		guiContainer.packStart(menubar, false, true, 0);
		guiContainer.packEnd(consoleWrap, true, true, 5);
		add(guiContainer);

		setIcon(new Pixbuf(RES_XPM_ICON));




		win = this;
	}


	static{
		__gshared Window win;
		

		void SetScene(Widget content){
			with(win){
				if(guiContent !is null)
					guiContent.destroy();
				guiContainer.packStart(content, false, false, 0);
				guiContent = content;
			}
		}
		void RemoveScene(){
			with(win){
				if(guiContent !is null)
					guiContent.destroy();
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
	VBox guiContainer;
	Widget guiContent;
	TextView console;
	bool consoleEmpty = true;
	


}