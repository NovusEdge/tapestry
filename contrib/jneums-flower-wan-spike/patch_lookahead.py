"""Patch flwr/supercore/grpc.py: raise HTTP/2 per-stream lookahead to 16 MB.

Applies to both the client channel (create_channel) and the server options.
Idempotent: skips if already patched.
"""

import sys

PATH = "/root/flenv/lib/python3.12/site-packages/flwr/supercore/grpc.py"
LOOKAHEAD = '        ("grpc.http2.lookahead_bytes", 16 * 1024 * 1024),\n'

src = open(PATH).read()
if "lookahead_bytes" in src:
    print("already patched")
    sys.exit(0)

# 1. Client channel options in create_channel
old_client = """    channel_options = [
        ("grpc.max_send_message_length", max_message_length),
        ("grpc.max_receive_message_length", max_message_length),
    ]
"""
new_client = """    channel_options = [
        ("grpc.max_send_message_length", max_message_length),
        ("grpc.max_receive_message_length", max_message_length),
        ("grpc.http2.lookahead_bytes", 16 * 1024 * 1024),
    ]
"""
assert src.count(old_client) == 1, "client options block not found"
src = src.replace(old_client, new_client)

# 2. Server options
old_server = '        ("grpc.keepalive_permit_without_calls", 0),\n    ]\n'
new_server = (
    '        ("grpc.keepalive_permit_without_calls", 0),\n'
    + LOOKAHEAD
    + "    ]\n"
)
assert src.count(old_server) == 1, "server options block not found"
src = src.replace(old_server, new_server)

open(PATH, "w").write(src)
print("patched OK")
