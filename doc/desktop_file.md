# Desktop Files
Desktop files are used to show entries in yast2 control center. They are used
also by AutoYaST to pass information configuration.
YaST desktop files are valid desktop files as defined by freedesktop organization.
For details about syntax, comments, localization and other stuff see
[latest desktop entry spec](http://standards.freedesktop.org/desktop-entry-spec/desktop-entry-spec-latest.html).

## Recognized Standard Keys
YaST control center require especially these keys:

* *Type* Yast use only `application`. It is a mandatory key.

* *Name* Used by the desktop environments, module name prefixed with YaST like
  `YaST Firewall`. Localized form is supported like
  `Name[pl_PL]=YaST Zapora Ogniowa`.

* *GenericName* Module name like `Firewall`. Localized form is supported like
  `Name[cs_CZ]=Pekelna brana`.

* *Comment* In YaST used as description of the application purpose,
  e.g. Configure a firewall.  Localized form is supported like
  `Comment[cs_CZ]=Upravit pocet byrokratu u pekelne brany`.

* *Categories* A semicolon-separated list of categories in which the entry will
  be shown in a menu, e.g. `Qt;X-SuSE-YaST;X-SuSE-YaST-Security;` means that it
  is shown in kde menu and also in yast center under security group.

* *Icon* Path to an image or preferable only a name of an icon to be displayed
  along with the application name in file managers and menus, e.g.
  yast-firewall. If only a name is used, the particular icon is looked up in the
  current theme.

* *Exec* A command which is executed when the application is launched like
  `xdg-su -c "/sbin/yast2 dasd"`.

## YaST Specific Keys
YaST have own keys that are enclosed in X-SuSE-YaST namespace:

* *X-SuSE-YaST-Call* Module name which is called with the yast2 command from
  YaST Control Center, e.g., firewall or users. Mandatory entry.

* *X-SuSE-YaST-Group* YaST group name. In YaST Control Center, YaST modules are
  listed under these groups. For recent possible values see in yast2 git
  repository directory yast2/library/desktop/groups/. Mandatory entry.

* *X-SuSE-YaST-Argument* Additional argument(s) for YaST. They can be
  --fullscreen and/or --noborder. By default it is empty.

* *X-SuSE-YaST-SortKey* String for sorting an application in the YaST Control
  Center. By default it is `zzzzz`.

* *X-SuSE-YaST-Geometry* Deprecated option. Do nothing.

* *X-SuSE-YaST-RootOnly* This entry defines whether the application will be
  visible only for root. Possible values are `true` and `false`.

## AutoYaST Specific Keys
AutoYaST have own keys that are also enclosed in X-SuSE-YaST namespace and have
Auto prefix:

* *X-SuSE-YaST-AutoInst* Specifies the module compatibility level with the
  AutoYaST. If not specified then no autoyast support is available, otherwise
  possible values are:

  * *all* Full auto-installation support, including the AutoYaST interface and
    writing configurations during autoinstall.

  * *write* Write only support. No integration into AutoYaST interface.

  * *configure* Configuration only support. Normally used only with parts related
    to installation like partitioning and general options which have no run-time
    module with support for auto-installation. Data is written using the common
    installation process and modules available in YaST2

* *X-SuSE-YaST-AutoInstPath* Deprecated option. Do nothing.

* *X-SuSE-YaST-AutoInstClient* Name of the client to call. By default it is
  `{module name}_auto`.

* *X-SuSE-YaST-AutoInstDataType* Data type of configuration section. Possible
  values are `list` and `map`. Default value is `map`.

* *X-SuSE-YaST-AutoInstResource* Specifies top level XML node under which is located
  module specific configuration in AutoYaST profile.

* *X-SuSE-YaST-AutoInstResourceAliases* Specifies a list of alternative names
  for the top level XML node. It is used to keep backward compatibility: for
  example, when migrating from `runlevel` to `services-manager`. Default value
  is empty.

* *X-SuSE-YaST-AutoInstRequires* Contains comma separated list of modules that
  are required to run before this module. By default it is empty.

* *X-SuSE-YaST-AutoInstMerge* Contains comma separated list of sections that
  can be handled by one module. For example users module can handle also groups
  and user\_defaults. By default it is empty.

* *X-SuSE-YaST-AutoInstMergeTypes* Contains comman separated list of section
  types. Useful only together with *X-SuSE-YaST-AutoInstMerge*. By default it
  is empty.

* *X-SuSE-YaST-AutoInstClonable* Specifies if module can be cloned. Possible
  values are `true` and `false`.

* *X-SuSE-YaST-AutoInstSchema* Specifies base name of schema file, including
  the rnc extension (Relax NG compact syntax). By default empty.

* *X-SuSE-YaST-AutoInstOptional* Specifies whether the element is optional in
  the schema. Except very basic parts it is almost always true. Possible
  values are `true` and `false`. By default `true`.

* *X-SuSE-YaST-AutoLogResource* Specifies whether data in profile can be logged.
  Useful if data contains sensitive information. Possible values are `true` and
  `false`. By default `true`.
