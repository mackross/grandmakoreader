#!/usr/bin/env python3
"""Stands in for the two GitHub endpoints the updater calls, for tools/review-auto-update.

Usage: auto-update-stub.py <control directory>
Serves <control directory>/release, with its subfolders, as the patches folder of any repository and branch,
to anonymous requests and to requests with the review token, like a public repository. Any other token is rejected,
and writes the port it listens on to <control directory>/port. While <control directory>/corrupt
exists, every file arrives altered.
"""
import hashlib
import json
import pathlib
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

control = pathlib.Path(sys.argv[1])
TOKEN = "Bearer review-token"


def blob_sha(content: bytes) -> str:
    return hashlib.sha1(b"blob %d\0" % len(content) + content).hexdigest()


class Handler(BaseHTTPRequestHandler):
    def reply(self, code, body: bytes):
        self.send_response(code)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        authorization = self.headers.get("Authorization")
        with open(control / "requests.log", "a") as log:
            sent = "none" if authorization is None else "sent"
            log.write(f"{self.path} user-agent={self.headers.get('User-Agent')!r} authorization={sent}\n")
        if authorization not in (None, TOKEN):
            return self.reply(401, b"bad credentials")
        release = control / "release"
        entries = sorted(release.rglob("*"))
        files = {f.relative_to(release).as_posix(): f.read_bytes() for f in entries if f.is_file()}
        path, _, query = self.path.partition("?")
        if "/git/trees/" in path and path.endswith(":patches") and query == "recursive=1":
            tree = [{"path": name, "type": "blob", "mode": "100644", "sha": blob_sha(content)}
                    for name, content in files.items()]
            tree += [{"path": d.relative_to(release).as_posix(), "type": "tree", "mode": "040000", "sha": "0" * 40}
                     for d in entries if d.is_dir()]
            # Entries the updater must leave alone: a dot file and a link.
            tree.append({"path": ".DS_Store", "type": "blob", "mode": "100644", "sha": "1" * 40})
            tree.append({"path": "link", "type": "blob", "mode": "120000", "sha": "2" * 40})
            return self.reply(200, json.dumps({"sha": "3" * 40, "tree": tree, "truncated": False}).encode())
        if "/git/blobs/" in path:
            wanted = path.rsplit("/", 1)[1]
            for content in files.values():
                if blob_sha(content) == wanted:
                    if (control / "corrupt").exists():
                        content += b"\n-- altered"
                    return self.reply(200, content)
        self.reply(404, b"not found")

    def log_message(self, *args):
        pass


server = HTTPServer(("127.0.0.1", 0), Handler)
(control / "port").write_text(str(server.server_port))
server.serve_forever()
