#!/bin/sh
export MESSAGE=`more /etc/machineoutputs/shutdown_message`
echo "{\"name\":\"`hostname`\",\"message\":\"$MESSAGE\",\"time\":\"`date`\"}" > /etc/machineoutputs/message.json
curl -XPOST 'http://elasticsearch-vcycle:9200/vcycle/machine' -d /etc/machineoutputs/message.json