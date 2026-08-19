import os
import sys
from http.server import HTTPServer, SimpleHTTPRequestHandler

PORT = 8080
DIRECTORY = os.path.dirname(os.path.abspath(__file__))

class MuxizDownloadHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def end_headers(self):
        # Enable CORS and disable aggressive caching for seamless downloads
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

    def guess_type(self, path):
        if path.endswith('.apk'):
            return 'application/vnd.android.package-archive'
        elif path.endswith('.ipa'):
            return 'application/octet-stream'
        return super().guess_type(path)

    def do_GET(self):
        # Rewrite routes so both clean version names and legacy URLs work seamlessly
        if self.path in ['/Muxiz-v1.0.0.apk', '/app-release.apk', '/muxiz.apk', '/download/apk']:
            filename = 'Muxiz-v1.0.0.apk'
            filepath = os.path.join(DIRECTORY, filename)
            if not os.path.exists(filepath):
                filepath = os.path.join(DIRECTORY, 'app-release.apk')
            return self._serve_attachment(filepath, 'Muxiz-v1.0.0.apk', 'application/vnd.android.package-archive')

        elif self.path in ['/Muxiz-v1.0.0.ipa', '/Muxiz.ipa', '/muxiz.ipa', '/download/ipa']:
            filename = 'Muxiz-v1.0.0.ipa'
            filepath = os.path.join(DIRECTORY, filename)
            if not os.path.exists(filepath):
                filepath = os.path.join(DIRECTORY, 'Muxiz.ipa')
            return self._serve_attachment(filepath, 'Muxiz-v1.0.0.ipa', 'application/octet-stream')

        return super().do_GET()

    def _serve_attachment(self, filepath, download_filename, content_type):
        if not os.path.exists(filepath):
            self.send_error(404, f"File {download_filename} not found")
            return

        file_size = os.path.getsize(filepath)
        self.send_response(200)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(file_size))
        self.send_header('Content-Disposition', f'attachment; filename="{download_filename}"')
        self.end_headers()

        with open(filepath, 'rb') as f:
            while chunk := f.read(64 * 1024):
                self.wfile.write(chunk)

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', PORT), MuxizDownloadHandler)
    print(f"Muxiz Download Server running on port {PORT}...")
    server.serve_forever()
