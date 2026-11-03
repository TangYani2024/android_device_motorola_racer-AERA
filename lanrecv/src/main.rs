// aera-lanrecv: tiny LAN file receiver for AERA Recovery.
//
// Two ways in, both plain HTTP on port 53317:
//   1. Web page (any browser): GET /  -> upload form + received-file list.
//   2. LocalSend v2 receive endpoints (best effort, plain HTTP):
//      GET  /api/localsend/v2/info
//      POST /api/localsend/v2/register
//      POST /api/localsend/v2/prepare-upload
//      POST /api/localsend/v2/upload?sessionId=..&fileId=..&token=..
//      POST /api/localsend/v2/cancel?sessionId=..
//
// Trust model: the server only runs while the user starts it from the
// recovery terminal; while it runs, transfers are accepted. Stop it with
// Ctrl-C. Files land in /sdcard/AERA/Downloads when /sdcard is available,
// else in /tmp/AERA-Downloads.

use std::collections::HashMap;
use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream, UdpSocket};
use std::path::PathBuf;
use std::sync::{Arc, Mutex};

const PORT: u16 = 53317;
const ALIAS: &str = "AERA-Recovery";

struct State {
    dir: PathBuf,
    fingerprint: String,
    sessions: Mutex<HashMap<String, HashMap<String, (String, u64)>>>, // session -> fileId -> (name, size)
}

fn rand_hex(n: usize) -> String {
    let mut buf = vec![0u8; n];
    if let Ok(mut f) = std::fs::File::open("/dev/urandom") {
        let _ = f.read_exact(&mut buf);
    } else {
        let t = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_nanos())
            .unwrap_or(0);
        for (i, b) in buf.iter_mut().enumerate() {
            *b = ((t >> ((i % 8) * 8)) & 0xff) as u8 ^ (i as u8).wrapping_mul(97);
        }
    }
    buf.iter().map(|b| format!("{:02x}", b)).collect()
}

fn sanitize(name: &str) -> String {
    let mut s: String = name
        .chars()
        .map(|c| match c {
            '/' | '\\' | '\0' => '_',
            c if (c as u32) < 0x20 => '_',
            c => c,
        })
        .collect();
    while s.starts_with('.') {
        s.remove(0);
    }
    if s.is_empty() {
        s = "file".to_string();
    }
    if s.len() > 200 {
        s.truncate(200);
    }
    s
}

fn dedupe(dir: &PathBuf, name: &str) -> PathBuf {
    let p = dir.join(name);
    if !p.exists() {
        return p;
    }
    let (stem, ext) = match name.rfind('.') {
        Some(i) if i > 0 => (name[..i].to_string(), name[i..].to_string()),
        _ => (name.to_string(), String::new()),
    };
    for i in 1..1000 {
        let cand = dir.join(format!("{} ({}){}", stem, i, ext));
        if !cand.exists() {
            return cand;
        }
    }
    dir.join(name)
}

fn url_decode(s: &str, plus_as_space: bool) -> String {
    let bytes = s.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        match bytes[i] {
            b'%' if i + 2 < bytes.len() => {
                let hex = |c: u8| -> Option<u8> {
                    match c {
                        b'0'..=b'9' => Some(c - b'0'),
                        b'a'..=b'f' => Some(c - b'a' + 10),
                        b'A'..=b'F' => Some(c - b'A' + 10),
                        _ => None,
                    }
                };
                if let (Some(h), Some(l)) = (hex(bytes[i + 1]), hex(bytes[i + 2])) {
                    out.push(h * 16 + l);
                    i += 3;
                } else {
                    out.push(bytes[i]);
                    i += 1;
                }
            }
            b'+' if plus_as_space => {
                out.push(b' ');
                i += 1;
            }
            c => {
                out.push(c);
                i += 1;
            }
        }
    }
    String::from_utf8_lossy(&out).into_owned()
}

fn query_params(q: &str) -> HashMap<String, String> {
    let mut m = HashMap::new();
    for pair in q.split('&') {
        if let Some((k, v)) = pair.split_once('=') {
            m.insert(url_decode(k, true), url_decode(v, true));
        }
    }
    m
}

fn json_escape(s: &str) -> String {
    let mut out = String::with_capacity(s.len() + 8);
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out
}

// Extract all `"key":"value"` string values in document order (tiny scanner
// for the LocalSend prepare-upload DTO; tolerant, not a full JSON parser).
fn json_strings(body: &str, key: &str) -> Vec<String> {
    let pat = format!("\"{}\"", key);
    let mut out = Vec::new();
    let mut rest = body;
    while let Some(pos) = rest.find(&pat) {
        let after = &rest[pos + pat.len()..];
        let after = after.trim_start();
        if let Some(after) = after.strip_prefix(':') {
            let after = after.trim_start();
            if let Some(after) = after.strip_prefix('"') {
                let mut val = String::new();
                let mut chars = after.chars();
                let mut closed = false;
                while let Some(c) = chars.next() {
                    match c {
                        '\\' => {
                            if let Some(e) = chars.next() {
                                match e {
                                    'n' => val.push('\n'),
                                    't' => val.push('\t'),
                                    'r' => val.push('\r'),
                                    'u' => {
                                        let hex: String = chars.by_ref().take(4).collect();
                                        if let Ok(n) = u32::from_str_radix(&hex, 16) {
                                            if let Some(ch) = char::from_u32(n) {
                                                val.push(ch);
                                            }
                                        }
                                    }
                                    other => val.push(other),
                                }
                            }
                        }
                        '"' => {
                            closed = true;
                            break;
                        }
                        c => val.push(c),
                    }
                }
                if closed {
                    out.push(val);
                }
                rest = after;
                continue;
            }
        }
        rest = &rest[pos + pat.len()..];
    }
    out
}

// Extract all `"key":123` numbers in document order.
fn json_numbers(body: &str, key: &str) -> Vec<u64> {
    let pat = format!("\"{}\"", key);
    let mut out = Vec::new();
    let mut rest = body;
    while let Some(pos) = rest.find(&pat) {
        let after = &rest[pos + pat.len()..];
        let after = after.trim_start();
        if let Some(after) = after.strip_prefix(':') {
            let after = after.trim_start();
            let num: String = after.chars().take_while(|c| c.is_ascii_digit()).collect();
            if let Ok(n) = num.parse::<u64>() {
                out.push(n);
            }
        }
        rest = &rest[pos + pat.len()..];
    }
    out
}

struct Request {
    method: String,
    path: String,
    query: HashMap<String, String>,
    content_length: u64,
    body_prefix: Vec<u8>, // bytes already read past the header (rare)
}

fn read_request(stream: &mut TcpStream) -> Option<Request> {
    let mut buf: Vec<u8> = Vec::with_capacity(8192);
    let mut chunk = [0u8; 4096];
    let header_end;
    loop {
        if let Some(pos) = find_subslice(&buf, b"\r\n\r\n") {
            header_end = pos + 4;
            break;
        }
        if buf.len() > 65536 {
            return None;
        }
        match stream.read(&mut chunk) {
            Ok(0) => return None,
            Ok(n) => buf.extend_from_slice(&chunk[..n]),
            Err(_) => return None,
        }
    }
    let head = String::from_utf8_lossy(&buf[..header_end]).into_owned();
    let body_prefix = buf[header_end..].to_vec();
    let mut lines = head.lines();
    let first = lines.next()?;
    let mut parts = first.split_whitespace();
    let method = parts.next()?.to_string();
    let raw_target = parts.next()?.to_string();
    let (path, query) = match raw_target.split_once('?') {
        Some((p, q)) => (url_decode(p, false), query_params(q)),
        None => (url_decode(&raw_target, false), HashMap::new()),
    };
    let mut content_length = 0u64;
    let mut expect_continue = false;
    for line in lines {
        if let Some((k, v)) = line.split_once(':') {
            let k = k.trim().to_ascii_lowercase();
            let v = v.trim();
            if k == "content-length" {
                content_length = v.parse().unwrap_or(0);
            } else if k == "expect" && v.eq_ignore_ascii_case("100-continue") {
                expect_continue = true;
            }
        }
    }
    if expect_continue {
        let _ = stream.write_all(b"HTTP/1.1 100 Continue\r\n\r\n");
    }
    Some(Request {
        method,
        path,
        query,
        content_length,
        body_prefix,
    })
}

fn find_subslice(hay: &[u8], needle: &[u8]) -> Option<usize> {
    hay.windows(needle.len()).position(|w| w == needle)
}

// Read and discard / collect a request body of known length.
fn read_body(stream: &mut TcpStream, req: &Request, mut sink: impl Write) -> std::io::Result<u64> {
    let mut remaining = req.content_length;
    let mut written = 0u64;
    if !req.body_prefix.is_empty() {
        let take = std::cmp::min(remaining, req.body_prefix.len() as u64);
        sink.write_all(&req.body_prefix[..take as usize])?;
        written += take;
        remaining -= take;
    }
    let mut buf = [0u8; 65536];
    while remaining > 0 {
        let want = std::cmp::min(remaining, buf.len() as u64) as usize;
        match stream.read(&mut buf[..want]) {
            Ok(0) => break,
            Ok(n) => {
                sink.write_all(&buf[..n])?;
                written += n as u64;
                remaining -= n as u64;
            }
            Err(e) => return Err(e),
        }
    }
    Ok(written)
}

fn respond(stream: &mut TcpStream, status: &str, ctype: &str, body: &[u8]) {
    let head = format!(
        "HTTP/1.1 {}\r\nContent-Type: {}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
        status,
        ctype,
        body.len()
    );
    let _ = stream.write_all(head.as_bytes());
    let _ = stream.write_all(body);
    let _ = stream.flush();
}

fn respond_json(stream: &mut TcpStream, status: &str, json: String) {
    respond(stream, status, "application/json", json.as_bytes());
}

fn info_json(st: &State) -> String {
    format!(
        "{{\"alias\":\"{}\",\"version\":\"2.0\",\"deviceModel\":\"racer\",\"deviceType\":\"headless\",\"fingerprint\":\"{}\",\"port\":{},\"protocol\":\"http\",\"download\":true}}",
        ALIAS, st.fingerprint, PORT
    )
}

fn save_upload(stream: &mut TcpStream, req: &Request, st: &State, raw_name: &str) -> (bool, String, u64) {
    let name = sanitize(raw_name);
    let final_path = dedupe(&st.dir, &name);
    let tmp_path = st.dir.join(format!(".recv-{}-{}", std::process::id(), rand_hex(4)));
    let result = (|| -> std::io::Result<u64> {
        let mut f = std::fs::File::create(&tmp_path)?;
        let n = read_body(stream, req, &mut f)?;
        f.flush()?;
        Ok(n)
    })();
    match result {
        Ok(n) => {
            if std::fs::rename(&tmp_path, &final_path).is_err() {
                let _ = std::fs::remove_file(&tmp_path);
                return (false, name, 0);
            }
            (true, final_path.file_name().unwrap().to_string_lossy().into_owned(), n)
        }
        Err(_) => {
            let _ = std::fs::remove_file(&tmp_path);
            (false, name, 0)
        }
    }
}

fn handle(mut stream: TcpStream, st: Arc<State>) {
    let req = match read_request(&mut stream) {
        Some(r) => r,
        None => return,
    };
    let method = req.method.as_str();
    let path = req.path.as_str();

    match (method, path) {
        ("GET", "/") => {
            respond(&mut stream, "200 OK", "text/html; charset=utf-8", PAGE.as_bytes());
        }
        ("GET", "/api/files") => {
            let mut items = Vec::new();
            if let Ok(rd) = std::fs::read_dir(&st.dir) {
                for e in rd.flatten() {
                    let name = e.file_name().to_string_lossy().into_owned();
                    if name.starts_with(".recv-") {
                        continue;
                    }
                    let size = e.metadata().map(|m| m.len()).unwrap_or(0);
                    items.push(format!(
                        "{{\"name\":\"{}\",\"size\":{}}}",
                        json_escape(&name),
                        size
                    ));
                }
            }
            items.sort();
            respond_json(&mut stream, "200 OK", format!("[{}]", items.join(",")));
        }
        ("POST", "/upload-web") => {
            let raw = req.query.get("name").cloned().unwrap_or_else(|| "file".into());
            let (ok, saved, n) = save_upload(&mut stream, &req, &st, &raw);
            if ok {
                println!("[recv] web upload: {} ({} bytes)", saved, n);
                respond_json(&mut stream, "200 OK", format!("{{\"ok\":true,\"name\":\"{}\",\"size\":{}}}", json_escape(&saved), n));
            } else {
                respond_json(&mut stream, "500 Internal Server Error", "{\"ok\":false}".into());
            }
        }
        ("GET", "/api/localsend/v2/info") | ("POST", "/api/localsend/v2/register") => {
            // Drain any request body so the connection closes cleanly.
            let _ = read_body(&mut stream, &req, std::io::sink());
            respond_json(&mut stream, "200 OK", info_json(&st));
        }
        ("POST", "/api/localsend/v2/prepare-upload") => {
            let mut body = Vec::new();
            let _ = read_body(&mut stream, &req, &mut body);
            let text = String::from_utf8_lossy(&body).into_owned();
            let ids = json_strings(&text, "id");
            let names = json_strings(&text, "fileName");
            let sizes = json_numbers(&text, "size");
            if names.is_empty() {
                respond_json(&mut stream, "400 Bad Request", "{\"error\":\"no files\"}".into());
                return;
            }
            let session = rand_hex(16);
            let mut files = HashMap::new();
            let mut resp_files = Vec::new();
            for (i, name) in names.iter().enumerate() {
                let fid = ids.get(i).cloned().unwrap_or_else(|| format!("f{}", i));
                let size = sizes.get(i).cloned().unwrap_or(0);
                files.insert(fid.clone(), (name.clone(), size));
                resp_files.push(format!("\"{}\":\"{}\"", json_escape(&fid), rand_hex(16)));
            }
            println!("[recv] localsend session {}: {} file(s): {}", session, names.len(), names.join(", "));
            st.sessions.lock().unwrap().insert(session.clone(), files);
            respond_json(
                &mut stream,
                "200 OK",
                format!("{{\"sessionId\":\"{}\",\"files\":{{{}}}}}", session, resp_files.join(",")),
            );
        }
        ("POST", "/api/localsend/v2/upload") => {
            let session = req.query.get("sessionId").cloned().unwrap_or_default();
            let file_id = req.query.get("fileId").cloned().unwrap_or_default();
            let entry = {
                let map = st.sessions.lock().unwrap();
                map.get(&session).and_then(|f| f.get(&file_id)).cloned()
            };
            match entry {
                Some((name, _size)) => {
                    let (ok, saved, n) = save_upload(&mut stream, &req, &st, &name);
                    if ok {
                        println!("[recv] localsend upload: {} ({} bytes)", saved, n);
                        respond(&mut stream, "200 OK", "text/plain", b"");
                    } else {
                        respond_json(&mut stream, "500 Internal Server Error", "{\"error\":\"save failed\"}".into());
                    }
                }
                None => {
                    let _ = read_body(&mut stream, &req, std::io::sink());
                    respond_json(&mut stream, "403 Forbidden", "{\"error\":\"unknown session/file\"}".into());
                }
            }
        }
        ("POST", "/api/localsend/v2/cancel") => {
            let _ = read_body(&mut stream, &req, std::io::sink());
            if let Some(s) = req.query.get("sessionId") {
                st.sessions.lock().unwrap().remove(s);
            }
            respond(&mut stream, "200 OK", "text/plain", b"");
        }
        _ => {
            if method == "GET" && path.starts_with("/dl/") {
                let name = sanitize(&path[4..]);
                let p = st.dir.join(&name);
                match std::fs::File::open(&p) {
                    Ok(mut f) => {
                        let len = f.metadata().map(|m| m.len()).unwrap_or(0);
                        let head = format!(
                            "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Length: {}\r\nContent-Disposition: attachment; filename=\"{}\"\r\nConnection: close\r\n\r\n",
                            len,
                            json_escape(&name)
                        );
                        let _ = stream.write_all(head.as_bytes());
                        let _ = std::io::copy(&mut f, &mut stream);
                        let _ = stream.flush();
                    }
                    Err(_) => respond(&mut stream, "404 Not Found", "text/plain", b"not found"),
                }
                return;
            }
            let _ = read_body(&mut stream, &req, std::io::sink());
            respond(&mut stream, "404 Not Found", "text/plain", b"not found");
        }
    }
}

fn primary_ip() -> String {
    // UDP "connect" sends nothing; it just reveals the default-route source IP.
    if let Ok(sock) = UdpSocket::bind("0.0.0.0:0") {
        if sock.connect("8.8.8.8:80").is_ok() {
            if let Ok(addr) = sock.local_addr() {
                return addr.ip().to_string();
            }
        }
    }
    "127.0.0.1".to_string()
}

fn main() {
    let dir = if std::path::Path::new("/sdcard").is_dir() {
        PathBuf::from("/sdcard/AERA/Downloads")
    } else {
        PathBuf::from("/tmp/AERA-Downloads")
    };
    if let Err(e) = std::fs::create_dir_all(&dir) {
        eprintln!("cannot create save dir {}: {}", dir.display(), e);
        std::process::exit(1);
    }
    let listener = match TcpListener::bind(("0.0.0.0", PORT)) {
        Ok(l) => l,
        Err(e) => {
            eprintln!("cannot bind port {}: {}", PORT, e);
            std::process::exit(1);
        }
    };
    let st = Arc::new(State {
        dir: dir.clone(),
        fingerprint: rand_hex(32),
        sessions: Mutex::new(HashMap::new()),
    });
    println!("aera-lanrecv listening on 0.0.0.0:{}", PORT);
    println!("  open on your phone browser:  http://{}:{}/", primary_ip(), PORT);
    println!("  LocalSend app: add this IP manually, port {}", PORT);
    println!("  files are saved to: {}", dir.display());
    println!("  while this runs, incoming transfers are accepted. Ctrl-C to stop.");
    for conn in listener.incoming() {
        match conn {
            Ok(stream) => {
                let st2 = Arc::clone(&st);
                std::thread::spawn(move || handle(stream, st2));
            }
            Err(_) => continue,
        }
    }
}

const PAGE: &str = r#"<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>AERA 局域网接收</title>
<style>
body{font-family:sans-serif;background:#111;color:#eee;margin:20px}
h1{font-size:20px}input,button{font-size:16px}
button{background:#2b7fff;color:#fff;border:0;border-radius:6px;padding:10px 18px}
.bar{height:8px;background:#333;border-radius:4px;margin:6px 0 14px}
.bar>i{display:block;height:100%;width:0;background:#2b7fff;border-radius:4px}
a{color:#7db4ff}
li{margin:6px 0}
</style></head><body>
<h1>AERA 局域网接收</h1>
<p>选择文件发送到 recovery（可多选）：</p>
<input type="file" id="f" multiple><br><br>
<button onclick="send()">发送</button>
<div id="list"></div>
<h2>已接收（点名字可下载回）</h2>
<ul id="files"></ul>
<script>
function send(){
  var files=document.getElementById('f').files, box=document.getElementById('list');
  box.innerHTML='';
  for(var i=0;i<files.length;i++){(function(file){
    var row=document.createElement('div');row.textContent=file.name+' ('+file.size+' B)';
    var bar=document.createElement('div');bar.className='bar';var fill=document.createElement('i');
    bar.appendChild(fill);box.appendChild(row);box.appendChild(bar);
    var x=new XMLHttpRequest();
    x.open('POST','/upload-web?name='+encodeURIComponent(file.name));
    x.upload.onprogress=function(e){if(e.lengthComputable)fill.style.width=(100*e.loaded/e.total)+'%';};
    x.onload=function(){row.textContent+=' ✓';load();};
    x.onerror=function(){row.textContent+=' ✗';};
    x.send(file);
  })(files[i]);}
}
function load(){
  fetch('/api/files').then(function(r){return r.json();}).then(function(items){
    var ul=document.getElementById('files');ul.innerHTML='';
    items.forEach(function(it){
      var li=document.createElement('li');
      var a=document.createElement('a');a.href='/dl/'+encodeURIComponent(it.name);a.textContent=it.name;
      li.appendChild(a);li.appendChild(document.createTextNode(' ('+it.size+' B)'));
      ul.appendChild(li);
    });
  });
}
load();
</script></body></html>
"#;
