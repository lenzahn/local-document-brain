# Local Document Brain

Private document chat that runs entirely on one machine. Ask questions about
technical PDFs — tables and diagrams included — and get answers grounded in the
real pages. Nothing leaves the computer, before or after setup.

Three maintained open-source projects, wired together. Nothing bespoke, and
every setting lives in `docker-compose.yml`.

| Component | Role | Where it runs |
|---|---|---|
| [Ollama](https://github.com/ollama/ollama) | The AI models | Host application |
| [Open WebUI](https://github.com/open-webui/open-webui) | Chat, chunking, embedding, retrieval | `open-webui` container |
| [Docling](https://github.com/docling-project/docling) | Reads PDFs: text, tables, figures | `docling` container |

---

## If you are an AI agent

1. Follow these steps in order. Use the exact commands and values given.
2. Do not invent model names, versions or URLs. Everything needed is here.
3. After each command, check the output before continuing.
4. If a command fails, stop and report the exact error. Do not guess a fix.
5. `start.cmd` does the rest of the work on its own. Do not re-implement it.

---

## Requirements

| | |
|---|---|
| Ollama | https://ollama.com/download |
| Docker Desktop | https://www.docker.com/products/docker-desktop/ |
| Git | https://git-scm.com/downloads |
| Machine | 16 GB RAM, 20 GB free disk, Windows 10/11 |

Downloads, once: about **9 GB** of container images
([Docling Serve](https://github.com/docling-project/docling-serve#container-images)
is the larger part) plus about **9 GB** of models.

Docker is required. If the machine cannot run Docker, this stack is not suitable
for it.

---

## Deploy

### 1. Install the three prerequisites

Ollama, Docker Desktop and Git. Start Docker Desktop once and confirm:

```bash
docker info
```

This must print a block of information, not an error.

### 2. Clone the repository

```bash
git clone https://github.com/lenzahn/local-document-brain
cd local-document-brain
```

### 3. Create the desktop shortcut

Double-click **`create-desktop-shortcut.cmd`**. It puts a
**Local Document Brain** shortcut on the Desktop.

That is the entire setup.

### 4. Use the shortcut

Double-click the shortcut. A terminal window opens and:

1. starts Docker Desktop if it is not running, and waits for it
2. starts Ollama if it is not running, and waits for it
3. downloads any missing model (first run only)
4. starts the two services
5. waits until the website answers, then opens **http://localhost:3000**
6. leaves a live log on screen

The first run takes a while — it downloads images and models. Later runs start
in seconds.

Press `Ctrl+C` to close the log window; the services keep running. To stop them
completely:

```bash
docker compose down
```

---

## Configure once

Two settings are not part of the repository, because they live outside it.

**Create the admin account.** On first launch, open **http://localhost:3000**
and register. The first account becomes the administrator.

**Raise the memory window.** Ollama's default context window is small:

```powershell
setx OLLAMA_CONTEXT_LENGTH 16384
```

Then quit Ollama from the system tray and start it again. See
[Ollama — context length](https://docs.ollama.com/context-length).

Leave `num_ctx` **blank** in Open WebUI. A value typed there overrides Ollama's
setting, and its control pre-fills with `2048`, which caps the model at a few
pages. See
[Open WebUI — starting with Ollama](https://docs.openwebui.com/getting-started/quick-start/connect-a-provider/starting-with-ollama).

That is all. There is nothing to configure in Open WebUI's admin panel.

---

## Using it

1. **Workspace → Knowledge → Create Knowledge**, name it.
2. Drag PDFs in and wait. A 15-page PDF with figure descriptions takes minutes.
3. New chat → model `granite4.2:8b` → type `#` and pick the knowledge base.
4. Ask.

For short documents, switch on **Full Context mode** in the chat settings. It
passes the whole document instead of searching it, and usually answers better.
Leave it off for long ones.

**Offline:** after setup, no internet is needed.

---

## Files

| File | Purpose |
|---|---|
| `start.cmd` | Launcher: checks, starts, opens the browser, shows logs |
| `create-desktop-shortcut.cmd` | Puts `start.cmd` on the Desktop |
| `docker-compose.yml` | The whole deployment, including all settings |
| `README.md` | This document |

---

## Configuration

All of it sits in `docker-compose.yml`. Variable names and defaults come from the
[Open WebUI environment reference](https://docs.openwebui.com/reference/env-configuration).

| Setting | Value | Why |
|---|---|---|
| `OLLAMA_BASE_URL` | `http://host.docker.internal:11434` | Ollama listens on the host; `localhost` inside a container is the container itself |
| `RAG_EMBEDDING_ENGINE` | `ollama` | Embed on the host rather than fetching a second model into the container |
| `RAG_EMBEDDING_MODEL` | `nomic-embed-text` | Small, well suited to retrieval |
| `RAG_EMBEDDING_CONTENT_PREFIX` | `search_document: ` | **Required by nomic-embed-text.** The reference names this exact string |
| `RAG_EMBEDDING_QUERY_PREFIX` | `search_query: ` | The counterpart, likewise named in the reference |
| `CONTENT_EXTRACTION_ENGINE` | `docling` | Use Docling instead of the built-in text loader |
| `DOCLING_SERVER_URL` | `http://docling:5001` | Matches the service name; also Docling's documented default |
| `DOCLING_PARAMS` | see file | Docling's options, described in the reference as "the primary configuration method" |
| `DOCLING_SERVE_ENABLE_REMOTE_SERVICES` | `true` | Without it Docling refuses to call Ollama; see [Docling usage](https://github.com/docling-project/docling-serve/blob/main/docs/usage.md) |
| `UVICORN_WORKERS` | `1` | More than one worker makes uploads fail with "Task not found" |
| `DOCLING_SERVE_MAX_SYNC_WAIT` | `600` | Default is 120s, too short for describing many figures |

Images are pinned to `open-webui:0.11.2` and `docling-serve:v1.33.0` so a
deployment does not change behaviour underneath you. Both projects also publish
`main`/`latest` if you would rather track them.

`DOCLING_PARAMS` turns on `do_picture_description` and points it at Ollama's
OpenAI-compatible endpoint. The field names inside `picture_description_api` —
`url`, `params`, `timeout`, `prompt` — are Docling's, not ours; see the
[picture description section of the Docling usage docs](https://github.com/docling-project/docling-serve/blob/main/docs/usage.md).

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

The containers reach it over `host.docker.internal`. That was tested rather than
assumed: on Docker Desktop it resolves to the host and reaches a service bound
to `127.0.0.1`, which is how Ollama listens by default. `gateway.docker.internal`
does **not** work for this, which is why the compose file uses
`host.docker.internal` and `extra_hosts` together.

---

## Sources

Everything above is taken from these; they are the place to check first.

| Document | Used for |
|---|---|
| [Open WebUI — environment reference](https://docs.openwebui.com/reference/env-configuration) | Every variable name, default and allowed value |
| [Open WebUI — Docling extraction](https://docs.openwebui.com/features/chat-conversations/rag/document-extraction/docling) | Installing Docling, and why nested options must be JSON strings |
| [Open WebUI — starting with Ollama](https://docs.openwebui.com/getting-started/quick-start/connect-a-provider/starting-with-ollama) | `num_ctx` versus `OLLAMA_CONTEXT_LENGTH` |
| [Ollama — context length](https://docs.ollama.com/context-length) | Default window sizes and how to change them |
| [Docling Serve](https://github.com/docling-project/docling-serve) | Container images, tags, sizes, ports |
| [Docling Serve — usage](https://github.com/docling-project/docling-serve/blob/main/docs/usage.md) | Conversion options, picture description, remote services |
| [Docling Serve — configuration](https://github.com/docling-project/docling-serve/blob/main/docs/configuration.md) | Server environment variables and presets |

---

## If it does not work

| Symptom | Cause | Fix |
|---|---|---|
| Questions work but figures are never described | Docling could not reach Ollama | Check `DOCLING_SERVE_ENABLE_REMOTE_SERVICES: "true"`, then `docker compose logs docling` |
| Open WebUI reports it cannot reach the document extractor | Wrong URL | `DOCLING_SERVER_URL` must be `http://docling:5001`, matching the service name |
| Upload fails with `Task not found` | More than one Docling worker | Keep `UVICORN_WORKERS: "1"`, then `docker compose up -d` |
| Answers ignore most of the document | Memory window too small | Redo the `setx` step, and leave `num_ctx` blank |
| No models listed in Open WebUI | Ollama unreachable from the container | `curl.exe http://localhost:11434/api/tags` should list them. If it does and Open WebUI is still empty, set `OLLAMA_HOST` to `0.0.0.0:11434` and restart Ollama |
| Website will not open | Docker not running | Run the shortcut again; it starts Docker for you |
| `start.cmd` closes straight away | A prerequisite is missing | Run it from a terminal instead of double-clicking, to read the message |
