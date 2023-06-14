#!/bin/bash
# add log
cat << "EOF" >> /etc/profile
#set user history
USER=`whoami`
USER_IP=`who -u am i 2>/dev/null| awk '{print $NF}'|sed -e 's/[()]//g'`
if [ "$USER_IP" = "" ]; then
    USER_IP=`hostname`
fi
if [ ! -d /var/log/history/${LOGNAME} ]; then
    sudo mkdir -p /var/log/history/${LOGNAME}
    sudo chown -R ${LOGNAME}:${LOGNAME} /var/log/history/${LOGNAME}
    sudo chmod 300 /var/log/history/${LOGNAME}
fi
export HISTORY_FILE="/var/log/history/${LOGNAME}/bash_history"
export PROMPT_COMMAND='{ msg=$(history 1 | { read x y; echo $y; });echo $(date +"%Y-%m-%d %H:%M:%S") [$USER@$LOGNAME@$USER_IP `pwd` ]" $msg" >> $HISTORY_FILE; }'
EOF
rm -rf /root/init.sh
