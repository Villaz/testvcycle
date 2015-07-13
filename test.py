import os
import stat
import subprocess
import base64

open('/var/lib/waagent/script.sh', 'w').write(base64.b64decode(open(event.src_path, 'r').read()))
os.chmod('/var/lib/waagent/script.sh', stat.S_IEXEC)
subprocess.call(['dos2unix', '/var/lib/waagent/script.sh'])
subprocess.call(['sh', '/var/lib/waagent/script.sh'])
os._exit(0)
