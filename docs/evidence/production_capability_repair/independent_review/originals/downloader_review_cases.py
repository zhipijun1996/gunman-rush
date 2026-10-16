import hashlib,json,sys,tempfile,threading,unittest
from pathlib import Path
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from unittest.mock import patch
sys.path.insert(0,str(Path.cwd()/'tools'))
import setup_environment as setup
BODY=b'reviewlockedartifact'*128
class Handler(BaseHTTPRequestHandler):
    requests=[]
    def log_message(self,*args):pass
    def do_GET(self):
        Handler.requests.append((self.path,self.headers.get('Range')))
        if self.path in ['/404','/429']:
            self.send_error(int(self.path[1:]));return
        self.send_response(200);self.send_header('Content-Length',str(len(BODY)));self.end_headers();self.wfile.write(BODY)
class Cases(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server=ThreadingHTTPServer(('127.0.0.1',0),Handler);cls.thread=threading.Thread(target=cls.server.serve_forever,daemon=True);cls.thread.start()
    @classmethod
    def tearDownClass(cls):cls.server.shutdown();cls.server.server_close();cls.thread.join()
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.root=Path(self.tmp.name);Handler.requests=[]
        p=patch.object(setup,'ROOT',self.root);p.start();self.addCleanup(p.stop)
    def spec(self,route):return {'url':f'http://127.0.0.1:{self.server.server_port}{route}','sha256':hashlib.sha256(BODY).hexdigest()}
    def partial(self,identity):
        d=self.root/'downloads';d.mkdir();(d/'review.zip.partial').write_bytes(b'bad-old-bytes');(d/'review.zip.partial.sha256').write_text(identity+'\n')
    def test_stale_partial_identity_is_discarded(self):
        self.partial('0'*64);self.assertEqual(setup.download(self.spec('/ok'),'review.zip').read_bytes(),BODY);self.assertEqual(Handler.requests,[('/ok',None)])
    def test_range_unsupported_restarts_without_installing_partial(self):
        self.partial(self.spec('/ok')['sha256']);self.assertEqual(setup.download(self.spec('/ok'),'review.zip').read_bytes(),BODY);self.assertEqual(Handler.requests,[('/ok','bytes=13-'),('/ok',None)])
    def test_404_terminal(self):
        with self.assertRaisesRegex(RuntimeError,'HTTP=404'):setup.download(self.spec('/404'),'review.zip')
        self.assertEqual(len(Handler.requests),1)
    def test_429_attempts_bounded(self):
        with self.assertRaisesRegex(RuntimeError,'HTTP=429'):setup.download(self.spec('/429'),'review.zip')
        self.assertEqual(len(Handler.requests),3)
        self.assertFalse((self.root/'downloads/review.zip').exists())
if __name__=='__main__':unittest.main()
