#ifndef _YAST_h
#define _YAST_h
/* #include "colors.h" */

#define YAST_TITLE "yast @ "
#define MAXGROUPS 100
#define MAXMODULES 200
/* #define MAXSTRLEN 180 */

#define MAX_WIDTH_END COLS-3
#define YAST_CFG_FILE "yast_color"
#define YAST_CFG_PATH "/usr/lib/YaST2/etc/"
#define MAX_GRP_DSP 10+(LINES-25)
#define GROUP_X 3		/* x-pos  section-menu */
#define GROUP_Y 5		/* y-pos  section-menu */
#define INFO_Y (LINES-6)
#define BUTTONCNT 2		/* starts from 0 */

#define BUTTON_HELP 1
#define BUTTON_OK 0
#define BUTTON_CANCEL 2

#define NAV_INIT -255
#define NAV_RESET -254
extern int yast_mod_auto;	/* auto-open for moduleframe */
extern int yast_grp_all;
extern int yast_dyn_mod;
extern int yast_quit_grp;
#endif
