#include "yastfunc.h"

#ifdef HAVE_NCURSES
#include "colors.h"
color_names_st color_names[] = {
  {"BLACK", COLOR_BLACK}
  ,
  {"RED", COLOR_RED}
  ,
  {"GREEN", COLOR_GREEN}
  ,
  {"YELLOW", COLOR_YELLOW}
  ,
  {"BLUE", COLOR_BLUE}
  ,
  {"MAGENTA", COLOR_MAGENTA}
  ,
  {"CYAN", COLOR_CYAN}
  ,
  {"WHITE", COLOR_WHITE}
  ,
};				/* color names */
#endif

#define VAR_LEN 30
#define COMMENT_LEN 70

/* Types of values */
#define VAL_INT  0
#define VAL_STR  1
#define VAL_BOOL 2
#define VAL_ATTR 3

/* Type of line in configuration file */
#define LINE_BLANK    2
#define LINE_COMMENT  1
#define LINE_OK       0
#define LINE_ERROR   -1

/* number of configuration variables */
#define VAR_COUNT        (sizeof(vars) / sizeof(vars_st))

/* check if character is white space */
#define whitespace(c)    (c == ' ' || c == '\t')

/* check if character is string quoting characters */
#define isquote(c)       (c == '"' || c == '\'')

/* get last character of string */
#define lastch(str)      str[strlen(str)-1]

/*
 * Configuration variables
 */
typedef struct
{
  char name[VAR_LEN];		/* name of configuration variable as in DIALOGRC */
  void *var;			/* address of actually variable to change */
  int type;			/* type of value */
  char comment[COMMENT_LEN];	/* comment to put in "rc" file */
}
vars_st;

vars_st vars[] = {
  {"use_colors",
   &use_colors,
   VAL_BOOL,
   "Turn color support ON or OFF"},

  {"screen_color",
   color_table[0],
   VAL_ATTR,
   "Screen color"},

  {"shadow_color",
   color_table[1],
   VAL_ATTR,
   "Shadow color"},

  {"dialog_color",
   color_table[2],
   VAL_ATTR,
   "Dialog box color"},

  {"title_color",
   color_table[3],
   VAL_ATTR,
   "Dialog box title color"},

  {"border_color",
   color_table[4],
   VAL_ATTR,
   "Dialog box border color"},

  {"button_active_color",
   color_table[5],
   VAL_ATTR,
   "Active button color"},

  {"button_inactive_color",
   color_table[6],
   VAL_ATTR,
   "Inactive button color"},

  {"button_key_active_color",
   color_table[7],
   VAL_ATTR,
   "Active button key color"},

  {"button_key_inactive_color",
   color_table[8],
   VAL_ATTR,
   "Inactive button key color"},

  {"button_label_active_color",
   color_table[9],
   VAL_ATTR,
   "Active button label color"},

  {"button_label_inactive_color",
   color_table[10],
   VAL_ATTR,
   "Inactive button label color"},

  {"inputbox_color",
   color_table[11],
   VAL_ATTR,
   "Input box color"},

  {"inputbox_border_color",
   color_table[12],
   VAL_ATTR,
   "Input box border color"},

  {"searchbox_color",
   color_table[13],
   VAL_ATTR,
   "Search box color"},

  {"searchbox_title_color",
   color_table[14],
   VAL_ATTR,
   "Search box title color"},

  {"searchbox_border_color",
   color_table[15],
   VAL_ATTR,
   "Search box border color"},

  {"position_indicator_color",
   color_table[16],
   VAL_ATTR,
   "File position indicator color"},

  {"menubox_color",
   color_table[17],
   VAL_ATTR,
   "Menu box color"},

  {"menubox_border_color",
   color_table[18],
   VAL_ATTR,
   "Menu box border color"},

  {"item_color",
   color_table[19],
   VAL_ATTR,
   "Item color"},

  {"item_selected_color",
   color_table[20],
   VAL_ATTR,
   "Selected item color"},

  {"tag_color",
   color_table[21],
   VAL_ATTR,
   "Tag color"},

  {"tag_selected_color",
   color_table[22],
   VAL_ATTR,
   "Selected tag color"},

  {"tag_key_color",
   color_table[23],
   VAL_ATTR,
   "Tag key color"},

  {"tag_key_selected_color",
   color_table[24],
   VAL_ATTR,
   "Selected tag key color"},

  {"check_color",
   color_table[25],
   VAL_ATTR,
   "Check box color"},

  {"check_selected_color",
   color_table[26],
   VAL_ATTR,
   "Selected check box color"},

  {"uarrow_color",
   color_table[27],
   VAL_ATTR,
   "Up arrow color"},

  {"darrow_color",
   color_table[28],
   VAL_ATTR,
   "Down arrow color"}
};				/* vars */

/* char *attr_to_str (int fg, int bg, int hl); */
static int str_to_attr (char *str, int *fg, int *bg, int *hl);
static int parse_line (char *line, char **var, char **value);

int yast_parse_cfg (char *cfg_path, char *cfg_file)
{
  int l = 1, parse, fg, bg, hl;
  unsigned i;
  char str[MAX_LEN + 1], *var, *value;
  FILE *rc_file;

  sprintf (str, "%s%s", cfg_path, cfg_file);
  if ((rc_file = fopen (str, "rt")) == NULL)
    return 0;			/* step (b) failed, use default values */

  /* Scan each line and set variables */
  while (fgets (str, MAX_LEN, rc_file) != NULL)
   {
     if (lastch (str) != '\n')
      {
	/* ignore rest of file if line too long */
	fprintf (stderr, "\nParse error: line %d of configuration"
		 " file too long.\n", l);
	fclose (rc_file);
	return -1;		/* parse aborted */
      }
     else
      {
	lastch (str) = '\0';
	parse = parse_line (str, &var, &value);	/* parse current line */

	switch (parse)
	 {
	 case LINE_BLANK:	/* ignore blank lines and comments */
	 case LINE_COMMENT:
	   break;
	 case LINE_OK:
	   /* search table for matching config variable name */
	   for (i = 0; i < VAR_COUNT && strcmp (vars[i].name, var); i++);

	   if (i == VAR_COUNT)
	    {			/* no match */
	      fprintf (stderr, "\nParse error: unknown variable "
		       "at line %d of configuration file.\n", l);
	      return -1;	/* parse aborted */
	    }
	   else
	    {			/* variable found in table, set run time variables */
	      switch (vars[i].type)
	       {
	       case VAL_INT:
		 *((int *) vars[i].var) = atoi (value);
		 break;
	       case VAL_STR:
		 if (!isquote (value[0]) || !isquote (lastch (value))
		     || strlen (value) < 2)
		  {
		    fprintf (stderr, "\nParse error: string value "
			     "expected at line %d of configuration "
			     "file.\n", l);
		    return -1;	/* parse aborted */
		  }
		 else
		  {
		    /* remove the (") quotes */
		    value++;
		    lastch (value) = '\0';
		    strcpy ((char *) vars[i].var, value);
		  }
		 break;
	       case VAL_BOOL:
		 if (!strcasecmp (value, "ON"))
		   *((bool *) vars[i].var) = TRUE;
		 else if (!strcasecmp (value, "OFF"))
		   *((bool *) vars[i].var) = FALSE;
		 else
		  {
		    fprintf (stderr, "\nParse error: boolean value "
			     "expected at line %d of configuration "
			     "file.\n", l);
		    return -1;	/* parse aborted */
		  }
		 break;
	       case VAL_ATTR:
		 if (str_to_attr (value, &fg, &bg, &hl) == -1)
		  {
		    fprintf (stderr, "\nParse error: attribute "
			     "value expected at line %d of configuration "
			     "file.\n", l);
		    return -1;	/* parse aborted */
		  }
		 ((int *) vars[i].var)[0] = fg;
		 ((int *) vars[i].var)[1] = bg;
		 ((int *) vars[i].var)[2] = hl;
		 break;
	       }
	    }
	   break;
	 case LINE_ERROR:
	   fprintf (stderr, "\nParse error: syntax error at line %d of "
		    "configuration file.\n", l);
	   return -1;		/* parse aborted */
	 }
      }
     l++;			/* next line */
   }

  fclose (rc_file);
  return 0;			/* parse successful */
}

static int str_to_attr (char *str, int *fg, int *bg, int *hl)
{
  int i = 0, j, get_fg = 1;
  char tempstr[MAX_LEN + 1], *part;

  if (str[0] != '(' || lastch (str) != ')')
    return -1;			/* invalid representation */

  /* remove the parenthesis */
  strcpy (tempstr, str + 1);
  lastch (tempstr) = '\0';

  /* get foreground and background */

  while (1)
   {
     /* skip white space before fg/bg string */
     while (whitespace (tempstr[i]) && tempstr[i] != '\0')
       i++;
     if (tempstr[i] == '\0')
       return -1;		/* invalid representation */
     part = tempstr + i;	/* set 'part' to start of fg/bg string */

     /* find end of fg/bg string */
     while (!whitespace (tempstr[i]) && tempstr[i] != ','
	    && tempstr[i] != '\0')
       i++;

     if (tempstr[i] == '\0')
       return -1;		/* invalid representation */
     else if (whitespace (tempstr[i]))
      {				/* not yet ',' */
	tempstr[i++] = '\0';

	/* skip white space before ',' */
	while (whitespace (tempstr[i]) && tempstr[i] != '\0')
	  i++;

	if (tempstr[i] != ',')
	  return -1;		/* invalid representation */
      }
     tempstr[i++] = '\0';	/* skip the ',' */
     for (j = 0; j < COLOR_COUNT && strcasecmp (part, color_names[j].name);
	  j++);
     if (j == COLOR_COUNT)	/* invalid color name */
       return -1;
     if (get_fg)
      {
	*fg = color_names[j].value;
	get_fg = 0;		/* next we have to get the background */
      }
     else
      {
	*bg = color_names[j].value;
	break;
      }
   }				/* got foreground and background */

  /* get highlight */

  /* skip white space before highlight string */
  while (whitespace (tempstr[i]) && tempstr[i] != '\0')
    i++;
  if (tempstr[i] == '\0')
    return -1;			/* invalid representation */
  part = tempstr + i;		/* set 'part' to start of highlight string */

  /* trim trailing white space from highlight string */
  i = strlen (part) - 1;
  while (whitespace (part[i]))
    i--;
  part[i + 1] = '\0';

  if (!strcasecmp (part, "ON"))
    *hl = TRUE;
  else if (!strcasecmp (part, "OFF"))
    *hl = FALSE;
  else
    return -1;			/* invalid highlight value */

  return 0;
}

/*
 * Parse a line in the configuration file
 *
 * Each line is of the form:  "variable = value". On exit, 'var' will contain
 * the variable name, and 'value' will contain the value string.
 *
 * Return values:
 *
 * LINE_BLANK   - line is blank
 * LINE_COMMENT - line is comment
 * LINE_OK      - line is ok
 * LINE_ERROR   - syntax error in line
 */
static int parse_line (char *line, char **var, char **value)
{
  int i = 0;

  /* ignore white space at beginning of line */
  while (whitespace (line[i]) && line[i] != '\0')
    i++;

  if (line[i] == '\0')		/* line is blank */
    return LINE_BLANK;
  else if (line[i] == '#')	/* line is comment */
    return LINE_COMMENT;
  else if (line[i] == '=')	/* variables names can't strart with a '=' */
    return LINE_ERROR;

  /* set 'var' to variable name */
  *var = line + i++;		/* skip to next character */

  /* find end of variable name */
  while (!whitespace (line[i]) && line[i] != '=' && line[i] != '\0')
    i++;

  if (line[i] == '\0')		/* syntax error */
    return LINE_ERROR;
  else if (line[i] == '=')
    line[i++] = '\0';
  else
   {
     line[i++] = '\0';

     /* skip white space before '=' */
     while (whitespace (line[i]) && line[i] != '\0')
       i++;

     if (line[i] != '=')	/* syntax error */
       return LINE_ERROR;
     else
       i++;			/* skip the '=' */
   }

  /* skip white space after '=' */
  while (whitespace (line[i]) && line[i] != '\0')
    i++;

  if (line[i] == '\0')
    return LINE_ERROR;
  else
    *value = line + i;		/* set 'value' to value string */

  /* trim trailing white space from 'value' */
  i = strlen (*value) - 1;
  while (whitespace ((*value)[i]))
    i--;
  (*value)[i + 1] = '\0';

  return LINE_OK;		/* no syntax error in line */
}
