#ifndef _parseyast_h
#define _parseyast_h

#include <string>
#include <vector>

#define GROUPS_FILE "/usr/share/YaST2/config/y2cc.groups"
#define GROUP_STR "[Y2Group "
#define MOD_STR "[Y2Module "
#define MOD_STR_LEN strlen(MOD_STR)

typedef struct
{
    std::string name;
    std::string textstr;
    int skey;
}
grp_data;

typedef struct
{
    std::string name;
    std::string textstr;
    std::string group;
    std::string textdomain;
    std::string infostr;
    std::string args;
    int skey;
}
mod_data;

extern std::vector<grp_data> groups;
extern std::vector<std::vector<mod_data> > modules;
extern const char *button_help;
extern const char *button_cancel;
extern int yast_grp_all;

void getbuttons ();
void getgroup (void);
void getmodules (void);
std::string cut_str (char *str);
void add_module (std::string mod_name, std::string namestr, std::string group,
		 std::string infostr,std:: string textdomain, std::string args,
		 int skey);


// return new copy of the input string without '&' characters
char *remove_and(const char *in);


#endif
