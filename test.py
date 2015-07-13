import os
import stat
import subprocess
import base64

open('/var/lib/waagent/test.sh', 'w').write(base64.b64decode(open(event.src_path, 'r').read()))
os.chmod('/var/lib/waagent/test.sh', stat.S_IEXEC)
subprocess.call(['dos2unix', '/var/lib/waagent/test.sh'])
subprocess.call(['sh', '/var/lib/waagent/test.sh'])
os._exit(0)
