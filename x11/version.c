/**************
FILE          : version.c
***************
PROJECT       : SaX2 - SuSE advanced X configuration
              :
AUTHOR        : Marcus Schäfer <ms@suse.de>
              :
BELONGS TO    : configuration tool for the X window system 
              : released under the XFree86 license
              :
DESCRIPTION   : check which XFree86 version should be used
              : to configure the installed card. The algoritm
              : works as follows:
              :
              : 1) Check number of cards
              : 2) if only one card installed check if there
              :    is a XFree86 4 spec given
              : 3) if no XFree84 4 spec is given check if there
              :    is a XFree86 3 spec given
              : 4) if yes version equals 3 in all other cases 
              :    version equals 4
              :
STATUS        : Up to date
**************/
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <hd.h>

//=====================================
// main
//-------------------------------------
int main (void) {
	hd_data_t *hd_data = NULL;
	driver_info_t *di0 = NULL;
	driver_info_t *di  = NULL;
	hd_t *hd1 = NULL;
	hd_t *hd2 = NULL;
	int cards = 0;

	hd_data = calloc (1, sizeof *hd_data);
	hd1 = hd_list (hd_data, hw_display, 1, NULL);
	hd2 = hd1;

	// ...
	// get number of cards if more than one card we
	// will use XFree86 4 for this setup
	// ---
	for (; hd2; hd2 = hd2->next) {
		cards++;
	}
	if (cards > 1) {
		exit (4);
	}
	// ...
	// have only one card: check if there
	// is a XFree86 4 spec given
	// ---
	di0 = hd1->driver_info;
	for (di = di0; di; di = di->next) {
	if (strcmp(di->x11.xf86_ver,"4") == 0) {
		exit (4);
	}
	}
	// ...
	// did not found a XFree86 4 spec, check if
	// there is a XFree86 3 spec
	// ---
	for (di = di0; di; di = di->next) {
	if (strcmp(di->x11.xf86_ver,"3") == 0) {
		exit (3);
	}
	}
	// ...
	// all other cases, version is 4
	// ---
	exit (4);
}
