
#ifndef _YAST_h
#include <string>
#include <vector>

#define _YAST_h

#define YAST_TITLE "yast @ "

#define YAST_CFG_FILE "y2menu-color"
#define YAST_CFG_PATH "/usr/share/YaST2/data/"

#define MAXGROUPS 100
#define MAXMODULES 200

#define MAX_WIDTH_END COLS-3
#define MAX_GRP_DSP 10+(LINES-25)
#define GROUP_X 3		/* x-pos section-menu */
#define GROUP_Y 5		/* y-pos section-menu */
#define INFO_Y (LINES-6)
#define BUTTONCNT 2		/* starts from 0 */

#define BUTTON_HELP 1
#define BUTTON_OK 0
#define BUTTON_CANCEL 2

#define NAV_INIT 10000
#define NAV_RESET 10001 
#define DEHIGHLIGHT 10002 
#define HIGHLIGHT 10003
extern int yast_mod_auto;	/* auto-open for moduleframe */
extern int yast_grp_all;
extern int yast_dyn_mod;
extern int yast_quit_grp;
 extern std::vector<std::string> helptext;
#endif
