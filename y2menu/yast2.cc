
#include <vector>
#include <string>
#include <locale.h>

#include "yastfunc.h"
#include "parseyast.h"
#include "myintl.h"

using std::vector;
using std::string;

/*
  Textdomain "base"
*/

/* sortorder */
#define NOSORT 0
#define BYNAME 1		/* default */
#define BYKEY 2	

void printhelp ();
int parseopt (char *option);

vector < grp_data > groups;
vector < vector < mod_data > > modules;
vector < string > helptext;
int sort = BYNAME;
int yast_mod_auto = 1;
int yast_grp_all = 0;
int yast_dyn_mod = 0;
int yast_quit_grp = 1;

const char *button_help;
const char *button_cancel;
int cmpmod (const void *mod1, const void *mod2);
static int current_grp;
int cmpgrp (const void *grp1, const void *grp2);

void fillhelp ();

int main (int argc, const char *const *argv)
{
  unsigned grp, mod;
  int i;
  int ret = 0;

  yast_mod_auto = 1;

  setlocale (LC_ALL, "");

  if (argc > 1)
    for (i = 1; i < argc; i++)
      if (parseopt ((char *) argv[i]) != 1)
       {
	 printf ("usage: %s <option>\n\n", argv[0]);
	 printhelp ();
	 return 1;
       }

  /* init groups */
  if (yast_grp_all)
   {
     set_textdomain ("base");

     grp_data group;

     group.name = string ("All");
     // button to show all yast2 modules
     group.textstr = string (remove_and (_( "&All" )));
     group.skey = 0;
     groups.push_back (group);
     modules.push_back (vector < mod_data > ());
   }

  getbuttons ();
  getgroup ();
  fillhelp ();

  int *map = new int[groups.size ()];

  for (grp = 0; grp < groups.size (); grp++)
    map[grp] = grp;
  qsort (map, groups.size (), sizeof (int), cmpgrp);
  vector < grp_data > new_groups;
  for (grp = 0; grp < groups.size (); grp++)
    new_groups.push_back (groups[map[grp]]);
  groups = new_groups;
  delete[]map;

  getmodules ();
  for (grp = 0; grp < groups.size (); grp++)
   {
     map = new int[modules[grp].size ()];

     for (mod = 0; mod < modules[grp].size (); mod++)
       map[mod] = mod;
     current_grp = grp;
     qsort (map, modules[grp].size (), sizeof (int), cmpmod);
     vector < mod_data > new_modules;
     for (mod = 0; mod < modules[grp].size (); mod++)
       new_modules.push_back (modules[grp][map[mod]]);
     modules[grp] = new_modules;
     delete[]map;
   }

  if (argc > 1 && !strcmp (argv[1], "--dump"))
   {

     fprintf (stderr, "grp_cnt: %d\n", (int) groups.size ());
     for (grp = 0; grp < groups.size (); grp++)
      {
	fprintf (stderr, "%s mod_cnt:%d  skey:%d\n",
		 groups[grp].textstr.c_str (),
		 (int) modules[grp].size (), groups[grp].skey);
	for (mod = 0; mod < modules[grp].size (); mod++)
	  fprintf (stderr, "  %s skey:%d\n",
		   modules[grp][mod].textstr.c_str (),
		   modules[grp][mod].skey);
      }

     return 0;
   }

  if (yast_quit_grp)
   {
     grp_data group;

     group.name = string (button_cancel);
     group.textstr = string (button_cancel);
     groups.push_back (group);
   }

  while (!ret)
   {
     yast_init ();
     ret = yast_menu ("hallo", "Yast2 Control Center", 10, 30);
     yast_end ();
   }

  return 0;
}

int cmpgrp (const void *grp1, const void *grp2)
{
  int a = *(int *) grp1, b = *(int *) grp2;

  if (sort == BYNAME)
    return groups[a].textstr.compare (groups[b].textstr);
  if (sort == BYKEY)
   {
     if (groups[a].skey > groups[b].skey)
       return 1;
     if (groups[a].skey < groups[b].skey)
       return -1;
   }

  return 0;
}

int cmpmod (const void *mod1, const void *mod2)
{
  int a = *(int *) mod1, b = *(int *) mod2;

  if (sort == BYNAME)
    return modules[current_grp][a].textstr.compare (modules[current_grp][b].
						    textstr);

  if (sort == BYKEY)
   {
     if (modules[current_grp][a].skey > modules[current_grp][b].skey)
       return 1;
     if (modules[current_grp][a].skey < modules[current_grp][b].skey)
       return -1;
   }

  return 0;
}

int parseopt (char *option)
{
  if (!strcmp (option, "-h") || !strcmp (option, "--help"))
    return 0;

  if (!strcmp (option, "-sa"))
   {
     sort = BYNAME;
     return 1;
   }
  if (!strcmp (option, "-sn"))
   {
     sort = NOSORT;
     return 1;
   }
  if (!strcmp (option, "-sk"))
   {
     sort = BYKEY;
     return 1;
   }
  if (!strcmp (option, "--auto"))
   {
     yast_mod_auto = 1;
     return 1;
   }

  if (!strcmp (option, "--noauto"))
   {
     yast_mod_auto = 0;
     return 1;
   }
  if (!strcmp (option, "--grpall"))
   {
     yast_grp_all = 1;
     return 1;
   }
  if (!strcmp (option, "--dynmod"))
   {
     yast_dyn_mod = 1;
     return 1;
   }

  if (!strcmp (option, "--noquitgrp"))
   {
     yast_quit_grp = 0;
     return 1;
   }
  if (!strcmp (option, "--dump"))
    return 1;
  return 0;
}

void printhelp ()
{
  printf ("sort groups and modules:\n");
  printf (" -sk          sort by sortkey\n");
  printf (" -sa          sort by name (default)\n");
  printf (" -sn          no sort\n\n");
  printf (" --help       print this help\n");
  printf (" --dump       print groups and modules to stderr and exit\n");
  printf (" --auto       auto-open of module-frame (default)\n");
  printf (" --noauto     no-auto-open of module-frame\n");
  printf (" --grpall     add the \"all\" entry to group-list\n");
  printf (" --dynmod     dynamic-module-frame frame-width depends on length of modulename\n");
  printf (" --noquitgrp  no \"quit\" entry in group-menu\n");
  printf ("\n");
}

void fillhelp ()
{
    vector <string> tmp;

    // help text for ncurses control center
    tmp.push_back (_( "Controlling YaST2 ncurses with the Keyboard" ));
    tmp.push_back ("");

    // help text for ncurses control center
    tmp.push_back (_( "1) General" ));
    // help text for ncurses control center
    tmp.push_back (_( "Navigate through the dialog elements with\n"
		      "<TAB> and <SHIFT>+<TAB> or <TAB> and <ALT>+<TAB>.\n"
		      "Select or activate elements with <SPACE> or <ENTER>.\n"
		      "Some elements use <ARROW> keys.\n" ));
    // help text for ncurses control center
    tmp.push_back (_( "Buttons are equipped with shortcut keys like <ALT> and a\n"
		      "letter. Because the environment can affect the use of\n"
		      "the keyboard, there is more than one way to\n"
		      "navigate the dialog pages. See the next section."));
    tmp.push_back ("");

    // help text for ncurses control center
    tmp.push_back (_( "2) Substitution of Keystrokes" ));
    // help text for ncurses control center
    tmp.push_back (_( "If <TAB> and <SHIFT>+<TAB> or <TAB> and <ALT>+<TAB> do not work,\n"
		      "move focus forward with <CTRL>+<F> and backward with <CTRL>+<B>.\n"
		      "If <ALT>+<letter> does not work, try <ESC>+<letter>. Example:\n" ));
    // help text for ncurses control center
    tmp.push_back (_( "<ALT>+<H> as <ESC>+<H>.\n" ));
    // help text for ncurses control center
    tmp.push_back (_( "<ESC>+<TAB> is also a substitute for <ALT>+<TAB>." ));
    tmp.push_back ("");

    // help text for ncurses control center
    tmp.push_back (_( "3) Function Keys" ));
    // help text for ncurses control center
    tmp.push_back (_( "F-keys provide a quick access to main functions.\n"
		      "There are many modules with special functions and it is not\n"
		      "possible to apply the following system to all of them. In some\n"
		      "environments, all or some F-keys are not availiable.\n"
		      "There is no solution for this problem yet." ));
    tmp.push_back ("");
    // help text for ncurses control center
    tmp.push_back (_( "F1  = Help" ));
    // help text for ncurses control center
    tmp.push_back (_( "F2  = Info or Description" ));
    // help text for ncurses control center
    tmp.push_back (_( "F3  = Add" ));
    // help text for ncurses control center
    tmp.push_back (_( "F4  = Edit or Configure" ));
    // help text for ncurses control center
    tmp.push_back (_( "F5  = Delete" ));
    // help text for ncurses control center
    tmp.push_back (_( "F6  = Test" ));
    // help text for ncurses control center
    tmp.push_back (_( "F7  = Expert or Advanced" ));
    // help text for ncurses control center
    tmp.push_back (_( "F8  = Back" ));
    // help text for ncurses control center
    tmp.push_back (_( "F9  = Abort" ));
    // help text for ncurses control center
    tmp.push_back (_( "F10 = OK, Next, Finish, or Accept" ));

    for (vector <string>::const_iterator it = tmp.begin (); it != tmp.end (); it++)
    {
	string::size_type a = 0;
	while (true)
	{
	    string::size_type b = it->find_first_of ('\n', a);
	    helptext.push_back (it->substr (a, b - a));
	    if (b == string::npos)
		break;
	    a = b + 1;
	}
    }
}
