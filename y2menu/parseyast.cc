#include <dirent.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <locale.h>
#include <libintl.h>

#include "parseyast.h"

#define TRANS_PATH "/usr/lib/YaST2/locale"
extern int _nl_msg_cat_cntr;

void getmodules ()
{

  DIR *dirp;
  struct dirent *entry;

  chdir (MENU_DIR);
  dirp = opendir (MENU_DIR);
  while ((entry = readdir (dirp)))
   {
     char mod_name[MAXSTRLEN] = "";
     char namestr[MAXSTRLEN] = "";
     char textdomain[MAXSTRLEN] = "";
     char group[MAXSTRLEN] = "";
     char infostr[MAXSTRLEN] = "";
     char args[MAXSTRLEN] = "";
     int skey = 0;

     if (!strncmp
	 (entry->d_name, MENU_FILE_PREFIX, strlen (MENU_FILE_PREFIX)))
      {
	FILE *mod_file;

	mod_file = fopen (entry->d_name, "r");

	while (!feof (mod_file))
	 {
	   char tmpstr[MAXSTRLEN + 1];

	   tmpstr[0] = 0;
	   fgets (tmpstr, MAXSTRLEN, mod_file);
	   tmpstr[MAXSTRLEN] = 0;

	   if (!strncmp (tmpstr, MOD_STR, MOD_STR_LEN))
	    {
	      int i;

	      for (i = strlen (tmpstr); i > MOD_STR_LEN; i--)
		if (tmpstr[i] == ']')
		 {
		   tmpstr[i] = 0;
		   break;
		 }

	      strcpy (mod_name, tmpstr + MOD_STR_LEN);

	    }			/* if */
	   else if (!strncmp (tmpstr, "Name", 4))
	     strcpy (namestr, cut_str (tmpstr));
	   else if (!strncmp (tmpstr, "Group", 5))
	     strcpy (group, cut_str (tmpstr));
	   else if (!strncmp (tmpstr, "Helptext", 8))
	     strcpy (infostr, cut_str (tmpstr));
	   else if (!strncmp (tmpstr, "Arguments", 9))
	     strcpy (args, cut_str (tmpstr));
	   else if (!strncmp (tmpstr, "Textdomain", 10))
	     strcpy (textdomain, cut_str (tmpstr));
	   if (!strncmp (tmpstr, "SortKey", 7))
	     skey = atoi (cut_str (tmpstr));

	 }			/* while */
	fclose (mod_file);
	add_module (mod_name, namestr, group, infostr, textdomain, args,
		    skey);

      }				/* while readdir */
   }
}

void getgroup ()
{
  FILE *grp_file;
  char tmpstr[MAXSTRLEN + 1];

  grp_file = fopen (GROUP_FILE, "r");
  while (!feof (grp_file))
   {

     tmpstr[0] = 0;

     fgets (tmpstr, MAXSTRLEN, grp_file);
     tmpstr[MAXSTRLEN] = 0;
     if (!strncmp (tmpstr, GROUP_STR, strlen (GROUP_STR)))
      {
	int i;

	for (i = strlen (tmpstr); i > 0; i--)
	  if (tmpstr[i] == ']')
	   {
	     tmpstr[i] = 0;
	     break;
	   }

	strcpy (groups[grp_cnt].name, tmpstr + strlen (GROUP_STR));
	groups[grp_cnt].mod_cnt = 0;

      }
     else
      {
	if (!strncmp (tmpstr, "Name", 4))
	 {
	   strcpy (groups[grp_cnt].textstr,
		   translate ("general", cut_str (tmpstr)));
	 }
	else if (!strncmp (tmpstr, "SortKey", 7))
	 {
	   groups[grp_cnt].skey = atoi (cut_str (tmpstr));
	   grp_cnt++;
	 }

      }				/* else */

   }				/* while */

  fclose (grp_file);

}

char *cut_str (char *str)
{
  char tmpstr[MAXSTRLEN + 1] = "";
  int i;

/* for(i=strlen(str);i>0;i--)
 if(str[i]!=' ' && str[i]!='\n')
  { str[i]=0; break; } */

  str[strlen (str) - 1] = 0;

  strcpy (tmpstr, str);
  for (i = 0; i < strlen (tmpstr); i++)
    if (tmpstr[i] == '=')
     {
       if (tmpstr[i + 1] == ' ')
	{
	  strcpy (str, tmpstr + i + 2);
	  break;
	}
       else
	{
	  strcpy (str, tmpstr + i + 1);
	  break;
	}

     }

  for (i = 0; i < strlen (str); i++)
    if (str[i] == '\"')
     {
       strcpy (tmpstr, str + i + 1);
       break;
     }

  for (i = strlen (tmpstr); i > 0; i--)
    if (tmpstr[i] == '\"')
     {
       tmpstr[i] = 0;
       strcpy (str, tmpstr);
       break;
     }

  return str;
}

char *trans_text (const char *textdomain, char *trans_str)
{

  return trans_str;
}

void add_module (char *mod_name, char *namestr, char *group, char *infostr,
		 char *textdomain, char *args, int skey)
{
  int i;
  int group_ok = 0;

  for (i = yast_grp_all ? 1 : 0; i < grp_cnt; i++)
    if (!strcmp (groups[i].name, group))
     {
       group_ok = 1;
       break;
     }

  if (!group_ok)
    return;

  strcpy (modules[i][groups[i].mod_cnt].name, mod_name);
  strcpy (modules[i][groups[i].mod_cnt].textstr,
	  (char *) translate (textdomain, namestr));
  strcpy (modules[i][groups[i].mod_cnt].infostr,
	  translate (textdomain, infostr));
  strcpy (modules[i][groups[i].mod_cnt].textdomain, textdomain);
  strcpy (modules[i][groups[i].mod_cnt].args, args);
  strcpy (modules[i][groups[i].mod_cnt].group, group);
  modules[i][groups[i].mod_cnt].skey = skey;

/* add to group all */
  if (yast_grp_all)
   {
     strcpy (modules[0][groups[0].mod_cnt].name, mod_name);
     strcpy (modules[0][groups[0].mod_cnt].textstr,
	     translate (textdomain, namestr));
     strcpy (modules[0][groups[0].mod_cnt].infostr,
	     translate (textdomain, infostr));
     strcpy (modules[0][groups[0].mod_cnt].textdomain, textdomain);
     strcpy (modules[0][groups[0].mod_cnt].args, args);
     strcpy (modules[0][groups[0].mod_cnt].group, group);
     modules[0][groups[0].mod_cnt].skey = skey;

     groups[0].mod_cnt++;
   }

  groups[i].mod_cnt++;
}

char *translate (char *txtdomain, char *transstr)
{
  setlocale (LC_ALL, "");

  bindtextdomain (txtdomain, TRANS_PATH);
  textdomain (txtdomain);
/*  bind_textdomain_codeset (txtdomain, "UTF-8"); */

  _nl_msg_cat_cntr++;
  return dgettext (txtdomain, transstr);
}

void getbuttons ()
{

  strcpy (button_help, translate ("wizard", "&Help") + 1);
  strcpy (button_cancel, translate ("wizard", "&Quit") + 1);
}
