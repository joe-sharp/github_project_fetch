# frozen_string_literal: true

module GithubRepoFetcher
  # UsageService describes how to use the API: a JSON document for programmatic
  # clients (curl, fetch) and a styled single-page HTML guide for browsers.
  class UsageService
    NAME = 'GitHub Project Fetcher'
    VERSION = '1.0.0'

    def self.json
      {
        name: NAME,
        version: VERSION,
        description: 'API to fetch public repositories and their language data for a given GitHub user. ' \
                     '(Unrelated to GitHub Projects)',
        endpoints: {
          usage: '/api',
          health: '/api/health',
          projects: '/api/projects?username={github_username}'
        },
        parameters: {
          username: 'Required for /api/projects. A GitHub username (max 39 characters).'
        },
        examples: {
          health: '/api/health',
          projects: '/api/projects?username=octocat'
        },
        limits: {
          rate_limit: '60 requests per 5 minutes per IP',
          caching: { projects: '10 minutes', health: '10 seconds', usage: '1 hour' }
        },
        errors: {
          '400' => 'Missing or invalid username, or rate limit exceeded',
          '404' => 'Unknown endpoint',
          '500' => 'GitHub API error (user not found, GitHub rate limit, ...)',
          '503' => 'Health check failed'
        },
        documentation: 'https://github.com/joe-sharp/github_project_fetch#-api-endpoints'
      }
    end

    # Browsers send text/html in Accept; curl and fetch default to */* and get JSON.
    def self.html_requested?(request)
      query = request.respond_to?(:query) ? request.query : nil
      format = query.is_a?(Hash) ? query['format'] : nil
      return format == 'html' if format

      accept = request['accept'] || request['headers']&.dig('accept')
      accept.to_s.include?('text/html')
    end

    def self.html
      HTML
    end

    HTML = <<~'HTML'
      <!DOCTYPE html>
      <html lang="en">
      <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
      <title>GitHub Project Fetch</title>
      <meta name="description" content="A tiny JSON API for a GitHub user's public repositories and their languages.">
      <link rel="preconnect" href="https://fonts.googleapis.com">
      <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
      <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@500;700&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
      <style>
        :root {
          --bg: #120b1a;
          --purple: #8b3fd1;
          --green: #1fa262;
          --gold: #e3b23c;
          --red: #e0115f;
          --ink: #f3eef9;
          --ink-muted: #b6a9c9;
          --hairline: rgba(227, 178, 60, 0.18);
          --panel: rgba(255, 255, 255, 0.04);
        }
        html { scroll-padding-top: env(safe-area-inset-top, 0px); }
        * { box-sizing: border-box; }
        body {
          margin: 0;
          min-height: 100vh;
          background:
            radial-gradient(circle at 12% 8%, rgba(139,63,209,0.35), transparent 40%),
            radial-gradient(circle at 88% 14%, rgba(31,162,98,0.22), transparent 38%),
            radial-gradient(circle at 50% 100%, rgba(227,178,60,0.12), transparent 45%),
            var(--bg);
          color: var(--ink);
          font-family: 'Inter', system-ui, sans-serif;
          display: flex;
          justify-content: center;
          overflow-x: hidden;
        }
        .beads { position: fixed; inset: 0; pointer-events: none; z-index: 0; opacity: 0.5; }
        .beads span { position: absolute; border-radius: 50%; }
        main {
          position: relative;
          z-index: 1;
          width: 100%;
          max-width: 560px;
          padding: calc(4rem + env(safe-area-inset-top, 0px)) 1.5rem 3.5rem;
        }
        .hero { text-align: center; margin-bottom: 2.5rem; }
        .mark { width: 46px; height: 46px; margin: 0 auto 1.5rem; display: block; }
        h1 {
          font-family: 'JetBrains Mono', 'Courier New', monospace;
          font-weight: 700;
          font-size: clamp(1.1rem, 5.4vw, 2rem);
          letter-spacing: -0.01em;
          line-height: 1.1;
          margin: 0 0 0.75rem;
        }
        h1 .prompt { color: var(--green); font-weight: 500; opacity: 0.8; }
        h1 .name-text {
          background: linear-gradient(100deg, var(--gold) 0%, #f0d98a 35%, var(--gold) 60%, #caa23a 100%);
          -webkit-background-clip: text;
          background-clip: text;
          color: transparent;
        }
        h1 .cursor { color: var(--gold); animation: blink 1.1s step-end infinite; }
        @keyframes blink { 0%, 45% { opacity: 1; } 50%, 95% { opacity: 0; } 100% { opacity: 1; } }
        .tagline { font-size: 0.92rem; line-height: 1.55; color: var(--ink-muted); max-width: 42ch; margin: 0 auto 1rem; }
        .pill {
          display: inline-flex; align-items: center; gap: 0.5rem;
          font-size: 0.75rem; color: var(--ink-muted);
          border: 1px solid var(--hairline); border-radius: 999px; padding: 0.3rem 0.75rem;
        }
        .pill i { width: 8px; height: 8px; border-radius: 50%; background: var(--ink-muted); }
        .pill.ok i { background: var(--green); box-shadow: 0 0 8px var(--green); }
        .pill.bad i { background: var(--red); box-shadow: 0 0 8px var(--red); }

        h2 {
          font-family: 'JetBrains Mono', monospace;
          font-size: 0.8rem; font-weight: 500; letter-spacing: 0.08em; text-transform: uppercase;
          color: var(--gold); margin: 2.5rem 0 0.9rem;
        }
        h2::before { content: '~$ '; color: var(--green); }

        .try {
          display: flex; gap: 0.5rem; padding: 0.4rem;
          background: var(--panel); border: 1px solid var(--hairline); border-radius: 12px;
        }
        .try input {
          flex: 1; min-width: 0; background: transparent; border: 0; outline: 0;
          color: var(--ink); font: 500 0.95rem 'JetBrains Mono', monospace; padding: 0.6rem 0.75rem;
        }
        .try input::placeholder { color: var(--ink-muted); opacity: 0.6; }
        .try button {
          border: 0; border-radius: 8px; padding: 0 1.1rem; cursor: pointer;
          background: var(--gold); color: #1a1024; font: 600 0.9rem 'Inter', sans-serif;
        }
        .try button:disabled { opacity: 0.6; cursor: progress; }
        .try button:focus-visible, .copy:focus-visible, summary:focus-visible { outline: 2px solid var(--gold); outline-offset: 2px; }
        #result { margin-top: 1rem; }
        .msg { font-size: 0.85rem; color: var(--ink-muted); }
        .msg.err { color: #ff7a9f; }
        .repo { padding: 0.8rem 0.25rem; border-top: 1px solid var(--hairline); }
        .repo:last-of-type { border-bottom: 1px solid var(--hairline); }
        .repo a { color: var(--ink); font-weight: 500; text-decoration: none; }
        .repo a:hover { color: var(--gold); }
        .repo .meta { font-size: 0.75rem; color: var(--ink-muted); margin-left: 0.5rem; }
        .repo p { margin: 0.25rem 0 0.4rem; font-size: 0.8rem; color: var(--ink-muted); }
        .chip {
          display: inline-block; font: 500 0.7rem 'JetBrains Mono', monospace; margin: 0 0.3rem 0.3rem 0;
          padding: 0.15rem 0.5rem; border-radius: 999px; background: rgba(139,63,209,0.2); color: #d9b8ff;
        }
        details { margin-top: 0.8rem; }
        summary { cursor: pointer; font-size: 0.8rem; color: var(--ink-muted); }

        .endpoint { padding: 1.05rem 0.25rem; border-top: 1px solid var(--hairline); }
        .endpoint:last-of-type { border-bottom: 1px solid var(--hairline); }
        .endpoint .head { display: flex; align-items: baseline; gap: 0.6rem; flex-wrap: wrap; }
        .method { font: 700 0.7rem 'JetBrains Mono', monospace; color: var(--green); }
        .path { font: 500 0.95rem 'JetBrains Mono', monospace; color: var(--ink); word-break: break-all; }
        .desc { font-size: 0.82rem; color: var(--ink-muted); margin: 0.35rem 0 0.7rem; line-height: 1.5; }
        .cmd {
          display: flex; align-items: flex-start; gap: 0.5rem;
          background: rgba(0,0,0,0.35); border-radius: 8px; padding: 0.6rem 0.75rem;
        }
        .cmd code {
          flex: 1; min-width: 0; font: 500 0.78rem/1.5 'JetBrains Mono', monospace;
          color: #e8dfa8; overflow-wrap: anywhere;
        }
        .copy {
          flex: none; background: none; border: 1px solid var(--hairline); color: var(--ink-muted);
          border-radius: 6px; font: 500 0.7rem 'Inter', sans-serif; padding: 0.2rem 0.5rem; cursor: pointer;
        }
        .copy:hover { color: var(--gold); border-color: var(--gold); }

        table { width: 100%; border-collapse: collapse; font-size: 0.82rem; }
        td { padding: 0.55rem 0.25rem; border-top: 1px solid var(--hairline); vertical-align: top; color: var(--ink-muted); }
        table tr:last-child td { border-bottom: 1px solid var(--hairline); }
        td:first-child { font-family: 'JetBrains Mono', monospace; color: var(--ink); white-space: nowrap; padding-right: 1rem; }
        pre {
          margin: 0.8rem 0 0; padding: 0.8rem; background: rgba(0,0,0,0.35); border-radius: 8px;
          font: 500 0.75rem/1.5 'JetBrains Mono', monospace; color: #e8dfa8; overflow-x: auto;
        }
        footer { text-align: center; margin-top: 3rem; font-size: 0.76rem; }
        footer a {
          color: #06b6d4; text-decoration: none; font-weight: 600; padding: 4px 8px; border-radius: 4px;
          display: inline-block; transition: all 0.3s ease;
        }
        footer a:hover { background: rgba(6,182,212,0.1); text-shadow: 0 0 8px rgba(6,182,212,0.6); color: #22d3ee; }
        @media (prefers-reduced-motion: reduce) {
          h1 .cursor { animation: none; opacity: 1; }
          footer a { transition: none; }
        }
      </style>
      </head>
      <body>
      <div class="beads" aria-hidden="true">
        <span style="width:7px;height:7px;background:var(--gold);top:6%;left:18%;"></span>
        <span style="width:5px;height:5px;background:var(--purple);top:12%;left:78%;"></span>
        <span style="width:6px;height:6px;background:var(--green);top:22%;left:8%;"></span>
        <span style="width:4px;height:4px;background:var(--gold);top:30%;left:88%;"></span>
        <span style="width:8px;height:8px;background:var(--purple);top:48%;left:4%;"></span>
        <span style="width:5px;height:5px;background:var(--green);top:58%;left:92%;"></span>
        <span style="width:6px;height:6px;background:var(--gold);top:72%;left:14%;"></span>
        <span style="width:4px;height:4px;background:var(--purple);top:80%;left:82%;"></span>
        <span style="width:5px;height:5px;background:var(--green);top:90%;left:22%;"></span>
      </div>

      <main>
        <div class="hero">
          <svg class="mark" viewBox="0 0 48 48" fill="none" aria-hidden="true">
            <circle cx="16" cy="18" r="10" fill="var(--purple)" opacity="0.9"/>
            <circle cx="32" cy="18" r="10" fill="var(--green)" opacity="0.9"/>
            <circle cx="24" cy="32" r="10" fill="var(--gold)" opacity="0.9"/>
          </svg>
          <h1><span class="prompt">~$</span> <span class="name-text">github-project-fetch</span><span class="cursor">_</span></h1>
          <p class="tagline">A tiny JSON API for a GitHub user's public repositories and the languages in them. No key, no signup.</p>
          <span class="pill" id="health"><i></i><span>checking API health&hellip;</span></span>
        </div>

        <h2>Try it</h2>
        <form class="try" id="tryForm">
          <input id="username" name="username" placeholder="github username" value="octocat"
                 maxlength="39" autocomplete="off" autocapitalize="off" spellcheck="false" aria-label="GitHub username">
          <button type="submit" id="go">Fetch</button>
        </form>
        <div id="result" aria-live="polite"></div>

        <h2>Endpoints</h2>
        <div class="endpoint">
          <div class="head"><span class="method">GET</span><span class="path">/api/projects?username={username}</span></div>
          <p class="desc">Public repositories for a user, each with its description, language byte counts, stars, forks and timestamps.</p>
          <div class="cmd"><code data-curl="/api/projects?username=octocat"></code><button class="copy" type="button">Copy</button></div>
        </div>
        <div class="endpoint">
          <div class="head"><span class="method">GET</span><span class="path">/api/health</span></div>
          <p class="desc">Status of the GitHub API connection and the remaining GitHub rate limit.</p>
          <div class="cmd"><code data-curl="/api/health"></code><button class="copy" type="button">Copy</button></div>
        </div>
        <div class="endpoint">
          <div class="head"><span class="method">GET</span><span class="path">/api</span></div>
          <p class="desc">This guide in a browser; the same information as JSON for anything else (or add <code>?format=json</code>).</p>
          <div class="cmd"><code data-curl="/api"></code><button class="copy" type="button">Copy</button></div>
        </div>

        <h2>Response shape</h2>
        <pre>{
        "username": "octocat",
        "projects_count": 8,
        "projects": [{
          "name": "linguist",
          "description": "Language Savant. ...",
          "languages": { "Ruby": 204865, "Shell": 910 },
          "forks_count": 219,
          "stargazers_count": 576,
          "html_url": "https://github.com/octocat/linguist",
          "created_at": "2016-08-02 17:35:14 UTC",
          "updated_at": "2025-08-03 07:36:00 UTC"
        }]
      }</pre>

        <h2>Good to know</h2>
        <table>
          <tr><td>Rate limit</td><td>60 requests per 5 minutes per IP.</td></tr>
          <tr><td>Caching</td><td>Projects 10 min, health 10 sec, this page 1 hour (stale-while-revalidate).</td></tr>
          <tr><td>Languages</td><td>From GitHub's languages API. Repos with none (YAML, JSON, Markdown only) fall back to file-extension counts.</td></tr>
          <tr><td>CORS</td><td>Open to any origin, so you can call it straight from the browser.</td></tr>
          <tr><td>400</td><td>Missing or invalid username, or rate limit exceeded.</td></tr>
          <tr><td>500</td><td>GitHub error, e.g. user not found or GitHub rate limit.</td></tr>
        </table>

        <footer>
          <a href="https://github.com/joe-sharp/github_project_fetch" target="_blank" rel="noopener">source on github</a>
          <a href="https://joe-sharp.com" target="_blank" rel="noopener">joe-sharp.com</a>
        </footer>
      </main>

      <script>
        (function () {
          var base = location.origin;
          var $ = function (id) { return document.getElementById(id); };

          document.querySelectorAll('[data-curl]').forEach(function (el) {
            el.textContent = "curl '" + base + el.getAttribute('data-curl') + "'";
          });
          document.querySelectorAll('.copy').forEach(function (btn) {
            btn.addEventListener('click', function () {
              var text = btn.parentNode.querySelector('code').textContent;
              if (!navigator.clipboard) return;
              navigator.clipboard.writeText(text).then(function () {
                btn.textContent = 'Copied';
                setTimeout(function () { btn.textContent = 'Copy'; }, 1500);
              });
            });
          });

          function setHealth(cls, text) {
            var pill = $('health');
            pill.className = 'pill ' + cls;
            pill.lastChild.textContent = text;
          }
          fetch('/api/health').then(function (r) { return r.json(); }).then(function (d) {
            if (d.status === 'healthy' && d.rate_limit) {
              setHealth('ok', 'API healthy · ' + d.rate_limit.remaining + ' GitHub calls left');
            } else {
              setHealth('bad', 'API unhealthy');
            }
          }).catch(function () { setHealth('bad', 'API unreachable'); });

          function el(tag, cls, text) {
            var n = document.createElement(tag);
            if (cls) n.className = cls;
            if (text !== undefined) n.textContent = text;
            return n;
          }

          function render(data) {
            var out = $('result');
            out.textContent = '';
            out.appendChild(el('p', 'msg', data.projects_count + ' public repositories for ' + data.username));
            data.projects.slice(0, 10).forEach(function (p) {
              var row = el('div', 'repo');
              var a = el('a', null, p.name);
              a.href = /^https:\/\/github\.com\//.test(p.html_url) ? p.html_url : '#';
              a.target = '_blank';
              a.rel = 'noopener';
              row.appendChild(a);
              row.appendChild(el('span', 'meta', '★ ' + p.stargazers_count + ' · forks ' + p.forks_count));
              if (p.description) row.appendChild(el('p', null, p.description));
              var langs = el('div');
              Object.keys(p.languages || {}).forEach(function (l) { langs.appendChild(el('span', 'chip', l)); });
              row.appendChild(langs);
              out.appendChild(row);
            });
            if (data.projects.length > 10) {
              out.appendChild(el('p', 'msg', 'Showing 10 of ' + data.projects.length + '.'));
            }
            var d = el('details');
            d.appendChild(el('summary', null, 'Raw JSON'));
            d.appendChild(el('pre', null, JSON.stringify(data, null, 2)));
            out.appendChild(d);
          }

          $('tryForm').addEventListener('submit', function (e) {
            e.preventDefault();
            var name = $('username').value.trim();
            var out = $('result');
            var btn = $('go');
            if (!name) return;
            btn.disabled = true;
            out.textContent = '';
            out.appendChild(el('p', 'msg', 'Fetching…'));
            fetch('/api/projects?username=' + encodeURIComponent(name))
              .then(function (r) { return r.json().then(function (j) { return { ok: r.ok, body: j }; }); })
              .then(function (res) {
                if (res.ok) { render(res.body); return; }
                out.textContent = '';
                out.appendChild(el('p', 'msg err', res.body.error || 'Request failed'));
              })
              .catch(function () {
                out.textContent = '';
                out.appendChild(el('p', 'msg err', 'Could not reach the API'));
              })
              .then(function () { btn.disabled = false; });
          });
        })();
      </script>
      </body>
      </html>
    HTML
  end
end
