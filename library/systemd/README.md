Action depending on current status:


| Status | Start | Stop | Restart | Reload |
|---|---|---|---|---|
| Socket running | start service or nothing or depends on start mode?  | stop socket?  | nothing?  | nothing? |
| Service running | nothing?  | stop service  | restart service | reload service ( if it support, otherwise restart???)  |
| Socket & Service running | nothing?  | stop service and socket?  | stop service?  | reload service?  |
| nothing runs | start socket or service or depends on start mode?  | nothing?  | nothing or start?  | nothing or start? |
