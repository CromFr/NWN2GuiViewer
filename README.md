
# NWN2 GUI viewer

- by Crom (Thibaut CHARLES)

# Notes

This program is no more useful since I discovered the parameter `idleexpiretime` (from UIScene) that allows to reload the GUI file from disk when closed.

Basically, you set `idleexpiretime` to a low value (ie 0.1) and then in-game, you just have to close & open the GUI to reload it.



# Features

- Check XML syntax & attributes correctness
- Auto reload current file if changed: save the file in your editor to update the view
- Windows/Linux (and OSX?) support, with command line options
- Bugs that need to be fixed

# Planned features

- Handle UIListBox & UIScrollbar
- OnXXX basic function calls (ie UIButton_Input_ShowObject, UIObject_Misc_SetLocalVarString, etc.)
- STRREF support
- Local var support
- UIGrid support
- ...

# Usage

### From the command line

```bash
nwn2gui [args] guifile
# guifile: Any NWN2 GUI file
# args:
#  -f, --file     Specify the XML file to open
#  -c, --check    Check only XML syntax
#                 Return nonzero on error
#  -p, --respath  NWN2 UI folder & custom resource folders
#                 Can specify multiples paths separated
#                 by ';' on windows or ':' on linux
```


```bash
# Example for Windows
nwn2gui -p "C:/Program Files (x86)/Atari/Neverwinter Nights 2/UI/default;." mainmenu.xml

# Linux
nwn2gui -p "/media/windows/Program Files (x86)/Atari/Neverwinter Nights 2/UI/default:." mainmenu.xml
```