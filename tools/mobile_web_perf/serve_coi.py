"""Local diagnostic server with the headers required by official threaded Web."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
class Handler(SimpleHTTPRequestHandler):
 def end_headers(self):
  self.send_header('Cross-Origin-Opener-Policy','same-origin');self.send_header('Cross-Origin-Embedder-Policy','require-corp');super().end_headers()
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--directory',required=True);p.add_argument('--port',type=int,default=8807);a=p.parse_args();ThreadingHTTPServer(('127.0.0.1',a.port),partial(Handler,directory=a.directory)).serve_forever()
