# Systemd actions

The following table describes the actions to perform over a systemd service and its associated socked (if any) when we try to start, stop, restart or reload the service.


| Status | Start | Stop | Restart | Reload |
|---|---|---|---|---|
| Socket running | nothing | stop socket | stop socket and start service/socket (depending on start mode) | nothing |
| Service running | nothing  | stop service  | stop service and start service/socket (depending on start mode) | reload service (if it support, otherwise restart) |
| Socket & Service running | nothing | stop service and socket | stop service and start service/socket (depending on start mode) | reload service (if it support, otherwise restart) |
| nothing runs | start service/socket (depending on start mode) | nothing | start service/socket (depending on start mode) | start service/socket (depending on start mode) |


## Actions over a `SystemService`

In systemd, it might happen that a service is compose by a set of units (services, sockets, paths and so on). This class `SystemService` is able to group those units and handle them together.

### `SystemService` status

* [1] A service is stopped when neither the systemd socket nor service are running
* [2] A service is running when the systemd socket and/or service are running

### Start

* Target
  * when the service is stopped (see [1]), the service is started again (see [2])

* Actions
  * when neither systemd socket nor service are running
    * and start mode is `on demand`
      * starts systemd socket
    * and start mode is `on boot` or `manually`
      * starts systemd service

### Stop

* Target
  * service is stopped (see [1])

* Actions
  * stops systemd service if it is running
  * stops systemd socket if it is running

### Restart

* Target
  * service is stopped (see [1]) and started again (see [2])

* Actions
  * calls to "stop service action" (see stop section) if the service is running (see [2])
  * calls to "start service action" (see start section)

### Reload

* Target
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
