#!/bin/sh

set -eox pipefail
#shopt -s nullglob

REDIS_CONF=${REDIS_CONF:-"/opt/k8s-redis/redis.conf"}

if [ "${1#-}" != "$1" ] || [ "${1%.conf}" != "$1" ]; then
  set -- redis-server "$@"
fi

if [ "$1" = 'redis-server' ] && [ -n "$SLAVEOF" ] && [ -z "$SENTINEL" ]; then
  echo "Starting Redis replica"
  set -- $@ "$REDIS_CONF" --slaveof "$SLAVEOF" 6379

elif [ "$1" = 'redis-server' ] && [ -n "$SENTINEL" ]; then
  echo "Starting Redis sentinel"

  while true; do
    redis-cli -h $SENTINEL INFO
    if [[ "$?" == "0" ]]; then
      break
    fi
    echo "Connecting to master failed.  Waiting..."
    sleep 10
  done

  echo "sentinel monitor primary $SENTINEL 6379 2" >> "$REDIS_CONF"
  echo "sentinel down-after-milliseconds primary 5000" >> "$REDIS_CONF"
  echo "sentinel failover-timeout primary 10000" >> "$REDIS_CONF"
  echo "sentinel parallel-syncs primary 1" >> "$REDIS_CONF"

  set -- $@ "$REDIS_CONF" --port 26379 --sentinel --protected-mode no

elif [ "$1" = 'redis-server' ]; then  
  echo "Starting Redis master"
  set -- $@ "$REDIS_CONF"
fi

exec "$@"
