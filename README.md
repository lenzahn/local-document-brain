# Local Document Brain

Private document chat that runs entirely on one Windows PC. Ask questions about
technical PDFs — tables and diagrams included — and get answers grounded in the
actual pages. Nothing is sent to the internet, before or after setup.

Three maintained open-source projects, wired together. Nothing bespoke.

| Project | Role |
|---|---|
| [Ollama](https://github.com/ollama/ollama) | Runs the AI models |
| [Open WebUI](https://github.com/open-webui/open-webui) | Chat interface, chunking, embedding, retrieval |
| [Docling](https://github.com/docling-project/docling) | Reads PDFs: text, tables, figures, charts |

---

## If you are an AI agent

1. Use the exact commands and values below. Do not invent names or versions.
2. Run one step at a time and check the output before continuing.
3. If a command fails, stop and paste the exact error. Do not guess a fix.
4. Ask the human before the downloads in steps 3 and 4.
5. Steps marked **[HUMAN]** are browser clicks. You cannot do them. Ask, then wait.

---

## Requirements

- **Ollama** — https://ollama.com/download
- **Docker Desktop** — https://www.docker.com/products/docker-desktop/
- Windows 10/11, 16 GB RAM or more, 20 GB free disk space

Docker is required. If the machine cannot run Docker, this stack is not suitable
for it.

---

## Setup

### 1. Install the two prerequisites

Install Ollama and Docker Desktop. Start Docker Desktop, then confirm it works:

```powershell
docker info
```

This must print a block of information, not an error.

### 2. Copy this folder to the machine

Open PowerShell inside the folder:

```powershell
Set-Location <path-to-this-folder>
```

### 3. Start the services

First run downloads roughly 9 GB of container images.

```powershell
docker compose up -d
docker compose ps
```

Both `open-webui` and `docling` must show `running`. If either shows `exited` or
`restarting`, run `docker compose logs` and stop.

### 4. Download the AI models

Roughly 9 GB.

```powershell
ollama pull granite4.2:8b
ollama pull ibm/granite3.3-vision:2b
ollama pull nomic-embed-text
ollama list
```

`ollama list` must show all three names.

### 5. **[HUMAN]** Configure the chat interface

Open **http://localhost:3000** and create the first account. It automatically
becomes the administrator. Then, in **Admin Settings → Documents**:

| Setting | Value |
|---|---|
| Content Extraction Engine | `Docling` |
| Extraction Engine URL | `http://docling:5001` |
| Embedding Engine | `Ollama` |
| Embedding Model | `nomic-embed-text` |
| Docling Parameters | paste the entire contents of `docling-settings.json` |

Save, then press `Ctrl+F5`. Open WebUI can start before the models finish
downloading, so the model list may look empty until the page is refreshed.

### 6. **[HUMAN]** Raise the model's memory window

In the **Ollama app** → Settings → **Context Length = 16384**.

Then in Open WebUI, open **Chat Controls → Advanced Parameters** and make sure
**`num_ctx` is blank**.

> This step is not optional. Ollama's default window is small, and Open WebUI's
> `num_ctx` box pre-fills with `2048`. If `num_ctx` has any value, it overrides
> Ollama and the model sees only a few pages — then answers incorrectly without
> warning. This is the single most common cause of bad results.

### 7. Verify

```powershell
curl.exe -s -o NUL -w "%{http_code}" http://localhost:5001/ui
curl.exe -s -o NUL -w "%{http_code}" http://localhost:3000
```

The first must print `200`. The second must print `200`, `302` or `307`.

---

## Using it

1. **Workspace → Knowledge → Create Knowledge**, and name it.
2. Drag your PDFs in. Wait for processing to finish — a 15-page PDF with figure
   descriptions can take several minutes.
3. Start a new chat, choose the model `granite4.2:8b`, and type `#` to attach
   the knowledge base.
4. Ask your question.

For short documents, switch on **Full Context mode** in the chat settings. It
passes the whole document instead of searching it, and usually answers better.
Leave it off for long documents.

**Starting it again:** start Docker Desktop, then run `docker compose up -d`.

**Going offline:** after setup, no internet is needed. Everything runs locally.

---

## How it works

```
PDF
 └─ Docling: OCR, table structure, and figure/chart descriptions
             (figures described by ibm/granite3.3-vision:2b)
     └─ Open WebUI: chunks, embeds with nomic-embed-text, stores locally
         └─ You ask a question
             └─ Open WebUI retrieves the matching chunks
                 └─ granite4.2:8b answers, grounded in those chunks
```

Ollama runs as a normal host application rather than a container, because
graphics-card access is simpler and better supported that way.

---

## Optional: turn on chart number extraction

Docling can also read the *numbers* out of bar, line and pie charts, not just
describe them. Add one line to `docling-settings.json` and re-index:

```json
"do_chart_extraction": true
```

Left off by default because it needs an extra model download inside the
container on first use, which must happen while the machine is online.

---

## Files

| File | Purpose |
|---|---|
| `docker-compose.yml` | Runs Open WebUI and Docling |
| `docling-settings.json` | Pasted into Open WebUI in step 5 |
| `README.md` | This document |

---

## Documentation

- Open WebUI + Docling (official guide) — https://docs.openwebui.com/features/chat-conversations/rag/document-extraction/docling
- Open WebUI + Ollama, including `num_ctx` — https://docs.openwebui.com/getting-started/quick-start/connect-a-provider/starting-with-ollama
- Ollama context length — https://docs.ollama.com/context-length
- Docling Serve — https://github.com/docling-project/docling-serve
- Docling conversion options — https://github.com/docling-project/docling-serve/blob/main/docs/usage.md

---

## If it does not work

| Symptom | Cause | Fix |
|---|---|---|
| Upload fails with `Task not found` | Docling running more than one worker | Keep `UVICORN_WORKERS: "1"`, then `docker compose up -d` |
| `Connections to remote services is only allowed when set explicitly` | Docling blocked from calling Ollama | Keep `DOCLING_SERVE_ENABLE_REMOTE_SERVICES: "true"` |
| `Invalid JSON for field ...` | Docling Parameters filled incorrectly | Re-paste `docling-settings.json` exactly, backslashes included |
| Figures get no description | The picture settings were not applied | Check `DOCLING_SERVER_URL` is `http://docling:5001` and that step 5 was saved |
| Answers ignore most of the document | Memory window too small | Redo step 6 |
| Website will not open | Docker not running | Start Docker Desktop, then `docker compose up -d` |
