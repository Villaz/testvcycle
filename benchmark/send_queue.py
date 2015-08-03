__author__ = 'luis'

import argparse
import stomp
import time

if __name__ == '__main__':

    parser = argparse.ArgumentParser()
    parser.add_argument("-p", "--port", nargs='?', help="Queue port")
    parser.add_argument("-s", "--server", nargs='?', help="Queue host")
    parser.add_argument("-u", "--username", nargs='?', help="Queue username")
    parser.add_argument("-w", "--password", nargs='?', help="Queue password")
    parser.add_argument("-n", "--name", nargs='?', help="Queue name")
    parser.add_argument("-f", "--file", nargs='?', help="File to send")
    args = parser.parse_args()

    file = open(args.file,'r').read()

    conn = stomp.Connection([(args.server, int(args.port))])
    conn.start()
    conn.connect(args.username, args.password, True)
    conn.send(body=file, destination=args.name)

    time.sleep(2)
    conn.disconnect()
