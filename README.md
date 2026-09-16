# Local Document Brain

Private document chat that runs entirely on one machine. Ask questions about
technical PDFs — tables and diagrams included — and get answers grounded in the
real pages. Nothing leaves the computer, before or after setup.

Three maintained open-source projects, wired together. Nothing bespoke, and
every setting lives in `docker-compose.yml`.

| Component | Role | Source |
|---|---|---|
| [Ollama](https://github.com/ollama/ollama) | Runs the AI models | Host application |
| [Open WebUI](https://github.com/open-webui/open-webui) | Chat, chunking, embedding, retrieval | `open-webui` service |
| [Docling](https://github.com/docling-project/docling) | Reads PDFs: text, tables, figures | `docling` service |

---

## If you are an AI agent

1. Follow these steps in order. Use the exact commands and values given.
2. Do not invent model names, versions or URLs. Everything needed is here.
3. After each command, check the output before continuing.
4. If a command fails, stop and report the exact error. Do not guess a fix.
5. Step 5 is a browser action for the human. You cannot do it. Ask, then wait.

---

## Requirements

| | |
|---|---|
| Ollama | https://ollama.com/download |
| Docker Desktop | https://www.docker.com/products/docker-desktop/ |
| Git | https://git-scm.com/downloads |
| Machine | 16 GB RAM, 20 GB free disk, Windows 10/11, macOS or Linux |

Downloads, once: **8.7 GB** of Docling image on x86-64 — 4.4 GB on ARM —
([Docling Serve container images](https://github.com/docling-project/docling-serve#container-images)),
plus roughly **9 GB** of models.

Docker is required. If the machine cannot run Docker, this stack is not suitable
for it.

---

## Setup

### 1. Install the prerequisites

Install Ollama and Docker Desktop. Start Docker Desktop, then confirm:

```bash
docker info
```

This must print a block of information, not an error.

### 2. Clone this repository

```bash
git clone https://github.com/lenzahn/local-document-brain
cd local-document-brain
```

### 3. Download the models

Do this before starting the services, so Open WebUI finds every model on its
first boot.

```bash
ollama pull granite4.2:8b
ollama pull ibm/granite3.3-vision:2b
ollama pull nomic-embed-text
ollama list
```

`ollama list` must show all three.

### 4. Raise the memory window

Ollama's default context window is small, so set it once at the operating
system level. On Windows:

```powershell
setx OLLAMA_CONTEXT_LENGTH 16384
```

Then quit Ollama from the system tray and start it again, so it picks up the
new value. (The Ollama app also exposes this as a **Context Length** slider in
its own settings.) See
[Ollama — context length](https://docs.ollama.com/context-length).

Leave `num_ctx` **blank** in Open WebUI. A value typed there overrides Ollama's
setting, and its control pre-fills with `2048`, which caps the model at a few
pages. See
[Open WebUI — starting with Ollama](https://docs.openwebui.com/getting-started/quick-start/connect-a-provider/starting-with-ollama).

### 5. Start the services

```bash
docker compose up -d
docker compose ps
```

Both `open-webui` and `docling` must show `running`. If either shows `exited` or
`restarting`, run `docker compose logs` and stop.

### 6. Open it

Go to **http://localhost:3000** and create the first account. It becomes the
administrator. That is the whole setup — there is nothing to configure in the
admin panel, and step 7 only confirms it.

### 7. Verify

On Windows (`curl` alone is a PowerShell alias, so call `curl.exe`):

```powershell
curl.exe -s -o NUL -w "%{http_code}`n" http://localhost:5001/ui   # reader
curl.exe -s -o NUL -w "%{http_code}`n" http://localhost:3000      # website
```

On macOS and Linux, use `-o /dev/null` instead of `-o NUL`.

The first must print `200`. The second must print `200`, `302` or `307`.

---

## Using it

1. **Workspace → Knowledge → Create Knowledge**, name it.
2. Drag PDFs in and wait. A 15-page PDF with figure descriptions takes minutes.
3. New chat → model `granite4.2:8b` → type `#` and pick the knowledge base.
4. Ask.

For short documents, switch on **Full Context mode** in the chat settings. It
passes the whole document instead of searching it, and usually answers better.
Leave it off for long ones.

**Restart:** start Docker Desktop, then `docker compose up -d`.

**Offline:** after setup, no internet is needed.

---

## Configuration

All of it sits in `docker-compose.yml`. Variable names and defaults are from the
[Open WebUI environment reference](https://docs.openwebui.com/reference/env-configuration).

| Setting | Value | Why |
|---|---|---|
| `OLLAMA_BASE_URL` | `http://host.docker.internal:11434` | Ollama listens on the host; `localhost` inside a container means the container itself |
| `RAG_EMBEDDING_ENGINE` | `ollama` | Embed on the host rather than downloading a second model into the container |
| `RAG_EMBEDDING_MODEL` | `nomic-embed-text` | Small and well suited to retrieval |
| `RAG_EMBEDDING_CONTENT_PREFIX` | `search_document: ` | **Required by nomic-embed-text.** The reference names this exact string |
| `RAG_EMBEDDING_QUERY_PREFIX` | `search_query: ` | The counterpart, likewise named in the reference |
| `CONTENT_EXTRACTION_ENGINE` | `docling` | Use Docling instead of the built-in text loader |
| `DOCLING_SERVER_URL` | `http://docling:5001` | Matches the service name; this is also Docling's documented default |
| `DOCLING_PARAMS` | see file | Docling's processing options, described in the reference as "the primary configuration method" |
| `DOCLING_SERVE_ENABLE_REMOTE_SERVICES` | `true` | Without it Docling refuses to call Ollama; see [Docling usage](https://github.com/docling-project/docling-serve/blob/main/docs/usage.md) |
| `UVICORN_WORKERS` | `1` | More than one worker makes uploads fail with "Task not found" |
| `DOCLING_SERVE_MAX_SYNC_WAIT` | `600` | Default is 120s, too short for describing many figures |

`DOCLING_PARAMS` turns on `do_picture_description` and points it at Ollama's
OpenAI-compatible endpoint. The field names inside `picture_description_api` —
`url`, `params`, `timeout`, `prompt` — are Docling's, not ours; see the
[picture description section of the Docling usage docs](https://github.com/docling-project/docling-serve/blob/main/docs/usage.md#picture-description).

To also read the *numbers* out of charts, add `"do_chart_extraction": true` to
`DOCLING_PARAMS` and re-index. It is off by default because it downloads an
extra model inside the container on first use, which needs internet.

---

## How it works

```
PDF
 └─ docling:  text, tables, and written descriptions of figures and charts
             (descriptions generated by ibm/granite3.3-vision:2b via Ollama)
     └─ open-webui:  chunks it, embeds it with nomic-embed-text, stores it locally
         └─ you ask a question
             └─ open-webui retrieves the matching chunks
                 └─ granite4.2:8b answers from those chunks
```

Ollama runs on the host rather than in a container so it can use the graphics
card directly — the arrangement both projects document.

---

## Sources

Everything above is taken from these; they are the place to check first.

| Document | Used for |
|---|---|
| [Open WebUI — environment reference](https://docs.openwebui.com/reference/env-configuration) | Every variable name, default and allowed value |
| [Open WebUI — Docling extraction](https://docs.openwebui.com/features/chat-conversations/rag/document-extraction/docling) | Installing Docling, and why nested options must be JSON strings |
| [Open WebUI — starting with Ollama](https://docs.openwebui.com/getting-started/quick-start/connect-a-provider/starting-with-ollama) | `num_ctx` versus `OLLAMA_CONTEXT_LENGTH` |
| [Ollama — context length](https://docs.ollama.com/context-length) | Default window sizes and how to change them |
| [Docling Serve](https://github.com/docling-project/docling-serve) | Container images, sizes, ports |
| [Docling Serve — usage](https://github.com/docling-project/docling-serve/blob/main/docs/usage.md) | Conversion options, picture description, remote services |
| [Docling Serve — configuration](https://github.com/docling-project/docling-serve/blob/main/docs/configuration.md) | Server environment variables and presets |

---

## If it does not work

| Symptom | Cause | Fix |
|---|---|---|
| Questions work but figures are never described | Docling could not reach Ollama | Check `DOCLING_SERVE_ENABLE_REMOTE_SERVICES: "true"`, then `docker compose logs docling` |
| Open WebUI reports it cannot reach the document extractor | Wrong URL | `DOCLING_SERVER_URL` must be `http://docling:5001`, matching the service name |
| Upload fails with `Task not found` | More than one Docling worker | Keep `UVICORN_WORKERS: "1"`, then `docker compose up -d` |
| Answers ignore most of the document | Memory window too small | Redo step 5, and leave `num_ctx` blank |
| No models listed in Open WebUI | Ollama unreachable from the container | Press `Ctrl+F5`; then `curl.exe http://localhost:11434/api/tags`. If that works but Open WebUI stays empty, set `OLLAMA_HOST` to `0.0.0.0:11434` and restart Ollama |
| Website will not open | Docker not running | Start Docker Desktop, then `docker compose up -d` |
