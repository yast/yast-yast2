#ifndef _yastfunc_h
#define _yastfunc_h
#include <sys/types.h>
#include <fcntl.h>
#include <unistd.h>
#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#include "yast.h"
#ifdef ultrix
#include <cursesX.h>
#else
#include <curses.h>
#endif

#define USE_COLORS TRUE

#define ESC 27
#define TAB 9
#define CTRL_F 6
#define CTRL_B 2
#define MAX_LEN 2048
#define BUF_SIZE (10*1024)
#define MIN(x,y) (x < y ? x : y)
#define MAX(x,y) (x > y ? x : y)

#ifndef HAVE_NCURSES
#ifndef ACS_ULCORNER
#define ACS_ULCORNER '+'
#endif
#ifndef ACS_LLCORNER
#define ACS_LLCORNER '+'
#endif
#ifndef ACS_URCORNER
#define ACS_URCORNER '+'
#endif
#ifndef ACS_LRCORNER
#define ACS_LRCORNER '+'
#endif
#ifndef ACS_HLINE
#define ACS_HLINE '-'
#endif
#ifndef ACS_VLINE
#define ACS_VLINE '|'
#endif
#ifndef ACS_LTEE
#define ACS_LTEE '+'
#endif
#ifndef ACS_RTEE
#define ACS_RTEE '+'
#endif
#ifndef ACS_UARROW
#define ACS_UARROW '^'
#endif
#ifndef ACS_DARROW
#define ACS_DARROW 'v'
#endif
#endif

#if 0				/* XXX These make nicer symbols, but are a bad hack. */
#undef  ACS_UARROW
#define ACS_UARROW '^'
#undef  ACS_DARROW
#define ACS_DARROW 'v'
#endif
/* 
 * Attribute names
 */
#define screen_attr                   attributes[0]
#define shadow_attr                   attributes[1]
#define dialog_attr                   attributes[2]
#define title_attr                    attributes[3]
#define border_attr                   attributes[4]
#define button_active_attr            attributes[5]
#define button_inactive_attr          attributes[6]
#define button_key_active_attr        attributes[7]
#define button_key_inactive_attr      attributes[8]
#define button_label_active_attr      attributes[9]
#define button_label_inactive_attr    attributes[10]
#define inputbox_attr                 attributes[11]
#define inputbox_border_attr          attributes[12]
#define searchbox_attr                attributes[13]
#define searchbox_title_attr          attributes[14]
#define searchbox_border_attr         attributes[15]
#define position_indicator_attr       attributes[16]
#define menubox_attr                  attributes[17]
#define menubox_border_attr           attributes[18]
#define item_attr                     attributes[19]
#define item_selected_attr            attributes[20]
#define tag_attr                      attributes[21]
#define tag_selected_attr             attributes[22]
#define tag_key_attr                  attributes[23]
#define tag_key_selected_attr         attributes[24]
#define check_attr                    attributes[25]
#define check_selected_attr           attributes[26]
#define uarrow_attr                   attributes[27]
#define darrow_attr                   attributes[28]

/* number of attributes */
#define ATTRIBUTE_COUNT               29

/*
 * Global variables
 */
#ifdef HAVE_NCURSES
extern bool use_colors;
extern bool use_shadow;
#endif

extern chtype attributes[];

extern const char *backtitle;

/*
 * Function prototypes
 */
void attr_clear (WINDOW * win, int height, int width, chtype attr);
void yast_clear (void);
void yast_init ();
void yast_end ();
void yast_print_autowrap (WINDOW * win, const char *prompt,
			  int width, int y, int x, chtype attr);
int yast_parse_cfg (char *cfg_path, char *cfg_file);
void yast_draw_frame (WINDOW * win, int y, int x, int height, int width,
		      chtype box, chtype border);
void yast_grp_menu (WINDOW * dialog, WINDOW * menu, int choice, int width,
		    int height);
int yast_menu (const char *title, const char *prompt, int height, int width);
void yast_dialog_print_button (WINDOW * win, const char *label, int y, int x,
			       int selected);
void _dialog_draw_box (WINDOW * win, int y, int x, int height, int width,
		       chtype box, chtype border);
void yast_del_box (WINDOW * win, int y, int x, int height, int width,
		   chtype box, chtype border);
#ifdef HAVE_NCURSES
void _dialog_draw_shadow (WINDOW * win, int y, int x, int height, int width);
#endif

int dialog_yesno (const char *title, const char *prompt, int height,
		  int width);
int dialog_msgbox (const char *title, const char *prompt, int height,
		   int width, int pause);
int dialog_textbox (const char *title, const char *file, int height,
		    int width);
int dialog_menu (const char *title, const char *prompt, int height, int width,
		 int menu_height, int item_no, const char *const *items);

int dialog_checklist (const char *title, const char *prompt, int height,
		      int width, int list_height, int item_no,
		      const char *const *items, int flag, int *status);
extern unsigned char dialog_input_result[];
int dialog_inputbox (const char *title, const char *prompt, int height,
		     int width, const char *init);
int dialog_gauge (const char *title, const char *prompt, int height,
		  int width, int percent);

/*
 * The following stuff is needed for mouse support
 */
#ifndef HAVE_LIBGPM

#define mouse_open() /**/
#define mouse_close() /**/
#define mouse_mkregion(y,x,height,width,code) /**/
#define mouse_mkbigregion(y,x,height,width,nitems,th,mode) /**/
#define mouse_setbase(x,y) /**/
#define mouse_wgetch(w) wgetch(w)
#else

void mouse_open (void);
void mouse_close (void);
void mouse_mkregion (int y, int x, int height, int width, int code);
void mouse_mkbigregion (int y, int x, int height, int width, int nitems,
			int th, int mode);
void mouse_setbase (int x, int y);
int mouse_wgetch (WINDOW *);
int Gpm_Wgetch (WINDOW * w);

#define mouse_wgetch(w) Gpm_Wgetch(w)

#endif

#define mouse_mkbutton(y,x,len,code) mouse_mkregion(y,x,1,len,code);

/*
 * This is the base for fictious keys, which activate
 * the buttons.
 *
 * Mouse-generated keys are the following:
 *   -- the first 32 are used as numbers, in addition to '0'-'9'
 *   -- the lowercase are used to signal mouse-enter events (M_EVENT + 'o')
 *   -- uppercase chars are used to invoke the button (M_EVENT + 'O')
 */
#define M_EVENT (KEY_MAX+1)

/*
 * The `flag' parameter in checklist is used to select between
 * radiolist and checklist
 */
#define FLAG_CHECK 1
#define FLAG_RADIO 0

#endif
