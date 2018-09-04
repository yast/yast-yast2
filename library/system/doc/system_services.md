# System Services Library

The system services library offers an API to interact with system services, allowing the user to
perform typical operations like querying the services, starting or stopping them, etc.

The set of classes which are included in this library can be divided into:

* A high level API which offers some abstractions on top of Systemd.
* A low level one to talk closely to Systemd units (including services and sockets).

Additionally, a widget that can be used in YaST modules (like yast2-dns-server) is included.

## High Level API

The high level API is composed by these classes:

* {Yast2::SystemService}: represents a service (like `cups` or `dbus`) from a high level point of
  view. Systemd concepts like *units* or *sockets* are abstracted by this class.
* {Yast2::CompoundService}: groups a set of related services that might be handled together.
  Think, for instance, about `iscsi`, `iscsid` and `iscsiuio` services in `yast2-iscsi-client`.
  This class offers basically the same API than {Yast2::SystemService}.

## Low Level API

The low level API can be more convenient in some situations and it is basically composed of a set of
classes that map to Systemd concepts: {Yast2::Systemd::Unit}, {Yast2::Systemd::Service},
{Yast2::Systemd::Socket} and {Yast2::Systemd::Target}.

## Service Widget

Additionally to the classes to interact with system services, this library offers a widget which
allows the user to decide how (and when) a service should be started. It is meant to be used by
modules which configure a given service (like `yast2-dns-server` or `yast2-iscsi-client`).

See {Yast2::ServiceWidget} for the widget documentation and {CWM::ServiceWidget} for the CWM
wrapper.
