
#ifndef _parseyast_h
#define _parseyast_h

#define MAXSTRLEN 180
#define MAXGROUPS 100
#define MAXMODULES 200
#define GROUPS_FILE "/usr/share/YaST2/config/y2cc.groups"
#define GROUP_STR "[Y2Group "
#define MOD_STR "[Y2Module "
#define MOD_STR_LEN strlen(MOD_STR)

typedef struct
{
    char name[MAXSTRLEN];
    char textstr[MAXSTRLEN];
    int mod_cnt;
    int skey;
}
grp_data;

typedef struct
{
    char name[MAXSTRLEN];
    char textstr[MAXSTRLEN];
    char group[MAXSTRLEN];
    char textdomain[MAXSTRLEN];
    char infostr[MAXSTRLEN];
    char args[MAXSTRLEN];
    int skey;
}
mod_data;

extern grp_data groups[MAXGROUPS];
extern mod_data modules[MAXGROUPS][MAXMODULES];
extern int grp_cnt;
extern char button_help[20];
extern char button_cancel[20];
extern int yast_grp_all;

void getbuttons ();
void getgroup (void);
void getmodules (void);
char *cut_str (char *str);
void add_module (char *mod_name, char *namestr, char *group, char *infostr,
		 char *textdomain, char *args, int skey);

#endif
