# 🔄 N8N Git Workflow Sync Manager (CI/CD Automated Deployment)

The **`n8n_git_sync_manager.json`** workflow automates synchronization between your GitHub repository and your N8N instance.

Whenever you push commits to GitHub, or when you click **Manual Trigger**, N8N automatically:
1. Scans the GitHub repository for workflow JSON files.
2. Fetches their content and parses nodes/connections.
3. Checks against existing N8N workflows by name.
4. **Updates** existing workflows or **Creates** new ones via the N8N Public API (`/api/v1/workflows`).
5. **Keeps all imported/updated workflows unpublished (`active: false`)** by default so you maintain full control over when to publish them.

---

## 🧭 Sync Pipeline Architecture

```
                                  🐙 GitHub Push Event
                                            │
                                            ▼
                    ┌───────────────────────────────────────────────┐
                    │       Webhook / Manual Trigger (N8N)          │
                    └───────────────────────┬───────────────────────┘
                                            │
                                            ▼
                    ┌───────────────────────────────────────────────┐
                    │    1. Fetch Repo Tree (GitHub API v3)         │
                    │       GET /repos/{owner}/{repo}/git/trees     │
                    └───────────────────────┬───────────────────────┘
                                            │
                                            ▼
                    ┌───────────────────────────────────────────────┐
                    │    2. Filter & Download Workflow JSONs        │
                    │       (flow0_*.json, flow1_*.json, etc.)      │
                    └───────────────────────┬───────────────────────┘
                                            │
                                            ▼
                    ┌───────────────────────────────────────────────┐
                    │    3. List Existing N8N Workflows             │
                    │       GET /api/v1/workflows                   │
                    └───────────────────────┬───────────────────────┘
                                            │
                                            ▼
                    ┌───────────────────────────────────────────────┐
                    │    4. Decision: Match by Workflow Name        │
                    └───────────────┬───────────────┬───────────────┘
                                    │               │
                            [Already Exists]   [Brand New]
                                    │               │
                                    ▼               ▼
                    ┌──────────────────────┐ ┌──────────────────────┐
                    │  PUT /workflows/{id} │ │   POST /workflows    │
                    │  (Update in-place)   │ │   (Create New)       │
                    └───────────────┬──────┘ └──────┬───────────────┘
                                    │               │
                                    └───────┬───────┘
                                            │
                                            ▼
                    ┌───────────────────────────────────────────────┐
                    │  5. Execution Summary (active: false policy)  │
                    └───────────────────────────────────────────────┘
```

---

## 🛠️ Step-by-Step Setup Guide

### 1. Generate an N8N Public API Key
1. Open your N8N instance (`http://localhost:5678` or `https://n8n.yourdomain.com`).
2. Go to **Settings > Public API**.
3. Click **Create API Key**, give it a name (e.g., `Git Sync API Key`), and copy the key.
4. In `n8n_git_sync_manager.json`, replace `YOUR_N8N_PUBLIC_API_KEY` with your API key in the three HTTP nodes:
   - `HTTP - List Existing N8N Workflows`
   - `HTTP - Update Workflow in N8N`
   - `HTTP - Create Workflow in N8N`

---

### 2. Configure GitHub Webhook (Auto-Sync on Push)
1. Go to your GitHub repository (**[`jjms95/n8n-commerce-flows`](https://github.com/jjms95/n8n-commerce-flows)**) > **Settings > Webhooks > Add webhook**.
2. **Payload URL**:
   ```
   https://n8n.yourdomain.com/webhook/github-push-sync
   ```
   *(Or your active ngrok tunnel URL: `https://<your-subdomain>.ngrok-free.app/webhook/github-push-sync`)*
3. **Content type**: `application/json`.
4. **Which events would you like to trigger this webhook?**: Select **Just the push event**.
5. Click **Add webhook**.

---

### 3. Workflow Configuration Node (`Code - Initialize Sync Configuration`)
Inside `n8n_git_sync_manager.json`, the node **`Code - Initialize Sync Configuration`** controls defaults:

```javascript
const DEFAULT_OWNER  = 'jjms95';
const DEFAULT_REPO   = 'n8n-commerce-flows';
const DEFAULT_BRANCH = 'main';
const N8N_BASE_URL   = 'http://127.0.0.1:5678';
const AUTO_ACTIVATE  = false; // Keeps workflows inactive for safety
```

* **Dynamic Repository Support**: When triggered by a GitHub Webhook push, the workflow automatically extracts `repository.name`, `repository.owner.login`, and `ref` from the webhook payload, allowing this single sync manager to handle **multiple different repositories** dynamically!

---

### 🔒 Publishing Policy (`AUTO_ACTIVATE = false`)
As per your requirement, newly created or updated workflows are saved with their full nodes, connections, and settings, but are **NOT** automatically published. You review them inside N8N and toggle the **Active (ON)** switch when you decide they are ready for production.
