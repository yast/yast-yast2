

/*
 *  Author: Arvin Schnell <arvin@suse.de>
 */

#ifndef MYINTL_H
#define MYINTL_H


#include <libintl.h>


inline const char* _(const char* msgid)
{
    return gettext (msgid);
}

inline const char* _(const char* msgid1, const char* msgid2, unsigned long int n)
{
    return ngettext (msgid1, msgid2, n);
}


void
set_textdomain (const char* domain);


#endif
