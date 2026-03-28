const http = require("http");
const fs = require("fs");
const path = require("path");

const port = Number(process.env.PORT) || 4173;
const rootDir = __dirname;

const mimeTypes = {
  ".css": "text/css; charset=utf-8",
  ".html": "text/html; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".txt": "text/plain; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".svg": "image/svg+xml",
  ".webp": "image/webp",
  ".ico": "image/x-icon",
};

function resolvePath(urlPath) {
  const cleanPath = decodeURIComponent(urlPath.split("?")[0]);
  const normalizedPath = path.normalize(cleanPath).replace(/^(\.\.[/\\])+/, "");
  const requestedPath = normalizedPath === "/" ? "/index.html" : normalizedPath;
  return path.join(rootDir, requestedPath);
}

function sendFile(filePath, response) {
  const extension = path.extname(filePath).toLowerCase();
  const contentType = mimeTypes[extension] || "application/octet-stream";

  fs.readFile(filePath, (error, content) => {
    if (error) {
      response.writeHead(500, { "Content-Type": "text/plain; charset=utf-8" });
      response.end("Internal server error");
      return;
    }

    response.writeHead(200, { "Content-Type": contentType });
    response.end(content);
  });
}

const server = http.createServer((request, response) => {
  const filePath = resolvePath(request.url || "/");

  fs.stat(filePath, (error, stats) => {
    if (!error && stats.isDirectory()) {
      sendFile(path.join(filePath, "index.html"), response);
      return;
    }

    if (!error && stats.isFile()) {
      sendFile(filePath, response);
      return;
    }

    if (path.extname(filePath)) {
      response.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
      response.end("Not found");
      return;
    }

    sendFile(path.join(rootDir, "index.html"), response);
  });
});

server.listen(port, () => {
  console.log(`dekhlobhai is running at http://localhost:${port}`);
});
