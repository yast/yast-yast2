#include <string>
#include <vector>
#include <glob.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <locale.h>
#include <libintl.h>

#include "parseyast.h"
#include "myintl.h"

using std::string;
using std::vector;

/*
  Textdomain "base"
*/


void getmodules ()
{
    string mod_name;
    string namestr;
    string textdomain;
    string group;
    string infostr;
    string args;
    int skey = 0;
    char *tmpstr = 0;
    size_t tmpstr_len = 0;

    glob_t globbuf;
    glob (CONFIGDIR "/*.y2cc", GLOB_NOSORT, 0, &globbuf);

    for (unsigned int i = 0; i < globbuf.gl_pathc; i++)
    {
	FILE *mod_file;

	mod_file = fopen (globbuf.gl_pathv[i], "r");

	while (getline (&tmpstr, &tmpstr_len, mod_file) != -1)
	{
	    if (!strncmp (tmpstr, MOD_STR, MOD_STR_LEN))
	    {
		int i;

		for (i = strlen (tmpstr); i > MOD_STR_LEN; i--)
		    if (tmpstr[i] == ']')
		    {
			tmpstr[i] = 0;
			break;
		    }

		mod_name = string (tmpstr + MOD_STR_LEN, i - MOD_STR_LEN);
	    }			/* if */
	    else if (!strncmp (tmpstr, "Name", 4))
		namestr = cut_str (tmpstr);
	    else if (!strncmp (tmpstr, "Group", 5))
		group = cut_str (tmpstr);
	    else if (!strncmp (tmpstr, "Helptext", 8))
		infostr = cut_str (tmpstr);
	    else if (!strncmp (tmpstr, "Arguments", 9))
		args = cut_str (tmpstr);
	    else if (!strncmp (tmpstr, "Textdomain", 10))
		textdomain = cut_str (tmpstr);
	    if (!strncmp (tmpstr, "SortKey", 7))
		skey = atoi (cut_str (tmpstr).c_str ());
	}			/* while */
	fclose (mod_file);

	add_module (mod_name, namestr, group, infostr, textdomain, args, skey);
    }

    free (tmpstr);
}


void getgroup ()
{
    FILE *grp_file;
    char *tmpstr = 0;
    size_t tmpstr_len = 0;
    grp_data group;

    grp_file = fopen (GROUPS_FILE, "r");
    while (getline (&tmpstr, &tmpstr_len, grp_file) != -1)
    {
	if (!strncmp (tmpstr, GROUP_STR, strlen (GROUP_STR)))
	{
	    int i;

	    for (i = strlen (tmpstr); i > 0; i--)
		if (tmpstr[i] == ']')
		{
		    tmpstr[i] = 0;
		    break;
		}

	    group.name = string (tmpstr + strlen (GROUP_STR));
	}
	else
	{
	    if (!strncmp (tmpstr, "Name", 4))
	    {
		set_textdomain ("base");
		group.textstr = string (_(cut_str (tmpstr).c_str ()));
	    }
	    else if (!strncmp (tmpstr, "SortKey", 7))
	    {
		group.skey = atoi (cut_str (tmpstr).c_str ());
		groups.push_back (group);
		modules.push_back (vector<mod_data> ());
	    }
	}				/* else */
    }				/* while */

    fclose (grp_file);
    free (tmpstr);
}


string cut_str (char *str)
{
    string result = string (str);

    // Remove newline
    result.erase (result.size() - 1);

    for (string::iterator i = result.begin (); i != result.end (); i++)
	if (*i == '=')
	{
	    if (++i != result.end () && *i == ' ')
	       ++i;
	    result.erase (result.begin (), i);
	    break;

	}

    for (string::iterator i = result.begin (); i != result.end (); i++)
	if (*i == '\"')
	{
	    result.erase (result.begin (), ++i);
	    break;
	}

    for (string::reverse_iterator i = result.rbegin (); i != result.rend (); i++)
	if (*i == '\"')
	{
	    result.erase (i.base () - 1, result.end ());
	    break;
	}

    return result;
}


char *trans_text (const char *textdomain, char *trans_str)
{

    return trans_str;
}


void add_module (string mod_name, string namestr, string group, string infostr,
		 string textdomain, string args, int skey)
{
    int i;
    int group_ok = 0;
    mod_data module;

    for (i = yast_grp_all ? 1 : 0; i < groups.size (); i++)
	if (groups[i].name == group)
	{
	    group_ok = 1;
	    break;
	}

    if (!group_ok)
	return;

    set_textdomain (textdomain.c_str ());

    module.name = mod_name;
    module.textstr = string (_(namestr.c_str ()));
    module.infostr = string (_(infostr.c_str ()));
    module.textdomain = textdomain;
    module.args = args;
    module.group = group;
    module.skey = skey;
    modules[i].push_back (module);

    /* add to group all */
    if (yast_grp_all)
    {
	module.name = mod_name;
	module.textstr = string (_(namestr.c_str ()));
	module.infostr = string (_(infostr.c_str ()));
	module.textdomain = textdomain;
	module.args = args;
	module.group = group;
	module.skey = skey;
	modules[0].push_back (module);
    }
}


void getbuttons ()
{
    set_textdomain ("base");

    button_help = _("&Help") + 1; // FIXME !!! HELP !!!
    button_cancel = _("&Quit") + 1; // FIXEM !!! HELP !!!
}
