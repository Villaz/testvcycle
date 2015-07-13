import os
import stat
import subprocess
import base64

open('/var/lib/waagent/test.sh', 'w').write(base64.b64decode(open('/var/lib/waagent/CustomData', 'r').read()))
os.chmod('/var/lib/waagent/test.sh', stat.S_IEXEC)
subprocess.call(['yum','install', '-y', 'dos2unix'])
subprocess.call(['dos2unix', '/var/lib/waagent/test.sh'])
subprocess.call(['sh', '/var/lib/waagent/test.sh'])
os._exit(0)
