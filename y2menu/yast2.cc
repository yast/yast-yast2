#include "yastfunc.h"
#include "parseyast.h"
/* sortorder */
#define NOSORT 0
#define BYNAME 1
#define BYKEY 2			/* default */

void printhelp ();
int parseopt (char *option);
grp_data groups[MAXGROUPS];
mod_data modules[MAXGROUPS][MAXMODULES];
int grp_cnt = 0;

int sort = BYKEY;
int yast_mod_auto = 1;
int yast_grp_all = 0;
int yast_dyn_mod = 0;
int yast_quit_grp = 1;

char button_help[20];
char button_cancel[20];
int cmpmod (const void *mod1, const void *mod2);
int cmpgrp (const void *grp1, const void *grp2);
int main (int argc, const char *const *argv)
{
  int grp, mod, i;
  int ret = 0;

  yast_mod_auto = 1;

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
     strcpy (groups[0].name, "All");
     strcpy (groups[0].textstr, translate ("general", "&All") + 1);
     groups[0].skey = 0;
     groups[0].mod_cnt = 0;
     grp_cnt = 1;
   }
  else
    grp_cnt = 0;

  getbuttons ();
  getgroup ();

  qsort (groups, grp_cnt, sizeof (grp_data), cmpgrp);

  getmodules ();
  for (grp = 0; grp < grp_cnt; grp++)
    qsort (modules[grp], groups[grp].mod_cnt, sizeof (mod_data), cmpmod);

  if (argc > 1 && !strcmp (argv[1], "--dump"))
   {

     fprintf (stderr, "grp_cnt: %d\n", grp_cnt);
     for (grp = 0; grp < grp_cnt; grp++)
      {
	fprintf (stderr, "%s mod_cnt:%d  skey:%d\n", groups[grp].textstr,
		 groups[grp].mod_cnt, groups[grp].skey);
	for (mod = 0; mod < groups[grp].mod_cnt; mod++)
	  fprintf (stderr, "  %s skey:%d\n", modules[grp][mod].textstr,
		   modules[grp][mod].skey);
      }

     return 0;
   }

  if (yast_quit_grp)
   {
     strcpy (groups[grp_cnt].name, button_cancel);
     strcpy (groups[grp_cnt].textstr, button_cancel);
     groups[grp_cnt].mod_cnt = 0;
     grp_cnt++;
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
  grp_data *a = (grp_data *) grp1, *b = (grp_data *) grp2;

  if (sort == BYNAME)
    return strcmp (a->textstr, b->textstr);
  if (sort == BYKEY)
   {
     if (a->skey > b->skey)
       return 1;
     if (a->skey < b->skey)
       return -1;
   }

  return 0;
}
int cmpmod (const void *mod1, const void *mod2)
{
  mod_data *a = (mod_data *) mod1, *b = (mod_data *) mod2;

  if (sort == BYNAME)
    return strcmp (a->textstr, b->textstr);

  if (sort == BYKEY)
   {
     if (a->skey > b->skey)
       return 1;
     if (a->skey < b->skey)
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
  return 0;
}

void printhelp ()
{
  printf ("sort groups and modules:\n");
  printf (" -sk          sort by sortkey (default)\n");
  printf (" -sa          sort by name\n");
  printf (" -sn          no sort\n\n");
  printf (" --help       print this help\n");
  printf (" --dump       print groups and modules to stderr and exit\n");
  printf (" --auto       auto-open of module-frame (default)\n");
  printf (" --noauto     no-auto-open of module-frame\n");
  printf (" --grpall     add the \"all\" entry to group-list\n");
  printf
    (" --dynmod     dynamic-module-frame frame-width depends on length of modulename\n");
  printf (" --noquitgrp  no \"quit\" entry in group-menu\n");
  printf ("\n");

}
