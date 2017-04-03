Introduction
============

Currently commonly used technique to create dialogs brings several
problems. The most important are:

-   Handling of all events is at one place, in one function, it is a
    little "spaghetti code"

-   Moving one widget from one dialog to another one brings the need to
    move also appropriate pieces of code used to set appropriate value
    to the widget and when leaving the dialog store the widget state to
    some variable

-   If one widget should be placed in multiple dialogs, then pieces of
    code related to the widget are duplicated

Because of this it is useful not to bind the handling routines to a
dialog, but to a widget.

If the widgets have separated pieces of code related to it one from each
other and all from the event loop, the code will be more transparent and
easier to maintain.

Also moving of a widget from one dialog to another one will mean minor
changes to the whole code, without need to check where the events
related to the widget are handled.

TODO
====

-   Testsuite

-   Documentation update:

    -   Examples screenshots

    -   Runnable examples

    -   Polish (better examples, using Popup:: module,...)

    -   Predefined useful routines

    -   Differences between description and real status

    -   Table Up/Down buttons handling

General concept
===============

The main goal is to provide a set of simple routines that can be used
for simple manipulation with widgets, easy moving of widgets between
dialogs and doing the common dialog stuff. All the routines are
contained in the CWM module.

The routines must be fully reentrant. This means, that no data may be
stored in the CWM module. Having no data in the CWM module allows not to
specify any fixed structure that would be required from the developer to
store the table data. But the calling component must provide a set of
callbacks that can be used by the CWM module to handle events that
happen on the dialog.

Each widget must be in described some way. The structure for widgets
description is a two-layer-map, where keys of the top layer are the
widget identifiers, their type must be string, the keys in the bottom
layer are the keys of widget properties.

    map<string,map<string, any> > widget_descr = $[
      "CWD_IN_ROOT_PATH" : $[
        "label" : _("&Current Directory in root's Path"),
        "widget" : `checkbox, 
      ,
      "CWD_IN_USER_PATH" : $[
        "label" : _("Curr&ent Directory in Path of Regular Users"),
        "widget" : `checkbox
      ],
    ]
        

The widgets description map defines two widgets, both are CheckBoxes,
one has the key "CWD\_IN\_ROOT\_PATH" and label "Current Directory in
root's Path", the other one has key "CWD\_IN\_USER\_PATH" and label
"Current Directory in Path of Regular Users".

This map is then used to create the dialog (in this case with 2
checkboxes). This means following steps:

1.  Place widgets to dialog

2.  Create the dialog

3.  Initialize the widgets

4.  Run the event loop, until the return value is \`next, \`back, or
    \`abort

5.  Get current values from widgets, store them

Developer must specify following:

-   The widgets that should be used (their keys), how to place them into
    the dialog

-   How to initialize them, how to validate them, how to store their
    settings

-   Dialog caption, help, what buttons are to be present,...

```
    // TODO: convert from ycp to ruby
    // include  here

    // function to initialize widgets
    global define void InitializeWidget (string key) {
        // let's suppose that the settings are stored in a map
        // named settings
        UI::ChangeWidget (`id (key), settings[key]:false);
    }

    // function for storing is similar
    global define void StoreWidget (string key, map event) {
        settings[key] = UI::QueryWidget (`id (`key), `Value);
    }

    define symbol runDialog {
        // create the basic layout
        term contents = `VBox (
        "CWD_IN_ROOT_PATH",
        "CWD_IN_USER_PATH"
        )

        map functions = $[
            "init" : InitializeWidget,
            "store" : StoreWidget,
        ];

        list<string> widget_names
            = [ "CWD_IN_ROOT_PATH", "CWD_IN_USER_PATH" ];

        string caption = _("Dialog Caption");

        // display and run the dialog
        symbol ret = CWM::ShowAndRun ($[
            "widget_names" : widget_names,
            "widget_descr" : widget_descr,
            "contents" : contents,
        "caption" : caption,
            "fallback_functions" : functions
        ]);

        return ret;
    }
```

Notes:

1.  init and store functions from ? cannot be used for radio button
    group widget (see ?), because it for getting currently selected
    radio button \`CurrentButton must be used instead of \`Value.

2.  Generic function will be available in CWM module for all internally
    supported widgets, task of the developer will be (typically) just
    a wrapper. This is still the future.

Placing widgets to the dialog (step 1)
======================================

Placing widgets to dialog means to create the dialog layout the normal
way, but instead of putting the widget descriptions just putting the
identifiers of the widgets. See ? for example.

Note, that when processing the term, only the VBox, HBox, Left, Right,
Frame, HWeight, and VWeight terms are processed into depth. If you need
some other container widgets, see ?.

Creating the dialog (step 2)
============================

The first task of CWM::ShowAndRun function is to display the dialog,
next tasks are described in following paragraphs. This function is just
a wrapper for other global functions, but in most cases this wrapper is
well usable. As a parameter it takes a map containing names of widgets
(the order is important if helps are used - see ?), map describing all
of the widgets, term describing contents of the dialog, dialog caption,
optionally labels of back, abort and next buttons and functions that are
used as fallback handlers and for confirming leaving dialog via Abort
event.

The first task of this wrapper is to create the "real" widgets from the
widgets description map. Then it replaces widget identifiers in the
dialog contents description with the "real" widgets and merges helps of
all widgets into one string that can be displayed in the dialog. After
it is done, the dialog contents is set and event loop is started. See ?.

Running the event loop (step 4)
===============================

Next task of the ShowAndRun function is to run the event loop. The
complete task means to nitialize the widgets, run while-loop, ask
UI::WaitForEvent () for an event, check if the event should finish the
dialog. If not, then continue (for now, see ?). Otherwise it will check
if the settings are to be stored. If yes, then validates the widgets
(see ?) and if everything is OK, then stores the settings of the
widgets. Returns the value for wizard sequencer.

This function needs to know:

-   what widgets are present in the dialog

-   how to initialize the dialog and how to store settings

Note, that storing settings doesn't mean to save them to some file, but
to grab them from the dialog and store them in some internal variables

Manipulation with widget values (steps 3, 5)
============================================

The way to initialize and store settings of a widget must be specified
by developer, because the generic engine cannot know anything about it.
Because of this the function running the event loop must know what
handlers it should call for initialization of the widgets and storing
their state. The Run function receives this information as a map. In
this map the keys are event names ("init" and "store") and values are
function references. The Init function must have as argument the widget
key (string), the store function must have as arguments the widget key
(string) and the evenet (map, the structure is the same as returned by
UI::WaitForEvent ()). The widget key is the key of the processed widget,
the event is the event that caused saving the settings. In most cases,
it can be ignored.

CWM Table concept
=================

Table widget and manupulation with data in this widget need same
behavior across whole YaST.

The CWM Table widget exists in order to make development of modules
using this UI concept consistent. It contains few most used buttons and
few automatic manipulation features.

The CWM Table widget allows Add/delete buttons, Edit button, Up/down
reorder buttons and custom button, which developer set to what they
need. Automatic edit action after double-click on table collumn. After
reorder is still selected same item, even if is moved. Reordering
handlers is called only if cell really can move in choosed direction.
Whole table Enable/Disable and automatic enable/disable reordering
button on collums which doesn't allow move in that direction.

Simple example for CWM Table
============================

This example show basic features of CWM table and also basic how to use.

```
    {
          import "CWM";
          import "CWMTable";
          import "Popup";
          import "Wizard";

          list<string> items = [];
          integer counter =0;

          void redraw_table(list<string> values){
            list<term> table_items = maplist(string s, values, {
              return `item(`id(s),s);
            });
            UI::ChangeWidget(`id(`_tw_table),`Items, table_items);
          }

          symbol add_handle(string key, map event){
            counter = counter +1;
            items = add(items,sformat("item %1",counter));
            redraw_table(items);
            return nil;
          }

          symbol edit_handle(string key, map event){
              Popup::Warning("edit");
            return nil;
          }

          symbol delete_handle(string key, map event){
              Popup::Warning("delete");
            return nil;
          }

          symbol updown_handle(string key, map event, boolean up, integer index){
            integer second = up ? (index-1):(index+1);
            y2milestone("updown with up %1 and index %2 and second %3",up,index,second);
            string value = items[second]:"";
            items[second] = items[index]:"";
            items[index] = value;
            redraw_table(items);
            return nil;
          }

          symbol custom_handle(string key, map event){
              Popup::Warning("Custom button");
            return nil;
          }

          map<string,any> table = CWMTable::CreateTableDescr(
            $[
              "add_delete_buttons" : true,
              "edit_button" : true,
              "up_down_buttons" : true,
              "custom_button" : true,
              "custom_button_name" : "Additional button",
              "custom_handle" : custom_handle,
              "header" : `header("id"),
              "edit":edit_handle,
              "delete":delete_handle,
              "add" : add_handle,
              "updown" : updown_handle,
            ],
            $[
              "help" : "",
            ]
          );

          Wizard::CreateDialog();
          symbol ret = CWM::ShowAndRun($[
            "widget_names" : ["table"],
            "widget_descr" : $[ "table" : table],
            "contents" : `VBox("table"),
            "caption" : "test"
          ]);
    }
```

CWM tutorial
============

How to create simple dialog using CWM
-------------------------------------

This section describes how to create a simple dialog using CWM.

### Create structure for holding the data

The easiest is to use a map, where key is name of configuration file
entry and value is its value.

```
    global map settings = $[
        "option1" : "value1",
        "option2" : "value2",
    ];
```

Additionally, this map can then be used as-is for exporting and
importing settings.

### Create generic initialization and settings storing functions

They can (in most cases) look the following way:

```
    global define void MyInit (string widget_id) ``{
        UI::ChangeWidget (`id (widget_id), `Value,
            settings[widget_id]:"");
    }

    global define void MyStore (string widget_id, map event) ``{
        settings[widget_id] = UI::QueryWidget (`id (widget_id),
            `Value);
    }
```

They don't do anything else than to get current value from the map and
change the widget appropriate way in case of init handler, and query the
widget value and store it to the settings map in case of the store
handler.

### Create the description of the widgets

It is a map with the same keys as the data map has, values are widget
description maps.

```
    map widgets = $[
        "option1" : $[
            "label" : _("The &first option"),
            "widget" : `textentry,
            "help" : _("Some clever help"),
        ],
        "option2" : $[
            "label" : _("The second option"),
            "widget" : `radio_buttons,
            "items" : [
                [ "item1", _("&This is label of the first radio button") ],
                [ "item2", _("&And the second radio button") ],
            ],
            "help" : _("Next clever help"),
            "init" : ``(MyModule::RadioButtonsInit ()),
            "store" : ``(MyModule::RadioButtonsStore ()),
        ],
    ];
```

If you use radio button group, you can't use above mentioned handlers,
because it is needed to use \`CurrentButton instead of \`Value. In this
case the init and store callbacks must be set if fallback handlers use
\`Value property.

### Create other needed callbacks

For radio button group the callback will look following way:

```
    global define void RadioButtonsInit (string widget_id) ``{
        UI::ChangeWidget (`id (widget_id), `CurrentButton,
            settings[widget_id]:"");
    }

    global define void RadioButtonsStore (string widget_id, map event) ``{
        settings[widget_id] = UI::QueryWidget (`id (widget_id),
            `CurrentButton);
    }
```  

### Create and run the dialog

It means to create dialog layout and call ShowAndRun with appropriate
parameters. This should be contents of the function that is called from
wizard sequencer.

```
    term contents = `VBox (
        "option1",
        `VSpacing (2),
        "option2"
    );

    map fallback_func = $[
        "init" : ``(MyModule::MyInit ()),
        "store" : ``(MyModule::MyStore ()),
    ];

    return CWM::ShowAndRun (["option1", "option2"], widgets,
        contents, _("Dialog caption"),
        Label::BackButton (), Label::NextButton (), fallback_func);
```  

### Whole example (runnable)

```
/usr/share/YaST2/modules/MyModule.ycp

    {

    module "MyModule";

    import "CWM";

    global map settings = $[
        "option1" : "value1",
        "option2" : "item1",
    ];

    global define void MyInit (string widget_id) ``{
        UI::ChangeWidget (`id (widget_id), `Value,
            settings[widget_id]:"");
    }

    global define void MyStore (string widget_id, map event) ``{
        settings[widget_id] = UI::QueryWidget (`id (widget_id),
            `Value);
    }

    global map widgets = $[
        "option1" : $[
            "label" : _("The &first option"),
            "widget" : `textentry,
            "help" : _("Some clever help"),
        ],
        "option2" : $[
            "label" : _("The second option"),
            "widget" : `radio_buttons,
            "items" : [
                [ "item1", _("&This is label of the first radio button") ],
                [ "item2", _("&And the second radio button") ],
            ],
            "help" : _("Next clever help"),
            "init" : ``(MyModule::RadioButtonsInit ()),
            "store" : ``(MyModule::RadioButtonsStore ()),
        ],
    ];

    global define void RadioButtonsInit (string widget_id) ``{
        UI::ChangeWidget (`id (widget_id), `CurrentButton,
            settings[widget_id]:"");
    }

    global define void RadioButtonsStore (string widget_id, map event) ``{
        settings[widget_id] = UI::QueryWidget (`id (widget_id),
            `CurrentButton);
    }

    global define symbol RunMyDialog () ``{

        term contents = `VBox (
            "option1",
            `VSpacing (2),
            "option2"
        );

        map fallback_func = $[
            "init" : ``(MyModule::MyInit ()),
            "store" : ``(MyModule::MyStore ()),
        ];

        return CWM::ShowAndRun (["option1", "option2"], widgets,
            contents, _("Dialog caption"),
            Label::BackButton (), Label::NextButton (), fallback_func);
    }

    }

/usr/share/YaST2/clients/myexample.ycp

    {
        import "MyModule";
        import "Wizard";

        Wizard::CreateDialog ();

        y2error ("Configuration before dialog: %1", MyModule::settings);

        MyModule::RunMyDialog ();

        y2error ("Configuration after dialog: %1", MyModule::settings);

        UI::CloseDialog ();
    }
```

Creating the table container
----------------------------

For getting the initial map the function map&lt;string,any&gt;
CWMTable::CreateTableDescr () can be used. It takes as a parameters a
map specifying the attributes of the table and a map specifying
additional settings that will be merged to the description map (see
below). Currently supported attributes are:

-   "add\_delete\_buttons" : boolean - if the Add and Delete buttons are
    wanted, set to true. If false, they will not be shown. Default (if
    key not present) is true.

-   "edit\_button" : boolean - if the Edit button is wanted, set
    to true. If false, it will not be shown. Default (if key
    not present) is true.

-   "up\_down\_buttons" : boolean - if the Up and Down (reorder) buttons
    are wanted, set to true. Otherwise, they will not be shown. Default
    (if not present) is false.

-   "custom\_button" : boolean - if the Custom button are wanted, set
    to true. Otherwise, they will not be shown. Default (if not present)
    is false.

-   "custom\_button\_name" : string - label for the Custom button.
    Default (if not present) is "Custom button".

-   "custom\_handle" : symbol(string,map) - handler for the
    Custom button. Default (if not present) is empty handler
    (do nothing).

-   "add" : symbol(string,map) - handler for the Add button. Default (if
    not present) is empty handler (do nothing).

-   "delete" : symbol(string,map) - handler for the Delete button.
    Default (if not present) is empty handler (do nothing).

-   "edit" : symbol(string,map) - handler for the Edit button. Default
    (if not present) is empty handler (do nothing).

-   "updown" : symbol(string,map, boolean, integer) - handler for the
    Updown button. Extra parameters is boolean if button is Up button
    and index of selected table collumn. Default (if not present) is
    empty handler (do nothing).

-   "header" : term - header term for table. It is mandatory key for
    CWM Table. Default (if not present) is nil and fail of widget.

For id of the widgets related to the table see ?.

Setting the widget map
----------------------

This is the same as for normal widgets. Set the keys according to your
needs. Only doesn't overwrite handle function, as it make all handling
stuff

Reserved UI events
==================

Some UI events (return values of UI::UserInput ()) are used internally
by the handling mechanism, and can't be used for other widgets.

The table widget contains following ids:

-   \`\_tw\_add - Add button - don't use although it is not present

-   \`\_tw\_edit - Edit button

-   \`\_tw\_delete - Delete button - don't use although it is not
    present

-   \`\_tw\_table - The table

-   \`\_tw\_up - The Up button

-   \`\_tw\_down - The Down button

-   \`\_tw\_custom - The Custom button

Dialogs using the Tab widget
============================

CWMTab is a widget for CWM that can be used for handling dialogs with
multiple tabs. Its tasks are following:

-   Switch the widgets (that are implemented via CWM) in the tab

-   Handle different GUIs (supporting or not supporting the
    Wizard widget)

The CWMTab widget is just a widget for CWM. It is limited to one
instance in a single dialog.

```
            map<string,map<string,any>> widgets = $[
               "w1" : $[...],
               "w2" : $[...],
               "w3" : $[...],
               "w4" : $[...],
               "w5" : $[...],
            ];

            widgets = (map<string,map<string,any>>) union (widgets, $[
                "tab" : CWMTab::CreateWidget ($[
    (1)             "tab_order" : ["t1", "t2", "t3"],
    (2)             "tabs" : $[
                        "t1" : $[
                            "header" : "Tab1",
                            "contents" : `VBox ("w1", "w2"),
                            "widget_names" : ["w1", "w2"],
                        ],
                        "t2" : $[
                            "header" : "Tab2",
                            "contents" : `HBox ("w3", "w4"),
                            "widget_names" : ["w3", "w4"],
                        ],
                        "t3" : $[
                            "header" : "Tab3",
                            "contents" : `Empty (),
                            "widget_names" : [],
                        ],
                    ],
    (3)             "initial_tab" : "t2",
    (4)             "widget_descr" : $[...],
    (5)             "tab_help" : _("TabWidgetHelp"),
                ])
            ]);

            CWM::ShowAndRun (
                ["w5", "tab"],
                widgets,
                `VBox ("w5", "tab"),
                _("Dialog caption"),
                Label::BackButton (),
                Label::NextButton (),
                $[...]
            );
```

Running the dialog with tab widget
==================================

Once the CWMTab widget is created, it can be used like any other CWM
widget. The only difference is that once the tab is switched, the
validation of the selected (before the switch) tab and store functions
of all widgets inside the tab is run. To run any such dialog, use
CWM::Run or CWM::ShowAndRun.

Creating the tab widget
=======================

To create the CMWTab widget, all the widgets that are on any of the tabs
must be created first (as they are one of the arguments of the
`CWMTab::CreateWidget` function. The way to go is to create map of all
other widgets first, then pass it to the functions that create the
CWMTab widget (or multiple CWMTab widgets), and merge these two
resulting maps.

The `CWMTab::CreateWidget` function has one argument, a map with all
attributes. The map has following keys.

-   `"tab_order" : list<string>` specifies the order of the tabs. It is
    a list of IDs of the tabs. For example, see ?, line (1).

-   `
    "tabs" : map<string,map<string,any>>
          ` is a map describing the tabs. See below for details.

-   `"initial_tab" : string` specifies the initial tab. Contains a
    string, ID of the initial tab. If not specified, the first tab is
    the default. For example, see ?, line (3).

-   `
    "widget_descr" : map<string,map<string,any>>
          ` is map describing all widgets in all tabs. See ? and
    following for additional information about this stuff.

-   `"tab_help" : string` contains optional help to the tab. It is
    displayed always, followed by the helps of widgets contained in the
    currently displayed tab.

-   `"fallback_functions" : map<string,any>` is a map specifying handler
    functions common for all widgets the tabs, if they are not specified
    for the individual tabs or widgets.

Specifying the tabs
===================

The tabs are specified as a map, where key is the tab ID and value is a
map describing the screen. The map must be of type
map&lt;string,map&lt;string,any&gt;&gt;. See ?, line (2) and following
for example.

For every screen description map, the following keys must be defined:

-   `"header" : string` is the tab header.

-   `"contents" : term` contains the term with the contents of the tab.
    All widget IDs are patched before the tab is displayed.

-   `"widget_names" : list<string>` contains the list of widget IDs of
    all widgets in the tab. The widgets will be handled in the same
    order as they are specified (also valid for help texts merging).

-   `"fallback_functions" : map<string,any>` is a map specifying handler
    functions common for all widgets in this tab, if they are not
    specified for the individual widgets.


TERMINOLOGY CONCEPT ADVANCED WIDGETS CWM\_TABLE TABLE\_POPUP
DIALOG\_TREE CWM\_TAB SERVICE\_START TSIG\_KEYS TUTOR
Dialogs based on the tree on the left (for English)
===================================================

DialogTree is a set of functions to help using CWM in the dialogs that
have the Tree widget on the left side. Its tasks are following:

-   Switch the dialogs (that are implemented via CWM)

-   Create the tree widget

-   Handle different GUIs (supporting or not supporting the
    Wizard widget)

```
            import "DialogTree";

            DialogTree::ShowAndRun ($[
    (1)         "screens" : $[
                    "s1" : $[
                "caption" : "Module X - Screen 1",
                "tree_label" : "Screen1",
                "widget_list" : [ "w1", "w2" ],
                "contents" : `VBox ("w1", "w2"),
            ],
                    "s2" : $[
                ...
            ],
                    "s3" : $[
                "caption" : "S3",
                ...
            ],
                ],
    (2)         "ids_order" : ["s1", "s2", "s3"],
    (3)         "initial_screen" : "s2",
                "widget_descr" : $[...],
    (4)         "back_button" : "",
                "next_button" : "NextButton",
                "abort_button" : "AbortButton",
                "functions" : $[...]
            ]);
```

Running the dialog
------------------

The dialog is started via one function call. This function processes all
needed operations, this means to open a new Wizard screen with the tree
on the left, runs event loop, and closes the newly open Wizard screen.

It takes one map as parameter. It contains all the needed information
for creating and running the dialog. Return value is a symbol for the
wizard sequencer.

Specifying the screens
----------------------

The screens are specified as a map, where key is the screen name and
value is a map describing the screen. The map must be of type
map&lt;string,map&lt;string,any&gt;&gt;. See ?, line (1) and following
for example.

For every screen description map, the following keys must be defined:

-   `"widget_names" : list<string>` contains the list of widget IDs of
    all widgets in the screen. The widgets will be handled in the same
    order as they are specified (also valid for help texts merging).

-   `"contents" : term` contains the term with the screen. All widget
    IDs are patched before the screen is displayed.

-   `"caption" : string` is the dialog caption. Will be used as the
    caption of the dialog when the screen is shown, and also as caption
    for the label to the tree widget the `"tree_item_label"` key
    is missing.

-   `"tree_item_label" : string` is the label of the screen in the
    tree widget. Is used only if the screens are ordered via a list
    (see below).

Ordering the screens
--------------------

The screens can be specified in two ways. The easier way is just to
provide a list of the screens. This way, all the screens are in the same
level.

The other way is to construct the tree via a callback function. This
way, the component developer can fully control how the tree is created.

If both list of screens and tree creator callback are specified, then
the callback is used.

### Flat list of screens

To make a flat list of screens in the dialog tree, just specify the key
`"ids_order"` and give it as value a list of strings containing the IDs
of all screens. See ?, line (2) for example.

### Multi-level tree of screens

To create a multi-level tree of screens, specify a callback that creates
the whole tree. To add items to the tree, use `Wizard::AddTreeItem`. The
`"tree_creator"` entry of the map must be a reference to a function of
type `list<map>()`. This function creates a list of widgets via the
`Wizard::AddTreeItem` and returns the output of the last call.

```
    define list<map> CreateWizardTree () {
        list<map> Tree = [];
        Tree = Wizard::AddTreeItem (Tree, "",  _("S1_label"), "s1");
        Tree = Wizard::AddTreeItem (Tree, "",  _("S2_label"), "s2");
        Tree = Wizard::AddTreeItem (Tree, "",  _("S3_label"), "s3");
        return Tree;
    }
```

Specifying the initial screen
-----------------------------

To specify the screen that will be shown after the dialog is displayed,
use the `"initial_screen"` key. Its value is a string contains the key
of the screen that is wanted to be displayed as the first. If not
specified and order of the screens is specified by the list, the first
is used. If not specified and the order is specified via a callback, the
default is undefined.

See ?, line (3) for example.

Widgets description map
-----------------------

To specify the widgets description map, use the `"widget_descr"`. See ?
and following for additional information about this stuff.

Button labels
-------------

To specify labels of the buttons on the bottom of the dialog, use the
keys `"next_button"`, `"back_button"` and `"abort_button"`. To hide any
particular button, just set the value to nil or empty string. In case of
NCurses UI (where no wizard widget is available), Help button is
automatically added. See ?, line (4) and following for example.

Fallback functions
------------------

To specify the fallback handlers of the widgets and functions for
handling abort and back events, use the `"functions"`. See ? and
following for additional information about this stuff.

Advanced Service Starting Widgets
=================================

CWMServiceStart is a set of widgets for CWM that can be used for setting
service start-on-boot and immediately start/stop a service. It handles
all the needed stuff via specified callback functions and via the
Service module.

Service start on boot
---------------------

To create a widget for setting if service should be started on boot, use
the CWMServiceStart::CreateAutoStartWidget () function. This function
has one argument (a map from string to any).

```
    boolean GetStartService () {...}
    boolean SetStartService (boolean start) {...}

    map<string,any> widget = CWMServiceStart::CreateAutoStartWidget ($[
        "get_service_auto_start" : DhcpServer::GetStartService,
        "set_service_auto_start" : DhcpServer::SetStartService,
        "start_auto_button" : _("Start DHCP Server when &Booting"),
        "start_manual_button" : _("Start DHCP Server &Manually"),
        "help" : _("Help to the widget..."),
    ]);
```

The parameters for service starting are following:

-   `
    "get_service_auto_start"
          ` is reference to a function with no parameter returning
    boolean value that says if the service is started. It is mandatory.

-   `
    "set_service_auto_start"
          ` is reference to a function with one boolean parameter saying
    if the service should be started at boot and return type void. It
    is mandatory.

-   `
    "get_service_start_via_xinetd"
          ` is reference to a function with no parameter returning
    boolean value that says if the service is started via xinetd. It is
    optional, if not present, the xinetd part of the widget is not shown

-   `
    "set_service_start_via_xinetd"
          ` is a reference to a function with one boolean parameter
    saying if the service should be started via xinetd and return
    type void. It is optional. If it is setting the value to true,
    "set\_service\_auto\_start" is set to false.

-   `
    "start_auto_button"
          ` contains the label of the "Start on boot" radio button. If
    not present, generic label is used.

-   `
    "start_manual_button"
          ` contains the label of the "Start only manually"
    radio button. If not present, generic label is used.

-   `
    "start_xinetd_button"
          ` contains the label of the "Start via xinetd" radio button.
    If not present, generic label is used. Used only if
    "get\_service\_start\_via\_xinetd" is defined.

-   `
    "help"
          ` contains the help to the widget. If not present, generic
    help is used. Note that if you change the labels of the buttons, you
    must specify the help. You can use
    CWMServiceStart::AutoStartHelpTemplate () and sformat to change only
    the button labels.

LDAP support
------------

To create a widget for enabling or disabling the LDAP support, use the
CWMServiceStart::CreateLdapWidget () function. This function has one
argument (a map from string to any).

```
    global define void SetUseLdap (boolean use_ldap) {...}
    global define boolean GetUseLdap () {...}

    map<string,any> widget = CWMServiceStart::CreateWidget ($[
        "get_use_ldap" : GetUseLdap,
        "set_use_ldap" : SetUseLdap,
        "use_ldap_checkbox" : _("Read DHCP Settings from &LDAP"),
        "help" : _("Help to the widget..."),
    ]);
```

The parameters for LDAP support are following:

-   `
    "get_use_ldap"
          ` is reference to a function with no parameter returning
    boolean value that says if LDAP support is enabled. If it is
    missing, LDAP check-box is not shown.

-   `
    "set_use_ldap"
          ` is reference to a function with one boolean parameter saying
    if the LDAP support should be active and return type void. If it is
    missing, LDAP check-box is not shown.

-   `
    "use_ldap_checkbox"
          ` contains the label of the "Use LDAP" check-box. If not
    present, generic label is used.

-   `
    "help"
          ` contains the help to the widget. If not present, generic
    help is used. Note that if you change the label of the check box,
    you must specify the help. You can use
    CWMServiceStart::EnableLdapHelpTemplate () and sformat to change
    only the check box label.

Immediate actions
-----------------

To create a widget for displaying service status and immediate starting
or stopping the service, use the CWMServiceStart::CreateStartStopWidget
() function. This function has one argument (a map from string to any).

```
    define void SaveAndRestart () {...}

    map<string,any> widget = CWMServiceStart::CreateStartStopWidget ($[
        "service_id" : "dhcpd",
        "service_running_label" : _("DHCP Server is running"),
        "service_not_running_label" : _("DHCP Server is not running"),
        "start_now_button" : _("&Start DHCP Server Now"),
        "stop_now_button" : _("S&top DHCP Server Now"),
        "save_now_action" : SaveAndRestart,
        "save_now_button" : _("Save and Restart DHCP Server &Now"),
        "help" : _("Help to the widget..."),
    ]);
```

The parameters for Immediate actions are following:

-   `
    "service_id"
          ` is the service name to be passed as argument for functions
    of the Service module. If it is missing, the service status and
    immediate actions buttons are not shown.

-   `
    "service_running_label"
          ` label to be displayed if the service is running. If it is
    missing, generic label is used.

-   `
    "service_not_running_label"
          ` label to be displayed if the service is not running. If it
    is missing, generic label is used.

-   `
    "start_now_button"
          ` label of the "Start service now" button. If it is missing,
    generic label is used.

-   `
    "stop_now_button"
          ` label of the "Stop service now" button. If it is missing,
    generic label is used.

-   `
    "save_now_action"
          ` is a reference to function without any parameters with void
    return type. Its task is to save all changes and restart
    the service. It is is missing, the "Save and restart service now"
    button is not shown.

-   `
    "start_now_action"
          ` is a reference to function, without any parameters with void
    return type. Its task is to restart the service. If it is missing,
    generic function using the `"service_id"` parameter is used.

-   `
    "stop_now_action"
          ` is a reference to function, without any parameters with void
    return type. Its task is to stop the service. If it is missing,
    generic function using the `"service_id"` parameter is used.

-   `
    "save_now_button"
          ` label of the "Save and restart service now" button. If it is
    missing, generic label is used.

-   `
    "help"
          ` contains the help to the widget. If not present, generic
    help is used. Note that if you change the labels of the buttons, you
    must specify the help. You can use
    CWMServiceStart::StartStopHelpTemplate () and sformat to change only
    the button labels.

Table/Popup concept
===================

Table/Popup superwidget is quite complex, that's why it has an extra
section.

The Table/Popup (TP for short) widget exists in order to make
development of modules using this UI concept easier. It contains
required widgets and helpful handling functions.

The CWM module contains widget for the whole table and most used popups.
Each option is described by a map specifying the type and behavior of
the table option.

In the following text distinguishing between "option id" and "option
key" is needed. See ?.

Basic table attributes
----------------------

Following text will refer on ?.

```
           map<string,map<string,any> > options = $[
               "popup1" : popup1_description_map,
               "popup2" : popup2_description_map,
           ];

           define list getTableContents (map<string,any> descr) {
               return ["a", "b", "c"]; // to display 3 items
                                       // in the table
           }

           define map<string,any> getGlobalTableWidget () {
    (1)        map<string,any> ret = CWM::CreateTableDescr (
                   $[
                       "add_delete_buttons" : true,
                       "edit_button" : true,
                       "up_down_buttons" : true
                   ],
                   $[
    (2)                "init" : TableInit,
    (3)                "handle" : CWM::TableHandleWrapper,
    (4)                "options" : options,
    (5)                "ids" : getTableContents,
                   ]
               );
               return ret;
           }
```


Notes:

1.  Many of the TP related values of the widget description map are used
    only by the predefined functions from the CWM module. If you use
    your own "init" and "handle" functions and they don't use the
    predefined function from the CWM module, you do not need to specify
    other table-related functions and attributes.

2.  All other keys that can be used by handlers can be defined according
    to the needs of the component developer.

3.  If you don't specify the "init" and "handle" functions, the defaults
    given as an argument in the ShowAndRun or Run function won't be
    used, but instead of them table-widget-specific defaults are used.

### Creating the table container (1)

For getting the initial map the function map&lt;string,any&gt;
CWM::CreateTableDescr () can be used. It takes as a parameters a map
specifying the attributes of the table and a map specifying additional
settings that will be merged to the description map (see below).
Currently supported attributes are:

-   "add\_delete\_buttons" : boolean - if the Add and Delete buttons are
    wanted, set to true. If false, they will not be shown. Default (if
    key not present) is true.

-   "edit\_button" : boolean - if the Edit button is wanted, set
    to true. If false, it will not be shown. Default (if key
    not present) is true.

-   "up\_down\_buttons" : boolean - if the Up and Down (reorder) buttons
    are wanted, set to true. Otherwise, they will not be shown. Default
    (if not present) is false.

-   "unique\_keys" : boolean - if true, then no key can be present in
    the table more times than once. Otherwise, it must be explicitly
    forbidden for such options. Default (if not present) is false.

For id of the widgets related to the table see ?.

### Setting the initialize and handle functions (2-3)

This is the same as for normal widgets. Set the functions according to
your needs.

There are predefined functions for this stuff. In most cases, they can
be used as they are, or via a wrapper. Typical case is that the
initialize function copies the data from the global storage to some
temporary variable (because of the Back button behavior), and then calls
the predefined initialization function.

CWM::TableInit () function asks for the list of entries that should be
displayed in the table, and for each of them gets the option label (for
the left column) and value (for the right column of the table). Then
changes the contents of the table.

CWM::TableHandle () function handles the events on the table. According
to the event and selected item it asks for a new option to add, displays
an option editing popup, calls the delete handler or makes the event
loop finish. It redraws whole table only if it is needed (reorder, add
or delete an item), otherwise only changes affected items.

Note that CWM::TableInit () and CWM::TableHandle () cannot be specified
directly in the widget description map as these functions have one
additional parameter. Use CWM::TableInitWrapper () resp.
CWM::TableHandleWrapper () instead.

### Transforming option key to option description map (4)

To operate the options, the TP mechanism requires the option description
maps (see ?). The options description map is stored under the "options"
key.

### The contents of the table (5)

Specify here the contents of the table that will be displayed. Should
return the list of option ids. The function has one argument, the table
widget description map.

Basic table option attributes
-----------------------------

Option description map describes the behavior of one single option in
the table. It describes its widget, user-readable description,
user-readable value, location of the value and many others.

Option description map is separated into 2 parts. One contains keys
related to the table, the other one contains keys related to the option
popup.

Note: The smallest possible option description map is empty map. In this
case widget type is (by default) text entry, and instead of option
specific handlers (init, store, summary) the table's fallback handlers
are used as label the option name is used.

Following text will refer to ?.

```
    define string EnableServiceSummary (
        any opt_id, string opt_key)
    {
        if (settings["enable_service"]:false)
        {
            return _("Yes");
        }
        else
        {
            return _("No");
        }
    }

    define void EnableServiceInit (
        any opt_id, string opt_key)
    {
        UI::ChangeWidget (`id ("enable_service"), `Value,
            settings["__run_dhcp_server"]:false);
    }

    define void EnableServiceStore (
        any opt_id, string opt_key)
    {
        settings["__run_dhcp_server"]
            = UI::QueryWidget (`id ("enable_service"), `Value);
    }

    map<string,map<string,any> > options = $[
        "enable_service" : $[
        "table" : $[
    (1)         "label" : _("Enable DHCP server at boot time"),
    (2)         "summary" : EnableServiceSummary,
            ],
            "popup" : $[
    (3)         "init" : EnableServiceInit,
    (4)         "store" : EnableServiceStore,
    (5)         "widget" : `checkbox,
            ],
        ],
    ];
```

This example describes a simple option, that is represented by a check
box in the popup, has label "Enable DHCP server at boot time" and own
functions to initialize the check box after the popup is displayed,
store its status before the dialog hides after user clicked the OK
button, and generate the text for the right column of the table.

### Option label (1)

Option label specifies the label that will be displayed in the left
column of the table. Contains a (translated) string. If not present, the
option name is used instead.

### Summary function (2)

Summary function is used to get the (localizable) value for the right
column of the table. The "summary" key contains a function reference,
the function has two arguments - option id (any) and option key
(string), returns the value description for the table (string).

### Popup initialization (3)

The initialization function is called immediately after the popup is
displayed. Its task is to set appropriate value to the displayed widget.
Has two parameters - option id (any) and option key (string), return
value is void.

### Popup state storing (4)

The state storing function is called before the popup is closed via the
"OK" button. Its task is to grab the values from the popup and store
them to appropriate variables. Has two parameters - option id (any) and
option key (string), return value is void.

### Widget specification (5)

The widget specification works the same way as for dialog widgets. See ?
for list of possible widgets.

Advanced table attributes
-------------------------

### Fallback handlers

For table entries that have no own handlers, fallback handlers init,
store, and summary can be defined in the table description map. They are
defined in the "fallback" submap of the widget description map. Init and
store are related to popups, summary to table entries. See ?.

Note, that because the TP mechanism doesn't know where the data are
stored, fallback handler or option-specific handler for every option
must be defined.

```
    define map<string,any> getTableWidget () {
        map<string,any> ret = CWM::CreateTableDescr (
            $[],
            $[
                "fallback" : $[
                    "init" : commonPopupInit;
                    "store" : commonPopupSave;
                    "summary" : commonTableEntrySummary;
                // other options of the widget description map come here
                ],
            ]
        );
        return ret;
    }
```

### Deleting entry

For deleting an entry from the table (via the Delete button below it),
this handler is used. The handler has two parameter - the option id
(any) and the option key (string). If return value is true, then it is
assumed, that the entry was really deleted, and the table should be
redrawn. Otherwise, the table is left as is.

```
    define map<string,any> getTableWidget () {
        map<string,any> ret = CWM::CreateTableDescr (
            $[],
            $[
                "option_delete" :
                    commonTableEntryDelete,
                // other options of the widget description map come here
            ]
        );
        return ret;
    }
```

### Items for adding

If the table has the "Add" button, this contains the options to be
offered in the combo that can be added. The add\_unlisted entry can
specify if the combo box will be editable and any option can be entered
(if true), or the combobox will not be editable, and the option list is
fixed (if false). If not present, default is true.

```
    define map<string,any> getTableWidget () {
        map<string,any> ret = CWM::CreateTableDescr (
            $[],
            $[
                "add_items" : ["a", "b", `item (`id ("c"), "C") ],
                "add_unlisted" : false,
                // other options of the widget description map come here
        ]
        );
        return ret;
    }
```

This will allow to add only these 3 entries.

### Transforming option id to option key

If you don't use the 1:1 mapping between the option id and option key,
set the function that will transform the option id to option key. Before
evaluation, the table description map and the option id will be added to
the term . If not present, then option key is the same as option id.

```
    define string id2key (map<string,any> descr, any opt_id) {
        return opt_id; // 1:1 translation
    }

    define map<string,any> getTableWidget () {
        map<string,any> ret = CWM::CreateTableDescr (
            $[],
            $[
                "id2key" : d2key,
                // other options of the widget description map come here
            ]
        );
        return ret;
    }
```

### Specifying reordering function

If the order of items makes sense, then it is needed to specify a
function that changes the order of items in appropriate structures. This
function must be specified (if Up and Down buttons are to be displayed)
via the "option\_move" key in the table description map as a term. Has
parameters option id (any), option key (string) and direction (symbol
\`up or \`down). Must return true if the order was really changed (in
order to redraw the table).

```
    global define any optMove (any opt_id, string opt_key, symbol direction) {
        // modify internal structure appropriate way here
        return true;
    }

    global define map<string,any> getTableWidget () {
        map<string,any> ret = CWM::CreateTableDescr (
            $[],
            $[
                "option_move" : optMove;
                // other options of the widget description map come here
            ]
        );
        return ret;
    }
```

Advanced table option attributes
--------------------------------

### Table - related

#### Optional values

An entry in the table may be mandatory (and not be possible to be
deleted), or optional (and be possible to be deleted). The "optional"
key in the "table" submap specifies if the entry is allowed be removed.
If not present, default is true.

#### Ordering

It is possible to allow or forbid to move the option in the table up or
down. If the "ordering" key in the "table" submap is set to true
(default), then it is possible to move this option up or down.
Otherwise, the up and down buttons are grayed if this option is
selected. If the up and down buttons aren't displayed at all (see ?),
this option is ignored.

#### Duplicate keys

In some cases it makes sense to have one key in the table more than
once. It usually doesn't make too much sense for all keys, but only for
some. If the "unique\_key" of the "table" submap is set to true, the key
can be present in the map only once. Default if false (if multiple
occurrences of a key in map aren't disabled at all, see ?).

#### Label as function

If the option label isn't static, a function that creates it can be
specified. Specify in the "table" submap the key "label\_func" and set
it as value a function that takes as arguments the widget id (any),
widget key (string) and returns the label to the table (string).

#### Option handlers

In some cases the generic behavior (display popup, initialize it, handle
UI events and store the settings) may be unusable. If the "handle" key
in the "table" submap is specified, then if the table entry is selected
and Edit button clicked, then it is evaluated instead of the usual
handling of this event.

It can be two types. If it is a symbol, then the symbol is immediately
returned and the event loop finishes.

If it is a function reference, then it is called with parameters option
id (any), option key (string) and event that occurred (map). If returned
value is nil, then the event loop continues with handler of next widget
in the dialog or next event. If a symbol is returned, then the event
loop is finished, and returned value passed to wizard sequencer. If a
special symbol \`\_tp\_normal is returned, then normal generic handler
is run (displays a popup, initializes it, handles the events, store the
settings via appropriate handlers).

### Popup related

#### Help

If it is needed, it is possible to enter some help. The help is
displayed as a label above the option, and is specified as a string with
the "help" key in the "popup" submap.

#### Popup validating

Popup validation works the same way as the validation of normal widget.
See ? for details. The validation parameters must be defined in the
"popup" submap. The only difference is in parameters added to the
validation function before evaluation, parameters option id, option key
and action are added before evaluation.

#### UI events handling

To handle the UI events, use the "handle" key in the "popup" submap. It
must contain a function with parameters option id (any), option key
(string) and event (map, return value of UI::WaitForEvent). It is called
every time the UI::WaitForEvent returns. If not set, no handling
function is run.

#### Widget attributes

The popup widgets have the same attributes as the dialog widgets. For
more information see ?.

The only difference is that if the "label" key is not present in the
"popup" submap, the "label" key in the "table" submap is used, and if it
isn't present, then generic label "Value" is used. Remember, that the
"label" in the "table" submap shouldn't have any keyboard shortcut, but
the "label" in the "popup" submap should have some.

The "custom\_widget" entry has the same behavior as for dialog widgets,
see ?.

More complex option example
---------------------------

    map popups = $[
      "loader_type" : $[
        "table" : $[
          // label, that will be shown in the table
          "label" : _("Boot Loader Type"),
          // will return "GRUB" if grub is selected,
          // "LILO" if lilo is selected,...
          "summary" : loaderTypeSummary,
          // some bootloader must be always selected 
          "optional" : false,
          // the order of this entry in global
          // options doesn't make sense
          "ordering" : false,
          // bootloader can't be specified more than once
          "unique_key" : true,
          // not needed, nil is default value,
          // really has a normal popup
          "handle" : nil,
        ],
        "popup" : $[
          // sets appropriate radio button selected
          "init" : loaderTypeInit,
          // queries for the active radio button, stores the result 
          "store" : loaderTypeSave,
          // no validation is done, validation always successful
    //    "validate" : not needed
          // generic widget is used, this option is not needed
    //    "custom_widget" : not needed
          // simple help for the user
          "help" : _("Select bootloader you want to use"),
          // label of the widget in the popup. Will be shown
          // as the title of the frame holding radio buttons
          "label" : _("&Boot Loader Type"),
          // set of radio buttons is shown
          "widget" : `radio_buttons,
          // specification of the radio buttons
          "items" : [ [ "grub", "&GRUB" ], [ "lilo", "&LILO" ]]
        ]
      ],
      ....
    ]

     

Misc
----

### Separator

If a table separator is wanted (in order to make the table more
transparent), it should be specified as an option with the key
"\_\_\_\_sep". Options with this key are automatically skipped when
selected. You can modify the label of the option in order to display the
separator the way you want to. It behaves like a normal option, with the
only difference that it isn't selectable.

Reserved UI events
------------------

Some UI events (return values of UI::UserInput ()) are used internally
by the handling mechanism, and can't be used for other widgets.

In popups following widget ids are reserved:

-   \`\_tp\_ok - the OK button

-   \`\_tp\_cancel - the Cancel button

The table widget contains following ids:

-   \`\_tp\_add - Add button - don't use although it is not present

-   \`\_tp\_edit - Edit button

-   \`\_tp\_delete - Delete button - don't use although it is not
    present

-   \`\_tp\_table - The table

-   \`\_tp\_up - The Up button

-   \`\_tp\_down - The Down button

-   \`\_tp\_table\_rp - The replace point on the right bottom of the
    table superwidget

Additionally, if some popup widget has the "t\_no\_popup" not nil,
return values of the evaluation of the term may be also results of the
actions on the table widget.

Terminology
===========

  ------------------ -----------------------------------------------------
  Widget             Basic element of dialog. In most cases a check box,
                     radio button, text entry,... but also a more complex
                     widget (called superwidget in this document).

  Widgets            Map describing widgets used by CWM. Contains
  description map    information in a fixed format, but developer can add
                     additional keys according to his needs, their types
                     and meaning are not specified in this document.

  Superwidget        A group of widgets, that build one entity, one
                     without the other one doesn't make too much sense.
                     Simple case can be eg. a widget, which consists of
                     multiple radio buttons, one radio button group, and
                     typically also a frame.

  Table              Special superwidget, is to see eg. in the YaST2
                     bootloader module. Consists from the Table (in
                     meaning of \`Table basic widget), 3 push buttons
                     (Add, Edit, Delete) bottom left, a replace point
                     bottom right, and optionally Up and Down buttons
                     right from the table.

  Table option       One line in the table, representing some kind of
                     information.

  Option id          Identifier of an option. Must be unique in the whole
                     table.

  Option key         Identifier of the option type. Handlers are related
                     to the option key. Multiple options with the same
                     option key can be present in one table. CWM must know
                     how to translate option id to option key.

  Options            Map describing options of one table. Contains
  description map    information in a fixed format, but developer can add
                     additional keys according to his needs, their types
                     and meaning are not specified in this document.

  Popup              A popup that is shown when user clicks the Edit
                     button when some table option is selected. Is used to
                     edit the value of the table option.

  Handler            Callback function used by CWM module to make a well
                     defined operation on the widget. Handlers can be
                     sorted according to operation they handle, and
                     according to entity it is related to.

  Widget handler     Handler related to a widget in a dialog. "init",
                     "store", "handle" and "validate" handlers are
                     possible for the dialog widgets.

  Table handler      Widget handler for the Table superwidget.
                     Additionally, the "option\_delete" handler is defined
                     to delete the options from the table.

  Option handler     Handler of an option in the table. Using this handler
                     it is possible to change the default behavior of the
                     option (displaying a popup). Only "handle" and
                     "summary" handlers are possible for table options

  Popup handler      Handler related to a popup. "init", "store", "handle"
                     and "validate" handlers are possible for the popups.

  "init" handler     Used to initialize the widget, typically to fetch
                     settings from some structures, and set appropriate
                     value to the widget.

  "store" handler    Used to store the settings of the widget. Typically
                     gets the state of the widget, and stores it to some
                     internal variables.

  "handle" handler   Used to handle events on the widgets. Is called every
                     time the UI::UserInput () returns, if the widgets
                     wants to handle this event.

  "validate\_functio Called before the widget settings are store, to
  n"                 ensure that the settings are consistent. Used if
  handler            validation by function is set for the widget.


  ------------------ -----------------------------------------------------

  : Terminology

TSIG Keys Management
====================

CWMTsigKeys is a widget for CWM that can be used for management of TSIG
keys (that are used for DDNS authentication between DNS and DHCP
servers). It handles all needed functionality.

Additionally, the module provides functions that can be very useful for
modules that manipulate TSIG keys.

To create the service start widget, use the `CWMTsigKeys::CreateWidget`
function. As parameter, it takes a map with settings needed to create
the widget and handle settings on it, returns a map with the widget for
CWM. This map can be used the same way as maps for other widgets.

```
            global define void SetKeysInfo (map<string,any>) {...}
            global define map<string,any> GetKeysInfo () {...}

            map<string,any> widget = CWMTsigKeys::CreateWidget ($[
                "get_keys_info" : DhcpServer::GetKeysInfo,
                "set_keys_info" : DhcpServer::SetKeysInfo,
            ]);
```

Reading and storing TSIG Keys
-----------------------------

The parameters for service starting are following:

-   `
    "get_keys_info"
          ` is reference to a function with no parameter returning a map
    with following keys:

    -   `
        "removed_files"
              ` lists of strings, file names of files with TSIG keys
        that were removed during previous runs of the dialog (just copy
        of the same value that passed to "set\_keys\_info". May
        be missing.

    -   `
        "new_files"
              ` lists of strings, file names of files with TSIG keys
        that were added during previous runs of the dialog (just copy of
        the same value that passed to "set\_keys\_info". May be missing.

    -   `
        "tsig_keys"
              ` is a list of maps of TSIG keys. Each map is of type
        string-&gt;string, with keys "key" and "filename" and values key
        ID resp. file name of the file with the key.

    -   `
        "key_files"
              ` is an alternative to "tsig\_keys". Is used only if
        "tsig\_keys" is missing. Contains a list of strings, file names
        of files with TSIG keys.

    It is mandatory. "key\_files" is used only if "tsig\_keys"
    is missing.

-   `
    "set_keys_info"
          ` is reference to a function with one map parameter containing
    information about TSIG keys and return type viod. The map is of
    type string-&gt;any. should be started at boot and return type void.
    It is mandatory.

    The map contains all keys mentioned in
    "get\_keys\_info" odcumentation.

Other stuff
-----------

Other supported parameters are following:

-   `
    "list_used_keys"
          ` is a reference to a function of type `list<string>()`
    returning a list of at the moment used TSIG keys. The list is used
    to prevent used TSIG keys from being deleted. If not present, all
    keys may get deleted.

-   `
    "help"
          ` the complete help for the widget. If it is not present,
    generic help is used (button labels are patched into the help texts.

Notes on the widget
-------------------

If "removed\_files" or "new\_files" is not present in output of
"get\_keys\_info", then in "set\_keys\_info" the value contains keys
that were added/removed during the one run of the dialog. Otherwise,
added/removed keys are added to the appropriate variables. The widget
takes care that no key is in both of the variables.

If keys are specified via "key\_files" and some of the files don't
contain any key, these files aren't specified in the variable in the
"set\_\_keys\_info". Such files aren't mentioned in "removed\_files".

Misc. functions
---------------

The CWMTsigKeys module also offers several functions tightly boud to the
TSIG keys. Following functions are available:

-   `
    list<string> AnalyzeTSIGKeyFile (string filename)
          ` Analyzes the file and return list of all TSIG Key IDs found
    in the file.

-   `
    list<string> Files2Keys (list<string> filenames)
          ` Analyzes all of the files and returns a list of all TSIG key
    IDs fount in the files.

-   `
    list<map<string,string>> Files2KeyMaps
    (list<string> filenames)
          ` Analyzes the files and returns a list of the maps of all
    TSIG keys found in the files. A TSIG Key map (string-&gt;string)
    contains keys "key" and "filename" with values Key ID resp. file
    name of the file.


Available widgets
=================

Note: in all examples additional parameters can be present, see ?.

Empty Widget
------------

Displays nothing but still can handle events.

widget

:   \`empty

<!-- -->

    map<string,map<string,any> > widget_descr = $[
      "HANDLER" : $[
        "widget" : `empty,
        "handle" : GlobalEventhandler,
      ],
    ]

Check Box
---------

widget

:   \`checkbox

label

:   The checkbox label, shown to the right of it

<!-- -->

    map<string,map<string,any> > widget_descr = $[
      "CHECKBOX" : $[
        "label" : _("&Checkbox"),
        "widget" : `checkbox,
      ],
    ]

Combo Box
---------

Parameters:

-   "widget" : must be set as \`combobox

-   "label" : label shown above the combobox

-   "items" : list of two-item-lists of \[id, label\], each item
    represents one item of the Combobox. Both id and label must
    be strings.

<!-- -->

    map<string,map<string,any> > widget_descr = $[
      "COMBOBOX" : $[
        "label" : _("&Combobox"),
        "widget" : `combobox,
        "items" : [
            [ "item1", _("Label1") ],
            [ "item2", _("Label2") ]
        ],
      ],
      ....
    ]

Selection Box
-------------

Parameters:

-   "widget" : must be set as \`selection\_box

-   "label" : label shown above the selection\_box

-   "items" : list of two-item-lists of \[id, label\], each item
    represents one item of the selection box. Both id and label must
    be strings.

Usage is similar to Combo Box.

MultiSelection Box
------------------

Parameters:

-   "widget" : must be set as \`multi\_selection\_box

-   "label" : label shown above the selection box

-   "items" : list of two-item-lists of \[id, label\], each item
    represents one item of the selection box. Both id and label must
    be strings.

Usage is similar to Combo Box.

Text Entry
----------

Parameters:

-   "widget" : must be set as \`textentry

-   "label" : label shown above the text entry

-   "valid\_chars" : list of characters that are valid for the text
    entry, if missing, all characters are valid

<!-- -->

    map<string,map<string,any> > widget_descr = $[
      "TEXTENTRY" : $[
        "label" : _("&TextEntry"),
        "widget" : `textentry,
        "valid_chars" : "0123456789AaBbCcDdEeFfXx",
            // for hexadecimal numbers
      ],
      ....
    ]

Int Field
---------

Parameters:

-   "widget" : must be set as \`intfield

-   "label" : label shown above the int field

-   "minimum" : minimal value of the int field, if not set, then 0 is
    used

-   "maximum" : maximal value of the int field, if not set, then 2\^31 -
    1 is used

<!-- -->

    map<string,map<string,any> > widget_descr = $[
      "INTFIELD" : $[
        "label" : _("&Intfield"),
        "widget" : `intfield,
        "minimum" : -1,
        "maximum" : 10,
      ],
      ....
    ]

Radio Buttons
-------------

Parameters:

-   "widget" : must be set as \`radio\_buttons

-   "label" : label of the frame around the radio buttons

-   "items" : list of two-item-lists of \[id, label\], each item
    represents one radio button. Both id and label must be strings.

-   "hspacing" : FIXME

-   "vspacing" : FIXME

-   "orientation" : says if the radio buttons should be oriented
    horizontally or vertically. Allowed values are \`horizontal and
    \`vertical, default is \`vertical. FIXME: NOT IMPLEMENTED

<!-- -->

    map<string,map<string,any> > widget_descr = $[
      "RADIO_BUTTONS" : $[
        "label" : _("RadioButtonGroup"),
        "widget" : `radio_buttons,
        "items" : [
            [ "item1", _("&Label1") ],
            [ "item2", _("La&bel2") ],
        ],
        "orientation" : `horizontal,
      ],
      ....
    ]

Radio Button
------------

This is the elementary radio button, for use in complex layouts where
radio\_buttons is not enough.

Parameters:

-   "widget" : must be set as \`radio\_button

-   "label" : label shown to the right of the radio button

<!-- -->

    map<string,map<string,any> > widget_descr = $[
      "RADIOBUTTON" : $[
        "label" : _("&Radio Button"),
        "widget" : `radio_button,
      ],
    ]

Push Button
-----------

Parameters:

-   "widget" : must be set as \`push\_button

-   "label" : push button label

<!-- -->

    map<string,map<string,any> > widget_descr = $[
      "PUSH_BUTTON" : $[
        "widget" : `push_button,
        "label" : _("Push Button"),
      ],
      ....
    ]

Menu Button
-----------

widget

:   \`menu\_button

label

:   The menu button label

items

:   List of string pairs \[id, label\] for the menu items

<!-- -->

    map<string,map<string,any> > widget_descr = $[
      "MENUBUTTON" : $[
        "label" : _("&Advanced"),
        "widget" : `menu_button,
        "items" : [
            [ "FIXIT", _("&Fix Everything") ],
            [ "CRASH", _("&Crash now") ]
        ],
      ],
      ....
    ]

Multi-Line Edit Box
-------------------

Parameters:

-   "widget" : must be set as \`multi\_line\_edit

-   "label" : title of the multiline widget

<!-- -->

    map<string,map<string,any> > widget_descr = $[
      "MULTI_EDIT" : $[
        "widget" : `multi_line_edit,
        "label" : _("Text editor"),
      ],
      ....
    ]

Rich Text Field
---------------

Parameters:

-   "widget" : must be set as \`richtext

<!-- -->

    map<string,map<string,any> > widget_descr = $[
      "RICH_TEXT" : $[
        "widget" : `richtext,
      ],
      ....
    ]

> **Note**
>
> To fill the contents of the rich text, initialization function calling
> `UI::ChangeWidget` must be defined.

Custom widget
-------------

Parameters:

-   "widget" : must be set as \`custom

-   "custom\_widget" : term describing the widget

<!-- -->

    map<string,map<string,any> > widget_descr = $[
      "PUSH_BUTTON" : $[
        "widget" : `custom,
        "custom_widget" : `PushButton (
                                `id (`push_button),
                                _("Push Button")),
      ],
      ....
    ]

Widget Description Map Reference
--------------------------------

widget

:   Kind of the widget. See ?. \#\# The term to be passed to UI.

    All

    symbol \#\# Internal.

    FIXME use a different key for the resulting term.

ui\_timeout

:   How long to wait for user input before an idle event is generated
    (FIXME which).

    All

    integer

init

:   Function that initializes widgets. The parameter is the id of
    the widget. All widgets are initialized before the event loop.

    All

    void (string)

    See: fallback\_functions in ShowAndRun

handle

:   Function that handles events. All widgets that have this function
    defined are handled on each event. The parameters are the id of the
    widget and the event map. It should return nil to continue
    processing or a symbol to be returned from the dialog.

    All

    symbol (string, map)

    See: fallback\_functions in ShowAndRun

handle\_events

:   Limits calling of the handle function to a certain list of
    widget ids.

    All

    list &lt;any&gt;

store

:   Function that saves the values of widgets. The parameters are the id
    of the widget and a map of the event that caused the dialog to end.
    All widgets are saved after the event loop unless \`back or \`abort
    is returned.

    All

    void (string, map)

    See: fallback\_functions in ShowAndRun

cleanup

:   Function that cleans up widgets. The parameter is the id of
    the widget. All widgets are cleaned up before the dialog ends, after
    they (would) have been saved.

    All

    void (string)

    See: fallback\_functions in ShowAndRun

custom\_widget

:   A UI term ready to be placed to the dialog.

    widget == \`custom

    term

widget\_func

:   A function that returns a UI term ready to be placed to the dialog.

    widget == \`func

    term ()

opt

:   Options to be placed to the \`opt term of the widget.

    All except \`empty, \`custom and \`func

    list &lt;any&gt;

label

:   Widget label.

    All except \`empty, \`custom and \`func (and why \`richtext?)

items

:   List of items for some widgets, in pairs \[id, label\].

    \`combobox, \`selection\_box, \`multi\_selection\_box,
    \`radio\_buttons, \`menu\_button

minimum

:   Minimum value for integer fields.

    \`intfield

    integer

maximum

:   Maximum value for integer fields.

    \`intfield

    integer

hspacing

:   Horizontal padding and spacing between the radio buttons.

    \`radio\_buttons

    integer (FIXME float?, not validated)

vspacing

:   Vertical padding and spacing between the radio buttons.

    \`radio\_buttons

    integer (FIXME float?, not validated)

validate\_type

:   \`function, \`function\_no\_popup, \`regexp\` or \`list. All widgets
    that have this defined are validated before the dialog would be
    successfully exited and saved. Actually not all, only until the
    first failure.

    All

    symbol

validate\_function

:   Function that validates the widget. The parameters are the widget
    key and the map of the event that causes the dialog to exit. In case
    of validation failure, for \`function, it should pop up an error by
    itself , and for \`function\_no\_popup, CWM will pop up an error
    (using validate\_help if present).

    validate\_type == \`function or \`function\_no\_popup

    boolean (string, map)

validate\_condition

:   validate\_type == \`regexp or \`list

    string or list

    FIXME, does not seem to work because of \`\_tp\_value

validate\_help

:   validate\_type != \`function

    string

    Contents of error popup shown if a widget fails to validate

help

:   Widget help

    All

    string

no\_help

:   If present, no error about missing help will be given. FIXME: use
    help:nil instead

    All

    any


Advanced stuff
==============

Helps
=====

Help is usually related to a widget. There is no reason not to add help
as attribute of a widget description, and move it with the widget
between dialogs. Each widget description map can have a "help" key, that
specifies the help related to the widget.

    map<string,map<string,any> > widget_descr = $[
      "CWD_IN_ROOT_PATH" : $[
        "label" : _("&Current Directory in root's Path"),
        "widget" : `checkbox,
        "help" : _("This is help for the widget"),
      ],
      .....
    ]

    list<string> widget_names = // see 
     

If you need to add a help that is not bound to any widget, see ?

If you don't want to add help to a widget and want to avoid errors in
the log, add a key `"no_help"` with any value to the widget instead.

    map<string,map<string,any> > widget_descr = $[
      "CWD_IN_ROOT_PATH" : $[
        "label" : _("&Current Directory in root's Path"),
        "widget" : `checkbox,
        "no_help" : true,
      ],
      .....
    ]
     

Widget validation
=================

Especially in case of more complex widgets, some validation may be
important to avoid storing any inconsistent settings. Widget validation
can be done two ways.

First means validation function. It can be specified in the widget
description map. It returns a boolean value, if true, validation is OK,
false if validation failed. In case of failure it is task of the
validation function to inform user where the problem is. The validation
function has as argument the widget key and the event that caused the
validation. Validation type must be set to \`function.

Second possibility is to validate widget by type. Supported are
validation by a regular expression (validation type "regex") and a by
list (validation type "enum"). This validation is usable eg. for
TextEntry and ComboBox widgets). Validation type must be set to \`regex
or \`enum, validate\_typespec must contain a string with regular
expression, resp. list of valid strings. If validation by type fails and
"validate\_help" key is defined in the widget description map, then the
value of the "validate\_help" entry in the map is shown to user,
otherwise generic error message is shown.

If no validation type is defined, validation is always OK.

```
    define boolean MyValidateWidget (string key, map event) {
        boolean value = UI::QueryWidget (
            `id (key),
            `Value);
        if (! value)
            return true;
        else
        {
            if (UI::YesNoPopup (_("You decided insert CWD to root's path.
    Are you sure?")))
                return true;
            else
            {
                UI::SetFocus (key);
                return false;
            }
        }
    }

    map<string,map<string,any> > widget_descr = $[
      "CWD_IN_ROOT_PATH" : $[
        "widget" : `checkbox,
        "label" : _("&Current Directory in root's Path"),
        "validate_type" : `function,
        "validate_function" : MyValidateWidget,
      ],
      "TEXT_ENTRY" : $[
        "widget" : `textentry,
        "label" : _("&TextEntry"),
        "validate_type" : `regex,
        "validate_typespec" : "[a-zA-Z]+",
        "validate_help" : _("Only a-z and A-Z are allowed.
    String cannot be empty");
      ],
      "TEXT_ENTRY_2" : $[
        "widget" : `textentry,
        "label" : _("Text&Entry 2"),
        "validate_type" : `enum,
        "validate_typespec" : ["Word1", "Word2"],
      ],
    ]
```

Widget options
==============

In some cases it is useful to specify the option of the widget, eg.
\`opt(\`notify) is quite often used. The "opt" key of the widget
description map can contain the list of options of the widget. If not
set, the options are empty ( \`opt () ).

    map<string,map<string,any> > widget_descr = $[
      "CWD_IN_ROOT_PATH" : $[
        "label" : _("&Current Directory in root's Path"),
        "widget" : `checkbox,
        "opt" : [ `notify , `immediate],
      ],
    ]
     

Widget-specific init/store functions
====================================

Some (super)widgets (see ?) can require their own function for
initializing themselves, or storing their settings. These functions must
be set in the widget description map. They are specified using key
"init" for the initialization function, and "store" for the storing
functions. The functions are defined as function refernces. The init
function must have as an argument the widget key (string), the store
function must have two arguments - widget key (string) and event that
caused storing the settings (map). If widget doesn't have any "init" or
"store" function specified, generic one is used (see ?).

```
    define void MyInitializeWidget (string key) {
        boolean value = this_global_variable;
        UI::ChangeWidget (`id (key), `Value, value);
    }

    define void MyStoreWidget (string key, map event) {
        boolean value = UI::QueryWidget (
            `id (key),
            `Value);
        this_global_variable = value;
    }

    map<string,map<string,any> > widget_descr = $[
      "CWD_IN_ROOT_PATH" : $[
        "label" : _("&Current Directory in root's Path"),
        "widget" : `checkbox,
        "init" : MyInitializeWidget,
        "store" : MyStoreWidget,
      ],
    ]
```

UI events handling
==================

Especially in case of more complex widgets, it may be useful to handle
also events that don't switch to other dialog nor should store anything,
eg. gray/un-gray some widget according to value of a check box. To do
this, every event, that occurs, must be handled. This handling function
can be specified in the widget description map. If not defined, no
handling is done. Note, that the handle event function is run in both of
the situations - if the storing is and isn't to be done. The handling
function must have two parameters the widget key (string) and the event
that is handler (map). Return value of handle function is described in
?.

It is also possible to specify the list of events to handle by the
widget, via the "handle\_events" key. If it is empty, or not present,
then the handle function is called for every generated event.

```
    define symbol MyHandleWidget (string key, map event) {
        UI::MessagePopup (_("You checked the checkbox. Restart to
    make the change effective ;-)"));
        return nil;
    }

    map<string,map<string,any> > widget_descr = $[
      "CWD_IN_ROOT_PATH" : $[
        "label" : _("&Current Directory in root's Path"),
        "widget" : `checkbox,
        "help" : _("This is help to the widget"),
        "handle" : MyHandleWidget,
      ],
    ]
```

Changing the return value
=========================

If it is required to quit dialog other way than via the Next, Back and
Abort buttons, the handle function of a widget (eg. push button) must
return a symbol value, that can be then passed to the wizard sequencer.

After every event that triggers exit, except \`back, \`abort and
\`cancel, the widget validation and status storing will proceed.

If the handle function does not want to exit the dialog, it must return
nil.

If a handle function returns a non-nil value, other handle functions
won't be run (because handle functions are intended for changing the
widgets, and it doesn't make sense if the dialog will be finished). The
handle functions are processed in the same order as widgets are
specified in the argument of CreateWidgets function.

The returned value (if not nil) is passed to the store functions as the
"ID" member of the event map.

```
    define symbol MyHandleButton (map event) {
        if (event["ID"]:nil == "PUSH_BUTTON")
        return `leave_dialog_other_way;
        else
        return nil; // don't leave the dialog
                        // because of this widget
    }

    map<string,map<string,any> > widget_descr = $[
      "PUSH_BUTTON" : $[
        "label" : _("&Exit dialog different way"),
        "widget" : `push_button,
        "handle" : MyHandleButton ()),
      ],
    ]
```

Changing whole widget
=====================

In some cases no predefined widget can be used. In this case it is
useful to allow programmer to create his own widget. He can specify a
superwidget.

The superwidget can be specified in the widget description map via the
"custom\_widget" keyword, "widget" entry must be set to \`custom. See ?.

In some cases it may be needed to create the widget "on-thefly". It is
also possible via specifying a function that is run every time a dialog
with the widget is started. In this case the "widget" entry must be
specified as \`func and "widget\_func" entry must contain a reference of
a function that returns the term to be displayed. Also note that if the
building of the widget creating function calls other functions, that
need some time, they aren't called when YaST2 component starts, but when
it is really needed (but every time the widget is displayed).

```
    define term getW2 () {
        return `VBox (`PushButton (`id (`w), _("W")));
    }

    map<string,map<string,any> > widget_descr = $[
      "W1" : $[
        "widget" : `custom,
        "custom_widget" : `VBox (`PushButton (`id (`w), _("W"))),
        "init" : WInit,
        "store" : WStore,
      ],
      "W2" : $[
        "widget" : `custom,
        "custom_widget" : getW2,
        "init" : WInit,
        "store" : WStore,
      ],
    ];
```

These two widgets (W1 and W2) are identical.

Replacing, Disabling, and Hiding the Back/Abort/Next buttons
============================================================

To specify the labels of the Abort, Back and Next buttons, use the
entries "abort\_button", "back\_button", "next\_button" in the map that
is passed to CWM::ShowAndRun as argument. If any of the keys is not
specified, then the default button label is set. If the label of the
button is empty string or nil, then the button is not shown. If the
entry "disable\_buttons" is present, it is a list of the buttons that
should be disabled (in the "foo\_button" form).

    CWM::ShowAndRun ($[
        "back_button" : nil, // will be hidden
        "next_button" : Label::FinishButton (), // label of the "Next" button
                       // abort button is not specified, will be "Abort" (default)
        "disable_buttons" : ["abort_button"],
        ....
    ]);
     

Generating UI event after specified timeout
===========================================

The new UI built-ins allow to emit an event after a specified timeout.
Getting an event after specified timeout can be useful in order to
update eg. s status label.

To define the timeout, specify the "ui\_timeout" entry in the widget
description map with integer value in seconds specifying the timeout.
Note that if there are multiple widgets in a dialog with UI timeout set,
the lowest timeout is used (which means that the timeout event can be
generated more often than specified).

```
    define symbol EventHandle (string key, map event) {
        if (event["ID"] == `timeout)
        {
            string status = GetStatus ();
            UI::ChangeWidget (`id (key), `Value, status);
        }
        return nil;
    }

    map<string,map<string,any> > widget_descr = $[
      "status" : $[
        "widget" : `text_entry,
        "label" : _("Status"),
        "ui_timeout" : 1, // each 1 second
        "handle" : EventHandle,
      ],
    ]
```

Empty widget
============

Empty widget is just a \`VBox () without any contents. It may be usable
for handling some events but without displaying anything in the dialog.

The only needed attribute to specify is the "widget" entry in the map
that must have the value \`empty.

```
    define symbol EventHandle (string key, map event) {
        // to something interesting here
        return nil;
    }

    map<string,map<string,any> > widget_descr = $[
      "status" : $[
        "widget" : `empty,
        "handle" : EventHandle,
      ],
    ]
```

More control over the dialog creation
=====================================

In some cases it may not be sufficient to use the standard dialog layout
creation. You may eg. need to add some additional help text. The same
dalog as in ? is created in ?.

```
    // include  here

    define symbol runSomeDialog {
        // create list of maps representing wanted widgets
        list<map<string,any> > widgets
            = CWM::CreateWidgets (
                [ "CWD_IN_ROOT_PATH", "CWD_IN_USER_PATH" ],
                widget_descr);

        term contents = `VBox (
            "CWD_IN_ROOT_PATH",
            "CWD_IN_USER_PATH"
        );
        contents = CWM::PrepareDialog (contents, w);
        string help = CWM::MergeHelps (widgets);

        Wizard::SetContentsButtons ("Dialog", contents, help,
            "Back", "Next");
        // here comes additional stuff, eg. renaming the "Abort"
        // button to "Cancel" if needed

        map functions = $[
            "initialize" : InitializeWidget,
            "store" : StoreWidget,
        ];

        // run the dialog
        symbol ret = CWM::Run (widgets, functions);

        return ret;
```

The first step is to process the relevant widgets from the widgets
description map in order to create the "real" widgets. The second task
is to create the dialog term. Instead of using widget names and calling
CWM::PrepareDialog function, you may use the preprocessed widget. In
this case you should write

        term contents = `VBox (
            "widgets[0. "widget"]:`VBox (),
            "widgets[1. "widget"]:`VBox (),
        )

Note that the "widget" entry in preprocessed widget contains the real
term.

Then function CWM::MergeHelps (list&lt;map&lt;string,any&gt; &gt;
widgets) will merge the helps of the widgets in the same order as the
widgets were specified in the argument of the CreateWidgets function. In
fact it only concatenates the help attributes of the widgets. For
advanced helps (eg. add some text not related to any widgets) programmer
must use his own function.

Then you can create the dialog (including setting the help and buttons).
Additionally, you can do any tasks you need (eg. remove the Back button,
change the label of the Abort button). Fallback handlers are to be set
the same way as when use the ShowAndRun wrapper. The last step is to
start the event loop via the Run function.

