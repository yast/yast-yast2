# Services and Sockets

In systemd, it might happen that a single service is managed by a set of units, for example when a service is able to be activated via socket, path, timer, etc. In such cases, systemd works with a service unit (e.g., cups.service) and also with a socket (or path, timer, etc) unit (e.g., cups.socket).

When a service is configured by using YaST (e.g., with the Services Manager), all units related to each service must be taken into account. For example, when a service is stopped, the socket associated to such service should be also stopped. Otherwise, the sevice could be automatically activated again via its socket.

This file describes a new class (named `SystemService`) to work with the service and its associated socket as a whole. The main goal of this new class is to perform actions over both, the service and the socket, when it is required.

## `SystemService` class

This class is intended to represent a service from a high level point of view. It will offer an API to:

* ask for service properties (e.g., is active, its state, start mode, etc)
* perform "in memory" actions (start, stop, restart or reload) and change its start mode (on boot, on demand or manually)
* apply all changes in the "real system"

One goal in this class is to offer an agnostic API. At this moment it uses Systemd in low levels layers, but in future this could change and the API should remain as much as possible.

### Actions over Systemd units

The following table describes the actions to perform over a systemd service and its associated socket (if any) when we try to start, stop, restart or reload a `SystemService`.


| Status | Start | Stop | Restart | Reload |
|---|---|---|---|---|
| Only socket running | nothing | stop socket | stop socket and start service/socket (depending on start mode) | nothing |
| Only service running | nothing  | stop service  | stop service and start service/socket (depending on start mode) | reload service (if it support, otherwise restart) |
| Socket & Service running | nothing | stop service and socket | stop service and socket and start service/socket (depending on start mode) | reload service (if it support, otherwise restart) |
| Nothing runs | start service/socket (depending on start mode) | nothing | start service/socket (depending on start mode) | start service/socket (depending on start mode) |


### Detailed actions

Here each `SystemService` action is decribed in a more detailed way.

First of all, we are going to consider that a `SystemService` is stopped/running as follows:

* [1] Stopped: when neither the systemd socket nor service are running
* [2] Running: when the systemd socket and/or service are running

### `#start`

* Goal
  * when the service is stopped (see [1]), the service is started again (see [2])

* Actions
  * when neither systemd socket nor service are running
    * and start mode is `on demand`
      * starts systemd socket
    * and start mode is `on boot` or `manually`
      * starts systemd service

### `#stop`

* Goal
  * service is stopped (see [1])

* Actions
  * stops systemd socket if it is running
  * stops systemd service if it is running

### `#restart`

* Goal
  * service is stopped (see [1]) and started again (see [2])

* Actions
  * calls to "stop service action" (see stop section) if the service is running (see [2])
  * calls to "start service action" (see start section)

### `#reload`

* Goal
  * service is reloaded or restarted or started

* Actions
  * when the service supports reload
    * and start mode is `on demand`
      * and systemd socket is running
        * and systemd service is running
          * reloads systemd service
      * and systemd socket is not running
        * and systemd service is running
          * reloads systemd service
        * and systemd service is not running
          * calls to "start service action" (see start section)
    * and start mode is `on boot` or `manually`
      * stops systemd socket if it is running
      * and systemd service is running
        * reloads systemd service
      * and systemd service is not running
        * starts systemd service
  * when service does not support reload
    * calls to "restart service action" (see restart section)
